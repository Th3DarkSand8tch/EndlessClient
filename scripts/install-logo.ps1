<#
.SYNOPSIS
    Genere toutes les declinaisons du logo a partir d'un seul fichier source.

.DESCRIPTION
    Depose ton logo une fois (PNG carre avec transparence, 512 px minimum) et
    lance ce script : il produit et place les sept fichiers attendus par le site
    et par le catalogue.

        public/logo.png                   512  og:image, en-tete
        public/android-chrome-512x512.png 512  manifeste PWA
        public/android-chrome-192x192.png 192  manifeste PWA
        public/apple-touch-icon.png       180  ecran d'accueil iOS
        public/favicon.ico           16/32/48  onglet navigateur
        public/favicon.svg                256  onglet, variante vectorielle
        mods/logo.png                     512  en-tete du catalogue

    Le redimensionnement passe par un bicubique haute qualite en
    PixelFormat.Format32bppArgb : la transparence du logo est preservee, et le
    fond reste transparent plutot que de virer au noir.

    Le .ico est ecrit a la main. System.Drawing ne sait produire qu'une icone
    32x32 monobloc via Icon.FromHandle, alors qu'un favicon correct embarque
    plusieurs tailles. On assemble donc un conteneur ICO contenant trois PNG,
    format accepte par tous les navigateurs actuels.

    favicon.svg est regenere comme un SVG enveloppant le PNG en data URI. Cela
    evite de toucher a BaseHead.astro, qui reference `/favicon.svg` en
    `type="image/svg+xml"` avec une priorite superieure au .ico.

.EXAMPLE
    pwsh -File scripts/install-logo.ps1 -Source ..\logo-source.png
    pwsh -File scripts/install-logo.ps1 -Source D:\logo.png -WhatIf
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory)]
    [string] $Source,

    [string] $Root = (Join-Path $PSScriptRoot '..')
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing

$Source = (Resolve-Path $Source).Path
$Root   = (Resolve-Path $Root).Path
$Public = Join-Path $Root 'web\apps\website\public'
$Mods   = Join-Path $Root 'mods'

foreach ($dir in @($Public, $Mods)) {
    if (-not (Test-Path -LiteralPath $dir)) { throw "Dossier introuvable : $dir" }
}

