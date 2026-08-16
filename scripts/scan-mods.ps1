<#
.SYNOPSIS
    Genere le catalogue des mods (mods.json + meta/<id>.json) a partir des depots.

.DESCRIPTION
    Parcourt les depots presents dans -ReposRoot et en extrait les metadonnees.
    Deux formats de declaration coexistent dans l'ecosysteme :

      1. stonecutter.properties.toml   (mods recents, multi-version Fabric)
         mod.id / mod.name / mod.version / mod.description, sections par version MC.

      2. gradle.properties             (mods historiques, Forge 1.8.9 / 1.12.2)
         mod_name / mod_id / mod_version, versions MC listees dans settings.gradle.kts.

    Un depot sans aucun des deux est classe hors "mod" (bibliotheque, outil, infra)
    via $CategoryOverrides, et reste dans le catalogue avec sa categorie propre.

    Lecture seule sur les depots : rien n'est modifie en dehors de -OutRoot.

.EXAMPLE
    pwsh -File scripts/scan-mods.ps1
    pwsh -File scripts/scan-mods.ps1 -ReposRoot D:\URG -OutRoot D:\URG\endlessclient.dev\mods
#>
[CmdletBinding()]
param(
    [string] $ReposRoot = (Join-Path $PSScriptRoot '..\..'),
    [string] $OutRoot   = (Join-Path $PSScriptRoot '..\mods'),
    [string] $IconSource = (Join-Path $PSScriptRoot '..\web\apps\website\public\media\branding\mods'),
    [string] $UpstreamRepo = 'https://github.com/th3darksand8tch/EndlessClient'
)

$ErrorActionPreference = 'Stop'
$ReposRoot = (Resolve-Path $ReposRoot).Path
$OutRoot   = (Resolve-Path $OutRoot).Path

# Depots qui ne sont pas des mods. Valeur = categorie publiee dans le catalogue.
$CategoryOverrides = @{
    'OneConfig'                = 'library'
    'OneConfig-Bootstrap'      = 'library'
    'OneConfigLoader'          = 'library'
    'OneConfigWrapper'         = 'library'
    'OneConfigMigrator'        = 'library'
    'OneConfigExampleMod'      = 'example'
    'ExamplePolyUIMod'         = 'example'
    'Elementa'                 = 'library'
    'UniversalCraft'           = 'library'
    'PolyMixin'                = 'library'
    'PolyIO'                   = 'library'
    'JTokens'                  = 'library'
    'keventbus-forge'          = 'library'
    'isolated-lwjgl3-loader'   = 'library'
    'lwjgl3-repacked'          = 'library'
    'arm-macos-lwjgl2'         = 'library'
    'skia'                     = 'library'
    'skiko'                    = 'library'
    'skinview3d'               = 'library'
    'SkyblockAPI'              = 'library'
    'Spice'                    = 'library'
    'sodium'                   = 'library'
    'blossom'                  = 'tooling'
    'defrost'                  = 'tooling'
    'Deleter'                  = 'tooling'
    'BuildFormat'              = 'tooling'
    'architectury-loom'        = 'tooling'
    'polyfrost-gradle-toolkit' = 'tooling'
    'packwiz'                  = 'tooling'
    'quick-pack'               = 'tooling'
    'PolySigner'               = 'tooling'
    'PolySnapper'              = 'tooling'
    'ursa-minor'               = 'tooling'
    'interlaced'               = 'tooling'
    'OneLauncher'              = 'app'
    'PolyBot'                  = 'app'
    'PolyHelper'               = 'app'
    'backend'                  = 'infra'
    'plus-backend'             = 'infra'
    'plus-website'             = 'infra'
    'plus-admin-dashboard'     = 'infra'
    'website'                  = 'infra'
    'infra'                    = 'infra'
    'interfrost-workers'       = 'infra'
    'Knowledgebase'            = 'docs'
    'OneConfig-Documentation'  = 'docs'
    'Legal'                    = 'docs'
    'Branding'                 = 'docs'
    'CrashData'                = 'data'
    'DataStorage'              = 'data'
    'DataStorageV2'            = 'data'
    'Crashylizer'              = 'tooling'
    'SmartSearch'              = 'library'
}

