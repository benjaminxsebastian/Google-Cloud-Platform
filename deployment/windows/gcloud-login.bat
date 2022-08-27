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

CALL %~dp0/check-for-gcloud-beta
CALL %~dp0/check-for-error %ERRORLEVEL%

ECHO:

SETLOCAL ENABLEDELAYEDEXPANSION
    SET activeAccount=
    FOR /F "usebackq delims==" %%A IN (`gcloud config get account`) DO (
        SET "activeAccount=%%A"
    )
    IF [!activeAccount!] EQU [] (
        ECHO No active account found. Logging in ...
        ECHO:
        CALL gcloud auth login
        CALL %~dp0/check-for-error !ERRORLEVEL!
    ) ELSE (
        ECHO Logged in as !activeAccount!.
    )
ENDLOCAL
