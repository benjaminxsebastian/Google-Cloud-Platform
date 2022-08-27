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
    ECHO Usage: normalize-string [String] [Normalized String Variable]
    SET invalidArgument=
    EXIT /B 1002
)

SETLOCAL ENABLEDELAYEDEXPANSION
    SET index=0
    SET "string=%~1"
    SET normalizedString=

:NextCharacter
    CALL :NormalizeCharacter !string:~%index%,1!
    SET /A index=index+1
    IF ["!string:~%index%,1!"] EQU [""] (
        GOTO EXIT
    ) ELSE (
        GOTO NextCharacter
    )

:NormalizeCharacter
    IF [%1%] EQU [A] SET "normalizedString=!normalizedString!-a" & EXIT /B
    IF [%1%] EQU [B] SET "normalizedString=!normalizedString!-b" & EXIT /B
    IF [%1%] EQU [C] SET "normalizedString=!normalizedString!-c" & EXIT /B
    IF [%1%] EQU [D] SET "normalizedString=!normalizedString!-d" & EXIT /B
    IF [%1%] EQU [E] SET "normalizedString=!normalizedString!-e" & EXIT /B
    IF [%1%] EQU [F] SET "normalizedString=!normalizedString!-f" & EXIT /B
    IF [%1%] EQU [G] SET "normalizedString=!normalizedString!-g" & EXIT /B
    IF [%1%] EQU [H] SET "normalizedString=!normalizedString!-h" & EXIT /B
    IF [%1%] EQU [I] SET "normalizedString=!normalizedString!-i" & EXIT /B
    IF [%1%] EQU [J] SET "normalizedString=!normalizedString!-j" & EXIT /B
    IF [%1%] EQU [K] SET "normalizedString=!normalizedString!-k" & EXIT /B
    IF [%1%] EQU [L] SET "normalizedString=!normalizedString!-l" & EXIT /B
    IF [%1%] EQU [M] SET "normalizedString=!normalizedString!-m" & EXIT /B
    IF [%1%] EQU [N] SET "normalizedString=!normalizedString!-n" & EXIT /B
    IF [%1%] EQU [O] SET "normalizedString=!normalizedString!-o" & EXIT /B
    IF [%1%] EQU [P] SET "normalizedString=!normalizedString!-p" & EXIT /B
    IF [%1%] EQU [Q] SET "normalizedString=!normalizedString!-q" & EXIT /B
    IF [%1%] EQU [R] SET "normalizedString=!normalizedString!-r" & EXIT /B
    IF [%1%] EQU [S] SET "normalizedString=!normalizedString!-s" & EXIT /B
    IF [%1%] EQU [T] SET "normalizedString=!normalizedString!-t" & EXIT /B
    IF [%1%] EQU [U] SET "normalizedString=!normalizedString!-u" & EXIT /B
    IF [%1%] EQU [V] SET "normalizedString=!normalizedString!-v" & EXIT /B
    IF [%1%] EQU [W] SET "normalizedString=!normalizedString!-w" & EXIT /B
    IF [%1%] EQU [X] SET "normalizedString=!normalizedString!-x" & EXIT /B
    IF [%1%] EQU [Y] SET "normalizedString=!normalizedString!-y" & EXIT /B
    IF [%1%] EQU [Z] SET "normalizedString=!normalizedString!-z" & EXIT /B
    SET "normalizedString=!normalizedString!%1%"
    EXIT /B

:Exit
ENDLOCAL & SET "%~2=%normalizedString%"
