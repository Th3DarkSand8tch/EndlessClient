<#
.SYNOPSIS
    Fait basculer les illustrations du site du bleu vers le violet EndlessClient.

.DESCRIPTION
    Le theme CSS (uno.config.ts) a deja ete passe en violet, mais les SVG
    decoratifs, le favicon et les degrades en dur gardent les bleus d'origine.
    Ce script les rattrape.

    Methode : chaque couleur litterale #RRGGBB est convertie en TSL, sa TEINTE
    est decalee vers le violet, et sa saturation comme sa luminosite sont
    conservees telles quelles. Les degrades, ombres et contrastes des dessins
    restent donc intacts — seule la famille chromatique change.

    Deux garde-fous :

      - Seules les couleurs suffisamment saturees sont touchees
        (-MinSaturation). Les gris de l'interface (#F0F2F4, #2A2C30...) ont une
        teinte nominale mais aucune couleur perceptible : les decaler ne ferait
        que salir les fonds.

      - Les couleurs de marque tierces sont exclues nommement ($Excluded).
        Le bleu Discord et le rouge YouTube identifient ces services, pas nous.

    Idempotent : apres un passage, les teintes sortent de la plage source et ne
    sont plus reconnues.

.EXAMPLE
    pwsh -File scripts/recolor-assets.ps1
    pwsh -File scripts/recolor-assets.ps1 -WhatIf
    pwsh -File scripts/recolor-assets.ps1 -TargetHue 285
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [string] $Root = (Join-Path $PSScriptRoot '..\web\apps\website'),

    # Teinte d'arrivee pour le centre de la plage source.
    # 271 deg = #A855F7, le violet vif du logo.
    [double] $TargetHue = 271,

    # Les teintes source s'etalent de 203 a 231 deg. On les recomprime autour de
    # $TargetHue avec ce facteur : 1.0 garderait tout l'ecart, 0 aplatirait tout
    # sur une teinte unique. 0.5 conserve la variation sans la caricaturer.
    [double] $SpreadFactor = 0.5,

    [double] $SourceHueMin = 190,
    [double] $SourceHueMax = 250,
    [double] $MinSaturation = 0.20
)

$ErrorActionPreference = 'Stop'
$Root = (Resolve-Path $Root).Path

Add-Type -AssemblyName System.Drawing

# Couleurs de marque tierces et neutres absolus : jamais decales.
$Excluded = @('#5865F2', '#FF0000', '#000000', '#FFFFFF')

$Extensions = @('.svg', '.astro', '.css', '.scss', '.ts', '.webmanifest', '.html')
$SkipPathRegex = '\\(\.git|node_modules|dist|\.astro|\.output)\\'

# Centre de la plage source, autour duquel on recomprime.
$sourceCenter = ($SourceHueMin + $SourceHueMax) / 2

function ConvertTo-Rgb {
    <#
        TSL -> RVB. System.Drawing sait lire une teinte (GetHue) mais ne sait pas
        reconstruire une couleur a partir d'une teinte : il faut le faire a la main.
        Algorithme HSL standard.
    #>
    param([double] $Hue, [double] $Saturation, [double] $Lightness)

    if ($Saturation -le 0) {
        $v = [int][Math]::Round($Lightness * 255)
        return , @($v, $v, $v)
    }

    $q = if ($Lightness -lt 0.5) { $Lightness * (1 + $Saturation) }
         else { $Lightness + $Saturation - ($Lightness * $Saturation) }
    $p = 2 * $Lightness - $q
    $hk = ((($Hue % 360) + 360) % 360) / 360.0

    # Parentheses obligatoires : en PowerShell la virgule lie plus fort que
    # l'arithmetique, donc `@($hk + 1/3.0, $hk, ...)` se lit
    # `$hk + (1 / (3.0, $hk, ...))`, soit une division par un tableau.
    $channels = @(($hk + 1 / 3.0), $hk, ($hk - 1 / 3.0))
    $out = foreach ($t in $channels) {
        $tc = $t
        if ($tc -lt 0) { $tc += 1 }
        if ($tc -gt 1) { $tc -= 1 }

        $value =
            if     ($tc -lt 1 / 6.0) { $p + ($q - $p) * 6 * $tc }
            elseif ($tc -lt 1 / 2.0) { $q }
            elseif ($tc -lt 2 / 3.0) { $p + ($q - $p) * (2 / 3.0 - $tc) * 6 }
            else                     { $p }

        # Litteraux 0.0 / 1.0 obligatoires : avec `0` et `1`, PowerShell choisit
        # la surcharge Math.Min(Int32, Int32) et tronque la valeur a 0 ou 1,
        # ce qui ecrase toutes les couleurs sur des primaires pures.
        [int][Math]::Round([Math]::Max(0.0, [Math]::Min(1.0, [double]$value)) * 255)
    }
    return , @($out)
}

function Get-ShiftedHex {
    param([string] $Hex)

    if ($Excluded -contains $Hex.ToUpperInvariant()) { return $null }

    $color = [System.Drawing.ColorTranslator]::FromHtml($Hex)
    $hue = $color.GetHue()
    $sat = $color.GetSaturation()
    $lum = $color.GetBrightness()

    if ($sat -lt $MinSaturation) { return $null }
    if ($hue -lt $SourceHueMin -or $hue -gt $SourceHueMax) { return $null }

    $newHue = $TargetHue + ($hue - $sourceCenter) * $SpreadFactor
    $rgb = ConvertTo-Rgb -Hue $newHue -Saturation $sat -Lightness $lum

    $result = '#{0:X2}{1:X2}{2:X2}' -f $rgb[0], $rgb[1], $rgb[2]
    # Respecte la casse d'origine : certains SVG sont tout en minuscules.
    if ($Hex -cmatch '^#[0-9a-f]+$') { return $result.ToLowerInvariant() }
    return $result
}

$files = Get-ChildItem -LiteralPath $Root -Recurse -File -Force |
    Where-Object {
        $_.FullName -notmatch $SkipPathRegex -and $Extensions -contains $_.Extension
    }

$utf8 = New-Object System.Text.UTF8Encoding $false
$changedFiles = 0
$changedColors = 0
$mapping = @{}

foreach ($file in $files) {
    $original = Get-Content -LiteralPath $file.FullName -Raw -ErrorAction SilentlyContinue
    if ($null -eq $original) { continue }

    $script:localCount = 0
    $text = [regex]::Replace($original, '#[0-9A-Fa-f]{6}\b', {
        param($match)
        $shifted = Get-ShiftedHex $match.Value
        if ($null -eq $shifted) { return $match.Value }
        $script:localCount++
        $mapping[$match.Value.ToUpperInvariant()] = $shifted.ToUpperInvariant()
        return $shifted
    })

    if ($text -ceq $original) { continue }

    $relative = $file.FullName.Substring($Root.Length + 1)
    if ($PSCmdlet.ShouldProcess($relative, "recolorer $script:localCount couleur(s)")) {
        [System.IO.File]::WriteAllText($file.FullName, $text, $utf8)
        $changedFiles++
        $changedColors += $script:localCount
    }
}

Write-Host ""
Write-Host "$changedColors couleur(s) decalee(s) dans $changedFiles fichier(s)." -ForegroundColor Green
Write-Host ""
Write-Host "Correspondances appliquees :" -ForegroundColor Cyan
$mapping.GetEnumerator() | Sort-Object Key | ForEach-Object {
    Write-Host ("  {0}  ->  {1}" -f $_.Key, $_.Value)
}
