<#
.SYNOPSIS
    Supprime toute trace de Polyfrost et des produits One* dans web/.

.DESCRIPTION
    Succede a rebrand.ps1, qui ne traitait que le mot "Polyfrost" et le domaine.
    Ce script va plus loin : il renomme les FICHIERS et DOSSIERS, pas seulement
    leur contenu, et traite les noms de produits.

    Correspondances :
        Polyfrost      -> EndlessClient       (organisation)
        OneClient      -> EndlessClient       (client)
        OneConfig      -> EndlessConfig       (bibliotheque de config)
        OneLauncher    -> EndlessLauncher     (lanceur)
        Poly<X>        -> Endless<X>          (mods : PolyBlur -> EndlessBlur)
        Overflow<X>    -> Endless<X>          (mods : OverflowParticles -> EndlessParticles)

    COLLISION RESOLUE : l'organisation (Polyfrost) et le client (OneClient)
    convergent tous deux vers "EndlessClient". Leurs jeux d'icones se
    telescoperaient (polyfrost.minimal.svg et oneclient.minimal.svg donneraient
    le meme endlessclient.minimal.svg). On reserve donc le prefixe `brand.` au
    logo de l'organisation, et `endlessclient.` au produit :

        polyfrost.full.svg        -> brand.full.svg
        polyfrost.minimal.svg     -> brand.minimal.svg
        polyfrost.minimal_bg.svg  -> brand.minimal_bg.svg
        oneclient.minimal.svg     -> endlessclient.minimal.svg

    C'est aussi ce script qui corrige le bug laisse par rebrand.ps1 : les
    references d'icones avaient ete renommees (`polyfrost.full` ->
    `endlessclient.full`) sans que les fichiers .svg le soient, ce qui faisait
    echouer la resolution d'astro-icon au build.

    Idempotent : relancer sur un dossier deja traite ne fait rien.

.EXAMPLE
    pwsh -File scripts/debrand.ps1
    pwsh -File scripts/debrand.ps1 -WhatIf
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [string] $WebRoot = (Join-Path $PSScriptRoot '..\web')
)

$ErrorActionPreference = 'Stop'
$WebRoot = (Resolve-Path $WebRoot).Path

$SkipPathRegex = '\\(\.git|node_modules|dist|\.astro|\.output)\\'
$SkipFilenames = @('ATTRIBUTION.md', 'LICENSE', 'LICENSE.md', 'pnpm-lock.yaml', 'flake.lock')
$TextExtensions = @(
    '.ts', '.tsx', '.js', '.mjs', '.cjs', '.json', '.jsonc', '.astro', '.vue',
    '.md', '.mdx', '.yaml', '.yml', '.css', '.scss', '.txt', '.html', '.svg',
    '.webmanifest', '.nix', '.toml'
)
$TextFilenames = @('webfinger', '.npmrc', '.nvmrc', '.editorconfig', '.gitignore', '.gitattributes')

