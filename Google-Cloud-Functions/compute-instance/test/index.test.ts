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

const mockProject = jest.fn();
const mockGetProjectId = jest.fn();
const mockInsert = jest.fn();
const mockAggregatedListAsync = jest.fn();
const mockDelete = jest.fn();
const mockWait = jest.fn();
const mockRequestGet = jest.fn();
const mockResponseStatus = jest.fn();
const mockResponseSend = jest.fn();

// eslint-disable-next-line node/no-unpublished-import
import { v4 as uuidV4 } from 'uuid';
import parameters from '../src/parameters.json';
const {
    createComputeInstance,
    listAllComputeInstances,
    deleteComputeInstance
} = require('../src/index');

jest.mock('gcp-metadata', () => {
    const originalModule = jest.requireActual('gcp-metadata');

    return {
        ...originalModule,
        project: mockProject
    };
});

jest.mock('@google-cloud/compute', () => {
    const originalModule = jest.requireActual('@google-cloud/compute');

    return {
        ...originalModule,
        InstancesClient: jest.fn(() => {
            return {
                getProjectId: mockGetProjectId,
                insert: mockInsert,
                aggregatedListAsync: mockAggregatedListAsync,
                delete: mockDelete
            };
        }),
        ZoneOperationsClient: jest.fn(() => {
            return {
                wait: mockWait
            };
        })
    };
});

const projectNumber = `test-project-number-${uuidV4()}`;
const projectIdentifier = `test-project-${uuidV4()}`;
const FREE_ZONE = `${parameters.FREE_TIER_REGION}-${parameters.FREE_TIER_ZONE}`;
const MACHINE_TYPE = 'e2-micro';
const NETWORK_NAME = 'global/networks/default';
const NETWORK_TIER = 'PREMIUM';
const SOURCE_IMAGE =
    'projects/debian-cloud/global/images/debian-11-bullseye-v20220719';
const DISK_SIZE_GB = '10';
const DISK_TYPE = 'pd-standard';

