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

const mockGetProjectId = jest.fn();
const mockGetProjectBillingInfo = jest.fn();
const mockUpdateProjectBillingInfo = jest.fn();

// eslint-disable-next-line node/no-unpublished-import
import { v4 as uuidV4 } from 'uuid';
import { protos } from '@google-cloud/billing';
const { stopProjectBilling } = require('../src/index');

jest.mock('@google-cloud/billing', () => {
    const originalModule = jest.requireActual('@google-cloud/billing');

    return {
        ...originalModule,
        CloudBillingClient: jest.fn(() => {
            return {
                getProjectId: mockGetProjectId,
                getProjectBillingInfo: mockGetProjectBillingInfo,
                updateProjectBillingInfo: mockUpdateProjectBillingInfo
            };
        })
    };
});

describe('Test stopProjectBilling: ', () => {
    beforeEach(() => {
        jest.clearAllMocks();
        mockGetProjectId.mockClear();
        mockGetProjectBillingInfo.mockClear();
        mockUpdateProjectBillingInfo.mockClear();
    });

    function createPubSubEvent(
        costAmount: number | undefined,
        budgetAmount: number | undefined
    ): { data: string } {
        const pubsubData = {
            budgetDisplayName: `budget-${uuidV4()}`,
            alertThresholdExceeded: 1.0,
            costAmount,
            costIntervalStart: new Date(
                Date.now() - 1000 * 3600 * 24
            ).toISOString(),
            budgetAmount,
            budgetAmountType: 'SPECIFIED_AMOUNT',
            currencyCode: 'USD'
        };

        return {
            data: Buffer.from(JSON.stringify(pubsubData)).toString('base64')
        };
    }

    function createProjectBillingInformation(
        projectIdentifier: string,
        billingEnabled: boolean
    ): protos.google.cloud.billing.v1.ProjectBillingInfo {
        const projectBillingInformation =
            new protos.google.cloud.billing.v1.ProjectBillingInfo();

        projectBillingInformation.name = `test-project-${uuidV4()}`;
        projectBillingInformation.projectId = projectIdentifier;
        projectBillingInformation.billingAccountName = `project-billing-account-${uuidV4()}`;
        projectBillingInformation.billingEnabled = billingEnabled;

        return projectBillingInformation;
    }

    test('costAmount < budgetAmount', async () => {
        const costAmount = 0.12;
        const budgetAmount = 100.0;
        const pubsubEvent = createPubSubEvent(costAmount, budgetAmount);
        const result = await stopProjectBilling(pubsubEvent);

        expect(mockGetProjectId).not.toBeCalled();
        expect(mockGetProjectBillingInfo).not.toBeCalled();
        expect(mockUpdateProjectBillingInfo).not.toBeCalled();
        expect(result).toBe(
            `No action necessary. (Current cost: ${costAmount} is less than budgeted amount: ${budgetAmount})`
        );
    });

    test('costAmount === budgetAmount', async () => {
        const costAmount = 100.0;
        const budgetAmount = 100.0;
        const pubsubEvent = createPubSubEvent(costAmount, budgetAmount);
        const result = await stopProjectBilling(pubsubEvent);

        expect(mockGetProjectId).not.toBeCalled();
        expect(mockGetProjectBillingInfo).not.toBeCalled();
        expect(mockUpdateProjectBillingInfo).not.toBeCalled();
        expect(result).toBe(
            `No action necessary. (Current cost: ${costAmount} is less than budgeted amount: ${budgetAmount})`
        );
    });

    test('projectBillingInformation.projectId !== projectIdentifier', async () => {
        const projectIdentifier = uuidV4();

        mockGetProjectId.mockResolvedValueOnce(projectIdentifier);
        const projectBillingInformation = createProjectBillingInformation(
            uuidV4(),
            true
        );
        const projectBillingInformationArray = [projectBillingInformation];

        mockGetProjectBillingInfo.mockResolvedValueOnce(
            projectBillingInformationArray
        );

        const costAmount = 123.45;
        const budgetAmount = 100.0;
        const pubsubEvent = createPubSubEvent(costAmount, budgetAmount);

        await expect(stopProjectBilling(pubsubEvent)).rejects.toThrow(
            `The project identifier in the project billing information: ${projectBillingInformation.projectId} does NOT match the billing project identifier: ${projectIdentifier}!`
        );

        expect(mockGetProjectId).toBeCalledTimes(1);
        expect(mockGetProjectBillingInfo).toBeCalledTimes(1);
        expect(mockGetProjectBillingInfo.mock.calls[0][0].name).toBe(
            `projects/${projectIdentifier}`
        );
        expect(mockUpdateProjectBillingInfo).not.toBeCalled();
    });

    test('updatedProjectBillingInformation.billingEnabled === true', async () => {
        const projectIdentifier = uuidV4();

        mockGetProjectId.mockResolvedValueOnce(projectIdentifier);
        const projectBillingInformation = createProjectBillingInformation(
            projectIdentifier,
            true
        );
        const projectBillingInformationArray = [projectBillingInformation];

        mockGetProjectBillingInfo.mockResolvedValueOnce(
            projectBillingInformationArray
        );
        const projectBillingInformationClone = JSON.parse(
            JSON.stringify(projectBillingInformation)
        );
        const projectBillingInformationArrayClone = [
            projectBillingInformationClone
        ];

        mockUpdateProjectBillingInfo.mockResolvedValueOnce(
            projectBillingInformationArrayClone
        );

        const costAmount = 123.45;
        const budgetAmount = 100.0;
        const pubsubEvent = createPubSubEvent(costAmount, budgetAmount);

        await expect(stopProjectBilling(pubsubEvent)).rejects.toThrow(
            `Failed to disable billing on project: ${projectBillingInformation.name}.`
        );

        expect(mockGetProjectId).toBeCalledTimes(1);
        expect(mockGetProjectBillingInfo).toBeCalledTimes(1);
        expect(mockGetProjectBillingInfo.mock.calls[0][0].name).toBe(
            `projects/${projectIdentifier}`
        );
        expect(mockUpdateProjectBillingInfo).toBeCalledTimes(1);
        expect(mockUpdateProjectBillingInfo.mock.calls[0][0].name).toBe(
            `projects/${projectIdentifier}`
        );
        expect(
            mockUpdateProjectBillingInfo.mock.calls[0][0].projectBillingInfo
        ).toBe(projectBillingInformation);
    });

    test('success', async () => {
        const projectIdentifier = uuidV4();

        mockGetProjectId.mockResolvedValueOnce(projectIdentifier);
        const projectBillingInformation = createProjectBillingInformation(
            projectIdentifier,
            true
        );
        const projectBillingInformationArray = [projectBillingInformation];

        mockGetProjectBillingInfo.mockResolvedValueOnce(
            projectBillingInformationArray
        );
        mockUpdateProjectBillingInfo.mockResolvedValueOnce(
            projectBillingInformationArray
        );

        const costAmount = 123.45;
        const budgetAmount = 100.0;
        const pubsubEvent = createPubSubEvent(costAmount, budgetAmount);

        const result = await stopProjectBilling(pubsubEvent);

        expect(mockGetProjectId).toBeCalledTimes(1);
        expect(mockGetProjectBillingInfo).toBeCalledTimes(1);
        expect(mockGetProjectBillingInfo.mock.calls[0][0].name).toBe(
            `projects/${projectIdentifier}`
        );
        expect(mockUpdateProjectBillingInfo).toBeCalledTimes(1);
        expect(mockUpdateProjectBillingInfo.mock.calls[0][0].name).toBe(
            `projects/${projectIdentifier}`
        );
        expect(
            mockUpdateProjectBillingInfo.mock.calls[0][0].projectBillingInfo
        ).toBe(projectBillingInformation);
        expect(result).toBe(
            `Billing disabled on ${
                projectBillingInformation.name
            }. updatedProjectBillingInfoResponse: ${JSON.stringify(
                projectBillingInformation
            )}.`
        );
    });

    test('projectBillingInformation.billingEnabled === false', async () => {
        const projectIdentifier = uuidV4();

        mockGetProjectId.mockResolvedValueOnce(projectIdentifier);
        const projectBillingInformation = createProjectBillingInformation(
            projectIdentifier,
            false
        );
        const projectBillingInformationArray = [projectBillingInformation];

        mockGetProjectBillingInfo.mockResolvedValueOnce(
            projectBillingInformationArray
        );

        const costAmount = 123.45;
        const budgetAmount = 100.0;
        const pubsubEvent = createPubSubEvent(costAmount, budgetAmount);

        const result = await stopProjectBilling(pubsubEvent);

        expect(mockGetProjectId).toBeCalledTimes(1);
        expect(mockGetProjectBillingInfo).toBeCalledTimes(1);
        expect(mockGetProjectBillingInfo.mock.calls[0][0].name).toBe(
            `projects/${projectIdentifier}`
        );
        expect(mockUpdateProjectBillingInfo).not.toBeCalled();
        expect(result).toBe(
            `Billing already disabled for project: ${projectIdentifier}.`
        );
    });

    test('!pubsubData.costAmount', async () => {
        const costAmount = undefined;
        const budgetAmount = 100.0;
        const pubsubEvent = createPubSubEvent(costAmount, budgetAmount);

        await expect(stopProjectBilling(pubsubEvent)).rejects.toThrow(
            `Incorrect budget billing notification format: ${JSON.stringify(
                JSON.parse(Buffer.from(pubsubEvent.data, 'base64').toString())
            )}`
        );

        expect(mockGetProjectId).not.toBeCalled();
        expect(mockGetProjectBillingInfo).not.toBeCalled();
        expect(mockUpdateProjectBillingInfo).not.toBeCalled();
    });

    test('!pubsubData.budgetAmount', async () => {
        const costAmount = 123.45;
        const budgetAmount = undefined;
        const pubsubEvent = createPubSubEvent(costAmount, budgetAmount);

        await expect(stopProjectBilling(pubsubEvent)).rejects.toThrow(
            `Incorrect budget billing notification format: ${JSON.stringify(
                JSON.parse(Buffer.from(pubsubEvent.data, 'base64').toString())
            )}`
        );

        expect(mockGetProjectId).not.toBeCalled();
        expect(mockGetProjectBillingInfo).not.toBeCalled();
        expect(mockUpdateProjectBillingInfo).not.toBeCalled();
    });

    test('!pubsubData.costAmount && !pubsubData.budgetAmount', async () => {
        const costAmount = undefined;
        const budgetAmount = undefined;
        const pubsubEvent = createPubSubEvent(costAmount, budgetAmount);

        await expect(stopProjectBilling(pubsubEvent)).rejects.toThrow(
            `Incorrect budget billing notification format: ${JSON.stringify(
                JSON.parse(Buffer.from(pubsubEvent.data, 'base64').toString())
            )}`
        );

        expect(mockGetProjectId).not.toBeCalled();
        expect(mockGetProjectBillingInfo).not.toBeCalled();
        expect(mockUpdateProjectBillingInfo).not.toBeCalled();
    });
});
