<!--
 Copyright 2022 Benjamin Sebastian
 
 Licensed under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License.
 You may obtain a copy of the License at
 
     http://www.apache.org/licenses/LICENSE-2.0
 
 Unless required by applicable law or agreed to in writing, software
 distributed under the License is distributed on an "AS IS" BASIS,
 WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 See the License for the specific language governing permissions and
 limitations under the License.
-->
# [Google Cloud-Platform](https://github.com/benjaminxsebastian/Google-Cloud-Platform)

This monorepo contains utilities that run on the Google Cloud Platform, with scripts to automate their deployment. These utilities include:

- ### Google Cloud Functions:

    - **budget-control**: The deployment script for this project creates a Pub/Sub topic, and sets up billing budgets to send notifications on that topic, which the deployed ***stop-project-billing*** Google Cloud Function then listens for. ***stop-project-billing*** will disable the billing on the project if the _costAmount_ in the received notification excedes its _budgetAmount_. It is based on the example presented here: https://cloud.google.com/billing/docs/how-to/notify#cap_disable_billing_to_stop_usage.

    - **compute-instance**: This project deploys the following Google Cloud Functions:

        - ***create-compute-instance***, which instantiates and runs a Google Cloud Compute Engine VM instance in the us-east1 region (which provides free usage as noted on https://cloud.google.com/free/docs/free-cloud-features#free-tier-usage-limits)

        - ***list-all-compute-instances***, which lists all the Google Cloud Compute Engine VM instances in the project, across all regions and zones.

        - ***delete-compute-instance***, which deletes the specified Google Cloud Compute Engine VM instance.

The projects in this monorepo were written in [TypeScript](https://www.typescriptlang.org/) to run on [NodeJS](https://nodejs.org/en/about/).

---

## Quick Start

1. Create a [Google Cloud account](https://console.cloud.google.com/freetrial?_ga=2.239631875.1051599602.1661295698-219743935.1661002807&_gac=1.153372362.1661619734.CjwKCAjwgaeYBhBAEiwAvMgp2g5T_H4Xbd5QaRTfaPaActn5RevGGpnMJ3W2b74-o4pEEPyiDOOdnRoCg5AQAvD_BwE).

2. Create a [Google Cloud Billing account](https://cloud.google.com/billing/docs/how-to/manage-billing-account#create_a_new_billing_account).

3. Install the [Google gcloud utility](https://cloud.google.com/sdk/docs/install).

4. Clone [this repository](https://github.com/benjaminxsebastian/Google-Cloud-Platform.git).

5. Run the [deploy](https://github.com/benjaminxsebastian/Google-Cloud-Platform/blob/main/deploy.bat) script in the root folder of this repository. This script will generate and submit a *cloudbuild.yaml* file, which will:

    - upload the projects in this monorepo into Google Cloud Build,
    - build those projects in Google Cloud Build, and
    - deploy the generated Google Cloud Functions.

---

## Building & Testing Locally

This monorepo can be built and tested locally by running:

```console
npm ci
npm run test
```
This will build and run the unit tests for the projects, written in [Jest](https://jestjs.io/).

---
## License
  - Apache Version 2.0
  - See [LICENSE](https://github.com/benjaminxsebastian/Google-Cloud-Platform/blob/main/LICENSE) for details.