# --- Regles de contenu -----------------------------------------------------
# Paires @(recherche, remplacement), appliquees DANS L'ORDRE. Un tableau et non
# une hashtable : les hashtables PowerShell sont insensibles a la casse et
# feraient entrer 'OneClient' / 'oneclient' / 'ONECLIENT' en collision.
#
# Les six premieres regles doivent passer AVANT celles sur OneClient :
# rebrand.ps1 a deja transforme `polyfrost.full` en `endlessclient.full`, et
# c'est cette forme-la qui doit devenir `brand.full`. Si on traitait OneClient
# d'abord, `oneclient.minimal` deviendrait `endlessclient.minimal` et serait
# ensuite avale par la regle du logo d'organisation.
#
# Pas de virgule avant le premier @(...) : `, @('a','b')` est l'operateur
# tableau unaire, il emballe la paire dans un tableau supplementaire, si bien
# que $pair[0] vaut la paire entiere et $pair[1] $null. La premiere regle est
# alors silencieusement ignoree.
[string[][]] $Replacements = @(
    # Seul `.full` est reference dans le CONTENU pour le logo d'organisation
    # (navbar et pied de page). Les variantes `.minimal` n'apparaissent que
    # comme noms de fichiers : les mapper ici volerait au produit EndlessClient
    # l'icone heritee de oneclient.minimal.svg. Voir $NameOnlyReplacements.
      @('endlessclient.full', 'brand.full'),
      @('polyfrost.full'    , 'brand.full'),

      @('OneConfig'  , 'EndlessConfig'),
      @('ONECONFIG'  , 'ENDLESSCONFIG'),
      @('oneconfig'  , 'endlessconfig'),
      @('OneLauncher', 'EndlessLauncher'),
      @('ONELAUNCHER', 'ENDLESSLAUNCHER'),
      @('onelauncher', 'endlesslauncher'),
      @('OneClient'  , 'EndlessClient'),
      @('ONECLIENT'  , 'ENDLESSCLIENT'),
      @('oneclient'  , 'endlessclient'),

      @('Polyfrost'  , 'EndlessClient'),
      @('POLYFROST'  , 'ENDLESSCLIENT'),
      @('polyfrost'  , 'endlessclient'),

    # Mods portant un prefixe de marque.
      @('OverflowAnimations' , 'EndlessAnimations'),
      @('overflowanimations' , 'endlessanimations'),
      @('overflow_animations', 'endless_animations'),
      @('OverflowParticles'  , 'EndlessParticles'),
      @('overflowparticles'  , 'endlessparticles'),
      @('PolyBlur'      , 'EndlessBlur'),       @('polyblur'      , 'endlessblur'),
      @('poly_blur'     , 'endless_blur'),
      @('PolyCrosshair' , 'EndlessCrosshair'),  @('polycrosshair' , 'endlesscrosshair'),
      @('PolyHitbox'    , 'EndlessHitbox'),     @('polyhitbox'    , 'endlesshitbox'),
      @('PolyKeystrokes', 'EndlessKeystrokes'), @('polykeystrokes', 'endlesskeystrokes'),
      @('PolyNametag'   , 'EndlessNametag'),    @('polynametag'   , 'endlessnametag'),
      @('poly_nametag'  , 'endless_nametag'),
      @('PolyPatcher'   , 'EndlessPatcher'),    @('polypatcher'   , 'endlesspatcher'),
      @('PolySprint'    , 'EndlessSprint'),     @('polysprint'    , 'endlesssprint'),
      @('poly_sprint'   , 'endless_sprint'),
      @('PolyTime'      , 'EndlessTime'),       @('polytime'      , 'endlesstime'),
      @('poly_time'     , 'endless_time'),
      @('PolyWeather'   , 'EndlessWeather'),    @('polyweather'   , 'endlessweather'),
      @('poly_weather'  , 'endless_weather'),
      @('PolyZoom'      , 'EndlessZoom'),       @('polyzoom'      , 'endlesszoom'),
      @('PolyUI'        , 'EndlessUI'),         @('polyui'        , 'endlessui')
)

# Appliques UNIQUEMENT aux noms de fichiers, jamais au contenu.
# Les .svg du logo d'organisation partent vers `brand.*` pour liberer le
# prefixe `endlessclient.*` au profit des icones du produit, heritees de
# oneclient.*. Aucune regle `endlessclient.* -> brand.*` ici : les fichiers
# portent encore leur nom d'origine (rebrand.ps1 n'a jamais renomme de fichier),
# et une telle regle renommerait l'icone du produit par-dessus celle de l'orga.
[string[][]] $NameOnlyReplacements = @(
      @('polyfrost.minimal_bg', 'brand.minimal_bg'),
      @('polyfrost.minimal'   , 'brand.minimal')
)

function Get-Rebranded {
    param([string] $Value, [switch] $ForFileName)
    $out = $Value
    if ($ForFileName) {
        foreach ($pair in $NameOnlyReplacements) { $out = $out.Replace($pair[0], $pair[1]) }
    }
    foreach ($pair in $Replacements) { $out = $out.Replace($pair[0], $pair[1]) }
    return $out
}

# --- Corrections d'URL -----------------------------------------------------
# Le renommage mecanique ci-dessus produit des URL syntaxiquement correctes
# mais fausses : `github.com/Polyfrost/OneLauncher` devient
# `github.com/EndlessClient/EndlessLauncher`, un depot qui n'existe pas.
# Tout doit converger vers le seul depot reel.
#
# Applique APRES $Replacements, et du plus long au plus court : la regle
# catch-all `github.com/EndlessClient` avalerait les deux premieres.
$GithubUrl = 'https://github.com/th3darksand8tch/EndlessClient'

