@echo off
setlocal EnableDelayedExpansion
chcp 437
set priDNS=209.222.18.222
set sndDNS=209.222.18.218

:: Main Thread
:init
cls
echo 1. Run Tests on ^<A^>ll Servers
echo 2. ^<R^>un Tests on Region-Specific Servers
echo 3. ^<G^>et All Server IPs (Only use this when connected to a VPN)
echo 4. ^<Q^>uit
echo.

SETLOCAL
set /p option=Input your Option: 

if %option% equ 1 (
	cls
	echo ALL SERVER TEST
	echo.
	CALL :all_server_test
	pause
	goto init

) else if /I %option%==A (
	cls
	echo ALL SERVER TEST
	echo.
	CALL :all_server_test
	pause
	goto init

) else if %option% equ 2 (
	cls
	echo DESIGNATED SERVER TEST
	echo.
	CALL :designated_server_test
	pause
	goto init

) else if /I %option%==R (
	cls
	echo DESIGNATED SERVER TEST
	echo.
	CALL :designated_server_test
	pause
	goto init

) else if %option% equ 3 (
	CALL :get_all_ip
	goto init

) else if /I %option%==G (
	CALL :get_all_ip
	goto init

) else if %option% equ 4 (
	exit 0;

) else if /I %option%==Q (
	exit 0;

) else (goto init)

ENDLOCAL


:: Defining Functions

:: Retrieves the Ping from 
:: param1: Server Address
:: output: Returns server delay in milliseconds, returns 1 when timeout
:test_connectivity
SETLOCAL
set /a delay=1
for /f "tokens=6,10 delims= " %%a in ('ping -n 2 -l 256 -n %2 -w 500 %1') do (set ping=%%a&if %%b==0 set /a delay=0)
if %delay%==0 (set /a delay=%ping:ms,=%)
exit /b %delay%
ENDLOCAL

:: Runs Connection Test on All Servers
:: input: Server names and ip from ip_list.txt
:: output: List of reachable servers documented in available_servers.txt
:all_server_test
SETLOCAL
set /p repetition=Tries per server (More tries mean better accuracy, but takes more time): 
echo %repetition%| findstr /r "^[1-9][0-9]*$">NUL
if not %ERRORLEVEL% equ 0 (
	echo Please input a valid number!
	goto :all_server_test
)
echo List of Reachable Servers: > available_servers.txt
for /f "tokens=1,2 delims= " %%a in (ip_list.txt) do (
	echo|set /p=%%b
	CALL :test_connectivity %%b %repetition%
	IF !ERRORLEVEL!==1 (echo  failed) ELSE (echo  !ERRORLEVEL!ms %%a&echo %%a %%b !ERRORLEVEL!ms >> available_servers.txt)
)
echo All server tested, results are saved in available_servers.txt
ENDLOCAL
exit /b 0

:: Runs Connection Test on Designated Servers
:: input: Server names and ip from ip_list.txt
:: output: List of reachable servers documented in available_servers_<input region>.txt
:designated_server_test
SETLOCAL
set /p repetition=Tries per server (More tries mean better accuracy, but takes more time): 
echo %repetition%| findstr /r "^[1-9][0-9]*$">NUL
if not %ERRORLEVEL% equ 0 (
	echo Please input a valid number!
	echo.
	goto :designated_server_test
)
:get_region
set /p location=Input Designated Server Region (Use "_" as to separate letters): 
set exists=
echo List of Reachable Servers: > available_servers_%location%.txt
for /f "tokens=1,2 delims= " %%a in (ip_list.txt) do (
	echo %%a| findstr /I %location%> NUL
	if !ERRORLEVEL! equ 0 (
		set exists=y
		echo|set /p=%%b
		CALL :test_connectivity %%b %repetition%
		IF !ERRORLEVEL!==1 (
			echo  failed
		) else (
			if /I %%a==%location% (
				echo  !ERRORLEVEL!ms&echo %%b !ERRORLEVEL!ms >> available_servers_%location%.txt
			) else (
				echo  !ERRORLEVEL!ms %%a&echo %%a %%b !ERRORLEVEL!ms >> available_servers_%location%.txt
			)
		)
	)
)
if defined exists (
	echo All server tested, results are saved in available_servers_%location%.txt
) else (
	del available_servers_%location%.txt
	echo No server in "%location%" found, please input another region ^(Available regions can be found in server_address.txt^)
	echo.
	goto :get_region
)
ENDLOCAL
exit /b 0

:: Gets the IP address for the input domain name
:: param1: Name of the Server
:: param2: Domain Name of the Server
:: param3: Assigned DNS Server
:: output: Writes server name and ip address to ip_list_temp.txt, outputs 0 when succeeded, 1 when failed
:get_ip
SETLOCAL
set /a resolved=0

for /f "tokens=*" %%x in ('nslookup %2 %3') do (
	if !resolved!==1 (
		for /f "tokens=1,2 delims= " %%a in ("%%x") do (
			echo %%a| findstr /r "^[1-9]"> NUL
			if !ERRORLEVEL! equ 0 (
				echo %%a
				echo %1 %%a >> ip_list_temp.txt
			) else (echo %%b&echo %1 %%b >> ip_list_temp.txt)
		)
	)
	echo %%x| findstr %2 >NUL
	if !ERRORLEVEL! equ 0 set /a resolved=1
)
if %resolved%==0 (exit /b 1) ELSE (exit /b 0)
ENDLOCAL

:: Gets the IP address for all domain names
:: input: Server names and domain name from server_address.txt
:: output: List of server ips in ip_list.txt
:get_all_ip
cls
del ip_list_temp.txt 2> NUL
echo DNS LOOKUP
echo.
echo Please wait while we retrieve IP from DNS server

SETLOCAL
set /a failure=0
set /a success=0
for /f "tokens=1,2 delims= " %%a in (server_address.txt) do (
	CALL :get_ip %%a %%b %priDNS% 2> NUL
	if !ERRORLEVEL!==1 (
		CALL :get_ip %%a %%b %sndDNS% 2> NUL
		if !ERRORLEVEL!==1 (echo IP Address Acquisition for %%a Failed & set /a failure=!failure!+1) else set /a success=!success!+1
	) else set /a success=!success!+1
)
echo All IP Acquisition Attempted, !success! Succeeded, !failure! Failed.
CALL :promp
ENDLOCAL
exit /b 0

:: Prompts user to overwrite the old IP cache in case some servers are unreachable
:promp
SETLOCAL
set /p option=Overwrite Old IP Address List? [y/n]:
if /I not %option%==n (
	if /I %option%==y (
		SETLOCAL
		set /p option=Old IP List will be overwritten. Are you sure? [y/n]:
		if /I !option!==y (
			CALL :overwrite
		) else goto promp
		ENDLOCAL
	) else goto promp
)
ENDLOCAL
del ip_list_temp.txt 2> NUL
exit /b 0

:: Overwrites ip_list.txt with new server ips
:overwrite
del ip_list.txt
ren ip_list_temp.txt ip_list.txt
echo IP List Renewed
exit /b 0
