@ECHO OFF
setlocal EnableDelayedExpansion
REM CALLING SEQUENCE: 
REM command[nrpe_nt_check_users]=c:nrpe_ntpluginscheck_user_count.bat $ARG1$ $ARG2$
REM -------------------------------------------
set EX=0 
set MS=OK 
SET /a COUNT=0
SET USER=
FOR /f "TOKENS=1" %%i IN ('query session ^|find "rdp-tcp#"') DO SET /a COUNT+=1
FOR /f "TOKENS=2" %%G IN ('query session ^|find "rdp-tcp#"') DO (
call :subroutine %%G
)

REM - CRITICAL (COUNT => $2)
if %COUNT% GEQ %2 ( set EX=2 && set MS=CRITICAL && goto end )

REM - WARNING (COUNT => $1)
if %COUNT% GEQ %1 ( set EX=1 && set MS=WARNING && goto end )

REM - NOT CRITICAL / WARNING
set EX=0
set MS=OK
goto end

:subroutine
SET USER=%USER% %1
GOTO :eof

:end
ECHO %MS%: Nombre de sessions actives = %COUNT% ^| 'number'=%COUNT%
EXIT /b %EX%