[string[][]] $UrlFixups = @(
      @('https://github.com/EndlessClient/EndlessLauncher/releases/latest', "$GithubUrl/releases/latest"),
      @('https://github.com/EndlessClient/EndlessLauncher', $GithubUrl),
      @('https://github.com/EndlessClient/Nexus'          , $GithubUrl),
      @('https://github.com/EndlessClient'                , $GithubUrl),
      @('https://github.com/endlessclient'                , $GithubUrl),
      @('https://github.com/w-overflow'                   , $GithubUrl),
      @('https://github.com/skyblockclient'               , $GithubUrl),

    # Reparation : une version anterieure de ce script mappait `.minimal` vers
    # le logo d'organisation, ce qui privait la page produit et l'entree
    # getProjects() de leur propre icone. Les guillemets fermants evitent
    # d'attraper `brand.minimal_bg` au passage.
      @("'brand.minimal'", "'endlessclient.minimal'"),
      @('"brand.minimal"', '"endlessclient.minimal"'),

    # Invitations Discord heritees : aucune ne nous appartient.
      @("'https://discord.gg/N4qW7TW3dv'", "'$GithubUrl'"),
      @("redirect('https://discord.gg/')", "redirect('$GithubUrl')"),

    # Le compteur n'agrege plus trois organisations mais un seul compte.
      @(
        'Download counts are aggregated across all public GitHub release assets and Modrinth project downloads for the <a class="underline underline-offset-2 transition-colors hover:text-gray-500" href="https://github.com/endlessclient">EndlessClient</a>, <a class="underline underline-offset-2 transition-colors hover:text-gray-500" href="https://github.com/w-overflow">W-OVERFLOW</a> (the previous home for EndlessClient mods), and <a class="underline underline-offset-2 transition-colors hover:text-gray-500" href="https://github.com/skyblockclient">SkyClient</a> (the mod downloader) GitHub organizations. Cached and refreshed hourly.',
        "Download counts are aggregated across all public GitHub release assets on the <a class=`"underline underline-offset-2 transition-colors hover:text-gray-500`" href=`"$GithubUrl`">EndlessClient</a> account. Cached and refreshed hourly."
    )
)

# Fichiers herites qui revendiquent une identite qui n'est pas la notre.
# Un webfinger pointant vers floss.social/@endlessclient annonce un compte
# Mastodon inexistant : mieux vaut ne rien servir que servir une fausse piste.
$Removals = @('apps\website\public\.well-known\webfinger')

# Garde-fou. Une paire mal formee ne provoque aucune erreur a l'execution :
# .Replace() recoit une chaine introuvable et ne fait rien. La regle est donc
# silencieusement ignoree et le rebranding sort incomplet sans le signaler.
# On echoue ici plutot que de livrer un resultat partiel.
foreach ($set in @(
    @{ Name = 'Replacements'        ; Pairs = $Replacements },
    @{ Name = 'NameOnlyReplacements'; Pairs = $NameOnlyReplacements },
    @{ Name = 'UrlFixups'           ; Pairs = $UrlFixups })) {
    foreach ($pair in $set.Pairs) {
        if ($pair.Length -ne 2 -or [string]::IsNullOrEmpty($pair[0]) -or $null -eq $pair[1]) {
            throw "`$$($set.Name) contient une paire mal formee : [$($pair -join ' | ')]"
        }
    }
}

# --- Etape 1 : renommage des fichiers et dossiers -------------------------
# Du plus profond au plus superficiel : renommer un dossier parent d'abord
# invaliderait les chemins de ses enfants dans la meme passe.

Write-Host "1. Renommage des fichiers et dossiers" -ForegroundColor Cyan

$renamed = 0
$entries = Get-ChildItem -LiteralPath $WebRoot -Recurse -Force |
    Where-Object { $_.FullName -notmatch $SkipPathRegex } |
    Sort-Object { ($_.FullName -split '\\').Count } -Descending

foreach ($entry in $entries) {
    if (-not (Test-Path -LiteralPath $entry.FullName)) { continue }

    $newName = Get-Rebranded $entry.Name -ForFileName
    if ($newName -ceq $entry.Name) { continue }

    # [IO.Path]::GetDirectoryName et pas Split-Path : le jeu de parametres
    # -LiteralPath de Split-Path n'accepte pas -Parent.
    $parent = [System.IO.Path]::GetDirectoryName($entry.FullName)
    $target = Join-Path $parent $newName
    if (Test-Path -LiteralPath $target) {
        Write-Host "  COLLISION ignoree : $($entry.Name) -> $newName (existe deja)" -ForegroundColor Red
        continue
    }

    if ($PSCmdlet.ShouldProcess($entry.FullName, "renommer en $newName")) {
        Rename-Item -LiteralPath $entry.FullName -NewName $newName
        Write-Host "  $($entry.Name)  ->  $newName" -ForegroundColor DarkCyan
        $renamed++
    }
}
Write-Host "  $renamed element(s) renomme(s)." -ForegroundColor Green

