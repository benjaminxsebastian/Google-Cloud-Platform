@ECHO OFF

REM // Copyright 2022 Benjamin Sebastian
REM // 
REM // Licensed under the Apache License, Version 2.0 (the "License");
REM // you may not use this file except in compliance with the License.
REM // You may obtain a copy of the License at
REM // 
REM //     http://www.apache.org/licenses/LICENSE-2.0
REM // 
REM // Unless required by applicable law or agreed to in writing, software
REM // distributed under the License is distributed on an "AS IS" BASIS,
REM // WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
REM // See the License for the specific language governing permissions and
REM // limitations under the License.

SET invalidArgument=
IF [%~1] EQU [] SET "invalidArgument=true"
IF [%invalidArgument%] NEQ [] (
    ECHO:
    ECHO Usage: install-sendgrid-email-delivery [SendGrid Email Delivery API Key]
    SET invalidArgument=
    EXIT /B
)

SETLOCAL ENABLEDELAYEDEXPANSION
    SET name=test-server
    SET sendGridEmailDeliverySetupScriptPath=https://raw.githubusercontent.com/benjaminxsebastian/Google-Cloud-Platform/main/resources/sendgrid-email-delivery/setup-scripts/setup-sendgrid-email-delivery.sh
    SET sendGridEmailDeliveryApiKey=%~1
    SET region=
    SET zone=
    SET data="{ \"name\": \"!name!\", \"scripts\": [\"!sendGridEmailDeliverySetupScriptPath!\", \"!openVpnAccessServerSetupScriptPath!\"], \"parameters\": [{ \"key\": \"SENDGRID_EMAIL_DELIVERY_API_KEY\", \"value\": \"!sendGridEmailDeliveryApiKey!\" }, { \"key\": \"OPENVPN_ACCESS_SERVER_USER_NAME\", \"value\": \"!openVpnAccessServerUserName!\" }, { \"key\": \"OPENVPN_ACCESS_SERVER_USER_PASSWORD\", \"value\": \"!openVpnAccessServerUserPassword!\" }] }"
    CALL %~dp0/../../create-instance !name! region zone !data!
ENDLOCAL
