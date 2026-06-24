Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Drawing

$ProjectRoot = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$ConfigPath = Join-Path $ProjectRoot "config\config.json"

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $logPath = Join-Path $ProjectRoot "logs\assinatura.log"
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $logPath) | Out-Null
    $line = "{0} [{1}] {2}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"), $Level, $Message
    Add-Content -Path $logPath -Value $line -Encoding UTF8
    Write-Host $line
}

function Get-AppConfig {
    if (-not (Test-Path -LiteralPath $ConfigPath)) {
        throw "Arquivo de configuracao nao encontrado: $ConfigPath. Copie config.example.json para config.json."
    }
    return Get-Content -Raw -Path $ConfigPath -Encoding UTF8 | ConvertFrom-Json
}

function Resolve-ConfiguredPath {
    param([string]$Path)

    if ([string]::IsNullOrWhiteSpace($Path)) {
        return $Path
    }

    if ([System.IO.Path]::IsPathRooted($Path)) {
        return $Path
    }

    return Join-Path $ProjectRoot $Path
}

function Remove-FolderContents {
    param([string]$FolderPath)
    $skip = @("Thumbs.db", "desktop.ini")
    Get-ChildItem -LiteralPath $FolderPath -Force | ForEach-Object {
        if ($_.PSIsContainer) {
            Remove-FolderContents -FolderPath $_.FullName
            Remove-Item -LiteralPath $_.FullName -Force -ErrorAction SilentlyContinue
        } elseif ($_.Name -notin $skip) {
            Remove-Item -LiteralPath $_.FullName -Force
        }
    }
}

function Clear-OutputFolder {
    param([string]$Path)

    if ([string]::IsNullOrWhiteSpace($Path)) {
        throw "Caminho de saida vazio."
    }

    if (-not (Test-Path -LiteralPath $Path)) {
        New-Item -ItemType Directory -Force -Path $Path | Out-Null
        return
    }

    Write-Log "Limpando pasta de saida: $Path"
    Remove-FolderContents -FolderPath $Path
}

function Import-DotEnv {
    $envPath = Join-Path $ProjectRoot ".env"
    if (-not (Test-Path -LiteralPath $envPath)) {
        return
    }

    Get-Content -Path $envPath -Encoding UTF8 | ForEach-Object {
        $line = $_.Trim()
        if ([string]::IsNullOrWhiteSpace($line) -or $line.StartsWith("#") -or $line -notmatch "^\s*([^=]+)\s*=\s*(.*)$") {
            return
        }
        $name = $matches[1].Trim()
        $value = $matches[2].Trim().Trim('"').Trim("'")
        [Environment]::SetEnvironmentVariable($name, $value, "Process")
    }
}

function ConvertTo-HtmlText {
    param([object]$Value)
    return [System.Net.WebUtility]::HtmlEncode(($Value | Out-String).Trim())
}

function Format-Phone {
    param([object]$Value)

    $phone = ($Value | Out-String).Trim()
    $digits = $phone -replace '\D', ''

    if ($digits.Length -eq 11) {
        return "({0}){1}-{2}" -f $digits.Substring(0, 2), $digits.Substring(2, 5), $digits.Substring(7, 4)
    }

    if ($digits.Length -eq 10) {
        return "({0}){1}-{2}" -f $digits.Substring(0, 2), $digits.Substring(2, 4), $digits.Substring(6, 4)
    }

    return $phone
}

function Draw-ImageFit {
    param(
        [System.Drawing.Graphics]$Graphics,
        [string]$Path,
        [int]$X,
        [int]$Y,
        [int]$Width,
        [int]$Height
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        return
    }

    $image = [System.Drawing.Image]::FromFile($Path)
    try {
        $ratio = [Math]::Min($Width / $image.Width, $Height / $image.Height)
        $drawWidth = [int]($image.Width * $ratio)
        $drawHeight = [int]($image.Height * $ratio)
        $drawX = $X + [int](($Width - $drawWidth) / 2)
        $drawY = $Y + [int](($Height - $drawHeight) / 2)
        $Graphics.DrawImage($image, $drawX, $drawY, $drawWidth, $drawHeight)
    }
    finally {
        $image.Dispose()
    }
}

function Get-FitFont {
    param(
        [System.Drawing.Graphics]$Graphics,
        [string]$Text,
        [System.Drawing.FontFamily]$FontFamily,
        [float]$StartSize,
        [int]$MaxWidth,
        [System.Drawing.FontStyle]$Style = [System.Drawing.FontStyle]::Regular
    )

    $size = $StartSize
    while ($size -ge 16) {
        $font = [System.Drawing.Font]::new($FontFamily, $size, $Style, [System.Drawing.GraphicsUnit]::Pixel)
        $measured = $Graphics.MeasureString($Text, $font)
        if ($measured.Width -le $MaxWidth) {
            return $font
        }
        $font.Dispose()
        $size -= 2
    }

    return [System.Drawing.Font]::new($FontFamily, 16, $Style, [System.Drawing.GraphicsUnit]::Pixel)
}

