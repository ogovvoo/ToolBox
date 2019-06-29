@echo off & title Data Backup Tools for GWM/ Data Backup is in progress... Please do not close this windows
REM Ver. 20190628
REM 增加防止休眠功能
REM 优化进程终止模式
REM 检测还原路径，防止多次备份还原后导致目录加深
REM 外置默认通用公共盘信息文件defsharedrive.txt



REM // Initialize the backup environment to terminate all processes for the current user //
REM // 初始化备份环境，终止所有当前用户的进程 //

for /f "delims=: tokens=2" %%i in ('tasklist /fi "username eq %username%" /fo list ^| find /i ".exe" ^| findstr /i /v "cmd.exe" ^| findstr /i /v "conhost.exe"') do taskkill /f /fi "username eq %username%" /im %%i

powercfg /x monitor-timeout-ac 0
powercfg /x disk-timeout-ac 0
powercfg /x standby-timeout-ac 0

cls
REM start explorer
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
REM P:\10.10.25.52\Public
if exist defsharedrive.txt more /e defsharedrive.txt >>.\Restore\%username%.cmd



REM // Export Mapped Network Drive info //
REM // 导出已映射的网络驱动器信息 //

REM // Data Backup Modules //
REM // 数据备份模块 //

md Backup\%username% & echo. >Backup\%username%\%username%_backuplog.log

REM First backup job
REM 第一次备份任务

call :backupstart
REM msg * /time:0 Backup complete!!

REM 2nd backup job to confirmation
REM 第二次备份任务进行确认
call :backupstart
msg * /time:0 Backup complete!!

REM export the backup error information to help to Verify data integrity
REM 导出备份错误信息列表以供校验数据完整性

powercfg /x monitor-timeout-ac 15
powercfg /x disk-timeout-ac 20
powercfg /x standby-timeout-ac 15

findstr "(0" .\Backup\%username%\%username%_backuplog.log > .\Backup\%username%\%username%_backuplog_error
start /max notepad .\Backup\%username%\%username%_backuplog_error

exit
:backupstart

REM Backup all below listed Drives Data
REM 备份所有列出的驱动器的数据

for %%i in (C D E F) do (
	if /i [%~d0] == [%%i:] goto :next
	if exist %%i: (
		if not exist %%i:\Deploy (
			robocopy %%i:\ .\Backup\%username%\%%i_Drive /s /xj /np /tee /njh /njs /log+:Backup\%username%\%username%_backuplog.log /r:1 /w:1 /xa:sh /xd config.msi boot $WINDOWS.~BT $RECYCLE.BIN "Documents and Settings" hiberfil.sys MSOCache  pagefile.sys ProgramData Recovery swapfile.sys "System Volume Information" users Windows "Program Files" "Program Files (x86)" | findstr "(0"
			attrib -s -h .\Backup\%username%\%%i_Drive
		)
	)
)		
:next

REM backup user profile 
REM 备份用户配置文件数据

robocopy "%userprofile%" .\Backup\%username%\%username%.bak /s /xj /np /tee /njh /njs /log+:Backup\%username%\%username%_backuplog.log /r:1 /w:1 /xa:sh /xd AppData IntelGraphicsProfiles | findstr "(0"
robocopy "%appdata%\microsoft\Signatures" .\Backup\%username%\Signatures /s /xj /np /tee /njh /njs /log+:Backup\%username%\%username%_backuplog.log /r:1 /w:1 | findstr "(0"

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

goto :eof

REM // Data Backup Modules //
REM // 数据备份模块 //

REM // Data Restore Modules //
REM // 数据还原模块 //
:start
@echo off & title Data Restore Tools for GWM/ Data Restore is in progress...

REM restore all files to C:\Data
REM 还原所有数据到C:\Data 目录

powercfg /x monitor-timeout-ac 0
powercfg /x disk-timeout-ac 0
powercfg /x standby-timeout-ac 0


if exist ..\Backup\%~n0\C_Drive\Data (
	robocopy /s /r:1 /w:1 ..\Backup\%~n0\C_Drive\Data\ C:\Data
) else (
	robocopy /s /r:1 /w:1 ..\Backup\%~n0\ C:\Data /xd %~n0.bak
)

REM restore user profile
REM 还原用户配置文件

robocopy /s /r:1 /w:1 ..\Backup\%~n0\%~n0.bak\ %userprofile%
robocopy ..\Backup\%~n0\Signatures\ "%appdata%\Microsoft\Signatures" /s /r:1 /W:1


