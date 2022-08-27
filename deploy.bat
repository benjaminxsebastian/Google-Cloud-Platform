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

SETLOCAL ENABLEDELAYEDEXPANSION
    SET selectedBillingAccountAndProject=
    SET openBillingAccount=
    SET activeProject=
    CALL %~dp0/deployment/windows/get-billable-active-project openBillingAccount activeProject
    IF !ERRORLEVEL! NEQ 0 EXIT /B
    SET projectNumber=
    FOR /F "usebackq delims==" %%N IN (`gcloud projects list --format="value(PROJECT_NUMBER)"`) DO (
        SET projectNumber=%%N
    )
    
    CALL gcloud services enable cloudbuild.googleapis.com
    IF !ERRORLEVEL! NEQ 0 EXIT /B
    CALL gcloud services enable cloudresourcemanager.googleapis.com
    IF !ERRORLEVEL! NEQ 0 EXIT /B
    CALL gcloud projects add-iam-policy-binding !activeProject! --member=serviceAccount:!projectNumber!@cloudbuild.gserviceaccount.com --role=roles/editor
    IF !ERRORLEVEL! NEQ 0 EXIT /B
    CALL gcloud projects add-iam-policy-binding !activeProject! --member=serviceAccount:!projectNumber!@cloudbuild.gserviceaccount.com --role=roles/iam.serviceAccountUser
    IF !ERRORLEVEL! NEQ 0 EXIT /B
    CALL gcloud projects add-iam-policy-binding !activeProject! --member=serviceAccount:!projectNumber!@cloudbuild.gserviceaccount.com --role=roles/cloudfunctions.developer
    IF !ERRORLEVEL! NEQ 0 EXIT /B

    SET cloudBuildYamlFile=%~dp0/cloudbuild.yaml
    ECHO steps: > !cloudBuildYamlFile!
    ECHO: >> !cloudBuildYamlFile!
    ECHO - name: node >> !cloudBuildYamlFile!
    ECHO   entrypoint: npm >> !cloudBuildYamlFile!
    ECHO   args: ['ci'] >> !cloudBuildYamlFile!
    CALL :CreateFunction budget-control
    IF !ERRORLEVEL! NEQ 0 EXIT /B
    CALL :CreateFunction compute-instance
    IF !ERRORLEVEL! NEQ 0 EXIT /B
    SET invocationLocation=
    FOR %%P IN (.) DO (
        SET invocationLocation=%%~dpnxP
    )
    CD  %~dp0
    CALL gcloud builds submit
    SET errorCode=!ERRORLEVEL!
    CD !invocationLocation!
    EXIT /B !errorCode!

:CreateFunction
    SET region=
    SET entryPointsAndTriggers=
    SET numberOfEntryPointsAndTriggers=0
    SET runtime=
    SET source=
    CALL %~dp0/Google-Cloud-Functions/%1%/deployment/windows/pre-deployment-tasks region entryPointsAndTriggers numberOfEntryPointsAndTriggers runtime source
    IF !ERRORLEVEL! NEQ 0 EXIT /B
    IF !numberOfEntryPointsAndTriggers! GTR 0 (
        IF !numberOfEntryPointsAndTriggers! EQU 1 (
            CALL :CreateFunctionBuildStep "!entryPointsAndTriggers!"
        ) ELSE (
            FOR %%E IN (!entryPointsAndTriggers!) DO (
                CALL :CreateFunctionBuildStep "%%E"
            )
        )
    ) ELSE (
        ECHO No entry points or triggers were detected in %1%.
    )
    EXIT /B

:CreateFunctionBuildStep
    ECHO: >> !cloudBuildYamlFile!
    FOR /F "tokens=1,2,3 delims=|" %%T IN (%1%) DO (
        SET "normalizedEntryPoint=%%T"
        SET "entryPoint=%%U"
        SET "trigger=%%V"
        ECHO - name: 'gcr.io/google.com/cloudsdktool/cloud-sdk' >> !cloudBuildYamlFile!
        ECHO   args: >> !cloudBuildYamlFile!
        ECHO   - gcloud >> !cloudBuildYamlFile!
        ECHO   - functions >> !cloudBuildYamlFile!
        ECHO   - deploy >> !cloudBuildYamlFile!
        ECHO   - !normalizedEntryPoint! >> !cloudBuildYamlFile!
        ECHO   - --gen2 >> !cloudBuildYamlFile!
        ECHO   - !region! >> !cloudBuildYamlFile!
        ECHO   - --entry-point=!entryPoint! >> !cloudBuildYamlFile!
        ECHO   - !trigger! >> !cloudBuildYamlFile!
        ECHO   - !runtime! >> !cloudBuildYamlFile!
        ECHO   - --source=./build/Google-Cloud-Functions/!source!/src >> !cloudBuildYamlFile!
    )
    EXIT /B
ENDLOCAL & SET "selectedBillingAccountAndProject="
