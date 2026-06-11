Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$ProjectRoot = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$ConfigPath = Join-Path $ProjectRoot "config\config.json"

function Write-Message {
    param([string]$Message)
    Write-Host $Message
}

function Get-AppConfig {
    if (-not (Test-Path -LiteralPath $ConfigPath)) {
        throw "Arquivo de configuracao nao encontrado: $ConfigPath"
    }
    return Get-Content -Raw -Path $ConfigPath -Encoding UTF8 | ConvertFrom-Json
}

function ConvertTo-SignatureLogin {
    param([string]$Value)

    $normalized = $Value.Trim().ToLowerInvariant()
    $normalized = $normalized -replace '\s+', '.'
    $normalized = $normalized -replace '[^a-z0-9._-]', ''
    return $normalized
}

function Resolve-SourceFolder {
    param($Config)

    $source = $Config.Install.SignaturesSourceFolder
    if ([string]::IsNullOrWhiteSpace($source)) {
        throw "Install.SignaturesSourceFolder nao configurado no config.json."
    }

    if ([System.IO.Path]::IsPathRooted($source)) {
        return $source
    }

    return Join-Path $ProjectRoot $source
}

try {
    $config = Get-AppConfig
    $signatureName = $config.Company.SignatureName
    $sourceRoot = Resolve-SourceFolder -Config $config

    $candidates = @()
    if (-not [string]::IsNullOrWhiteSpace($env:USERNAME)) {
        $candidates += (ConvertTo-SignatureLogin $env:USERNAME)
    }

    try {
        $windowsName = ([System.DirectoryServices.AccountManagement.UserPrincipal]::Current.DisplayName)
        if (-not [string]::IsNullOrWhiteSpace($windowsName)) {
            $candidates += (ConvertTo-SignatureLogin $windowsName)
        }
    }
    catch {
        # DisplayName pode nao estar disponivel em maquinas fora de dominio.
    }

    $candidates = @($candidates | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -Unique)
    if ($candidates.Count -eq 0) {
        throw "Nao consegui identificar o usuario logado."
    }

    Write-Message "Usuario Windows: $env:USERNAME"
    Write-Message "Origem das assinaturas: $sourceRoot"
    Write-Message "Tentando localizar assinatura em: $($candidates -join ', ')"

    if (-not (Test-Path -LiteralPath $sourceRoot)) {
        throw "A pasta de origem nao esta acessivel: $sourceRoot"
    }

    $employeeFolder = $null
    foreach ($candidate in $candidates) {
        $path = Join-Path $sourceRoot $candidate
        if (Test-Path -LiteralPath (Join-Path $path "$signatureName.htm")) {
            $employeeFolder = $path
            break
        }
    }

    if (-not $employeeFolder) {
        throw "Assinatura nao encontrada para o usuario atual. Pastas testadas: $($candidates -join ', ')"
    }

    $destination = Join-Path $env:APPDATA "Microsoft\Signatures"
    New-Item -ItemType Directory -Force -Path $destination | Out-Null

    Copy-Item -LiteralPath (Join-Path $employeeFolder "$signatureName.htm") -Destination $destination -Force
    Copy-Item -LiteralPath (Join-Path $employeeFolder "$signatureName.txt") -Destination $destination -Force

    $mailSettings = "HKCU:\Software\Microsoft\Office\16.0\Common\MailSettings"
    New-Item -Path $mailSettings -Force | Out-Null
    Set-ItemProperty -Path $mailSettings -Name "NewSignature" -Value $signatureName
    Set-ItemProperty -Path $mailSettings -Name "ReplySignature" -Value $signatureName

    Write-Message "Assinatura instalada com sucesso: $signatureName"
    Write-Message "Destino: $destination"
    Write-Message "Feche e abra o Outlook para atualizar."
    exit 0
}
catch {
    Write-Host "Erro ao instalar assinatura: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
