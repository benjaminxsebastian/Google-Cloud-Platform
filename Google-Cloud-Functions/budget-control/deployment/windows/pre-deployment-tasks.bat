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
    EXIT /B 10001
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
    CALL gcloud services enable eventarc.googleapis.com
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
    CALL gcloud services enable pubsub.googleapis.com
    IF !ERRORLEVEL! NEQ 0 (
        SET errorCode=!ERRORLEVEL!
        GOTO Exit
    )

    ECHO:

    SET "topic=LowBudgetWarning"
    SET inError=
    CALL gcloud pubsub topics create !topic!
    IF !ERRORLEVEL! LSS 0 SET "inError=true"
    IF !ERRORLEVEL! GTR 1 SET "inError=true"
    IF [!inError!] NEQ [] (
        SET errorCode=10002
        GOTO Exit
    )

    ECHO:

    SET projectNumber=
    FOR /F "usebackq delims==" %%N IN (`gcloud projects list --format="value(PROJECT_NUMBER)"`) DO (
        SET projectNumber=%%N
    )
    CALL gcloud projects add-iam-policy-binding !activeProject! --member=serviceAccount:!projectNumber!-compute@developer.gserviceaccount.com --role=roles/billing.projectManager
    IF !ERRORLEVEL! NEQ 0 (
        SET errorCode=!ERRORLEVEL!
        GOTO Exit
    )
    CALL gcloud services enable cloudbilling.googleapis.com
    IF !ERRORLEVEL! NEQ 0 (
        SET errorCode=!ERRORLEVEL!
        GOTO Exit
    )
    CALL gcloud services enable billingbudgets.googleapis.com
    IF !ERRORLEVEL! NEQ 0 (
        SET errorCode=!ERRORLEVEL!
        GOTO Exit
    )

    ECHO:

    SET "budgetName=BillingAccountBudget"
    SET budgetExists=
    FOR /F "usebackq delims==" %%B IN (`gcloud billing budgets list --billing-account=!openBillingAccount! --filter="displayName=!budgetName! AND notificationsRule.pubsubTopic=projects/!activeProject!/topics/!topic!"`) DO (
        SET "budgetExists=true"
    )
    IF [!budgetExists!] EQU [] (
        CALL gcloud billing budgets create --billing-account=!openBillingAccount! --display-name=!budgetName! --budget-amount=1.00USD --notifications-rule-pubsub-topic=projects/!activeProject!/topics/!topic! --threshold-rule=percent=0.01 --threshold-rule=percent=0.03,basis=forecasted-spend
        IF !ERRORLEVEL! NEQ 0 (
            SET errorCode=!ERRORLEVEL!
            GOTO Exit
        )
    ) ELSE (
        ECHO The budget: !budgetName! with notification to the PubSub topic: !topic! already exists.
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
    SET modifiedEntryPointsAndTriggers=
    FOR %%E IN (!entryPointsAndTriggers!) DO (
        SET /A numberOfEntryPointsAndTriggers=!numberOfEntryPointsAndTriggers!+1
        SET "entryPointAndTrigger=%%E"
        IF [!modifiedEntryPointsAndTriggers!] EQU [] (
            SET "modifiedEntryPointsAndTriggers=!entryPointAndTrigger!=!topic!"
        ) ELSE (
            SET "modifiedEntryPointsAndTriggers=!modifiedEntryPointsAndTriggers! !entryPointAndTrigger!=!topic!"
        )
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
    SET "entryPointsAndTriggers=!modifiedEntryPointsAndTriggers!"
    
:Exit
ENDLOCAL & SET "%~1=%region%" & SET "%~2=%entryPointsAndTriggers%" & SET "%~3=%numberOfEntryPointsAndTriggers%" & SET "%~4=%runtime%" & SET "%~5=%source%" & CD %invocationLocation% & SET "invocationLocation= " & EXIT /B %errorCode%