for %%i in (c:\data\wlan\*.xml) do netsh wlan add profile filename="%%i"
robocopy /s /r:1 /w:1 ..\Tools-Docs\Dict C:\Data\Dict
copy /y C:\Data\Dict\Youdao.lnk "%userprofile%\desktop\Youdao.lnk"

REM restore chrome bookmarks
REM 还原Chrome收藏夹

md "%localappdata%\Google\Chrome\User Data\Default" & copy /y google_bookmarks "%localappdata%\google\chrome\user data\default\bookmarks"

REM // Export Network Drive Restore Module //
REM // 导出网络驱动器还原模块 //

for /f "delims=:" %%i in ('findstr /n "^:netdrive$" "%~f0"') do set line=%%i
more /e +%line% "%~f0" >%userprofile%\desktop\%~n0.cmd
msg * /time:0 Data Restore complete!!

powercfg /x monitor-timeout-ac 15
powercfg /x disk-timeout-ac 20
powercfg /x standby-timeout-ac 15

exit

REM // Export Network Drive Restore Module //
REM // 导出网络驱动器还原模块 //

REM // Data Restore Modules //
REM // 数据还原模块 //

REM // Network Drive Restore Modules //
REM // 网络驱动器还原模块 //

:netdrive
@echo off & title Network Driver Re-Map Tools for GWM/ Network Driver Re-Map is in progress...

set /p _user=please enter your Domain ID:
set /p _pw=Please enter your Domain PW:

cls

REM uses the file name as the user name if Enter key pressed
REM 回车使用当前文件名作为域用户名 - 建议使用

if "%_user%" EQU "" set _user=%~n0

REM cmdkey /add:*.sc.cn /user:schenker_sc\%_user% /pass:%_pw%
REM cmdkey /add:sc.cn /user:schenker_sc\%_user% /pass:%_pw%

REM // Add credentials for each server //
REM // 为每台服务器添加凭据 //

cmdkey /add:10.10.25.52  /user:sc_cc\%_user% /pass:%_pw%
cmdkey /add:10.10.27.237  /user:sc_cc\%_user% /pass:%_pw%
cmdkey /add:*.cc.cn  /user:scr_cc\%_user% /pass:%_pw%
cmdkey /add:cc.cn  /user:sc_cc\%_user% /pass:%_pw%

REM // Add credentials for each server //
REM // 为每台服务器添加凭据 //

for /f "delims=:" %%i in ('findstr /n "^:setup$" "%~f0"') do set line=%%i
for /f "delims=: tokens=1,2*" %%a in ('more /e +%line% "%~f0"') do (
	if exist %%a: net use %%a: /d /y
	net use %%a: "\%%b" /p:y /y
)
msg * /time:0 Network Driver Restore complete!!
rem start /max shell:mycomputerfolder

REM // Network Drive Restore Modules //
REM // 网络驱动器还原模块 //

REM // Printer Modules //
REM // 打印机模块 //

for /f %%a in ('mshta VBScript:code(close(Execute("FmtDate=msgbox(""Continue to add printers to users?"",36,""Printer""):CreateObject(""Scripting.FileSystemObject"").GetStandardStream(1).Write FmtDate"^)^)^)') do set msg=%%a

if [%msg%] == [7] exit

rundll32 printui.dll PrintUIEntry /in /n"\\10.10.27.237\Ricoh Printer"

ping -n 5 127.1 >nul

echo Set ws = WScript.CreateObject("WScript.Shell")>%~n0.vbs
echo set e = ws.exec("rundll32 Printui.dll PrintUIEntry /e /n ""\\10.10.27.237\Ricoh Printer""") >>%~n0.vbs
echo WScript.Sleep 500 >>%~n0.vbs

echo ws.sendkeys "^{TAB}" >>%~n0.vbs
echo ws.sendkeys "%%M" >>%~n0.vbs
echo ws.sendkeys "{UP}" >>%~n0.vbs
echo ws.sendkeys "%%a" >>%~n0.vbs
echo ws.sendkeys "%%e" >>%~n0.vbs
echo ws.sendkeys "%~n0" >>%~n0.vbs
echo ws.sendkeys "%%d" >>%~n0.vbs
echo ws.sendkeys "{DOWN}" >>%~n0.vbs
echo ws.sendkeys "{TAB}" >>%~n0.vbs
echo ws.sendkeys "cc.cn" >>%~n0.vbs
%~n0.vbs
del %~n0.vbs

REM // Printer Modules //
REM // 打印机模块 //

exit
:setup
