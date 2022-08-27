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
    ECHO Usage: get-entrypoints-and-triggers [Path to NodeJS index.js or index.ts file] [Entry Points And Triggers Array Variable]
    SET invalidArgument=
    EXIT /B 1010
)

SETLOCAL ENABLEDELAYEDEXPANSION
    SET entryPointsAndTriggers=
    SET exportsLine=
    SET trackingExportsLine=
    SET argumentsLine=
    SET trackingArgumentsLine=
    FOR /F "tokens=*" %%L IN (%~1) DO (
        SET "line=%%L"
        ECHO."!line!" | FINDSTR /C:"exports." 1>NUL
        IF !ERRORLEVEL! EQU 0 (
            SET "exportsLine=!line!"
            SET "trackingExportsLine=true"
        ) ELSE (
            IF [!trackingExportsLine!] EQU [true] (
                SET "exportsLine=!exportsLine! !line!"
                SET "line=!line:)=!"
                IF [!line!] NEQ [%%L] (
                    SET trackingExportsLine=
                    FOR %%T IN (!exportsLine!) DO (
                        SET "token=%%T"
                        SET "entryPoint=!token:exports.=!"
                        IF [!entryPoint!] NEQ [%%T] (
                            SET normalizedEntryPoint=
                            CALL %~dp0/normalize-string !entryPoint! normalizedEntryPoint
                            CALL %~dp0/check-for-error !ERRORLEVEL!
                            IF [!entryPointsAndTriggers!] EQU [] (
                                SET "entryPointsAndTriggers=!normalizedEntryPoint!|!entryPoint!"
                            ) ELSE (
                                SET "entryPointsAndTriggers=!entryPointsAndTriggers! !normalizedEntryPoint!|!entryPoint!"
                            )
                        )
                        SET "argumentsStart=!token:(=!"
                        IF [!argumentsStart!] NEQ [%%T] (
                            SET "argumentsLine=!token!"
                            SET "trackingArgumentsLine=true"
                        ) ELSE (
                            IF [!trackingArgumentsLine!] EQU [true] (
                                SET "argumentsLine=!argumentsLine!!token!"
                                SET "argumentsEnd=!token:)=!"
                                IF [!argumentsEnd!] NEQ [%%T] (
                                    SET trackingArgumentsLine=
                                    FOR /F "tokens=2 delims=:)" %%A IN ("!argumentsLine!") DO (
                                        SET trigger=
                                        IF [%%A] EQU [PubsubMessage] (
                                            SET "trigger=--trigger-topic"
                                        ) ELSE (
                                            IF [%%A] EQU [ExpressRequestresponse] (
                                                SET "trigger=--trigger-http"
                                            )
                                        )                                        
                                        IF [!trigger!] NEQ [] (
                                            SET "entryPointsAndTriggers=!entryPointsAndTriggers!|!trigger!"
                                        )
                                    )
                                )
                            )
                        )
                    )
                )
            )
        )
    )
ENDLOCAL & SET "%~2=%entryPointsAndTriggers%" & EXIT /B 0