function Get-FitSize {
    param(
        [System.Drawing.Graphics]$Graphics,
        [string[]]$Texts,
        [System.Drawing.FontFamily]$FontFamily,
        [float]$StartSize,
        [int]$MaxWidth,
        [System.Drawing.FontStyle]$Style = [System.Drawing.FontStyle]::Regular
    )
    $size = $StartSize
    while ($size -ge 16) {
        $allFit = $true
        foreach ($text in $Texts) {
            $font = [System.Drawing.Font]::new($FontFamily, $size, $Style, [System.Drawing.GraphicsUnit]::Pixel)
            $fits = $Graphics.MeasureString($text, $font).Width -le $MaxWidth
            $font.Dispose()
            if (-not $fits) { $allFit = $false; break }
        }
        if ($allFit) { return $size }
        $size -= 2
    }
    return 16.0
}

function Initialize-FontCollections {
    param([string]$FontsFolder)

    $boldPfc   = [System.Drawing.Text.PrivateFontCollection]::new()
    $mediumPfc = [System.Drawing.Text.PrivateFontCollection]::new()

    $boldPath   = Join-Path $FontsFolder "AkzidenzGroteskBQ-BdCndAlt.ttf"
    $mediumPath = Join-Path $FontsFolder "AkzidenzGroteskBQ-MdCndAlt.ttf"

    if (Test-Path -LiteralPath $boldPath)   { $boldPfc.AddFontFile($boldPath) }
    if (Test-Path -LiteralPath $mediumPath) { $mediumPfc.AddFontFile($mediumPath) }

    $boldFamily   = if ($boldPfc.Families.Count   -gt 0) { $boldPfc.Families[0]   } else { [System.Drawing.FontFamily]::new("Arial") }
    $mediumFamily = if ($mediumPfc.Families.Count -gt 0) { $mediumPfc.Families[0] } else { [System.Drawing.FontFamily]::new("Arial Narrow") }

    return @{
        BoldCollection   = $boldPfc
        MediumCollection = $mediumPfc
        BoldFamily       = $boldFamily
        MediumFamily     = $mediumFamily
    }
}

