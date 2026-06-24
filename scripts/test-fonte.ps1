Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Drawing

$ProjectRoot  = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$AssetsFolder = Join-Path $ProjectRoot "assets"
$FontsFolder  = Join-Path $ProjectRoot "fontes"
$OutputDir    = Join-Path $ProjectRoot "output"
$OutputPath   = Join-Path $OutputDir   "teste-fonte.png"

New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null

function Invoke-DrawImageFit {
    param(
        [System.Drawing.Graphics]$Graphics,
        [string]$Path,
        [int]$X, [int]$Y, [int]$Width, [int]$Height
    )
    if (-not (Test-Path -LiteralPath $Path)) { return }
    $img = [System.Drawing.Image]::FromFile($Path)
    try {
        $ratio = [Math]::Min($Width / $img.Width, $Height / $img.Height)
        $dw = [int]($img.Width * $ratio); $dh = [int]($img.Height * $ratio)
        $dx = $X + [int](($Width - $dw) / 2); $dy = $Y + [int](($Height - $dh) / 2)
        $Graphics.DrawImage($img, $dx, $dy, $dw, $dh)
    } finally { $img.Dispose() }
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
        if ($Graphics.MeasureString($Text, $font).Width -le $MaxWidth) { return $font }
        $font.Dispose()
        $size -= 2
    }
    return [System.Drawing.Font]::new($FontFamily, 16, $Style, [System.Drawing.GraphicsUnit]::Pixel)
}

# Carregar fontes customizadas
$boldPfc   = [System.Drawing.Text.PrivateFontCollection]::new()
$mediumPfc = [System.Drawing.Text.PrivateFontCollection]::new()
$boldPfc.AddFontFile((Join-Path $FontsFolder "AkzidenzGroteskBQ-BdCndAlt.ttf"))
$mediumPfc.AddFontFile((Join-Path $FontsFolder "AkzidenzGroteskBQ-MdCndAlt.ttf"))
$boldFamily   = $boldPfc.Families[0]
$mediumFamily = $mediumPfc.Families[0]

Write-Host "Fonte negrito : $($boldFamily.Name)"
Write-Host "Fonte regular : $($mediumFamily.Name)"

# Dados de teste (replicando o padrao.jpg)
$nome  = "Claudia Leao"
$cargo = "Assistente Administrativo"
$email = "claudia.leao@distribuidoralopes.com"
$fone  = "(92)98114-9736"
$site  = "www.distribuidoralopes.com"

$background = [System.Drawing.Image]::FromFile((Join-Path $AssetsFolder "bg.png"))
$bitmap     = [System.Drawing.Bitmap]::new($background.Width, $background.Height)
$graphics   = [System.Drawing.Graphics]::FromImage($bitmap)

try {
    $graphics.SmoothingMode     = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $graphics.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit
    $graphics.DrawImage($background, 0, 0, $background.Width, $background.Height)

    $blue      = [System.Drawing.ColorTranslator]::FromHtml("#00528D")
    $blueBrush = [System.Drawing.SolidBrush]::new($blue)
    $bluePen   = [System.Drawing.Pen]::new($blue, 3)

    try {
        Invoke-DrawImageFit -Graphics $graphics -Path (Join-Path $AssetsFolder "logo-lopes.png") -X 70 -Y 50 -Width 350 -Height 300

        $nameFont    = Get-FitFont -Graphics $graphics -Text $nome  -FontFamily $boldFamily   -StartSize 48 -MaxWidth 420
        $roleFont    = Get-FitFont -Graphics $graphics -Text $cargo -FontFamily $mediumFamily -StartSize 36 -MaxWidth 420
        $contactSize = Get-FitSize -Graphics $graphics -Texts @($email, $fone, $site) -FontFamily $mediumFamily -StartSize 27 -MaxWidth 390
        $contactFont = [System.Drawing.Font]::new($mediumFamily, $contactSize, [System.Drawing.FontStyle]::Regular, [System.Drawing.GraphicsUnit]::Pixel)
        $phoneFont   = [System.Drawing.Font]::new($mediumFamily, $contactSize, [System.Drawing.FontStyle]::Regular, [System.Drawing.GraphicsUnit]::Pixel)
        $siteFont    = [System.Drawing.Font]::new($mediumFamily, $contactSize, [System.Drawing.FontStyle]::Regular, [System.Drawing.GraphicsUnit]::Pixel)

        try {
            $graphics.DrawString($nome,  $nameFont,    $blueBrush, 482, 82)
            $graphics.DrawString($cargo, $roleFont,    $blueBrush, 483, 134)
            Invoke-DrawImageFit -Graphics $graphics -Path (Join-Path $AssetsFolder "email.png") -X 488 -Y 196 -Width 26 -Height 26
            $graphics.DrawString($email, $contactFont, $blueBrush, 529, 194)
            Invoke-DrawImageFit -Graphics $graphics -Path (Join-Path $AssetsFolder "whats.png") -X 488 -Y 247 -Width 26 -Height 26
            $graphics.DrawString($fone,  $phoneFont,   $blueBrush, 529, 245)
            Invoke-DrawImageFit -Graphics $graphics -Path (Join-Path $AssetsFolder "web.png")   -X 488 -Y 298 -Width 26 -Height 26
            $graphics.DrawString($site,  $siteFont,    $blueBrush, 529, 296)
        } finally {
            $nameFont.Dispose(); $roleFont.Dispose(); $contactFont.Dispose()
            $phoneFont.Dispose(); $siteFont.Dispose()
        }

        $graphics.DrawLine($bluePen, 1030, 82, 1030, 318)
        Invoke-DrawImageFit -Graphics $graphics -Path (Join-Path $AssetsFolder "logo-principal.png") -X 1120 -Y 118 -Width 360 -Height 110
        Invoke-DrawImageFit -Graphics $graphics -Path (Join-Path $AssetsFolder "instagram.png") -X 1200 -Y 240 -Width 42 -Height 42
        Invoke-DrawImageFit -Graphics $graphics -Path (Join-Path $AssetsFolder "facebook.png")  -X 1290 -Y 240 -Width 42 -Height 42
        Invoke-DrawImageFit -Graphics $graphics -Path (Join-Path $AssetsFolder "linkedin.png")  -X 1380 -Y 240 -Width 42 -Height 42
    } finally {
        $blueBrush.Dispose()
        $bluePen.Dispose()
    }

    $bitmap.Save($OutputPath, [System.Drawing.Imaging.ImageFormat]::Png)
    Write-Host "Imagem gerada: $OutputPath"
} finally {
    $graphics.Dispose()
    $bitmap.Dispose()
    $background.Dispose()
    $boldPfc.Dispose()
    $mediumPfc.Dispose()
}
