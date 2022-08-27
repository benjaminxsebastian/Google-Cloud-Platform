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
    ECHO Usage: select-billing-account [Open Billing Account Variable]
    SET invalidArgument=
    EXIT /B 1008
)

CALL %~dp0/gcloud-login
CALL %~dp0/check-for-error %ERRORLEVEL%

ECHO:

SETLOCAL ENABLEDELAYEDEXPANSION
    SET selectedBillingAccount=

:SelectBillingAccount
    FOR /F "usebackq delims==" %%A IN (`gcloud beta billing accounts list --filter="open=true"`) DO (
        ECHO %%A
    )
    ECHO:
    SET /P "billingAccount=Please enter the ACCOUNT ID of the open billing account that you wish to select: "
    FOR /F "usebackq delims==" %%A IN (`gcloud beta billing accounts list --filter="open=true" --format="value(ACCOUNT_ID)"`) DO (
        IF [!billingAccount!] EQU [%%A] (
            SET selectedBillingAccount=!billingAccount!
        )
    )
    ECHO:
    IF [!selectedBillingAccount!] EQU [] (
        ECHO Could not find an open billing account with the ACCOUNT ID: !billingAccount!
        ECHO:
        ECHO:
        GOTO SelectBillingAccount
    ) ELSE (
        ECHO Selected the open billing account: !selectedBillingAccount!.
    )
ENDLOCAL & SET "%~1=%selectedBillingAccount%"
