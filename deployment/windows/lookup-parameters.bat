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
IF ["%~1"] EQU [] SET "invalidArgument=true"
IF [%~2] EQU [] SET "invalidArgument=true"
IF [%invalidArgument%] NEQ [] (
    ECHO:
    ECHO Usage: lookup-parameters [Quoted, Comma Separated List Of Parameters To Lookup] [Parameter Values Comma Separated List Variable]
    SET invalidArgument=
    EXIT /B 1003
)

SET "PARAMETERS_FILE_PATH=%~dp0/../parameters.yaml"

SETLOCAL ENABLEDELAYEDEXPANSION
    SET readingYamlFile=
    SET parametersValues=0
    SET parameters=
    SET values=
    SET locatedValues=
    FOR /F "tokens=*" %%L IN (!PARAMETERS_FILE_PATH!) DO (
        IF [!readingYamlFile!] EQU [true] (
            SET /A parametersValues=!parametersValues!+1
            SET "parameterValue=%%L"
            SET parameter=
            SET value=
            FOR /F "tokens=1,2 delims=:" %%P IN ("!parameterValue!") DO (
                SET "parameter=%%P"
                SET "parameter=!parameter: =!"
                SET "parameters[!parametersValues!]=!parameter!"
                SET "value=%%Q"
                SET "value=!value: =!"
                SET "values[!parametersValues!]=!value!"
            )
        ) ELSE (
            IF [%%L] EQU [---] (
                SET "readingYamlFile=true"
            )
        )
    )
    FOR %%C IN (%~1) DO (
        FOR /L %%I IN (1,1,%parametersValues%) DO (
            IF [%%C] EQU [!parameters[%%I]!] (
                SET "locatedValues=!locatedValues!!values[%%I]!"
            )
        )
        SET "locatedValues=!locatedValues!,"
    )
ENDLOCAL & SET "%~2=%locatedValues%" & SET "PARAMETERS_FILE_PATH= " & EXIT /B
