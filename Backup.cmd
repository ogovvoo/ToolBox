@echo off & title Backup Tools Ver.20190703

REM // Initialize the backup environment to terminate all processes for the current user //
REM // 初始化备份环境，终止所有当前用户的进程 //
if [%1] == [] start /max /high cmd /c "%~f0 1" & exit
echo; Backup is now in processes, Please wait......

for /f "delims=: tokens=2" %%i in ('tasklist /fi "username eq %username%" /fo list ^| find /i ".exe" ^| findstr /i /v "cmd.exe conhost.exe"') do taskkill /f /fi "username eq %username%" /im %%i 2>nul 1>nul >nul

powercfg /x monitor-timeout-ac 0
powercfg /x disk-timeout-ac 0
powercfg /x standby-timeout-ac 0

cls
if not exist Restore md Restore

REM // Initialize the backup environment to terminate all processes for the current user //
REM // 初始化备份环境，终止所有当前用户的进程 //

REM // Export Mapped Network Drive info //
REM // 导出已映射的网络驱动器信息 //

for /f "delims=:" %%i in ('findstr /n "^:start$" "%~f0"') do set line=%%i
more /e +%line% "%~f0" >.\Restore\%username%.cmd
(for /f "tokens=2*" %%i in ('net use^|find ":"') do (
    setlocal enabledelayedexpansion
    set dr=%%j
    set dr=!dr:Microsoft Windows Network=!
    for /f "tokens=*" %%a in ("%%i!dr!") do (
		set _fp=%%~fa
	)
	echo !_fp!
    endlocal
))>>.\Restore\%username%.cmd

REM 外置默认通用公共盘信息文件defsharedrive.txt
REM 公共盘信息编写格式如下：
REM P:\10.213.25.52\Public
if exist defsharedrive.txt more /e defsharedrive.txt >>.\Restore\%username%.cmd

if not exist Backup\%username% md Backup\%username%

REM Backup all below listed Drives Data
REM 备份所有列出的驱动器的数据

for /f %%i in ('mountvol ^|find ":\"') do (
	setlocal enabledelayedexpansion
	set drv=%%i 
	set drv=!drv:~0,1!
	if [%%i] NEQ [%~d0\] (	
		if not exist !drv!:\Deploy (
			robocopy !drv!:\ .\Backup\%username%\!drv!_Drive /s /e /xj /xa:s /mt:15 /np /tee /njh /njs /v /log+:Backup\%username%\%username%_backuplog.log /r:0 /w:0 /xa:sh /xd config.msi boot $WINDOWS.~BT $RECYCLE.BIN "Documents and Settings" MSOCache ProgramData Recovery "System Volume Information" users Windows windows.old "Program Files" "Program Files (x86)" /xf pagefile.sys hiberfil.sys swapfile.sys
			attrib -s -h .\Backup\%username%\!drv!_Drive
			)		
		)
	set drv=		
	endlocal
)

REM backup user profile 
REM 备份用户配置文件数据

robocopy "%userprofile%" .\Backup\%username%\%username%.bak /s /e /xj /xa:s /mt:15 /np /tee /njh /njs /v /log+:Backup\%username%\%username%_backuplog.log /r:0 /w:0 /xa:sh /xd AppData IntelGraphicsProfiles
if exist "%appdata%\microsoft\Signatures" robocopy "%appdata%\microsoft\Signatures" .\Backup\%username%\Signatures /s /e /xj /np /tee /njh /njs /v /log+:Backup\%username%\%username%_backuplog.log /r:0 /w:0

REM backup chrome bookmarks
REM 备份Chrome收藏夹

for /f "delims=*" %%i in ('cd /d %localappdata%\google ^& dir /a/s/b bookmarks') do copy "%%i" .\Backup\%username%\google_bookmarks

REM backup WIFI record
REM 备份WIFI数据

if not exist .\Backup\%username%\WLAN mkdir .\Backup\%username%\WLAN
netsh wlan export profile folder=.\Backup\%username%\WLAN key=clear >nul

REM Ignore WIFI record which not need
REM 清理还原出错的WIFI记录

del .\Backup\%username%\WLAN\*aironet.xml >nul 2>nul

powercfg /x monitor-timeout-ac 15
powercfg /x disk-timeout-ac 20
powercfg /x standby-timeout-ac 15

start /min explorer
REM export the backup error information to help to Verify data integrity
REM 导出备份错误信息列表以供校验数据完整性

find "/" .\Backup\%username%\%username%_backuplog.log > .\Backup\%username%\%username%_backuplog_error
start /max notepad .\Backup\%username%\%username%_backuplog_error

for /f %%a in ('mshta VBScript:code(close(Execute("FmtDate=msgbox(""Backup Complete""+Chr(13)+Chr(13)+""Would you like to shutdown the computer?"",68,""Shutdown""):CreateObject(""Scripting.FileSystemObject"").GetStandardStream(1).Write FmtDate"^)^)^)') do set msg=%%a

if [%msg%] == [6] shutdown /f /s /t 0
exit

:start
@echo off & title Data Restore Tools Ver.20190703

REM restore all files to C:\Data
REM 还原所有数据到C:\Data 目录

powercfg /x monitor-timeout-ac 0
powercfg /x disk-timeout-ac 0
powercfg /x standby-timeout-ac 0


if exist ..\Backup\%~n0\C_Drive\Data (
	robocopy /s /r:0 /w:0 ..\Backup\%~n0\C_Drive\Data\ C:\Data
) else (
	robocopy /s /r:0 /w:0 ..\Backup\%~n0\ C:\Data /xd %~n0.bak
)

REM restore user profile
REM 还原用户配置文件

robocopy /s /r:0 /w:0 ..\Backup\%~n0\%~n0.bak\ %userprofile%
robocopy ..\Backup\%~n0\Signatures\ "%appdata%\Microsoft\Signatures" /s /r:0 /w:0


for %%i in (c:\data\wlan\*.xml) do netsh wlan add profile filename="%%i"
robocopy /s /r:0 /w:0 ..\Tools-Docs\Dict C:\Data\Dict
copy /y C:\Data\Dict\Youdao.lnk "%userprofile%\desktop\Youdao.lnk"

REM restore chrome bookmarks
REM 还原Chrome收藏夹

md "%localappdata%\Google\Chrome\User Data\Default" & copy /y google_bookmarks "%localappdata%\google\chrome\user data\default\bookmarks"

for /f "delims=:" %%i in ('findstr /n "^:netdrive$" "%~f0"') do set line=%%i
more /e +%line% "%~f0" >%userprofile%\desktop\%~n0.cmd
msg * /time:0 Data Restore complete!!

powercfg /x monitor-timeout-ac 15
powercfg /x disk-timeout-ac 20
powercfg /x standby-timeout-ac 15

exit

:netdrive
@echo off & title Network Driver Re-Map Tools Ver. 20190703


for /f "delims=:" %%i in ('findstr /n "^:setup$" "%~f0"') do set line=%%i
for /f "delims=: tokens=1,2*" %%a in ('more /e +%line% "%~f0"') do (
	if exist %%a: net use %%a: /d /y
	net use %%a: "\%%b" /p:y /y
)
msg * /time:0 Network Driver Restore complete!!

exit
:setup
