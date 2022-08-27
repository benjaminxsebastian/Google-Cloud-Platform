// Copyright 2022 Benjamin Sebastian
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import parameters from './parameters.json';
import {
    Request as ExpressRequest,
    Response as ExpressResponse
} from 'express';
import { project } from 'gcp-metadata';
import {
    protos as computeProtos,
    InstancesClient,
    ZoneOperationsClient
} from '@google-cloud/compute';

const instancesClient = new InstancesClient();
const zoneOperationsClient = new ZoneOperationsClient();

let projectNumber: string;
let projectIdentifier: string;

async function initializeProjectNumber() {
    if (!projectNumber) {
        projectNumber = await project('numeric-project-id');
    }
}

async function initializeProjectIdentifier() {
    if (!projectIdentifier) {
        projectIdentifier = await instancesClient.getProjectId();
    }
}

async function initializeProjectMetadata() {
    await initializeProjectNumber();
    await initializeProjectIdentifier();
}

(async () => {
    await initializeProjectMetadata();
})();

const FREE_ZONE = `${parameters.FREE_TIER_REGION}-${parameters.FREE_TIER_ZONE}`;
const MACHINE_TYPE = 'e2-micro';
const NETWORK_NAME = 'global/networks/default';
const NETWORK_TIER = 'PREMIUM';
const SOURCE_IMAGE =
    'projects/debian-cloud/global/images/debian-11-bullseye-v20220719';
const DISK_SIZE_GB = '10';
const DISK_TYPE = 'pd-standard';

exports.createComputeInstance = async (
    request: ExpressRequest,
    response: ExpressResponse
) => {
    let name: string;
    let scripts: string[] | undefined;
    let parameters: computeProtos.google.cloud.compute.v1.IItems[] | undefined;
    let startupCommand;
    let metadata: computeProtos.google.cloud.compute.v1.IMetadata | undefined;
    let insertResult;

    await initializeProjectMetadata();
    switch (request.method) {
        case 'POST':
            switch (request.get('content-type')) {
                case 'application/json':
                case 'application/x-www-form-urlencoded':
                    try {
                        ({ name, scripts, parameters } = request.body);
                        if (scripts) {
                            startupCommand = '#!/bin/bash';
                            startupCommand += '\n';
                            startupCommand +=
                                '\nPACKAGE_INSTALLED=$(dpkg-query -W --showformat=\'${Status}\n\' dos2unix | grep "install ok installed")';
                            startupCommand += '\n';
                            startupCommand +=
                                '\nif [ "$PACKAGE_INSTALLED" = "" ]; then';
                            startupCommand += '\n    apt -y install dos2unix';
                            startupCommand += '\nfi';
                            for (const scriptPath of scripts) {
                                const script = scriptPath.substring(
                                    scriptPath.lastIndexOf('/') + 1
                                );

                                startupCommand += '\nmkdir -p startupScripts';
                                startupCommand += '\ncd startupScripts';
                                startupCommand += `\nif [ ! -f ./${script} ]; then`;
                                startupCommand += `\n    curl ${scriptPath} -o ${script}`;
                                startupCommand += `\n    dos2unix ./${script}`;
                                startupCommand += `\n    chmod +x ./${script}`;
                                startupCommand += '\nfi';
                                startupCommand += `\n./${script}`;
                                startupCommand += '\ncd ..';
                            }
                            metadata = {
                                items: [
                                    {
                                        key: 'startup-script',
                                        value: startupCommand
                                    }
                                ]
                            };
                            if (parameters) {
                                metadata.items =
                                    metadata.items!.concat(parameters);
                            }
                        }
                        [insertResult] = await instancesClient.insert({
                            project: projectIdentifier,
                            zone: FREE_ZONE,
                            instanceResource: {
                                name,
                                tags: { items: [name] },
                                machineType: `zones/${FREE_ZONE}/machineTypes/${MACHINE_TYPE}`,
                                zone: FREE_ZONE,
                                networkInterfaces: [
                                    {
                                        name: NETWORK_NAME,
                                        accessConfigs: [
                                            {
                                                networkTier: NETWORK_TIER
                                            }
                                        ]
                                    }
                                ],
                                disks: [
                                    {
                                        boot: true,
                                        initializeParams: {
                                            sourceImage: SOURCE_IMAGE,
                                            diskSizeGb: DISK_SIZE_GB,
                                            diskType: `zones/${FREE_ZONE}/diskTypes/${DISK_TYPE}`
                                        },
                                        autoDelete: true
                                    }
                                ],
                                serviceAccounts: [
                                    {
                                        email: `${projectNumber}-compute@developer.gserviceaccount.com`,
                                        scopes: [
                                            'https://www.googleapis.com/auth/compute',
                                            'https://www.googleapis.com/auth/logging.write',
                                            'https://www.googleapis.com/auth/monitoring.write',
                                            'https://www.googleapis.com/auth/servicecontrol',
                                            'https://www.googleapis.com/auth/trace.append'
                                        ]
                                    }
                                ],
                                metadata
                            }
                        });
                        await zoneOperationsClient.wait({
                            operation: insertResult.name,
                            project: projectIdentifier,
                            zone: FREE_ZONE
                        });
                        response
                            .status(200)
                            .send(
                                `Created free instance: ${name} in: ${FREE_ZONE}.`
                            );
                    } catch (caughtException) {
                        response
                            .status(500)
                            .send(
                                `Error processing request to create instance: ${
                                    request.body.name
                                }. caughtException: ${JSON.stringify(
                                    caughtException
                                )}`
                            );
                    }
                    break;
                default:
                    response
                        .status(400)
                        .send(
                            "Content-Type request header must be either 'application/json' or 'application/x-www-form-urlencoded'."
                        );
                    break;
            }
            break;
        default:
            response.status(400).send('Request method must be a POST.');
            break;
    }
};

