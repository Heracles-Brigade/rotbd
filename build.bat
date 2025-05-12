@echo off
REM f not exist "dist" mkdir "dist"
REM el ".\dist\*" /Q
REM opy .\deps\BZ98R-Advanced-Lua-API\baked\*.lua ".\dist"
REM or /R .\src %%F in (*) do xcopy "%%F" ".\dist" /Y /EXCLUDE:no_dist.txt

setlocal enabledelayedexpansion

REM Check if the -dev argument is provided
set DEV_MODE=0
if "%1"=="-dev" set DEV_MODE=1

REM Ensure the dist folder exists
if not exist "dist" mkdir "dist"

REM Clear the dist folder
del ".\dist\*" /Q

REM Define the exclude filter
set EXCLUDE_FILE=no_dist.txt

REM Function to check if a file is excluded
for /F "delims=" %%E in (%EXCLUDE_FILE%) do (
    set "EXCLUDE[%%E]=1"
)

REM Copy or create symlinks/junctions
if %DEV_MODE%==1 (
    echo Running in DEV mode: Creating symlinks/junctions...
    for /R .\src %%F in (*) do (
        if not defined EXCLUDE[%%~nxF] (
            mklink ".\dist\%%~nxF" "%%F" >nul 2>&1
        )
    )
) else (
    echo Running in normal mode: Copying files...
    for /R .\src %%F in (*) do (
        if not defined EXCLUDE[%%~nxF] (
            copy "%%F" ".\dist\%%~nxF" >nul
        )
    )
)

REM Copy baked Lua files
if %DEV_MODE%==1 (
    echo Running in DEV mode: Creating symlinks/junctions...
    for /R .\deps\BZ98R-Advanced-Lua-API\baked %%F in (*) do (
        if not defined EXCLUDE[%%~nxF] (
            mklink ".\dist\%%~nxF" "%%F" >nul 2>&1
        )
    )
) else (
    echo Running in normal mode: Copying files...
    for /R .\deps\BZ98R-Advanced-Lua-API\baked %%F in (*) do (
        if not defined EXCLUDE[%%~nxF] (
            copy "%%F" ".\dist\%%~nxF" >nul
        )
    )
)

echo Build complete.