function New-SignaturePreviewPng {
    param($Config, [System.Data.DataRow]$Employee, [string]$Destination)

    $assetsSource = Resolve-ConfiguredPath $Config.Paths.AssetsFolder
    $backgroundPath = Join-Path $assetsSource "bg.png"
    if (-not (Test-Path -LiteralPath $backgroundPath)) {
        return
    }

    $fonts        = Initialize-FontCollections -FontsFolder (Join-Path $ProjectRoot "fontes")
    $boldFamily   = $fonts.BoldFamily
    $mediumFamily = $fonts.MediumFamily

    $signatureName = $Config.Company.SignatureName
    $outputPath = Join-Path $Destination "$signatureName.png"
    $background = [System.Drawing.Image]::FromFile($backgroundPath)
    $bitmap = [System.Drawing.Bitmap]::new($background.Width, $background.Height)
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)

    try {
        $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
        $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
        $graphics.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit
        $graphics.DrawImage($background, 0, 0, $background.Width, $background.Height)

        $blue = [System.Drawing.ColorTranslator]::FromHtml("#00528D")
        $red = [System.Drawing.ColorTranslator]::FromHtml("#C91522")
        $blueBrush = [System.Drawing.SolidBrush]::new($blue)
        $redBrush = [System.Drawing.SolidBrush]::new($red)
        $bluePen = [System.Drawing.Pen]::new($blue, 3)

        try {
            Draw-ImageFit -Graphics $graphics -Path (Join-Path $assetsSource "logo-lopes.png") -X 70 -Y 50 -Width 350 -Height 300

            $name = ($Employee.NOME_ASSINATURA | Out-String).Trim()
            $role = ($Employee.FUNCAO | Out-String).Trim()
            $email = ($Employee.EMAIL_ASSINATURA | Out-String).Trim()
            $phone = Format-Phone $Employee.TELEFONE
            $site = ($Employee.SITE | Out-String).Trim()

            $nameFont    = Get-FitFont -Graphics $graphics -Text $name  -FontFamily $boldFamily   -StartSize 48 -MaxWidth 420
            $roleFont    = Get-FitFont -Graphics $graphics -Text $role  -FontFamily $mediumFamily -StartSize 36 -MaxWidth 420
            $contactSize = Get-FitSize -Graphics $graphics -Texts @($email, $phone, $site) -FontFamily $mediumFamily -StartSize 27 -MaxWidth 390
            $contactFont = [System.Drawing.Font]::new($mediumFamily, $contactSize, [System.Drawing.FontStyle]::Regular, [System.Drawing.GraphicsUnit]::Pixel)
            $phoneFont   = [System.Drawing.Font]::new($mediumFamily, $contactSize, [System.Drawing.FontStyle]::Regular, [System.Drawing.GraphicsUnit]::Pixel)
            $siteFont    = [System.Drawing.Font]::new($mediumFamily, $contactSize, [System.Drawing.FontStyle]::Regular, [System.Drawing.GraphicsUnit]::Pixel)

            try {
                $graphics.DrawString($name, $nameFont, $blueBrush, 482, 82)
                $graphics.DrawString($role, $roleFont, $blueBrush, 483, 134)

                Draw-ImageFit -Graphics $graphics -Path (Join-Path $assetsSource "email.png") -X 488 -Y 196 -Width 26 -Height 26
                $graphics.DrawString($email, $contactFont, $blueBrush, 529, 194)

                Draw-ImageFit -Graphics $graphics -Path (Join-Path $assetsSource "whats.png") -X 488 -Y 247 -Width 26 -Height 26
                $graphics.DrawString($phone, $phoneFont, $blueBrush, 529, 245)

                Draw-ImageFit -Graphics $graphics -Path (Join-Path $assetsSource "web.png") -X 488 -Y 298 -Width 26 -Height 26
                $graphics.DrawString($site, $siteFont, $blueBrush, 529, 296)
            }
            finally {
                $nameFont.Dispose()
                $roleFont.Dispose()
                $contactFont.Dispose()
                $phoneFont.Dispose()
                $siteFont.Dispose()
            }

            $graphics.DrawLine($bluePen, 1030, 82, 1030, 318)
            Draw-ImageFit -Graphics $graphics -Path (Join-Path $assetsSource "logo-principal.png") -X 1120 -Y 118 -Width 360 -Height 110
            Draw-ImageFit -Graphics $graphics -Path (Join-Path $assetsSource "instagram.png") -X 1200 -Y 240 -Width 42 -Height 42
            Draw-ImageFit -Graphics $graphics -Path (Join-Path $assetsSource "facebook.png") -X 1290 -Y 240 -Width 42 -Height 42
            Draw-ImageFit -Graphics $graphics -Path (Join-Path $assetsSource "linkedin.png") -X 1380 -Y 240 -Width 42 -Height 42
        }
        finally {
            $blueBrush.Dispose()
            $redBrush.Dispose()
            $bluePen.Dispose()
        }

        $bitmap.Save($outputPath, [System.Drawing.Imaging.ImageFormat]::Png)
    }
    finally {
        $graphics.Dispose()
        $bitmap.Dispose()
        $background.Dispose()
        $fonts.BoldCollection.Dispose()
        $fonts.MediumCollection.Dispose()
    }
}

function Get-Password {
    param($Config)

    $password = [Environment]::GetEnvironmentVariable($Config.Database.PasswordEnvironmentVariable, "Process")
    if ([string]::IsNullOrWhiteSpace($password)) {
        $password = [Environment]::GetEnvironmentVariable($Config.Database.PasswordEnvironmentVariable, "User")
    }
    if ([string]::IsNullOrWhiteSpace($password)) {
        $password = [Environment]::GetEnvironmentVariable($Config.Database.PasswordEnvironmentVariable, "Machine")
    }
    if ([string]::IsNullOrWhiteSpace($password)) {
        throw "Variavel de ambiente de senha nao encontrada: $($Config.Database.PasswordEnvironmentVariable)"
    }
    return $password
}

function Invoke-AllEmployeesQuery {
    param($Config)

    $queryPath = Resolve-ConfiguredPath $Config.Paths.AllEmployeesQueryFile
    $query = Get-Content -Raw -Path $queryPath -Encoding UTF8
    $password = Get-Password -Config $Config

    $connectionString = "DSN=$($Config.Database.Dsn);UID=$($Config.Database.User);PWD=$password;"
    $connection = [System.Data.Odbc.OdbcConnection]::new($connectionString)
    $connection.Open()

    try {
        $command = $connection.CreateCommand()
        $command.CommandText = $query

        $adapter = [System.Data.Odbc.OdbcDataAdapter]::new($command)
        $table = [System.Data.DataTable]::new()
        [void]$adapter.Fill($table)
        return ,$table
    }
    finally {
        $connection.Close()
    }
}

function Get-SafeFolderName {
    param([string]$Email)

    $login = ($Email -split "@")[0].ToLowerInvariant()
    return ($login -replace '[<>:"/\\|?*]', "_")
}