# Jamais catalogue.
$Excluded = @('.github', 'endlessclient.dev')

function Get-BrandedName {
    <#
        Applique la marque EndlessClient aux noms herites.

        Seuls les PREFIXES de marque sont remplaces :
            Polyfrost*  -> EndlessClient*     (Polyfrost -> EndlessClient)
            One*        -> Endless*           (OneConfig -> EndlessConfig)
            Poly*       -> Endless*           (PolySprint -> EndlessSprint)
            Overflow*   -> Endless*           (OverflowParticles -> EndlessParticles)

        Les noms purement descriptifs (Chatting, FullBright, DamageTint,
        VanillaHUD...) ne portent aucune marque et sont laisses intacts :
        les prefixer donnerait "EndlessFullBright", illisible et sans gain.

        `Polyfrost` passe en premier, sinon la regle `^Poly` le transformerait
        en "Endlessfrost". Les variantes bas de casse traitent les identifiants.
    #>
    param([string] $Value)
    if ([string]::IsNullOrEmpty($Value)) { return $Value }

    $out = $Value -creplace '^Polyfrost', 'EndlessClient'
    $out = $out   -creplace '^polyfrost', 'endlessclient'
    $out = $out   -creplace '^(One|Poly|Overflow)', 'Endless'
    $out = $out   -creplace '^(one|poly|overflow)', 'endless'
    return $out
}

# Marques a remplacer PARTOUT dans un texte libre, pas seulement en prefixe.
# Les descriptions et les groupes Maven sont recopies tels quels depuis les
# README et les .toml des depots : ils citent OneConfig, org.polyfrost, etc.
# Ordre du plus long au plus court ; `Polyfrost` avant `Poly`.
#
# Pas de virgule avant le premier @(...) : `, @('a','b')` est l'operateur
# tableau unaire, il emballe la paire dans un tableau supplementaire. $pair[0]
# vaut alors la paire entiere et $pair[1] $null, donc la premiere regle est
# silencieusement ignoree. Une liste separee par des virgules suffit : PowerShell
# n'aplatit pas les sous-tableaux des lors qu'il y a plus d'un element.
[string[][]] $TextBrands = @(
      @('OverflowAnimations', 'EndlessAnimations'),
      @('OverflowParticles' , 'EndlessParticles'),
      @('Polyfrost'         , 'EndlessClient'),
      @('polyfrost'         , 'endlessclient'),
      @('OneConfig'         , 'EndlessConfig'),
      @('oneconfig'         , 'endlessconfig'),
      @('OneLauncher'       , 'EndlessLauncher'),
      @('onelauncher'       , 'endlesslauncher'),
      @('OneClient'         , 'EndlessClient'),
      @('oneclient'         , 'endlessclient'),
      @('PolyUI'            , 'EndlessUI')     , @('polyui'       , 'endlessui'),
      @('PolyBlur'          , 'EndlessBlur')   , @('polyblur'     , 'endlessblur'),
      @('PolySprint'        , 'EndlessSprint') , @('polysprint'   , 'endlesssprint'),
      @('PolyTime'          , 'EndlessTime')   , @('polytime'     , 'endlesstime'),
      @('PolyWeather'       , 'EndlessWeather'), @('polyweather'  , 'endlessweather'),
      @('PolyNametag'       , 'EndlessNametag'), @('polynametag'  , 'endlessnametag'),
      @('PolyHitbox'        , 'EndlessHitbox') , @('polyhitbox'   , 'endlesshitbox'),
      @('PolyCrosshair'     , 'EndlessCrosshair'), @('polycrosshair', 'endlesscrosshair'),
      @('PolyZoom'          , 'EndlessZoom')   , @('polyzoom'     , 'endlesszoom'),
      @('PolyPatcher'       , 'EndlessPatcher'), @('polypatcher'  , 'endlesspatcher')
)

