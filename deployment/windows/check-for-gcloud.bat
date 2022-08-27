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

ECHO:

WHERE /Q gcloud
IF %ERRORLEVEL% EQU 0 (
    ECHO Located the gcloud CLI.
) ELSE (
    ECHO Could not locate the gcloud CLI. Please make sure that you have the gcloud CLI installed on your PATH. See instructions at https://cloud.google.com/sdk/docs/install.
    EXIT /B 1004
)
