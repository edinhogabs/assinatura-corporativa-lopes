@echo off
setlocal

pushd "%~dp0" >nul
if errorlevel 1 (
    echo Nao foi possivel acessar a pasta do instalador:
    echo %~dp0
    pause
    exit /b 1
)

if not exist ".\config\config.json" (
    echo Arquivo config\config.json nao encontrado.
    echo Verifique se o instalador esta junto das pastas config e scripts.
    popd
    pause
    exit /b 1
)

if not exist ".\scripts\05_instalar_assinatura_usuario.ps1" (
    echo Script scripts\05_instalar_assinatura_usuario.ps1 nao encontrado.
    echo Verifique se o instalador esta junto das pastas config e scripts.
    popd
    pause
    exit /b 1
)

powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\scripts\05_instalar_assinatura_usuario.ps1"
set "EXIT_CODE=%ERRORLEVEL%"

echo.
if not "%EXIT_CODE%"=="0" (
    echo Falha ao instalar assinatura. Codigo: %EXIT_CODE%
    popd
    pause
    exit /b %EXIT_CODE%
)

echo Assinatura instalada com sucesso.
popd
pause
exit /b 0
