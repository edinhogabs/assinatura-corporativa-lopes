@echo off
setlocal

cd /d "%~dp0"

powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\scripts\04_gerar_assinaturas_local.ps1"
set "EXIT_CODE=%ERRORLEVEL%"

if not "%EXIT_CODE%"=="0" (
    echo.
    echo Erro ao gerar assinaturas. Codigo: %EXIT_CODE%
    exit /b %EXIT_CODE%
)

echo.
echo Assinaturas geradas com sucesso.
exit /b 0