exports.listAllComputeInstances = async (
    request: ExpressRequest,
    response: ExpressResponse
) => {
    let aggregatedListResult;
    const zonesInstances = new Map<string, string[]>();

    await initializeProjectMetadata();
    switch (request.method) {
        case 'GET':
            try {
                aggregatedListResult = instancesClient.aggregatedListAsync({
                    project: projectIdentifier
                });
                for await (const [zone, scopedList] of aggregatedListResult) {
                    if (scopedList.instances) {
                        for (const instance of scopedList.instances) {
                            if (instance.name) {
                                const zoneInstances =
                                    zonesInstances.get(zone) ?? [];

                                zoneInstances.push(instance.name);
                                zonesInstances.set(zone, zoneInstances);
                            }
                        }
                    }
                }
                response
                    .status(200)
                    .send(JSON.stringify(Array.from(zonesInstances.entries())));
            } catch (caughtException) {
                response
                    .status(500)
                    .send(
                        `Error processing request to get all instances. caughtException: ${JSON.stringify(
                            caughtException
                        )}`
                    );
            }
            break;
        default:
            response.status(400).send('Request method must be a GET.');
            break;
    }
};

exports.deleteComputeInstance = async (
    request: ExpressRequest,
    response: ExpressResponse
) => {
    let name: string;
    let zone: string | undefined;
    let deleteResult;

    await initializeProjectMetadata();
    switch (request.method) {
        case 'POST':
            switch (request.get('content-type')) {
                case 'application/json':
                case 'application/x-www-form-urlencoded':
                    try {
                        ({ name, zone } = request.body);
                        zone ??= FREE_ZONE;
                        [deleteResult] = await instancesClient.delete({
                            instance: name,
                            project: projectIdentifier,
                            zone
                        });
                        await zoneOperationsClient.wait({
                            operation: deleteResult.name,
                            project: projectIdentifier,
                            zone
                        });
                        response
                            .status(200)
                            .send(`Deleted instance: ${name} in: ${zone}.`);
                    } catch (caughtException) {
                        response
                            .status(500)
                            .send(
                                `Error processing request to delete instance: ${
                                    request.body.name
                                } in zone: ${zone}. caughtException: ${JSON.stringify(
                                    caughtException
                                )}`
                            );
                    }
                    break;
                default:
                    response
                        .status(400)
                        .send(
                            "Content-Type request header must be either 'application/json' or 'application/x-www-form-urlencoded'."
                        );
                    break;
            }
            break;
        default:
            response.status(400).send('Request method must be a POST.');
            break;
    }
};
