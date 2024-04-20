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
IF [%~3] EQU [] SET "invalidArgument=true"
IF [%~4] EQU [] SET "invalidArgument=true"
IF [%~5] EQU [] SET "invalidArgument=true"
IF [%invalidArgument%] NEQ [] (
    ECHO:
    ECHO Usage: pre-deployment-tasks [Region Variable] [Entry Points and Triggers Array Variable] [Number of Entry Points and Triggers Array Variable] [Runtime Variable] [Source Variable]
    SET invalidArgument=
    EXIT /B 20001
)

SET invocationLocation=
FOR %%P IN (.) DO (
    SET "invocationLocation=%%~dpnxP"
)
CD  %~dp0

SETLOCAL ENABLEDELAYEDEXPANSION
    SET "region=--region="
    SET entryPointsAndTriggers=
    SET numberOfEntryPointsAndTriggers=0
    SET "runtime=--runtime=nodejs20"
    SET source=
    FOR %%D IN (../..) DO (
        SET source=%%~nxD
    )

    SET errorCode=0
    
    SET openBillingAccount=
    SET activeProject=
    CALL %~dp0/../../../../deployment/windows/get-billable-active-project openBillingAccount activeProject
    IF !ERRORLEVEL! NEQ 0 (
        SET errorCode=!ERRORLEVEL!
        GOTO Exit
    )

    ECHO:

    SET projectNumber=
    FOR /F "usebackq delims==" %%N IN (`gcloud projects list --format="value(PROJECT_NUMBER)"`) DO (
        SET projectNumber=%%N
    )
    CALL gcloud projects add-iam-policy-binding !activeProject! --member=serviceAccount:!projectNumber!-compute@developer.gserviceaccount.com --role=roles/compute.instanceAdmin.v1
    IF !ERRORLEVEL! NEQ 0 (
        SET errorCode=!ERRORLEVEL!
        GOTO Exit
    )
    CALL gcloud projects add-iam-policy-binding !activeProject! --member=serviceAccount:!projectNumber!-compute@developer.gserviceaccount.com --role=roles/compute.instanceAdmin
    IF !ERRORLEVEL! NEQ 0 (
        SET errorCode=!ERRORLEVEL!
        GOTO Exit
    )
    CALL gcloud projects add-iam-policy-binding !activeProject! --member=serviceAccount:!projectNumber!-compute@developer.gserviceaccount.com --role=roles/iam.serviceAccountUser
    IF !ERRORLEVEL! NEQ 0 (
        SET errorCode=!ERRORLEVEL!
        GOTO Exit
    )
    CALL gcloud services enable cloudfunctions.googleapis.com
    IF !ERRORLEVEL! NEQ 0 (
        SET errorCode=!ERRORLEVEL!
        GOTO Exit
    )
    CALL gcloud services enable artifactregistry.googleapis.com
    IF !ERRORLEVEL! NEQ 0 (
        SET errorCode=!ERRORLEVEL!
        GOTO Exit
    )
    CALL gcloud services enable run.googleapis.com
    IF !ERRORLEVEL! NEQ 0 (
        SET errorCode=!ERRORLEVEL!
        GOTO Exit
    )
    CALL gcloud services enable logging.googleapis.com
    IF !ERRORLEVEL! NEQ 0 (
        SET errorCode=!ERRORLEVEL!
        GOTO Exit
    )
    CALL gcloud services enable compute.googleapis.com
    IF !ERRORLEVEL! NEQ 0 (
        SET errorCode=!ERRORLEVEL!
        GOTO Exit
    )
    CALL %~dp0/../../../../deployment/windows/get-nodejs-entry-points-and-triggers %~dp0/../../src/index.ts entryPointsAndTriggers
    IF !ERRORLEVEL! NEQ 0 (
        SET errorCode=!ERRORLEVEL!
        GOTO Exit
    )
    SET parametersValues=
    CALL %~dp0/../../../../deployment/windows/lookup-parameters "FREE_TIER_REGION" parametersValues
    IF !ERRORLEVEL! NEQ 0 (
        SET errorCode=!ERRORLEVEL!
        GOTO Exit
    )
    FOR %%P IN (!parametersValues!) DO (
        SET "region=!region!%%P"
    )
    FOR %%E IN (!entryPointsAndTriggers!) DO (
        SET /A numberOfEntryPointsAndTriggers=!numberOfEntryPointsAndTriggers!+1
        SET "entryPointAndTrigger=%%E"
        FOR /F "tokens=1,2 delims=|" %%T IN ("!entryPointAndTrigger!") DO (
            SET "normalizedEntryPoint=%%T"
            SET "entryPoint=%%U"
            CALL %~dp0/../../../../deployment/windows/delete-function !normalizedEntryPoint! !entryPoint! "!region!"
            IF !ERRORLEVEL! NEQ 0 (
                SET errorCode=!ERRORLEVEL!
                GOTO Exit
            )
        )
    )
    
:Exit
ENDLOCAL & SET "%~1=%region%" & SET "%~2=%entryPointsAndTriggers%" & SET "%~3=%numberOfEntryPointsAndTriggers%" & SET "%~4=%runtime%" & SET "%~5=%source%" & CD %invocationLocation% & SET "invocationLocation= " & EXIT /B %errorCode%