function Get-SignatureImageSrc {
    param($Config, [string]$FolderName)

    if ($Config.Paths.PSObject.Properties.Name -contains "ImageBaseUrl" -and -not [string]::IsNullOrWhiteSpace($Config.Paths.ImageBaseUrl)) {
        return ("{0}/{1}.png" -f $Config.Paths.ImageBaseUrl.TrimEnd("/"), $FolderName)
    }

    return "assinatura_files/image001.png"
}

function New-SignatureFiles {
    param($Config, [System.Data.DataRow]$Employee, [string]$DestinationRoot, [string]$PngOutputRoot)

    $signatureName = $Config.Company.SignatureName
    $folderName = Get-SafeFolderName -Email $Employee.EMAIL_ASSINATURA
    $destination = Join-Path $DestinationRoot $folderName
    New-Item -ItemType Directory -Force -Path $destination | Out-Null

    $templatePath = Resolve-ConfiguredPath $Config.Paths.TemplateFile
    $template = Get-Content -Raw -Path $templatePath -Encoding UTF8

    $phone = Format-Phone $Employee.TELEFONE
    $imageSrc = Get-SignatureImageSrc -Config $Config -FolderName $folderName

    $html = $template `
        -replace "{{NOME}}", (ConvertTo-HtmlText $Employee.NOME_ASSINATURA) `
        -replace "{{FUNCAO}}", (ConvertTo-HtmlText $Employee.FUNCAO) `
        -replace "{{EMAIL}}", (ConvertTo-HtmlText $Employee.EMAIL_ASSINATURA) `
        -replace "{{TELEFONE}}", (ConvertTo-HtmlText $phone) `
        -replace "{{SITE}}", (ConvertTo-HtmlText $Employee.SITE) `
        -replace "{{IMAGEM_ASSINATURA}}", (ConvertTo-HtmlText $imageSrc)

    Set-Content -Path (Join-Path $destination "$signatureName.htm") -Value $html -Encoding UTF8
    Set-Content -Path (Join-Path $destination "$signatureName.txt") -Value @(
        $Employee.NOME_ASSINATURA
        $Employee.FUNCAO
        $Employee.EMAIL_ASSINATURA
        $phone
        $Employee.SITE
    ) -Encoding UTF8

    New-SignaturePreviewPng -Config $Config -Employee $Employee -Destination $destination

    $sourcePng = Join-Path $destination "$signatureName.png"
    $signatureFilesFolder = Join-Path $destination "assinatura_files"
    New-Item -ItemType Directory -Force -Path $signatureFilesFolder | Out-Null
    if (Test-Path -LiteralPath $sourcePng) {
        Copy-Item -LiteralPath $sourcePng -Destination (Join-Path $signatureFilesFolder "image001.png") -Force
    }

    if (-not [string]::IsNullOrWhiteSpace($PngOutputRoot)) {
        New-Item -ItemType Directory -Force -Path $PngOutputRoot | Out-Null
        if (Test-Path -LiteralPath $sourcePng) {
            Copy-Item -LiteralPath $sourcePng -Destination (Join-Path $PngOutputRoot "$folderName.png") -Force
        }
    }

    $assetsSource = Resolve-ConfiguredPath $Config.Paths.AssetsFolder
    if (Test-Path -LiteralPath $assetsSource) {
        Get-ChildItem -Path $assetsSource -File | Where-Object { $_.Name -ne ".gitkeep" } | ForEach-Object {
            Copy-Item -LiteralPath $_.FullName -Destination $destination -Force
        }
    }

    return $destination
}

try {
    Import-DotEnv
    $config = Get-AppConfig
    $outputRoot = Resolve-ConfiguredPath $config.Paths.LocalOutputFolder
    $pngOutputRoot = Resolve-ConfiguredPath $config.Paths.PngOutputFolder

    Write-Log "Iniciando geracao local de assinaturas em $outputRoot."
    $employees = Invoke-AllEmployeesQuery -Config $config

    if ($employees.Rows.Count -eq 0) {
        Write-Log "Nenhum colaborador encontrado para geracao local. Encerrando sem erro." "WARN"
        exit 0
    }

    Clear-OutputFolder -Path $outputRoot
    Clear-OutputFolder -Path $pngOutputRoot
    New-Item -ItemType Directory -Force -Path $outputRoot | Out-Null
    New-Item -ItemType Directory -Force -Path $pngOutputRoot | Out-Null

    $count = 0
    foreach ($employee in $employees.Rows) {
        [void](New-SignatureFiles -Config $config -Employee $employee -DestinationRoot $outputRoot -PngOutputRoot $pngOutputRoot)
        $count++
    }

    Write-Log "Geracao local concluida. Total de assinaturas: $count. Pasta: $outputRoot."
    Write-Log "PNGs consolidados em: $pngOutputRoot."
}
catch {
    Write-Log "Erro ao gerar assinaturas locais: $($_.Exception.Message)" "ERROR"
    exit 1
}