# Garde-fou. Une paire mal formee ne provoque aucune erreur a l'execution :
# .Replace() recoit une chaine introuvable et ne fait rien. La regle est donc
# silencieusement ignoree et le catalogue sort avec des noms non rebrandes.
foreach ($pair in $TextBrands) {
    if ($pair.Length -ne 2 -or [string]::IsNullOrEmpty($pair[0]) -or $null -eq $pair[1]) {
        throw "`$TextBrands contient une paire mal formee : [$($pair -join ' | ')]"
    }
}

function Get-BrandedText {
    param([string] $Value)
    if ([string]::IsNullOrEmpty($Value)) { return $Value }
    $out = $Value
    foreach ($pair in $TextBrands) { $out = $out.Replace($pair[0], $pair[1]) }
    return $out
}

function Get-TomlValue {
    param([string] $Text, [string] $Key)
    # Capture `mod.id = "chatting"` en ignorant tout ce qui suit une section [x].
    $head = ($Text -split '(?m)^\s*\[')[0]
    if ($head -match "(?m)^\s*$([regex]::Escape($Key))\s*=\s*`"([^`"]*)`"") { return $Matches[1] }
    return $null
}

function Get-PropertiesValue {
    # Les gradle.properties de l'ecosysteme melangent deux conventions de clef :
    #   mod_name = X   (pgt / egt, mods Forge historiques)
    #   mod.name = X   (dgt, mods plus recents)
    # On passe donc toutes les variantes et on retient la premiere trouvee.
    param([string] $Text, [string[]] $Keys)
    foreach ($key in $Keys) {
        if ($Text -match "(?m)^\s*$([regex]::Escape($key))\s*=\s*(.+?)\s*$") { return $Matches[1] }
    }
    return $null
}

function Get-LicenseId {
    param([string] $Dir)
    foreach ($name in @('LICENSE', 'LICENSE.md', 'LICENSE.txt', 'COPYING.LESSER', 'COPYING')) {
        $path = Join-Path $Dir $name
        if (-not (Test-Path -LiteralPath $path)) { continue }
        $head = (Get-Content -LiteralPath $path -TotalCount 30 -ErrorAction SilentlyContinue) -join ' '
        switch -Regex ($head) {
            'GNU LESSER GENERAL PUBLIC LICENSE'  { return 'LGPL-3.0' }
            'GNU AFFERO GENERAL PUBLIC LICENSE'  { return 'AGPL-3.0' }
            'GNU GENERAL PUBLIC LICENSE'         { return 'GPL-3.0' }
            'Apache License'                     { return 'Apache-2.0' }
            'MIT License|Permission is hereby granted, free of charge' { return 'MIT' }
            'Mozilla Public License'             { return 'MPL-2.0' }
            'BSD'                                { return 'BSD-3-Clause' }
        }
        return 'other'
    }
    return $null
}

function Get-ReadmeSummary {
    param([string] $Dir)
    foreach ($name in @('README.md', 'README.MD', 'readme.md', 'README.rst', 'README')) {
        $path = Join-Path $Dir $name
        if (-not (Test-Path -LiteralPath $path)) { continue }

        foreach ($line in (Get-Content -LiteralPath $path -TotalCount 60 -ErrorAction SilentlyContinue)) {
            $t = $line.Trim()
            if ($t.Length -lt 20) { continue }
            # Ignore titres, badges, images, HTML brut, citations et listes.
            if ($t -match '^(#|!\[|\[!\[|<|>|-|\*|\||```)') { continue }
            $t = $t -replace '\[([^\]]+)\]\([^)]*\)', '$1'   # liens markdown -> texte
            $t = ($t -replace '[*_`]', '').Trim()
            if ($t.Length -gt 300) { $t = $t.Substring(0, 297).TrimEnd() + '...' }
            return $t
        }
        return $null
    }
    return $null
}

function Get-VersionTargets {
    param([string] $Dir)
    # Renvoie les chaines brutes de version declarees dans settings.gradle.kts.
    # stonecutter :  versions("1.21.1", "1.21.4", ...)
    # pgt/egt     :  listOf("1.8.9-forge", "1.12.2-forge")
    $path = Join-Path $Dir 'settings.gradle.kts'
    if (-not (Test-Path -LiteralPath $path)) { return @() }
    $text = Get-Content -LiteralPath $path -Raw

    $block = $null
    if ($text -match '(?s)\bversions\s*\(([^)]*)\)')     { $block = $Matches[1] }
    elseif ($text -match '(?s)\blistOf\s*\(([^)]*)\)')   { $block = $Matches[1] }
    if (-not $block) { return @() }

    return [regex]::Matches($block, '"([^"]+)"') |
        ForEach-Object { $_.Groups[1].Value } |
        Where-Object { $_ -match '^\d+(\.\d+)*' }
}

function Get-StonecutterReleases {
    param([string] $Text)
    # Agrege tous les `mod.mc_releases = ["a", "b"]` des sections par version.
    $out = [System.Collections.Generic.List[string]]::new()
    foreach ($m in [regex]::Matches($Text, '(?m)^\s*mod\.mc_releases\s*=\s*\[([^\]]*)\]')) {
        foreach ($v in [regex]::Matches($m.Groups[1].Value, '"([^"]+)"')) {
            if (-not $out.Contains($v.Groups[1].Value)) { $out.Add($v.Groups[1].Value) }
        }
    }
    return $out
}

# --- Collecte -------------------------------------------------------------

$repos = Get-ChildItem -LiteralPath $ReposRoot -Directory |
    Where-Object { $Excluded -notcontains $_.Name } |
    Sort-Object Name

$catalog = [System.Collections.Generic.List[object]]::new()

foreach ($repo in $repos) {
    $dir  = $repo.FullName
    $toml = Join-Path $dir 'stonecutter.properties.toml'
    $prop = Join-Path $dir 'gradle.properties'

    $id = $null; $name = $null; $version = $null; $description = $null
    $group = $null; $modrinth = $null; $source = 'none'
    $minecraft = @(); $loaders = @()

    if (Test-Path -LiteralPath $toml) {
        $source = 'stonecutter'
        $text = Get-Content -LiteralPath $toml -Raw

        $id          = Get-TomlValue $text 'mod.id'
        $name        = Get-TomlValue $text 'mod.name'
        $version     = Get-TomlValue $text 'mod.version'
        $description = Get-TomlValue $text 'mod.description'
        $group       = Get-TomlValue $text 'mod.group'
        $modrinth    = Get-TomlValue $text 'publish.modrinth'

        $minecraft = @(Get-StonecutterReleases $text)
        if ($minecraft.Count -eq 0) { $minecraft = @(Get-VersionTargets $dir) }
        # Ces mods ciblent Fabric ; le loader Forge n'apparait pas dans ce format.
        if ($text -match 'deps\.fabric_loader') { $loaders = @('fabric') }
    }
    elseif ((Test-Path -LiteralPath $prop) -and ((Get-Content -LiteralPath $prop -Raw) -match '(?m)^\s*mod[_.]name\s*=')) {
        $source = 'gradle'
        $text = Get-Content -LiteralPath $prop -Raw

        $name     = Get-PropertiesValue $text @('mod_name', 'mod.name')
        $id       = Get-PropertiesValue $text @('mod_id', 'mod.id')
        $version  = Get-PropertiesValue $text @('mod_version', 'mod.version')
        $group    = Get-PropertiesValue $text @('mod_group', 'mod.group')
        $modrinth = Get-PropertiesValue $text @('publish.modrinth', 'modrinth_id')

        $targets = @(Get-VersionTargets $dir)
        $minecraft = @($targets | ForEach-Object { ($_ -split '-')[0] } | Select-Object -Unique)
        $loaders   = @($targets | ForEach-Object {
                if ($_ -match '-(forge|fabric|neoforge|quilt)$') { $Matches[1] }
            } | Select-Object -Unique)
    }
    elseif ((Test-Path -LiteralPath $prop) -and ((Get-Content -LiteralPath $prop -Raw) -match '(?m)^\s*archives_base_name\s*=')) {
        # Template Fabric standard (pas de nom de mod declare) : on retombe sur
        # archives_base_name pour l'id et sur le nom du depot pour l'affichage.
        $source = 'fabric-template'
        $text = Get-Content -LiteralPath $prop -Raw

        $id      = Get-PropertiesValue $text @('archives_base_name')
        $version = Get-PropertiesValue $text @('mod_version')
        $group   = Get-PropertiesValue $text @('maven_group')

        $mc = Get-PropertiesValue $text @('minecraft_version')
        if ($mc -and $mc -ne '[VERSIONED]') { $minecraft = @($mc) }
        if ($text -match '(?m)^\s*(loader_version|fabric_api_version)\s*=') { $loaders = @('fabric') }
    }

    # Quatre depots (ColoredBedsDataModV1, ExamplePolyUIMod, OneConfigExampleMod,
    # PolyPack) n'ont jamais edite le gabarit et declarent tous mod.name=ExampleMod
    # / mod.id=examplemod. Les garder tels quels donnerait quatre entrees
    # homonymes et ferait coller n'importe quel examplemod-*.jar a la premiere.
    # Le nom du depot est la seule valeur fiable dans ce cas.
    $placeholder = '^(example ?mod|my ?mod|template ?mod|mod ?id|modid|changeme)$'
    if ($name -and $name -match $placeholder) { $name = $null }
    if ($id   -and $id   -match $placeholder) { $id   = $null }

    if (-not $name) { $name = $repo.Name }
    if (-not $id)   { $id = ($repo.Name.ToLowerInvariant() -replace '[^a-z0-9]', '') }
    if (-not $description) { $description = Get-ReadmeSummary $dir }

    # Applique apres les valeurs de repli : quand le nom du depot sert de
    # defaut, il doit etre rebrande lui aussi. Et avant la recherche d'icone,
    # dont les candidats derivent du nom (EndlessSprint -> endless_sprint.svg).
    # Get-BrandedName ne traite que le prefixe ; Get-BrandedText finit le
    # travail au milieu des chaines (ExamplePolyUIMod -> ExampleEndlessUIMod).
    $name = Get-BrandedText (Get-BrandedName $name)
    $id   = Get-BrandedText (Get-BrandedName $id)

    # Texte libre recopie des depots : nettoyage sur toute la chaine, pas
    # seulement en prefixe ("Built with OneConfig", "org.polyfrost").
    $description = Get-BrandedText $description
    $group       = Get-BrandedText $group

    # Certains depots sont des clones vides (juste .git, ou un LICENSE seul).
    # Les marquer evite qu'ils remontent comme "projet" sur le site.
    $payload = @(Get-ChildItem -LiteralPath $dir -Force -ErrorAction SilentlyContinue |
        Where-Object Name -ne '.git')
    $isEmpty = $payload.Count -eq 0 -or
               ($payload.Count -le 2 -and -not ($payload | Where-Object { $_.PSIsContainer -or $_.Name -like '*.gradle*' }))

    $category = if ($isEmpty) { 'empty' }
                elseif ($CategoryOverrides.ContainsKey($repo.Name)) { $CategoryOverrides[$repo.Name] }
                elseif ($source -ne 'none') { 'mod' }
                else { 'other' }

    $slug = (Get-BrandedText (Get-BrandedName $repo.Name)).ToLowerInvariant() -replace '[^a-z0-9]+', '-'

    # Icone : les assets du site sont en snake_case derive du nom en CamelCase
    # (PolySprint -> poly_sprint.svg, EvergreenHUD -> evergreen_h_u_d.svg).
    # Deux ecarts recurrents : le suffixe de version (BehindYouV3 -> behind_you)
    # et le prefixe de marque (PolyKeystrokes -> keystrokes). On teste les deux.
    $snake = { param($s) ($s -creplace '(?<!^)(?=[A-Z])', '_').ToLowerInvariant() }
    $base  = & $snake $name
    $iconCandidates = @(
        $base
        ($base -replace '_v\d+$', '')     # behind_you_v3 -> behind_you
        ($base -replace '\d+$', '')
        ($base -replace '^endless_', '')  # endless_keystrokes -> keystrokes
        ($base -replace '^poly_', '')     # avant rebranding : poly_keystrokes
        (& $snake $repo.Name)
        $repo.Name.ToLowerInvariant()
        $id
    ) | Where-Object { $_ } | Select-Object -Unique

    $icon = $null
    foreach ($candidate in $iconCandidates) {
        $svg = Join-Path $IconSource "$candidate.svg"
        if (Test-Path -LiteralPath $svg) { $icon = "icons/$candidate.svg"; break }
    }

    # JAR depose manuellement dans mods/jars/ : on rattache par prefixe de nom.
    $jar = $null
    $jarDir = Join-Path $OutRoot 'jars'
    if (Test-Path -LiteralPath $jarDir) {
        $match = Get-ChildItem -LiteralPath $jarDir -Filter '*.jar' -File -ErrorAction SilentlyContinue |
            Where-Object { $_.BaseName -match "^(?i)$([regex]::Escape($id))([-_.]|$)" -or
                           $_.BaseName -match "^(?i)$([regex]::Escape($name))([-_.]|$)" } |
            Sort-Object Name -Descending | Select-Object -First 1
        if ($match) { $jar = "jars/$($match.Name)" }
    }

    # [pscustomobject] et pas [ordered]@{} : Group-Object / Where-Object -Property
    # lisent les proprietes via le PSObject, ce qu'un OrderedDictionary n'expose pas.
    $catalog.Add([pscustomobject][ordered]@{
        id          = $id
        name        = $name
        slug        = $slug
        version     = $version
        description = $description
        group       = $group
        category    = $category
        source      = $source
        # Nom du dossier source, conserve tel quel : c'est la seule cle qui
        # permet de retrouver le depot d'origine apres rebranding.
        repo        = $repo.Name
        loaders     = @($loaders)
        minecraft   = @($minecraft)
        license     = Get-LicenseId $dir
        modrinth    = $modrinth
        # Depot unique : th3darksand8tch/EndlessClient regroupe tout, il n'y a
        # pas d'URL par mod.
        upstream    = $UpstreamRepo
        icon        = $icon
        jar         = $jar
    })
}

# --- Ecriture -------------------------------------------------------------

New-Item -ItemType Directory -Force -Path (Join-Path $OutRoot 'meta')  | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $OutRoot 'icons') | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $OutRoot 'jars')  | Out-Null

