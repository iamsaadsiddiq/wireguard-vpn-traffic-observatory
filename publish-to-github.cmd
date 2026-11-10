@echo off
setlocal EnableExtensions
cd /d "%~dp0"

echo =======================================================
echo  WireGuard VPN Lab - GitHub Repository Publisher
echo =======================================================
echo.

where git >nul 2>&1
if errorlevel 1 (
    echo ERROR: Git is missing. Install from https://git-scm.com/download/win
    exit /b 1
)
where gh >nul 2>&1
if errorlevel 1 (
    echo ERROR: GitHub CLI is missing. Install from https://cli.github.com/
    exit /b 1
)

gh auth status >nul 2>&1
if errorlevel 1 (
    echo GitHub CLI is not yet authenticated on this computer.
    echo Sign in through your browser when prompted.
    gh auth login
    if errorlevel 1 exit /b 1
)

set "OWNER=iamsaadsiddiq"
set "REPO=wireguard-vpn-traffic-observatory"

echo.
echo Publishing project to %OWNER%/%REPO% ...
echo Only files that are not ignored will be included.
echo Do NOT add keys, client .conf files or real traffic captures.
set /p "CONFIRM=Continue? (y/N): "
if /i not "%CONFIRM%"=="y" exit /b 0

if not exist .git (
    git init -b main
    if errorlevel 1 exit /b 1
)
git add .
if errorlevel 1 exit /b 1
echo Files staged:
git diff --cached --name-only
git diff --cached --quiet
if errorlevel 1 (
    git commit -m "Update WireGuard VPN Lab"
    if errorlevel 1 exit /b 1
)

git remote get-url origin >nul 2>&1
if errorlevel 1 (
    git remote add origin "https://github.com/%OWNER%/%REPO%.git"
    if errorlevel 1 exit /b 1
)
echo Pulling changes from remote. Resolve conflicts rather than force pushing.
git pull origin main --rebase
if errorlevel 1 exit /b 1
git push -u origin main
if errorlevel 1 exit /b 1
echo Repository updated successfully.
gh repo view "%OWNER%/%REPO%" --web
