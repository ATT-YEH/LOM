@echo off
setlocal

rem ============================================================
rem  Legend of Mortal - one-click save backup to private GitHub repo
rem ============================================================

rem ---- Settings (change if needed) ----
set "SAVE_DIR=%USERPROFILE%\AppData\LocalLow\Obb Studio\Mortal"
set "REPO_DIR=%USERPROFILE%\LOM-save-backup"
set "REMOTE_URL=https://github.com/ATT-YEH/LOM-save-backup.git"
set "REG_KEY=HKCU\Software\Obb Studio\Mortal"
rem -------------------------------------

echo.
echo [LOM backup] Start
echo.

where git >nul 2>&1
if errorlevel 1 (
    echo [ERROR] Git not found. Install Git for Windows first: https://git-scm.com/download/win
    goto :end
)

if not exist "%SAVE_DIR%" (
    echo [ERROR] Save folder not found:
    echo         %SAVE_DIR%
    goto :end
)

tasklist /FI "IMAGENAME eq Mortal.exe" 2>nul | find /I "Mortal.exe" >nul
if not errorlevel 1 (
    echo [WARN] The game seems to be running. Close it first so the save files are complete.
    pause
)

rem ---- First run: clone the private repo ----
if not exist "%REPO_DIR%\.git" (
    echo [INFO] First run, cloning backup repo...
    git clone "%REMOTE_URL%" "%REPO_DIR%"
    if errorlevel 1 (
        echo [ERROR] Clone failed. Check that the private repo LOM-save-backup exists on GitHub
        echo         and that you are logged in.
        goto :end
    )
)

cd /d "%REPO_DIR%"

rem ---- Keep save files byte-exact (no line-ending conversion) ----
if not exist "%REPO_DIR%\.gitattributes" (
    echo * -text> "%REPO_DIR%\.gitattributes"
)
git config core.autocrlf false

git config user.name >nul 2>&1 || git config user.name "ATT-YEH"
git config user.email >nul 2>&1 || git config user.email "ATT-YEH@users.noreply.github.com"

rem ---- Copy save folder (mirror) ----
robocopy "%SAVE_DIR%" "%REPO_DIR%\Mortal" /MIR /R:2 /W:1 /NFL /NDL /NJH /NJS /NP >nul
if errorlevel 8 (
    echo [ERROR] Copy failed.
    goto :end
)
echo [OK] Save folder copied

rem ---- Export registry (Unity settings, in case progress is stored there) ----
reg query "%REG_KEY%" >nul 2>&1
if not errorlevel 1 (
    reg export "%REG_KEY%" "%REPO_DIR%\registry.reg" /y >nul
    echo [OK] Registry exported
) else (
    echo [INFO] No registry key found, skipped
)

rem ---- Commit and push ----
for /f "usebackq delims=" %%t in (`powershell -NoProfile -Command "Get-Date -Format 'yyyy-MM-dd HH:mm'"`) do set "NOW=%%t"

git add -A
git diff --cached --quiet
if not errorlevel 1 (
    echo [INFO] Nothing changed since last backup.
    goto :end
)

git commit -q -m "Save backup %NOW%"
git push -q
if errorlevel 1 (
    git push -q -u origin HEAD
    if errorlevel 1 (
        echo [ERROR] Push failed. The backup is committed locally; run this again later.
        goto :end
    )
)

echo.
echo [DONE] Backup %NOW% pushed to GitHub.

:end
echo.
pause
endlocal
