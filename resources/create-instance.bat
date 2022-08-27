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
IF ["%~4"] EQU [] SET "invalidArgument=true"
IF [%invalidArgument%] NEQ [] (
    ECHO:
    ECHO Usage: delete-old-instances [Name]
    SET invalidArgument=
    EXIT /B
)

ECHO:

WHERE /Q curl
IF %ERRORLEVEL% EQU 0 (
    ECHO Located curl.
) ELSE (
    ECHO:
    ECHO Could not locate curl. Please make sure that you have curl installed on your PATH. See documentation at https://curl.se/download.html.
    EXIT /B
)

SETLOCAL ENABLEDELAYEDEXPANSION
    SET name=%~1
    SET region=
    CALL :GetRegion
    IF !ERRORLEVEL! NEQ 0 EXIT /B
    SET zone=
    CALL :GetZone
    IF !ERRORLEVEL! NEQ 0 EXIT /B
    SET authorization=
    CALL :GetAuthorization
    IF [!authorization!] EQU [] EXIT /B
    SET createComputeInstanceUrl=
    CALL :GetFunctionUri create-compute-instance createComputeInstanceUrl
    IF [!createComputeInstanceUrl!] EQU [] EXIT /B
    SET listAllComputeInstancesUrl=
    CALL :GetFunctionUri list-all-compute-instances listAllComputeInstancesUrl
    IF [!listAllComputeInstancesUrl!] EQU [] EXIT /B
    SET deleteComputeInstanceUrl=
    CALL :GetFunctionUri delete-compute-instance deleteComputeInstanceUrl
    IF [!deleteComputeInstanceUrl!] EQU [] EXIT /B
    SET deleteAllInstances=
    SET data=%~4

:GetAllComputeInstances
    SET zonesInstances=
    FOR /F "usebackq delims==" %%L IN (`curl -m 70 -s -X GET !listAllComputeInstancesUrl! -H "Authorization:bearer !authorization!"`) DO (
        SET "zonesInstances=%%L"
    )
    IF [!zonesInstances!] NEQ [[]] (
        CALL :ConfirmDeleteOption
        SET "zonesInstances=!zonesInstances:],=|!"
        SET deletedInstances=0
        CALL :ParseZonesInstances zonesInstances
        IF !deletedInstances! NEQ 0 (
            GOTO GetAllComputeInstances
        )
    )
    GOTO CreateInstance

:GetRegion
    SET parametersValues=
    CALL %~dp0/../deployment/windows/lookup-parameters "FREE_TIER_REGION" parametersValues
    IF !ERRORLEVEL! NEQ 0 EXIT /B
    FOR %%P IN (!parametersValues!) DO (
        SET "region=%%P"
    )
    EXIT /B

:GetZone
    SET parametersValues=
    CALL %~dp0/../deployment/windows/lookup-parameters "FREE_TIER_ZONE" parametersValues
    IF !ERRORLEVEL! NEQ 0 EXIT /B
    FOR %%P IN (!parametersValues!) DO (
        SET "zone=%%P"
    )
    EXIT /B

:GetAuthorization
    FOR /F "usebackq delims==" %%A IN (`gcloud auth print-identity-token`) DO (
        SET authorization=%%A
    )
    EXIT /B

:GetFunctionUri
    FOR /F "usebackq delims==" %%S IN (`gcloud functions describe %~1 --gen2 --region=!region!`) DO (
        SET "setting=%%S"
        ECHO."!setting!" | FINDSTR /C:"uri: https://%~1" 1>NUL
        IF !ERRORLEVEL! EQU 0 (
            SET setting=!setting: =!
            SET setting=!setting:~4!
            SET "%~2%=!setting!"
        )
    )
    EXIT /B

:ConfirmDeleteOption
    IF [!deleteAllInstances!] EQU [] (
        ECHO:
        SET /P "deleteAllInstances=Do you wish to delete all instances, in all zones? [Yes/No]: "
        IF [!deleteAllInstances!] NEQ [Yes] (
            IF [!deleteAllInstances!] NEQ [No] (
                SET deleteAllInstances=
                GOTO ConfirmDeleteOption
            )
        )
    )
    EXIT /B
    
:ParseZonesInstances
    FOR /F "tokens=1* delims=|" %%I IN ("!%~1!") DO (
        SET "zoneInstances=%%I"
        SET "zoneInstances=!zoneInstances:[=!"
        SET "zoneInstances=!zoneInstances:]=!"
        CALL :DeleteZoneInstances zoneInstances
        SET "%~1=%%J"
        CALL :ParseZonesInstances %~1
    )
    EXIT /B

:DeleteZoneInstances
    FOR /F "tokens=1* delims=," %%K IN ("!%~1!") DO (
        SET "instancesZone=%%K"
        SET "instancesZone=!instancesZone:"=!"
        SET "instancesZone=!instancesZone:zones/=!"
        CALL :DeleteZoneInstance !instancesZone! "%%L"
    )
    EXIT /B

:DeleteZoneInstance
    SET "instances=%~2"
    FOR /F "tokens=1* delims=," %%M IN ("!instances!") DO (
        SET "instanceToDelete=%%M"
        SET "instanceToDelete=!instanceToDelete:"=!"
        IF [!deleteAllInstances!] EQU [No] (
            IF [%~1] EQU [!region!-!zone!] (
                IF [!instanceToDelete!] EQU [!name!] (
                    CALL :DeletingZoneInstance !instanceToDelete! %~1
                )
            )
        ) ELSE (
            CALL :DeletingZoneInstance !instanceToDelete! %~1
        )
        CALL :DeleteZoneInstance %~1 "%%N"
    )
    EXIT /B

:DeletingZoneInstance
    ECHO:
    ECHO Deleting instance: %~1 in zone: %~2
    FOR /F "usebackq delims==" %%D IN (`curl -m 70 -s -X POST !deleteComputeInstanceUrl! -H "Authorization:bearer !authorization!" -H "Content-Type:application/json" -d "{ \"name\": \"%~1\", \"zone\": \"%~2\" }"`) DO (
        ECHO %%D
    )
    SET /A deletedInstances=deletedInstances+1
    EXIT /B

:CreateInstance
    ECHO:
    ECHO Creating instance: !name!
    FOR /F "usebackq delims==" %%C IN (`curl -m 70 -s -X POST !createComputeInstanceUrl! -H "Authorization:bearer !authorization!" -H "Content-Type:application/json" -d "!data!"`) DO (
        ECHO %%C
    )
ENDLOCAL & SET "%~2=%region%" & SET "%~3=%zone%"