if (Test-Path -LiteralPath $IconSource) {
    Copy-Item -Path (Join-Path $IconSource '*') -Destination (Join-Path $OutRoot 'icons') -Force
}

$utf8 = New-Object System.Text.UTF8Encoding $false

foreach ($entry in $catalog) {
    $target = Join-Path $OutRoot "meta\$($entry.slug).json"
    [System.IO.File]::WriteAllText($target, ($entry | ConvertTo-Json -Depth 6), $utf8)
}

$document = [ordered]@{
    generated = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
    site      = 'endlessclient.dev'
    count     = $catalog.Count
    mods      = $catalog
}
[System.IO.File]::WriteAllText((Join-Path $OutRoot 'mods.json'), ($document | ConvertTo-Json -Depth 6), $utf8)

# --- Rapport --------------------------------------------------------------

$byCategory = $catalog | Group-Object category | Sort-Object Count -Descending
Write-Host ""
Write-Host "$($catalog.Count) depots catalogues dans $OutRoot" -ForegroundColor Green
foreach ($group in $byCategory) {
    Write-Host ("  {0,-10} {1,3}" -f $group.Name, $group.Count)
}

$mods = @($catalog | Where-Object category -eq 'mod')
$noVersion = @($mods | Where-Object { -not $_.version })
$noMc      = @($mods | Where-Object { $_.minecraft.Count -eq 0 })

Write-Host ""
Write-Host "Mods : $($mods.Count)  |  sans version : $($noVersion.Count)  |  sans version MC : $($noMc.Count)" -ForegroundColor Cyan
if ($noVersion.Count) { Write-Host ("  version manquante : " + (($noVersion.repo) -join ', ')) -ForegroundColor DarkYellow }
if ($noMc.Count)      { Write-Host ("  versions MC manquantes : " + (($noMc.repo) -join ', ')) -ForegroundColor DarkYellow }