function New-Square {
    <#
        Redimensionne en carre sans deformer : l'image est contenue puis
        centree sur un fond transparent.
    #>
    param([System.Drawing.Image] $Image, [int] $Size)

    $bitmap = New-Object System.Drawing.Bitmap($Size, $Size, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    try {
        $graphics.CompositingMode    = [System.Drawing.Drawing2D.CompositingMode]::SourceCopy
        $graphics.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality
        $graphics.InterpolationMode  = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
        $graphics.SmoothingMode      = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
        $graphics.PixelOffsetMode    = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
        $graphics.Clear([System.Drawing.Color]::Transparent)

        $ratio = [Math]::Min($Size / $Image.Width, $Size / $Image.Height)
        $w = [int][Math]::Round($Image.Width * $ratio)
        $h = [int][Math]::Round($Image.Height * $ratio)
        $x = [int](($Size - $w) / 2)
        $y = [int](($Size - $h) / 2)

        $graphics.DrawImage($Image, $x, $y, $w, $h)
    }
    finally { $graphics.Dispose() }
    return $bitmap
}

function Get-PngBytes {
    param([System.Drawing.Bitmap] $Bitmap)
    $stream = New-Object System.IO.MemoryStream
    try {
        $Bitmap.Save($stream, [System.Drawing.Imaging.ImageFormat]::Png)
        return , $stream.ToArray()
    }
    finally { $stream.Dispose() }
}

$image = [System.Drawing.Image]::FromFile($Source)
try {
    Write-Host "Source : $Source" -ForegroundColor Cyan
    Write-Host "         $($image.Width) x $($image.Height) px, $($image.PixelFormat)"

    if ($image.Width -lt 512 -or $image.Height -lt 512) {
        Write-Host "  ! source sous 512 px : les grandes tailles seront interpolees" -ForegroundColor Yellow
    }
    if ($image.Width -ne $image.Height) {
        Write-Host "  ! source non carree : le logo sera centre sur un carre transparent" -ForegroundColor Yellow
    }

    Write-Host ""
    Write-Host "Ecriture :" -ForegroundColor Cyan

    foreach ($target in @(
        @{ Size = 512; Path = (Join-Path $Public 'logo.png') },
        @{ Size = 512; Path = (Join-Path $Public 'android-chrome-512x512.png') },
        @{ Size = 192; Path = (Join-Path $Public 'android-chrome-192x192.png') },
        @{ Size = 180; Path = (Join-Path $Public 'apple-touch-icon.png') },
        @{ Size = 512; Path = (Join-Path $Mods   'logo.png') })) {

        $bitmap = New-Square -Image $image -Size $target.Size
        try {
            if ($PSCmdlet.ShouldProcess($target.Path, "ecrire $($target.Size)px")) {
                [System.IO.File]::WriteAllBytes($target.Path, (Get-PngBytes $bitmap))
                $kb = [int]((Get-Item -LiteralPath $target.Path).Length / 1KB)
                Write-Host ("  {0,-30} {1,8}  {2,4} Ko" -f (Split-Path $target.Path -Leaf), "$($target.Size)px", $kb) -ForegroundColor DarkCyan
            }
        }
        finally { $bitmap.Dispose() }
    }

    # --- favicon.ico multi-tailles ---
    $icoPath = Join-Path $Public 'favicon.ico'
    $sizes = @(16, 32, 48)
    $blobs = @()
    foreach ($size in $sizes) {
        $bitmap = New-Square -Image $image -Size $size
        try { $blobs += , (Get-PngBytes $bitmap) }
        finally { $bitmap.Dispose() }
    }

    if ($PSCmdlet.ShouldProcess($icoPath, 'ecrire ICO 16/32/48')) {
        $stream = New-Object System.IO.MemoryStream
        $writer = New-Object System.IO.BinaryWriter($stream)
        try {
            # ICONDIR : reserve, type 1 (icone), nombre d'images.
            $writer.Write([uint16]0)
            $writer.Write([uint16]1)
            $writer.Write([uint16]$sizes.Count)

            # Chaque ICONDIRENTRY fait 16 octets ; les donnees suivent le repertoire.
            $offset = 6 + (16 * $sizes.Count)
            for ($i = 0; $i -lt $sizes.Count; $i++) {
                $writer.Write([byte]$sizes[$i])   # largeur (0 signifierait 256)
                $writer.Write([byte]$sizes[$i])   # hauteur
                $writer.Write([byte]0)            # palette : aucune
                $writer.Write([byte]0)            # reserve
                $writer.Write([uint16]1)          # plans
                $writer.Write([uint16]32)         # bits par pixel
                $writer.Write([uint32]$blobs[$i].Length)
                $writer.Write([uint32]$offset)
                $offset += $blobs[$i].Length
            }
            foreach ($blob in $blobs) { $writer.Write($blob) }

            $writer.Flush()
            [System.IO.File]::WriteAllBytes($icoPath, $stream.ToArray())
        }
        finally { $writer.Dispose(); $stream.Dispose() }

        $kb = [int]((Get-Item -LiteralPath $icoPath).Length / 1KB)
        Write-Host ("  {0,-30} {1,8}  {2,4} Ko" -f 'favicon.ico', '16/32/48', $kb) -ForegroundColor DarkCyan
    }

    # --- favicon.svg : enveloppe vectorielle autour du PNG ---
    $svgPath = Join-Path $Public 'favicon.svg'
    if ($PSCmdlet.ShouldProcess($svgPath, 'ecrire SVG 256')) {
        $bitmap = New-Square -Image $image -Size 256
        try { $base64 = [Convert]::ToBase64String((Get-PngBytes $bitmap)) }
        finally { $bitmap.Dispose() }

        $svg = @"
<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" viewBox="0 0 256 256" width="256" height="256">
  <image width="256" height="256" xlink:href="data:image/png;base64,$base64"/>
</svg>
"@
        [System.IO.File]::WriteAllText($svgPath, $svg, (New-Object System.Text.UTF8Encoding $false))
        $kb = [int]((Get-Item -LiteralPath $svgPath).Length / 1KB)
        Write-Host ("  {0,-30} {1,8}  {2,4} Ko" -f 'favicon.svg', '256px', $kb) -ForegroundColor DarkCyan
    }
}
finally { $image.Dispose() }

Write-Host ""
Write-Host "Termine. Publie avec : sudo ./deploy.sh" -ForegroundColor Green
Write-Host "safari-pinned-tab.svg n'est pas regenere : c'est un masque monochrome" -ForegroundColor DarkGray
Write-Host "vectoriel, il demande un trace, pas une image matricielle." -ForegroundColor DarkGray
