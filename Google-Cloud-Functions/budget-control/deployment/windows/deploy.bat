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
    SET region=
    SET entryPointsAndTriggers=
    SET numberOfEntryPointsAndTriggers=0
    SET runtime=
    SET source=
    CALL %~dp0/pre-deployment-tasks region entryPointsAndTriggers numberOfEntryPointsAndTriggers runtime source
    CALL %~dp0/../../../../deployment/windows/check-for-error !ERRORLEVEL!
    ECHO:
    IF !numberOfEntryPointsAndTriggers! GTR 0 (
        IF !numberOfEntryPointsAndTriggers! EQU 1 (
            CALL :CreateFunction "!entryPointsAndTriggers!"
        ) ELSE (
            FOR %%E IN (!entryPointsAndTriggers!) DO (
                CALL :CreateFunction "%%E"
            )
        )
    ) ELSE (
        ECHO No entry points or triggers were detected in this project.
    )
    EXIT /B

:CreateFunction
    FOR /F "tokens=1,2,3 delims=|" %%T IN (%1%) DO (
        SET "normalizedEntryPoint=%%T"
        SET "entryPoint=%%U"
        SET "trigger=%%V"
        CALL gcloud functions deploy !normalizedEntryPoint! --gen2 !region! --entry-point=!entryPoint! !trigger! !runtime! --source=%~dp0/../../../../build/Google-Cloud-Functions/!source!/src -q
        CALL %~dp0/../../../../deployment/windows/check-for-error !ERRORLEVEL!
    )
    EXIT /B
ENDLOCAL & SET "selectedBillingAccountAndProject="
