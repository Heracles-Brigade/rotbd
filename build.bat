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

REM Define allowed extensions (space-separated, include dot)
set "ALLOWED_EXT=.bzn .hg2 .lua .mat .trn .otf .wav .dds .png .material .geo .mesh .skeleton .sdf .vdf .odf .inf .des .ini .sta .cfg .txdi"

REM Need
REM .bzn .hg2 .lua .mat .trn
REM .otf .wav
REM .dds .png .material
REM .geo .mesh .skeleton .sdf .vdf
REM .odf .inf .des .ini .sta

REM Temporary
REM .txdi

REM BZ1 Only
REM .hgt .lgt .map

REM Excluded
REM .notes

REM Copy or create symlinks/junctions
if %DEV_MODE%==1 (
    echo Running in DEV mode: Creating symlinks/junctions...
    for /R .\src %%F in (*) do (
        set "IS_ALLOWED=0"
        for %%E in (%ALLOWED_EXT%) do (
            if /I "%%~xF"=="%%E" set "IS_ALLOWED=1"
        )
        if !IS_ALLOWED! == 1 (
            mklink ".\dist\%%~nxF" "%%F" >nul 2>&1
        )
    )
) else (
    echo Running in normal mode: Copying files...
    for /R .\src %%F in (*) do (
        set "IS_ALLOWED=0"
        for %%E in (%ALLOWED_EXT%) do (
            if /I "%%~xF"=="%%E" set "IS_ALLOWED=1"
        )
        if !IS_ALLOWED! == 1 (
            copy "%%F" ".\dist\%%~nxF" >nul
        )
    )
)

REM Copy baked Lua files
if %DEV_MODE%==1 (
    echo Running in DEV mode: Creating symlinks/junctions...
    for /R .\deps\BZ98R-Advanced-Lua-API\baked %%F in (*) do (
        set "IS_ALLOWED=0"
        for %%E in (%ALLOWED_EXT%) do (
            if /I "%%~xF"=="%%E" set "IS_ALLOWED=1"
        )
        if !IS_ALLOWED! == 1 (
            mklink ".\dist\%%~nxF" "%%F" >nul 2>&1
        )
    )
) else (
    echo Running in normal mode: Copying files...
    for /R .\deps\BZ98R-Advanced-Lua-API\baked %%F in (*) do (
        set "IS_ALLOWED=0"
        for %%E in (%ALLOWED_EXT%) do (
            if /I "%%~xF"=="%%E" set "IS_ALLOWED=1"
        )
        if !IS_ALLOWED! == 1 (
            copy "%%F" ".\dist\%%~nxF" >nul
        )
    )
)

echo Build complete.