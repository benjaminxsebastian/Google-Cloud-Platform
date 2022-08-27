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
IF [%~2] EQU [] SET "invalidArgument=true"
IF [%invalidArgument%] NEQ [] (
    ECHO:
    ECHO Usage: get-billable-active-project [Open Billing Account Variable] [Active Project Variable]
    SET invalidArgument=
    EXIT /B 1007
)

CALL %~dp0/gcloud-login
CALL %~dp0/check-for-error %ERRORLEVEL%

ECHO:

SETLOCAL ENABLEDELAYEDEXPANSION
    SET activeProject=
    FOR /F "usebackq delims==" %%P IN (`gcloud config get project`) DO (
        SET "activeProject=%%P"
    )
    SET openBillingAccounts=0
    SET openBillingAccount=
    FOR /F "usebackq delims==" %%A IN (`gcloud beta billing accounts list --filter="open=true" --format="value(ACCOUNT_ID)"`) DO (
        SET /A openBillingAccounts=!openBillingAccounts!+1
        SET "openBillingAccount=%%A"
        IF [!activeProject!] NEQ [] (
            FOR /F "usebackq delims==" %%B IN (`gcloud beta billing projects list --billing-account=!openBillingAccount! --filter="project_id=!activeProject!" --format="value(PROJECT_ID)"`) DO (
                GOTO ConfirmChoices
            )
        )
    )
    ECHO:
    IF !openBillingAccounts! EQU 0 (
        ECHO    -- Please create a billing account by following the instructions at https://cloud.google.com/billing/docs/how-to/manage-billing-account#create_a_new_billing_account.
        ECHO:
        EXIT
    )

:SelectBillingAccount
    CALL %~dp0/select-billing-account openBillingAccount
    CALL %~dp0/check-for-error !ERRORLEVEL!

:SelectProject
    CALL %~dp0/select-project !openBillingAccount! activeProject
    CALL %~dp0/check-for-error !ERRORLEVEL!
    ECHO:

:ConfirmChoices
    IF [!selectedBillingAccountAndProject!] NEQ [true] (
        SET /P "confirmation=Do you wish to use the project: !activeProject! with the billing account: !openBillingAccount!? [Yes/No]: "
        IF [!confirmation!] EQU [No] (
            SET confirmation=
            GOTO SelectBillingAccount
        ) ELSE (
            IF [!confirmation!] EQU [Yes] (
                ECHO:
            ) ELSE (
                GOTO ConfirmChoices
            )
        )
    )
    ECHO Using the project: !activeProject! with the billing account: !openBillingAccount!.
    CALL gcloud config set project !activeProject!
    CALL %~dp0/check-for-error !ERRORLEVEL!
ENDLOCAL & SET "selectedBillingAccountAndProject=true" & SET "%~1=%openBillingAccount%" & SET "%~2=%activeProject%"
