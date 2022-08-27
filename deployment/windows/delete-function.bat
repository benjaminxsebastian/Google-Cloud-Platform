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
IF ["%~3"] EQU [] SET "invalidArgument=true"
IF [%invalidArgument%] NEQ [] (
    ECHO:
    ECHO Usage: delete-function [Function Name] [Entry Point] [Region]
    SET invalidArgument=
    EXIT /B 1011
)

ECHO:

SETLOCAL ENABLEDELAYEDEXPANSION
    CALL gcloud services enable cloudfunctions.googleapis.com
    CALL %~dp0/check-for-error !ERRORLEVEL!
    SET functionExists=
    FOR /F "usebackq delims==" %%F IN (`gcloud functions list --filter="NAME:%~1" --format="value(NAME)"`) DO (
        SET "functionExists=true"
    )
    IF [!functionExists!] EQU [true] (
        SET locatedEntryPoint=
        FOR /F "usebackq delims==" %%S IN (`gcloud functions describe %~1 --gen2 %~3`) DO (
            SET "setting=%%S"
            ECHO."!setting!" | FINDSTR /C:"entryPoint: %~2" 1>NUL
            IF !ERRORLEVEL! EQU 0 (
                SET "locatedEntryPoint=true"
            )
        )
        IF [!locatedEntryPoint!] EQU [true] (
            CALL gcloud functions delete %~1 --gen2 %~3 --quiet
            CALL %~dp0/check-for-error !ERRORLEVEL!
        ) ELSE (
            ECHO The function: %~1 already exists with a different entry point. Please rename or delete that function before rerunning this script.
            EXIT /B 5100
        )
    )
ENDLOCAL
