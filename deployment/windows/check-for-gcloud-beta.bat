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

CALL %~dp0/check-for-gcloud
CALL %~dp0/check-for-error %ERRORLEVEL%

ECHO:

SETLOCAL ENABLEDELAYEDEXPANSION
    SET locatedBetaComponent=
    FOR /F "usebackq delims==" %%P IN (`gcloud --version`) DO (
        SET "locatedComponent=%%P"
        SET "locatedComponent=!locatedComponent:beta=!"
        IF [!locatedComponent!] NEQ [%%P] (
            SET "locatedBetaComponent=%%P"
        )
    )
    IF [!locatedBetaComponent!] EQU [] (
        ECHO Could not locate the gcloud beta component. Please make sure that you have the gcloud beta component installed on your PATH. See instructions at https://cloud.google.com/sdk/docs/install and https://cloud.google.com/sdk/gcloud/reference/components/install.
        EXIT /B 2201
    ) ELSE (
         ECHO Located the gcloud beta component: !locatedBetaComponent!.
    )
ENDLOCAL