describe('Test compute-instance: ', () => {
    beforeAll(() => {
        mockProject.mockImplementationOnce(parameter => {
            if (parameter === 'numeric-project-id') {
                return Promise.resolve(projectNumber);
            }

            return Promise.resolve(undefined);
        });
        mockGetProjectId.mockResolvedValueOnce(projectIdentifier);
    });

    beforeEach(() => {
        jest.clearAllMocks();
        mockInsert.mockClear();
        mockAggregatedListAsync.mockClear();
        mockDelete.mockClear();
        mockWait.mockClear();
        mockRequestGet.mockClear();
        mockResponseStatus.mockClear();
        mockResponseSend.mockClear();
    });

    interface RequestGet {
        (parameter: string): string;
    }

    interface Parameter {
        key: string;
        value: string;
    }

    interface Request {
        method: string;
        get: RequestGet;
        body: {
            name: string;
            zone?: string;
            scripts?: string[];
            parameters?: Parameter[];
        };
    }

    function createRequest(method: string, contentType: string): Request {
        mockRequestGet.mockImplementation(parameter => {
            if (parameter === 'content-type') {
                return contentType;
            }

            return undefined;
        });

        return {
            method,
            get: mockRequestGet,
            body: {
                name: `test-machine-${uuidV4()}`,
                scripts: [
                    `https://test-path-${uuidV4()}/test-script-1-${uuidV4()}`,
                    `https://test-path-${uuidV4()}/test-script-2-${uuidV4()}`
                ],
                parameters: [
                    {
                        key: `key-1-${uuidV4()}`,
                        value: `value-1-${uuidV4()}`
                    },
                    {
                        key: `key-2-${uuidV4()}`,
                        value: `value-2-${uuidV4()}`
                    }
                ]
            }
        };
    }

    interface ResponseStatus {
        (status: number): Response;
    }

    interface ResponseSend {
        (body: string): Response;
    }

    interface Response {
        status: ResponseStatus;
        send: ResponseSend;
    }

    function createResponse(): Response {
        return {
            status: mockResponseStatus,
            send: mockResponseSend
        };
    }

    describe('Test createComputeInstance: ', () => {
        test('POST JSON with no scripts, and no parameters', async () => {
            const request = createRequest('POST', 'application/json');

            request.body.scripts = undefined;
            request.body.parameters = undefined;
            const response = createResponse();

            mockInsert.mockResolvedValueOnce([{ name: request.body.name }]);
            mockResponseStatus.mockReturnValueOnce(response);
            mockResponseSend.mockReturnValueOnce(response);

            await createComputeInstance(request, response);

            expect(mockProject).toBeCalledTimes(1);
            expect(mockGetProjectId).toBeCalledTimes(1);
            expect(mockRequestGet).toBeCalledTimes(1);
            expect(mockRequestGet.mock.calls[0][0]).toBe('content-type');
            expect(mockInsert).toBeCalledTimes(1);
            expect(mockInsert.mock.calls[0][0].project).toBe(projectIdentifier);
            expect(mockInsert.mock.calls[0][0].zone).toBe(FREE_ZONE);
            expect(mockInsert.mock.calls[0][0].instanceResource.name).toBe(
                request.body.name
            );
            expect(
                mockInsert.mock.calls[0][0].instanceResource.tags.items.length
            ).toBe(1);
            expect(
                mockInsert.mock.calls[0][0].instanceResource.tags.items[0]
            ).toBe(request.body.name);
            expect(
                mockInsert.mock.calls[0][0].instanceResource.machineType
            ).toBe(`zones/${FREE_ZONE}/machineTypes/${MACHINE_TYPE}`);
            expect(mockInsert.mock.calls[0][0].instanceResource.zone).toBe(
                FREE_ZONE
            );
            expect(
                mockInsert.mock.calls[0][0].instanceResource.networkInterfaces
                    .length
            ).toBe(1);
            expect(
                mockInsert.mock.calls[0][0].instanceResource
                    .networkInterfaces[0].name
            ).toBe(NETWORK_NAME);
            expect(
                mockInsert.mock.calls[0][0].instanceResource
                    .networkInterfaces[0].accessConfigs.length
            ).toBe(1);
            expect(
                mockInsert.mock.calls[0][0].instanceResource
                    .networkInterfaces[0].accessConfigs[0].networkTier
            ).toBe(NETWORK_TIER);
            expect(
                mockInsert.mock.calls[0][0].instanceResource.disks.length
            ).toBe(1);
            expect(
                mockInsert.mock.calls[0][0].instanceResource.disks[0].boot
            ).toBe(true);
            expect(
                mockInsert.mock.calls[0][0].instanceResource.disks[0]
                    .initializeParams.sourceImage
            ).toBe(SOURCE_IMAGE);
            expect(
                mockInsert.mock.calls[0][0].instanceResource.disks[0]
                    .initializeParams.diskSizeGb
            ).toBe(DISK_SIZE_GB);
            expect(
                mockInsert.mock.calls[0][0].instanceResource.disks[0]
                    .initializeParams.diskType
            ).toBe(`zones/${FREE_ZONE}/diskTypes/${DISK_TYPE}`);
            expect(
                mockInsert.mock.calls[0][0].instanceResource.disks[0].autoDelete
            ).toBe(true);
            expect(
                mockInsert.mock.calls[0][0].instanceResource.serviceAccounts
                    .length
            ).toBe(1);
            expect(
                mockInsert.mock.calls[0][0].instanceResource.serviceAccounts[0]
                    .email
            ).toBe(`${projectNumber}-compute@developer.gserviceaccount.com`);
            expect(
                mockInsert.mock.calls[0][0].instanceResource.serviceAccounts[0]
                    .scopes.length
            ).toBe(5);
            expect(
                mockInsert.mock.calls[0][0].instanceResource.serviceAccounts[0]
                    .scopes[0]
            ).toBe('https://www.googleapis.com/auth/compute');
            expect(
                mockInsert.mock.calls[0][0].instanceResource.serviceAccounts[0]
                    .scopes[1]
            ).toBe('https://www.googleapis.com/auth/logging.write');
            expect(
                mockInsert.mock.calls[0][0].instanceResource.serviceAccounts[0]
                    .scopes[2]
            ).toBe('https://www.googleapis.com/auth/monitoring.write');
            expect(
                mockInsert.mock.calls[0][0].instanceResource.serviceAccounts[0]
                    .scopes[3]
            ).toBe('https://www.googleapis.com/auth/servicecontrol');
            expect(
                mockInsert.mock.calls[0][0].instanceResource.serviceAccounts[0]
                    .scopes[4]
            ).toBe('https://www.googleapis.com/auth/trace.append');
            expect(
                mockInsert.mock.calls[0][0].instanceResource.metadata
            ).not.toBeDefined();
            expect(mockWait).toBeCalledTimes(1);
            expect(mockWait.mock.calls[0][0].operation).toBe(request.body.name);
            expect(mockWait.mock.calls[0][0].project).toBe(projectIdentifier);
            expect(mockWait.mock.calls[0][0].zone).toBe(FREE_ZONE);
            expect(mockResponseStatus).toBeCalledTimes(1);
            expect(mockResponseStatus.mock.calls[0][0]).toBe(200);
            expect(mockResponseSend).toBeCalledTimes(1);
            expect(mockResponseSend.mock.calls[0][0]).toBe(
                `Created free instance: ${request.body.name} in: ${FREE_ZONE}.`
            );
            expect(mockAggregatedListAsync).not.toBeCalled();
            expect(mockDelete).not.toBeCalled();
        });

        test('POST Form with scripts, and no parameters', async () => {
            const request = createRequest(
                'POST',
                'application/x-www-form-urlencoded'
            );

            request.body.parameters = undefined;
            const response = createResponse();

            mockInsert.mockResolvedValueOnce([{ name: request.body.name }]);
            mockResponseStatus.mockReturnValueOnce(response);
            mockResponseSend.mockReturnValueOnce(response);

            await createComputeInstance(request, response);

            expect(mockProject).not.toBeCalled();
            expect(mockGetProjectId).not.toBeCalled();
            expect(mockRequestGet).toBeCalledTimes(1);
            expect(mockRequestGet.mock.calls[0][0]).toBe('content-type');
            expect(mockInsert).toBeCalledTimes(1);
            expect(mockInsert.mock.calls[0][0].project).toBe(projectIdentifier);
            expect(mockInsert.mock.calls[0][0].zone).toBe(FREE_ZONE);
            expect(mockInsert.mock.calls[0][0].instanceResource.name).toBe(
                request.body.name
            );
            expect(
                mockInsert.mock.calls[0][0].instanceResource.tags.items.length
            ).toBe(1);
            expect(
                mockInsert.mock.calls[0][0].instanceResource.tags.items[0]
            ).toBe(request.body.name);
            expect(
                mockInsert.mock.calls[0][0].instanceResource.machineType
            ).toBe(`zones/${FREE_ZONE}/machineTypes/${MACHINE_TYPE}`);
            expect(mockInsert.mock.calls[0][0].instanceResource.zone).toBe(
                FREE_ZONE
            );
            expect(
                mockInsert.mock.calls[0][0].instanceResource.networkInterfaces
                    .length
            ).toBe(1);
            expect(
                mockInsert.mock.calls[0][0].instanceResource
                    .networkInterfaces[0].name
            ).toBe(NETWORK_NAME);
            expect(
                mockInsert.mock.calls[0][0].instanceResource
                    .networkInterfaces[0].accessConfigs.length
            ).toBe(1);
            expect(
                mockInsert.mock.calls[0][0].instanceResource
                    .networkInterfaces[0].accessConfigs[0].networkTier
            ).toBe(NETWORK_TIER);
            expect(
                mockInsert.mock.calls[0][0].instanceResource.disks.length
            ).toBe(1);
            expect(
                mockInsert.mock.calls[0][0].instanceResource.disks[0].boot
            ).toBe(true);
            expect(
                mockInsert.mock.calls[0][0].instanceResource.disks[0]
                    .initializeParams.sourceImage
            ).toBe(SOURCE_IMAGE);
            expect(
                mockInsert.mock.calls[0][0].instanceResource.disks[0]
                    .initializeParams.diskSizeGb
            ).toBe(DISK_SIZE_GB);
            expect(
                mockInsert.mock.calls[0][0].instanceResource.disks[0]
                    .initializeParams.diskType
            ).toBe(`zones/${FREE_ZONE}/diskTypes/${DISK_TYPE}`);
            expect(
                mockInsert.mock.calls[0][0].instanceResource.disks[0].autoDelete
            ).toBe(true);
            expect(
                mockInsert.mock.calls[0][0].instanceResource.serviceAccounts
                    .length
            ).toBe(1);
            expect(
                mockInsert.mock.calls[0][0].instanceResource.serviceAccounts[0]
                    .email
            ).toBe(`${projectNumber}-compute@developer.gserviceaccount.com`);
            expect(
                mockInsert.mock.calls[0][0].instanceResource.serviceAccounts[0]
                    .scopes.length
            ).toBe(5);
            expect(
                mockInsert.mock.calls[0][0].instanceResource.serviceAccounts[0]
                    .scopes[0]
            ).toBe('https://www.googleapis.com/auth/compute');
            expect(
                mockInsert.mock.calls[0][0].instanceResource.serviceAccounts[0]
                    .scopes[1]
            ).toBe('https://www.googleapis.com/auth/logging.write');
            expect(
                mockInsert.mock.calls[0][0].instanceResource.serviceAccounts[0]
                    .scopes[2]
            ).toBe('https://www.googleapis.com/auth/monitoring.write');
            expect(
                mockInsert.mock.calls[0][0].instanceResource.serviceAccounts[0]
                    .scopes[3]
            ).toBe('https://www.googleapis.com/auth/servicecontrol');
            expect(
                mockInsert.mock.calls[0][0].instanceResource.serviceAccounts[0]
                    .scopes[4]
            ).toBe('https://www.googleapis.com/auth/trace.append');
            expect(
                mockInsert.mock.calls[0][0].instanceResource.metadata.items
                    .length
            ).toBe(1);
            expect(
                mockInsert.mock.calls[0][0].instanceResource.metadata.items[0]
                    .key
            ).toBe('startup-script');
            expect(
                mockInsert.mock.calls[0][0].instanceResource.metadata.items[0]
                    .value
            ).toMatch(new RegExp('^#!/bin/bash?'));
            expect(mockWait).toBeCalledTimes(1);
            expect(mockWait.mock.calls[0][0].operation).toBe(request.body.name);
            expect(mockWait.mock.calls[0][0].project).toBe(projectIdentifier);
            expect(mockWait.mock.calls[0][0].zone).toBe(FREE_ZONE);
            expect(mockResponseStatus).toBeCalledTimes(1);
            expect(mockResponseStatus.mock.calls[0][0]).toBe(200);
            expect(mockResponseSend).toBeCalledTimes(1);
            expect(mockResponseSend.mock.calls[0][0]).toBe(
                `Created free instance: ${request.body.name} in: ${FREE_ZONE}.`
            );
            expect(mockAggregatedListAsync).not.toBeCalled();
            expect(mockDelete).not.toBeCalled();
        });

        test('POST JSON with scripts, and with parameters', async () => {
            const request = createRequest('POST', 'application/json');
            const response = createResponse();

            mockInsert.mockResolvedValueOnce([{ name: request.body.name }]);
            mockResponseStatus.mockReturnValueOnce(response);
            mockResponseSend.mockReturnValueOnce(response);

            await createComputeInstance(request, response);

            expect(mockProject).not.toBeCalled();
            expect(mockGetProjectId).not.toBeCalled();
            expect(mockRequestGet).toBeCalledTimes(1);
            expect(mockRequestGet.mock.calls[0][0]).toBe('content-type');
            expect(mockInsert).toBeCalledTimes(1);
            expect(mockInsert.mock.calls[0][0].project).toBe(projectIdentifier);
            expect(mockInsert.mock.calls[0][0].zone).toBe(FREE_ZONE);
            expect(mockInsert.mock.calls[0][0].instanceResource.name).toBe(
                request.body.name
            );
            expect(
                mockInsert.mock.calls[0][0].instanceResource.tags.items.length
            ).toBe(1);
            expect(
                mockInsert.mock.calls[0][0].instanceResource.tags.items[0]
            ).toBe(request.body.name);
            expect(
                mockInsert.mock.calls[0][0].instanceResource.machineType
            ).toBe(`zones/${FREE_ZONE}/machineTypes/${MACHINE_TYPE}`);
            expect(mockInsert.mock.calls[0][0].instanceResource.zone).toBe(
                FREE_ZONE
            );
            expect(
                mockInsert.mock.calls[0][0].instanceResource.networkInterfaces
                    .length
            ).toBe(1);
            expect(
                mockInsert.mock.calls[0][0].instanceResource
                    .networkInterfaces[0].name
            ).toBe(NETWORK_NAME);
            expect(
                mockInsert.mock.calls[0][0].instanceResource
                    .networkInterfaces[0].accessConfigs.length
            ).toBe(1);
            expect(
                mockInsert.mock.calls[0][0].instanceResource
                    .networkInterfaces[0].accessConfigs[0].networkTier
            ).toBe(NETWORK_TIER);
            expect(
                mockInsert.mock.calls[0][0].instanceResource.disks.length
            ).toBe(1);
            expect(
                mockInsert.mock.calls[0][0].instanceResource.disks[0].boot
            ).toBe(true);
            expect(
                mockInsert.mock.calls[0][0].instanceResource.disks[0]
                    .initializeParams.sourceImage
            ).toBe(SOURCE_IMAGE);
            expect(
                mockInsert.mock.calls[0][0].instanceResource.disks[0]
                    .initializeParams.diskSizeGb
            ).toBe(DISK_SIZE_GB);
            expect(
                mockInsert.mock.calls[0][0].instanceResource.disks[0]
                    .initializeParams.diskType
            ).toBe(`zones/${FREE_ZONE}/diskTypes/${DISK_TYPE}`);
            expect(
                mockInsert.mock.calls[0][0].instanceResource.disks[0].autoDelete
            ).toBe(true);
            expect(
                mockInsert.mock.calls[0][0].instanceResource.serviceAccounts
                    .length
            ).toBe(1);
            expect(
                mockInsert.mock.calls[0][0].instanceResource.serviceAccounts[0]
                    .email
            ).toBe(`${projectNumber}-compute@developer.gserviceaccount.com`);
            expect(
                mockInsert.mock.calls[0][0].instanceResource.serviceAccounts[0]
                    .scopes.length
            ).toBe(5);
            expect(
                mockInsert.mock.calls[0][0].instanceResource.serviceAccounts[0]
                    .scopes[0]
            ).toBe('https://www.googleapis.com/auth/compute');
            expect(
                mockInsert.mock.calls[0][0].instanceResource.serviceAccounts[0]
                    .scopes[1]
            ).toBe('https://www.googleapis.com/auth/logging.write');
            expect(
                mockInsert.mock.calls[0][0].instanceResource.serviceAccounts[0]
                    .scopes[2]
            ).toBe('https://www.googleapis.com/auth/monitoring.write');
            expect(
                mockInsert.mock.calls[0][0].instanceResource.serviceAccounts[0]
                    .scopes[3]
            ).toBe('https://www.googleapis.com/auth/servicecontrol');
            expect(
                mockInsert.mock.calls[0][0].instanceResource.serviceAccounts[0]
                    .scopes[4]
            ).toBe('https://www.googleapis.com/auth/trace.append');
            expect(
                mockInsert.mock.calls[0][0].instanceResource.metadata.items
                    .length
            ).toBe(1 + request.body.parameters!.length);
            expect(
                mockInsert.mock.calls[0][0].instanceResource.metadata.items[0]
                    .key
            ).toBe('startup-script');
            expect(
                mockInsert.mock.calls[0][0].instanceResource.metadata.items[0]
                    .value
            ).toMatch(new RegExp('^#!/bin/bash?'));
            expect(mockWait).toBeCalledTimes(1);
            expect(mockWait.mock.calls[0][0].operation).toBe(request.body.name);
            expect(mockWait.mock.calls[0][0].project).toBe(projectIdentifier);
            expect(mockWait.mock.calls[0][0].zone).toBe(FREE_ZONE);
            expect(mockResponseStatus).toBeCalledTimes(1);
            expect(mockResponseStatus.mock.calls[0][0]).toBe(200);
            expect(mockResponseSend).toBeCalledTimes(1);
            expect(mockResponseSend.mock.calls[0][0]).toBe(
                `Created free instance: ${request.body.name} in: ${FREE_ZONE}.`
            );
            expect(mockAggregatedListAsync).not.toBeCalled();
            expect(mockDelete).not.toBeCalled();
        });

        test('POST JSON with scripts, and with parameters, throws exception', async () => {
            const request = createRequest('POST', 'application/json');
            const response = createResponse();
            const errorMessage = `test-error-message-${uuidV4()}`;

            mockInsert.mockRejectedValueOnce(errorMessage);
            mockResponseStatus.mockReturnValueOnce(response);
            mockResponseSend.mockReturnValueOnce(response);

            await createComputeInstance(request, response);

            expect(mockProject).not.toBeCalled();
            expect(mockGetProjectId).not.toBeCalled();
            expect(mockRequestGet).toBeCalledTimes(1);
            expect(mockRequestGet.mock.calls[0][0]).toBe('content-type');
            expect(mockInsert).toBeCalledTimes(1);
            expect(mockInsert.mock.calls[0][0].project).toBe(projectIdentifier);
            expect(mockInsert.mock.calls[0][0].zone).toBe(FREE_ZONE);
            expect(mockInsert.mock.calls[0][0].instanceResource.name).toBe(
                request.body.name
            );
            expect(
                mockInsert.mock.calls[0][0].instanceResource.tags.items.length
            ).toBe(1);
            expect(
                mockInsert.mock.calls[0][0].instanceResource.tags.items[0]
            ).toBe(request.body.name);
            expect(
                mockInsert.mock.calls[0][0].instanceResource.machineType
            ).toBe(`zones/${FREE_ZONE}/machineTypes/${MACHINE_TYPE}`);
            expect(mockInsert.mock.calls[0][0].instanceResource.zone).toBe(
                FREE_ZONE
            );
            expect(
                mockInsert.mock.calls[0][0].instanceResource.networkInterfaces
                    .length
            ).toBe(1);
            expect(
                mockInsert.mock.calls[0][0].instanceResource
                    .networkInterfaces[0].name
            ).toBe(NETWORK_NAME);
            expect(
                mockInsert.mock.calls[0][0].instanceResource
                    .networkInterfaces[0].accessConfigs.length
            ).toBe(1);
            expect(
                mockInsert.mock.calls[0][0].instanceResource
                    .networkInterfaces[0].accessConfigs[0].networkTier
            ).toBe(NETWORK_TIER);
            expect(
                mockInsert.mock.calls[0][0].instanceResource.disks.length
            ).toBe(1);
            expect(
                mockInsert.mock.calls[0][0].instanceResource.disks[0].boot
            ).toBe(true);
            expect(
                mockInsert.mock.calls[0][0].instanceResource.disks[0]
                    .initializeParams.sourceImage
            ).toBe(SOURCE_IMAGE);
            expect(
                mockInsert.mock.calls[0][0].instanceResource.disks[0]
                    .initializeParams.diskSizeGb
            ).toBe(DISK_SIZE_GB);
            expect(
                mockInsert.mock.calls[0][0].instanceResource.disks[0]
                    .initializeParams.diskType
            ).toBe(`zones/${FREE_ZONE}/diskTypes/${DISK_TYPE}`);
            expect(
                mockInsert.mock.calls[0][0].instanceResource.disks[0].autoDelete
            ).toBe(true);
            expect(
                mockInsert.mock.calls[0][0].instanceResource.serviceAccounts
                    .length
            ).toBe(1);
            expect(
                mockInsert.mock.calls[0][0].instanceResource.serviceAccounts[0]
                    .email
            ).toBe(`${projectNumber}-compute@developer.gserviceaccount.com`);
            expect(
                mockInsert.mock.calls[0][0].instanceResource.serviceAccounts[0]
                    .scopes.length
            ).toBe(5);
            expect(
                mockInsert.mock.calls[0][0].instanceResource.serviceAccounts[0]
                    .scopes[0]
            ).toBe('https://www.googleapis.com/auth/compute');
            expect(
                mockInsert.mock.calls[0][0].instanceResource.serviceAccounts[0]
                    .scopes[1]
            ).toBe('https://www.googleapis.com/auth/logging.write');
            expect(
                mockInsert.mock.calls[0][0].instanceResource.serviceAccounts[0]
                    .scopes[2]
            ).toBe('https://www.googleapis.com/auth/monitoring.write');
            expect(
                mockInsert.mock.calls[0][0].instanceResource.serviceAccounts[0]
                    .scopes[3]
            ).toBe('https://www.googleapis.com/auth/servicecontrol');
            expect(
                mockInsert.mock.calls[0][0].instanceResource.serviceAccounts[0]
                    .scopes[4]
            ).toBe('https://www.googleapis.com/auth/trace.append');
            expect(
                mockInsert.mock.calls[0][0].instanceResource.metadata.items
                    .length
            ).toBe(1 + request.body.parameters!.length);
            expect(
                mockInsert.mock.calls[0][0].instanceResource.metadata.items[0]
                    .key
            ).toBe('startup-script');
            expect(
                mockInsert.mock.calls[0][0].instanceResource.metadata.items[0]
                    .value
            ).toMatch(new RegExp('^#!/bin/bash?'));
            expect(mockWait).not.toBeCalled();
            expect(mockResponseStatus).toBeCalledTimes(1);
            expect(mockResponseStatus.mock.calls[0][0]).toBe(500);
            expect(mockResponseSend).toBeCalledTimes(1);
            expect(mockResponseSend.mock.calls[0][0]).toBe(
                `Error processing request to create instance: ${
                    request.body.name
                }. caughtException: ${JSON.stringify(errorMessage)}`
            );
            expect(mockAggregatedListAsync).not.toBeCalled();
            expect(mockDelete).not.toBeCalled();
        });

        test('POST JSON with invalid content-type', async () => {
            const request = createRequest('POST', 'invalid-content-type');
            const response = createResponse();

            mockResponseStatus.mockReturnValueOnce(response);
            mockResponseSend.mockReturnValueOnce(response);

            await createComputeInstance(request, response);

            expect(mockProject).not.toBeCalled();
            expect(mockGetProjectId).not.toBeCalled();
            expect(mockRequestGet).toBeCalledTimes(1);
            expect(mockRequestGet.mock.calls[0][0]).toBe('content-type');
            expect(mockInsert).not.toBeCalled();
            expect(mockWait).not.toBeCalled();
            expect(mockResponseStatus).toBeCalledTimes(1);
            expect(mockResponseStatus.mock.calls[0][0]).toBe(400);
            expect(mockResponseSend).toBeCalledTimes(1);
            expect(mockResponseSend.mock.calls[0][0]).toBe(
                "Content-Type request header must be either 'application/json' or 'application/x-www-form-urlencoded'."
            );
            expect(mockAggregatedListAsync).not.toBeCalled();
            expect(mockDelete).not.toBeCalled();
        });

        test('POST JSON with invalid method', async () => {
            const request = createRequest('INVALID-METHOD', 'application/json');
            const response = createResponse();

            mockResponseStatus.mockReturnValueOnce(response);
            mockResponseSend.mockReturnValueOnce(response);

            await createComputeInstance(request, response);

            expect(mockProject).not.toBeCalled();
            expect(mockGetProjectId).not.toBeCalled();
            expect(mockRequestGet).not.toBeCalled();
            expect(mockInsert).not.toBeCalled();
            expect(mockWait).not.toBeCalled();
            expect(mockResponseStatus).toBeCalledTimes(1);
            expect(mockResponseStatus.mock.calls[0][0]).toBe(400);
            expect(mockResponseSend).toBeCalledTimes(1);
            expect(mockResponseSend.mock.calls[0][0]).toBe(
                'Request method must be a POST.'
            );
            expect(mockAggregatedListAsync).not.toBeCalled();
            expect(mockDelete).not.toBeCalled();
        });
    });

    describe('Test listAllComputeInstances: ', () => {
        test('GET', async () => {
            const request = createRequest('GET', 'application/json');

            request.body.scripts = undefined;
            request.body.parameters = undefined;
            const response = createResponse();
            const mockNext = jest.fn();
            const zone1 = `test-zone-1-${uuidV4()}`;
            const instance11 = { name: `test-machine-1-1-${uuidV4()}` };
            const instance12 = { name: `test-machine-1-2-${uuidV4()}` };
            const value1 = [zone1, { instances: [instance11, instance12] }];

            mockNext.mockResolvedValueOnce({
                value: value1,
                done: false
            });
            const zone2 = `test-zone-2-${uuidV4()}`;
            const instance21 = { name: `test-machine-2-1-${uuidV4()}` };
            const instance22 = { name: `test-machine-2-2-${uuidV4()}` };
            const value2 = [zone2, { instances: [instance21, instance22] }];

            mockNext.mockResolvedValueOnce({
                value: value2,
                done: false
            });
            const zone3 = zone1;
            const instance31 = { name: `test-machine-3-1-${uuidV4()}` };
            const value3 = [zone3, { instances: [instance31] }];

            mockNext.mockResolvedValueOnce({
                value: value3,
                done: false
            });
            mockNext.mockResolvedValueOnce({ done: true });
            const mockAsyncIterator = jest.fn();

            mockAsyncIterator.mockImplementationOnce(() => {
                return {
                    next: mockNext
                };
            });
            mockAggregatedListAsync.mockImplementationOnce(argument => {
                if (argument.project === projectIdentifier) {
                    return {
                        [Symbol.asyncIterator]: mockAsyncIterator
                    };
                }

                return undefined;
            });
            mockResponseStatus.mockReturnValueOnce(response);
            mockResponseSend.mockReturnValueOnce(response);

            await listAllComputeInstances(request, response);

            expect(mockProject).not.toBeCalled();
            expect(mockGetProjectId).not.toBeCalled();
            expect(mockAggregatedListAsync).toBeCalledTimes(1);
            expect(mockAggregatedListAsync.mock.calls[0][0].project).toBe(
                projectIdentifier
            );
            expect(mockAsyncIterator).toBeCalledTimes(1);
            expect(mockNext).toBeCalledTimes(4);
            expect(mockResponseStatus).toBeCalledTimes(1);
            expect(mockResponseStatus.mock.calls[0][0]).toBe(200);
            expect(mockResponseSend).toBeCalledTimes(1);
            expect(mockResponseSend.mock.calls[0][0]).toBe(
                JSON.stringify([
                    [
                        zone1,
                        [instance11.name, instance12.name, instance31.name]
                    ],
                    [zone2, [instance21.name, instance22.name]]
                ])
            );
            expect(mockRequestGet).not.toBeCalled();
            expect(mockInsert).not.toBeCalled();
            expect(mockWait).not.toBeCalled();
            expect(mockDelete).not.toBeCalled();
        });

        test('GET throws exception', async () => {
            const request = createRequest('GET', 'application/json');

            request.body.scripts = undefined;
            request.body.parameters = undefined;
            const response = createResponse();
            const errorMessage = `test-error-message-${uuidV4()}`;

            mockAggregatedListAsync.mockImplementation(() => {
                throw errorMessage;
            });
            mockResponseStatus.mockReturnValueOnce(response);
            mockResponseSend.mockReturnValueOnce(response);

            await listAllComputeInstances(request, response);

            expect(mockProject).not.toBeCalled();
            expect(mockGetProjectId).not.toBeCalled();
            expect(mockAggregatedListAsync).toBeCalledTimes(1);
            expect(mockAggregatedListAsync.mock.calls[0][0].project).toBe(
                projectIdentifier
            );
            expect(mockResponseStatus).toBeCalledTimes(1);
            expect(mockResponseStatus.mock.calls[0][0]).toBe(500);
            expect(mockResponseSend).toBeCalledTimes(1);
            expect(mockResponseSend.mock.calls[0][0]).toBe(
                `Error processing request to get all instances. caughtException: ${JSON.stringify(
                    errorMessage
                )}`
            );
            expect(mockRequestGet).not.toBeCalled();
            expect(mockInsert).not.toBeCalled();
            expect(mockWait).not.toBeCalled();
            expect(mockDelete).not.toBeCalled();
        });

        test('GET with invalid method', async () => {
            const request = createRequest('INVALID-METHOD', 'application/json');

            request.body.scripts = undefined;
            request.body.parameters = undefined;
            const response = createResponse();

            mockResponseStatus.mockReturnValueOnce(response);
            mockResponseSend.mockReturnValueOnce(response);

            await listAllComputeInstances(request, response);

            expect(mockProject).not.toBeCalled();
            expect(mockGetProjectId).not.toBeCalled();
            expect(mockAggregatedListAsync).not.toBeCalled();
            expect(mockResponseStatus).toBeCalledTimes(1);
            expect(mockResponseStatus.mock.calls[0][0]).toBe(400);
            expect(mockResponseSend).toBeCalledTimes(1);
            expect(mockResponseSend.mock.calls[0][0]).toBe(
                'Request method must be a GET.'
            );
            expect(mockRequestGet).not.toBeCalled();
            expect(mockInsert).not.toBeCalled();
            expect(mockWait).not.toBeCalled();
            expect(mockDelete).not.toBeCalled();
        });
    });

    describe('Test deleteComputeInstance: ', () => {
        test('POST JSON with no zone, no scripts, and no parameters', async () => {
            const request = createRequest('POST', 'application/json');

            request.body.scripts = undefined;
            request.body.parameters = undefined;
            const response = createResponse();

            mockDelete.mockResolvedValueOnce([{ name: request.body.name }]);
            mockResponseStatus.mockReturnValueOnce(response);
            mockResponseSend.mockReturnValueOnce(response);

            await deleteComputeInstance(request, response);

            expect(mockProject).not.toBeCalled();
            expect(mockGetProjectId).not.toBeCalled();
            expect(mockRequestGet).toBeCalledTimes(1);
            expect(mockRequestGet.mock.calls[0][0]).toBe('content-type');
            expect(mockDelete).toBeCalledTimes(1);
            expect(mockDelete.mock.calls[0][0].instance).toBe(
                request.body.name
            );
            expect(mockDelete.mock.calls[0][0].project).toBe(projectIdentifier);
            expect(mockDelete.mock.calls[0][0].zone).toBe(FREE_ZONE);
            expect(mockWait).toBeCalledTimes(1);
            expect(mockWait.mock.calls[0][0].operation).toBe(request.body.name);
            expect(mockWait.mock.calls[0][0].project).toBe(projectIdentifier);
            expect(mockWait.mock.calls[0][0].zone).toBe(FREE_ZONE);
            expect(mockResponseStatus).toBeCalledTimes(1);
            expect(mockResponseStatus.mock.calls[0][0]).toBe(200);
            expect(mockResponseSend).toBeCalledTimes(1);
            expect(mockResponseSend.mock.calls[0][0]).toBe(
                `Deleted instance: ${request.body.name} in: ${FREE_ZONE}.`
            );
            expect(mockInsert).not.toBeCalled();
            expect(mockAggregatedListAsync).not.toBeCalled();
        });

        test('POST Form with zone, scripts, and parameters', async () => {
            const request = createRequest(
                'POST',
                'application/x-www-form-urlencoded'
            );

            request.body.zone = `test-zone-${uuidV4()}`;
            const response = createResponse();

            mockDelete.mockResolvedValueOnce([{ name: request.body.name }]);
            mockResponseStatus.mockReturnValueOnce(response);
            mockResponseSend.mockReturnValueOnce(response);

            await deleteComputeInstance(request, response);

            expect(mockProject).not.toBeCalled();
            expect(mockGetProjectId).not.toBeCalled();
            expect(mockRequestGet).toBeCalledTimes(1);
            expect(mockRequestGet.mock.calls[0][0]).toBe('content-type');
            expect(mockDelete).toBeCalledTimes(1);
            expect(mockDelete.mock.calls[0][0].instance).toBe(
                request.body.name
            );
            expect(mockDelete.mock.calls[0][0].project).toBe(projectIdentifier);
            expect(mockDelete.mock.calls[0][0].zone).toBe(request.body.zone);
            expect(mockWait).toBeCalledTimes(1);
            expect(mockWait.mock.calls[0][0].operation).toBe(request.body.name);
            expect(mockWait.mock.calls[0][0].project).toBe(projectIdentifier);
            expect(mockWait.mock.calls[0][0].zone).toBe(request.body.zone);
            expect(mockResponseStatus).toBeCalledTimes(1);
            expect(mockResponseStatus.mock.calls[0][0]).toBe(200);
            expect(mockResponseSend).toBeCalledTimes(1);
            expect(mockResponseSend.mock.calls[0][0]).toBe(
                `Deleted instance: ${request.body.name} in: ${request.body.zone}.`
            );
            expect(mockInsert).not.toBeCalled();
            expect(mockAggregatedListAsync).not.toBeCalled();
        });

        test('POST JSON with scripts, and with parameters, throws exception', async () => {
            const request = createRequest('POST', 'application/json');

            request.body.zone = `test-zone-${uuidV4()}`;
            const response = createResponse();
            const errorMessage = `test-error-message-${uuidV4()}`;

            mockDelete.mockRejectedValueOnce(errorMessage);
            mockResponseStatus.mockReturnValueOnce(response);
            mockResponseSend.mockReturnValueOnce(response);

            await deleteComputeInstance(request, response);

            expect(mockProject).not.toBeCalled();
            expect(mockGetProjectId).not.toBeCalled();
            expect(mockRequestGet).toBeCalledTimes(1);
            expect(mockRequestGet.mock.calls[0][0]).toBe('content-type');
            expect(mockDelete).toBeCalledTimes(1);
            expect(mockDelete.mock.calls[0][0].instance).toBe(
                request.body.name
            );
            expect(mockDelete.mock.calls[0][0].project).toBe(projectIdentifier);
            expect(mockDelete.mock.calls[0][0].zone).toBe(request.body.zone);
            expect(mockWait).not.toBeCalled();
            expect(mockResponseStatus).toBeCalledTimes(1);
            expect(mockResponseStatus.mock.calls[0][0]).toBe(500);
            expect(mockResponseSend).toBeCalledTimes(1);
            expect(mockResponseSend.mock.calls[0][0]).toBe(
                `Error processing request to delete instance: ${
                    request.body.name
                } in zone: ${
                    request.body.zone
                }. caughtException: ${JSON.stringify(errorMessage)}`
            );
            expect(mockInsert).not.toBeCalled();
            expect(mockAggregatedListAsync).not.toBeCalled();
        });

        test('POST JSON with invalid content-type', async () => {
            const request = createRequest('POST', 'invalid-content-type');
            const response = createResponse();

            mockResponseStatus.mockReturnValueOnce(response);
            mockResponseSend.mockReturnValueOnce(response);

            await deleteComputeInstance(request, response);

            expect(mockProject).not.toBeCalled();
            expect(mockGetProjectId).not.toBeCalled();
            expect(mockRequestGet).toBeCalledTimes(1);
            expect(mockRequestGet.mock.calls[0][0]).toBe('content-type');
            expect(mockDelete).not.toBeCalled();
            expect(mockWait).not.toBeCalled();
            expect(mockResponseStatus).toBeCalledTimes(1);
            expect(mockResponseStatus.mock.calls[0][0]).toBe(400);
            expect(mockResponseSend).toBeCalledTimes(1);
            expect(mockResponseSend.mock.calls[0][0]).toBe(
                "Content-Type request header must be either 'application/json' or 'application/x-www-form-urlencoded'."
            );
            expect(mockInsert).not.toBeCalled();
            expect(mockAggregatedListAsync).not.toBeCalled();
        });

        test('POST JSON with invalid method', async () => {
            const request = createRequest('INVALID-METHOD', 'application/json');
            const response = createResponse();

            mockResponseStatus.mockReturnValueOnce(response);
            mockResponseSend.mockReturnValueOnce(response);

            await deleteComputeInstance(request, response);

            expect(mockProject).not.toBeCalled();
            expect(mockGetProjectId).not.toBeCalled();
            expect(mockRequestGet).not.toBeCalled();
            expect(mockDelete).not.toBeCalled();
            expect(mockWait).not.toBeCalled();
            expect(mockResponseStatus).toBeCalledTimes(1);
            expect(mockResponseStatus.mock.calls[0][0]).toBe(400);
            expect(mockResponseSend).toBeCalledTimes(1);
            expect(mockResponseSend.mock.calls[0][0]).toBe(
                'Request method must be a POST.'
            );
            expect(mockInsert).not.toBeCalled();
            expect(mockAggregatedListAsync).not.toBeCalled();
        });
    });
});
