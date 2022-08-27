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
    ECHO Usage: get-billable-active-project [Open Billing Account] [Project Variable]
    SET invalidArgument=
    EXIT /B 1009
)

CALL %~dp0/gcloud-login
CALL %~dp0/check-for-error %ERRORLEVEL%

ECHO:

SETLOCAL ENABLEDELAYEDEXPANSION
    SET selectedProjectIdentifier=

:SelectProject
    SET ERRORLEVEL=0
    FOR /F "usebackq delims==" %%A IN (`gcloud beta billing projects list --billing-account=%~1`) DO (
        ECHO %%A
    )
    CALL %~dp0/check-for-error !ERRORLEVEL!
    ECHO:
    SET /P "projectidentifier=Please enter the PROJECT ID of the project that you wish to select, or enter 000-000-000 to create a new project under this billing account: "
    IF [!projectidentifier!] EQU [000-000-000] (
        GOTO CreateProject
    ) ELSE (
        FOR /F "usebackq delims==" %%B IN (`gcloud beta billing projects list --billing-account=%~1 --filter="project_id=!projectidentifier!" --format="value(PROJECT_ID)"`) DO (
            IF [!projectidentifier!] EQU [%%B] (
                SET selectedProjectIdentifier=!projectidentifier!
            )
        )
        ECHO:
        IF [!selectedProjectIdentifier!] EQU [] (
            ECHO Could not find the project: !selectedProjectIdentifier! under the billing account: %~1
            ECHO:
            ECHO:
            GOTO SelectProject
        ) ELSE (
            GOTO Exit
        )
    )

:CreateProject
    ECHO:
    SET /A randomNumber1=%RANDOM% * 101 / 32768 + 100
    SET dateToday=!DATE%:~4!
    SET dateToday=%dateToday:/=%
    SET timeNow=!TIME!
    SET timeNowHour=%timeNow:~0,2%
    IF "%timeNowHour:~0,1%" EQU "0" (set timeNowHour=%timeNowHour:~1%)
    SET timeNowMinute=%timeNow:~3,2%
    IF "%timeNowMinute:~0,1%" EQU "0" (set timeNowMinute=%timeNowMinute:~1%)
    SET timeNowSecond=%timeNow:~6,2%
    IF "%timeNowSecond:~0,1%" EQU "0" (set timeNowSecond=%timeNowSecond:~1%)
    SET /A timeInSeconds=%timeNowHour% * 3600 + %timeNowMinute% * 60 + %timeNowSecond%
    SET /A randomNumber2=%RANDOM% * 10000 / 32768 + 10000
    SET projectIdentifier=proj-%randomNumber1%-%dateToday%%timeInSeconds%-%randomNumber2%
    CALL gcloud projects create !projectIdentifier!
    IF !ERRORLEVEL! EQU 0 (
        CALL gcloud beta billing projects link !projectidentifier! --billing-account=%~1
        CALL %~dp0/check-for-error !ERRORLEVEL!
        SET selectedProjectIdentifier=!projectidentifier!
    ) ELSE (
        SET ERRORLEVEL=0
        GOTO CreateProject
    )

:Exit
ENDLOCAL & SET "%~2=%selectedProjectIdentifier%"
