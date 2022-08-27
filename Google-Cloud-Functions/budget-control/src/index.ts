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

import { PubsubMessage } from '@google-cloud/pubsub/build/src/publisher';
import { CloudBillingClient } from '@google-cloud/billing';

const cloudBillingClient = new CloudBillingClient();

exports.stopProjectBilling = async (
    pubsubEvent: PubsubMessage
): Promise<string> => {
    const pubsubData = JSON.parse(
        Buffer.from(pubsubEvent.data as string, 'base64').toString()
    );

    if (
        // eslint-disable-next-line no-prototype-builtins
        pubsubData.hasOwnProperty('costAmount') &&
        // eslint-disable-next-line no-prototype-builtins
        pubsubData.hasOwnProperty('budgetAmount')
    ) {
        if (pubsubData.costAmount <= pubsubData.budgetAmount) {
            return `No action necessary. (Current cost: ${pubsubData.costAmount} is less than budgeted amount: ${pubsubData.budgetAmount})`;
        }
        const projectIdentifier = await cloudBillingClient.getProjectId();
        const [projectBillingInformation] =
            await cloudBillingClient.getProjectBillingInfo({
                name: `projects/${projectIdentifier}`
            });

        if (projectBillingInformation.projectId !== projectIdentifier) {
            throw new Error(
                `The project identifier in the project billing information: ${projectBillingInformation.projectId} does NOT match the billing project identifier: ${projectIdentifier}!`
            );
        }
        if (projectBillingInformation.billingEnabled) {
            projectBillingInformation.billingAccountName = '';
            projectBillingInformation.billingEnabled = false;
            const [updatedProjectBillingInformation] =
                await cloudBillingClient.updateProjectBillingInfo({
                    name: `projects/${projectIdentifier}`,
                    projectBillingInfo: projectBillingInformation
                });

            if (updatedProjectBillingInformation.billingEnabled) {
                throw new Error(
                    `Failed to disable billing on project: ${updatedProjectBillingInformation.name}.`
                );
            }

            return `Billing disabled on ${
                updatedProjectBillingInformation.name
            }. updatedProjectBillingInfoResponse: ${JSON.stringify(
                updatedProjectBillingInformation
            )}.`;
        } else {
            return `Billing already disabled for project: ${projectIdentifier}.`;
        }
    } else {
        throw new Error(
            `Incorrect budget billing notification format: ${JSON.stringify(
                pubsubData
            )}`
        );
    }
};
