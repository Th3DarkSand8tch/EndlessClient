<#
.SYNOPSIS
    Rebrande le monorepo web/ de Polyfrost vers EndlessClient (endlessclient.dev).

.DESCRIPTION
    Remplace le nom de marque et le domaine dans les sources du site Astro.

    Ce qui est REMPLACE :
      - @polyfrost/<pkg>   -> @endlessclient/<pkg>   (scope npm)
      - *.polyfrost.org    -> *.endlessclient.dev    (domaine, sitemap, security.txt)
      - Polyfrost          -> EndlessClient          (nom affiche)

    Ce qui est PRESERVE volontairement (voir $Protected) :
      - github.com/Polyfrost, owner: 'Polyfrost', la liste ORGS de /api/downloads
        -> ce sont de vrais appels a l'API GitHub. Les renommer casse la page.
      - youtube.com/@Polyfrost, l'id d'organisation Modrinth, floss.social
        -> comptes externes reels ; a changer a la main quand les tiens existent.
      - ATTRIBUTION.md et LICENSE
        -> l'attribution amont est une obligation de licence, pas du branding.

    Le script est idempotent : le relancer sur un dossier deja rebrande ne fait rien.

.EXAMPLE
    pwsh -File scripts/rebrand.ps1
    pwsh -File scripts/rebrand.ps1 -WhatIf
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [string] $WebRoot = (Join-Path $PSScriptRoot '..\web'),
    [string] $Brand   = 'EndlessClient',
    [string] $Domain  = 'endlessclient.dev',
    [string] $Scope   = 'endlessclient'
)

$ErrorActionPreference = 'Stop'
$WebRoot = (Resolve-Path $WebRoot).Path

# Extensions traitees. Les binaires (png, jpg, ico, woff...) sont ignores.
$TextExtensions = @(
    '.ts', '.tsx', '.js', '.mjs', '.cjs', '.json', '.jsonc', '.astro', '.vue',
    '.md', '.mdx', '.yaml', '.yml', '.css', '.scss', '.txt', '.html', '.svg',
    '.webmanifest', '.nix', '.toml'
)

# Fichiers sans extension utile a traiter quand meme.
$TextFilenames = @('webfinger', '.npmrc', '.nvmrc', '.editorconfig')

# Jamais touches : attribution legale + fichiers generes/verrouilles.
$SkipFilenames = @('ATTRIBUTION.md', 'LICENSE', 'LICENSE.md', 'pnpm-lock.yaml', 'flake.lock')

# Segments de chemin exclus.
$SkipPathRegex = '\\(\.git|node_modules|dist|\.astro|\.output)\\'

# Chaines gelees avant remplacement, restaurees apres.
# Paires @(marqueur, texte litteral a preserver).
# Un tableau, pas une hashtable : les hashtables PowerShell sont insensibles a la
# casse, donc 'Polyfrost' / 'POLYFROST' / 'polyfrost' y entreraient en collision.
[string[][]] $Protected = @(
      @('@@GH_URL@@'     , 'github.com/Polyfrost'),
      @('@@GH_OWNER@@'   , "owner: 'Polyfrost'"),
      @('@@GH_ORGS@@'    , "['polyfrost', 'w-overflow', 'skyblockclient']"),
      @('@@YT_URL@@'     , 'youtube.com/@Polyfrost'),
      @('@@MODRINTH_ID@@', "id: 'polyfrost'"),
      @('@@FLOSS@@'      , 'floss.social')
)

# Paires @(recherche, remplacement), appliquees dans l'ordre :
# du plus specifique au plus general. Comparaison sensible a la casse.
[string[][]] $Replacements = @(
      @('@polyfrost/'  , "@$Scope/"),
      @('polyfrost.org', $Domain),
      @('Polyfrost'    , $Brand),
      @('POLYFROST'    , $Brand.ToUpperInvariant()),
      @('polyfrost'    , $Scope)
)

# Garde-fou. Une paire mal formee ne provoque aucune erreur a l'execution :
# .Replace() recoit une chaine introuvable et ne fait rien. La regle est donc
# silencieusement ignoree et le rebranding sort incomplet sans le signaler.
foreach ($set in @(
    @{ Name = 'Protected'   ; Pairs = $Protected },
    @{ Name = 'Replacements'; Pairs = $Replacements })) {
    foreach ($pair in $set.Pairs) {
        if ($pair.Length -ne 2 -or [string]::IsNullOrEmpty($pair[0]) -or $null -eq $pair[1]) {
            throw "`$$($set.Name) contient une paire mal formee : [$($pair -join ' | ')]"
        }
    }
}

$files = Get-ChildItem -LiteralPath $WebRoot -Recurse -File -Force |
    Where-Object {
        $_.FullName -notmatch $SkipPathRegex -and
        $SkipFilenames -notcontains $_.Name -and
        ($TextExtensions -contains $_.Extension -or $TextFilenames -contains $_.Name)
    }

$changed = 0
$scanned = 0

foreach ($file in $files) {
    $scanned++
    $original = Get-Content -LiteralPath $file.FullName -Raw -ErrorAction SilentlyContinue
    if ($null -eq $original -or $original -notmatch '(?i)polyfrost') { continue }

    $text = $original

    foreach ($pair in $Protected)     { $text = $text.Replace($pair[1], $pair[0]) }
    foreach ($pair in $Replacements)  { $text = $text.Replace($pair[0], $pair[1]) }
    foreach ($pair in $Protected)     { $text = $text.Replace($pair[0], $pair[1]) }

    if ($text -eq $original) { continue }

    $relative = $file.FullName.Substring($WebRoot.Length + 1)
    if ($PSCmdlet.ShouldProcess($relative, 'rebrand')) {
        # UTF8 sans BOM : Astro/Vite refusent un BOM en tete de module.
        [System.IO.File]::WriteAllText($file.FullName, $text, (New-Object System.Text.UTF8Encoding $false))
        Write-Host "  rebrande  $relative" -ForegroundColor DarkCyan
        $changed++
    }
}

Write-Host ""
Write-Host "$changed fichier(s) modifie(s) sur $scanned scanne(s)." -ForegroundColor Green

# Verification : ce qui reste doit etre uniquement du contenu protege.
$leftovers = @()
foreach ($file in $files) {
    $text = Get-Content -LiteralPath $file.FullName -Raw -ErrorAction SilentlyContinue
    if ($null -eq $text -or $text -notmatch '(?i)polyfrost') { continue }

    foreach ($pair in $Protected) { $text = $text.Replace($pair[1], '') }
    if ($text -match '(?i)polyfrost') {
        $leftovers += $file.FullName.Substring($WebRoot.Length + 1)
    }
}

if ($leftovers.Count -gt 0) {
    Write-Host "Occurrences restantes a verifier a la main :" -ForegroundColor Yellow
    $leftovers | ForEach-Object { Write-Host "  $_" -ForegroundColor Yellow }
}
else {
    Write-Host "Aucune occurrence residuelle hors contenu protege." -ForegroundColor Green
}