# --- Etape 2 : contenu -----------------------------------------------------

Write-Host ""
Write-Host "2. Reecriture du contenu" -ForegroundColor Cyan

$files = Get-ChildItem -LiteralPath $WebRoot -Recurse -File -Force |
    Where-Object {
        $_.FullName -notmatch $SkipPathRegex -and
        $SkipFilenames -notcontains $_.Name -and
        ($TextExtensions -contains $_.Extension -or $TextFilenames -contains $_.Name)
    }

$utf8 = New-Object System.Text.UTF8Encoding $false
$changed = 0

foreach ($file in $files) {
    $original = Get-Content -LiteralPath $file.FullName -Raw -ErrorAction SilentlyContinue
    if ($null -eq $original) { continue }

    $text = Get-Rebranded $original
    foreach ($pair in $UrlFixups) { $text = $text.Replace($pair[0], $pair[1]) }
    if ($text -ceq $original) { continue }

    $relative = $file.FullName.Substring($WebRoot.Length + 1)
    if ($PSCmdlet.ShouldProcess($relative, 'reecrire')) {
        [System.IO.File]::WriteAllText($file.FullName, $text, $utf8)
        $changed++
    }
}
Write-Host "  $changed fichier(s) reecrit(s) sur $($files.Count) scanne(s)." -ForegroundColor Green

foreach ($relative in $Removals) {
    $path = Join-Path $WebRoot $relative
    if (-not (Test-Path -LiteralPath $path)) { continue }
    if ($PSCmdlet.ShouldProcess($relative, 'supprimer')) {
        Remove-Item -LiteralPath $path -Force
        Write-Host "  supprime  $relative" -ForegroundColor DarkYellow
    }
}

# --- Etape 3 : verification ------------------------------------------------

Write-Host ""
Write-Host "3. Verification" -ForegroundColor Cyan

$files = Get-ChildItem -LiteralPath $WebRoot -Recurse -File -Force |
    Where-Object {
        $_.FullName -notmatch $SkipPathRegex -and
        $SkipFilenames -notcontains $_.Name -and
        ($TextExtensions -contains $_.Extension -or $TextFilenames -contains $_.Name)
    }

$iconDir = Join-Path $WebRoot 'apps\website\src\icons'
$available = @{}
if (Test-Path -LiteralPath $iconDir) {
    Get-ChildItem -LiteralPath $iconDir -Filter '*.svg' |
        ForEach-Object { $available[($_.Name -replace '\.svg$', '')] = $true }
}

# astro-icon resout `icon="nom"` vers src/icons/nom.svg : une reference sans
# fichier correspondant fait echouer le build, pas seulement l'affichage.
$broken = [System.Collections.Generic.List[string]]::new()
$leftover = [System.Collections.Generic.List[string]]::new()

foreach ($file in $files) {
    $text = Get-Content -LiteralPath $file.FullName -Raw -ErrorAction SilentlyContinue
    if (-not $text) { continue }
    $relative = $file.FullName.Substring($WebRoot.Length + 1)

    foreach ($m in [regex]::Matches($text, '(?:icon|logo)\s*[:=]\s*[''"\[]\s*[''"]?([a-z0-9_.-]+)[''"]')) {
        $name = $m.Groups[1].Value
        if (-not $available.ContainsKey($name)) { $broken.Add("$relative -> $name") }
    }

    if ($text -match '(?i)polyfrost|one(config|client|launcher)') { $leftover.Add($relative) }
}

if ($broken.Count) {
    Write-Host "  References d'icones sans fichier :" -ForegroundColor Red
    $broken | Sort-Object -Unique | ForEach-Object { Write-Host "    $_" -ForegroundColor Red }
}
else {
    Write-Host "  Toutes les references d'icones resolvent." -ForegroundColor Green
}

if ($leftover.Count) {
    Write-Host "  Occurrences restantes de polyfrost/one* :" -ForegroundColor Yellow
    $leftover | Sort-Object -Unique | ForEach-Object { Write-Host "    $_" -ForegroundColor Yellow }
}
else {
    Write-Host "  Aucune occurrence de polyfrost / oneconfig / oneclient / onelauncher." -ForegroundColor Green
}
