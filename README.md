# endlessclient.dev

Paquet de déploiement complet pour **EndlessClient** : le site web, le catalogue
des mods, et les scripts pour installer le tout sur un serveur Linux.

Construit à partir des 108 dépôts PolyFrost présents dans `D:\URG`.

---

## Arborescence

```
endlessclient.dev/
├── install.sh              installation complète sur le serveur (à lancer une fois)
├── deploy.sh               republication du contenu (à relancer à chaque mise à jour)
│
├── web/                    site Astro, rebrandé depuis le monorepo PolyFrost
│   └── apps/website/       l'application ; build → dist/client + dist/server
│
├── mods/                   ce dossier est publié sur mods.endlessclient.dev
│   ├── index.html          page de listing (recherche + filtres)
│   ├── mods.json           catalogue généré — 107 dépôts, dont 52 mods
│   ├── meta/               une fiche JSON par dépôt
│   ├── icons/              icônes des mods
│   └── jars/               ← dépose ici les .jar compilés
│
├── server/
│   ├── nginx/              gabarits de vhosts (jetons __DOMAIN__ etc.)
│   └── systemd/            gabarit de l'unité du serveur SSR
│
└── scripts/
    ├── rebrand.ps1         1re passe : nom d'organisation et domaine
    ├── debrand.ps1         2e passe : produits, noms de fichiers, URL
    ├── recolor-assets.ps1  bascule les illustrations du bleu au violet
    ├── install-logo.ps1    génère toutes les tailles depuis un logo source
    └── scan-mods.ps1       (re)génère mods.json depuis les dépôts
```

## Ce qui est servi où

| Domaine | Contenu | Origine |
|---|---|---|
| `endlessclient.dev` | le site | `web/` buildé, servi depuis `/var/www/endlessclient.dev` |
| `www.endlessclient.dev` | redirection | gérée par certbot |
| `mods.endlessclient.dev` | catalogue + `.jar` + API JSON | `mods/` copié tel quel |

---

## Démarrage rapide

**1. DNS** — fais pointer les trois enregistrements A/AAAA vers le serveur
*avant* de lancer le script, sinon Let's Encrypt refusera le certificat :

```
endlessclient.dev.        A    <ip-du-serveur>
www.endlessclient.dev.    A    <ip-du-serveur>
mods.endlessclient.dev.   A    <ip-du-serveur>
```

**2. Envoi** — copie ce dossier sur le serveur :

```bash
rsync -av --exclude node_modules --exclude .git \
      ./endlessclient.dev/ root@<ip>:/root/endlessclient.dev/
```

**3. Installation** :

```bash
cd /root/endlessclient.dev
chmod +x install.sh deploy.sh      # les droits d'exécution ne survivent pas à Windows
sudo ./install.sh --email toi@exemple.fr
```

Le script est **idempotent** : le relancer met à jour sans rien casser.
`sudo ./install.sh --help` liste toutes les options.

### Mises à jour ensuite

```bash
sudo ./deploy.sh                # site + catalogue
sudo ./deploy.sh --mods-only    # uniquement les .jar et mods.json
```

---

## Le catalogue de mods

`scripts/scan-mods.ps1` lit les dépôts et produit `mods/mods.json`.
Il gère les **quatre** conventions de métadonnées qui coexistent dans
l'écosystème :

| Source | Fichier | Clés | Dépôts |
|---|---|---|---|
| `stonecutter` | `stonecutter.properties.toml` | `mod.id`, `mod.version`, sections par version MC | 20 |
| `gradle` | `gradle.properties` | `mod_name` **ou** `mod.name` — les deux existent | 31 |
| `fabric-template` | `gradle.properties` | `archives_base_name`, `minecraft_version` | 1 |
| — | aucune | classé via la table `$CategoryOverrides` | 55 |

Répartition obtenue :

```
mod 52 · library 21 · tooling 12 · infra 7 · docs 4 · app 3 · data 3 · empty 3 · example 2
```

Le scan applique aussi le rebranding : les préfixes de marque sont remplacés
(`PolySprint` → `EndlessSprint`, `OverflowParticles` → `EndlessParticles`,
`OneConfig` → `EndlessConfig`) dans `name`, `id`, `slug`, ainsi que dans les
descriptions et les groupes Maven repris des dépôts (`org.polyfrost` →
`org.endlessclient`).

Les noms purement descriptifs — Chatting, FullBright, VanillaHUD, DamageTint —
ne portent aucune marque et sont **laissés intacts** : les préfixer donnerait
« EndlessFullBright », illisible et sans gain.

Régénérer après un changement dans les dépôts :

```powershell
pwsh -File scripts/scan-mods.ps1
```

### Ajouter des `.jar`

Voir [`mods/jars/README.md`](mods/jars/README.md) pour les règles de nommage.
En résumé : `chatting-3.1.3.jar` est rattaché à Chatting, `mon-chatting.jar` ne
l'est pas. Après dépôt, relance le scan puis `deploy.sh --mods-only`.

---

## Le logo

Dépose ton logo **une seule fois** — PNG carré, transparence, 512 px minimum —
puis lance :

```powershell
pwsh -File scripts/install-logo.ps1 -Source .\logo-source.png
```

Le script produit et place les sept déclinaisons :

| Fichier | Taille | Usage |
|---|---|---|
| `public/logo.png` | 512 | `og:image`, en-tête |
| `public/android-chrome-512x512.png` | 512 | manifeste PWA |
| `public/android-chrome-192x192.png` | 192 | manifeste PWA |
| `public/apple-touch-icon.png` | 180 | écran d'accueil iOS |
| `public/favicon.ico` | 16/32/48 | onglet navigateur |
| `public/favicon.svg` | 256 | onglet, variante vectorielle |
| `mods/logo.png` | 512 | en-tête du catalogue |

Redimensionnement bicubique haute qualité en `Format32bppArgb` : la
transparence est préservée et l'image est centrée sans déformation si la source
n'est pas carrée. Le `.ico` est un conteneur multi-tailles écrit à la main —
`System.Drawing` ne sait produire qu'une icône 32×32 monobloc.

`safari-pinned-tab.svg` n'est **pas** régénéré : c'est un masque monochrome
vectoriel, il demande un tracé et non une image matricielle.

La palette du site est alignée sur le logo (violet `#a855f7` / `#7e22ce` /
pierre sombre `#2e1048`), définie dans
[`web/apps/website/uno.config.ts`](web/apps/website/uno.config.ts).

Attention en relisant ce fichier : l'échelle de couleurs s'appelle toujours
`blue` et la teinte sombre `navy-peony`. Ce sont les **noms hérités** utilisés
dans une trentaine de fichiers `.astro` ; seules les valeurs RGB ont basculé en
violet, pour éviter un renommage de masse des classes utilitaires.

### Les illustrations

`scripts/recolor-assets.ps1` a décalé **411 couleurs dans 66 fichiers** — SVG
décoratifs, favicon, dégradés en dur.

Chaque littéral `#RRGGBB` est converti en TSL, sa **teinte** est décalée vers le
violet, et sa saturation comme sa luminosité sont conservées. Les dégradés,
ombres et contrastes des dessins restent donc intacts ; seule la famille
chromatique change. Les teintes source s'étalaient de 203° à 231° — quasi
uniformément bleues — et sont recomprimées autour de 271° (`#a855f7`).

```
#0A5BE8 → #790AE8      #2B4BFF → #AC2BFF      #E0E9FB → #EEE0FB
```

Deux exclusions : les couleurs sous 20 % de saturation (les gris d'interface,
qu'un décalage ne ferait que salir) et les couleurs de marque tierces —
`#5865F2` identifie Discord, pas nous. C'est la seule teinte bleue qui subsiste
dans `web/`, et c'est voulu.

Le script est idempotent : après un passage les teintes sortent de la plage
source et ne sont plus reconnues.

---

## Le rebranding

Deux passes, dans cet ordre. Les deux sont idempotentes.

**`scripts/rebrand.ps1`** — organisation et domaine :
`polyfrost.org` → `endlessclient.dev`, `Polyfrost` → `EndlessClient`,
scope npm `@polyfrost/` → `@endlessclient/`. 28 fichiers.

**`scripts/debrand.ps1`** — noms de produits, **noms de fichiers** et URL :

| Avant | Après |
|---|---|
| OneClient | EndlessClient |
| OneConfig | EndlessConfig |
| OneLauncher | EndlessLauncher |
| `Poly<X>` | `Endless<X>` (PolySprint → EndlessSprint) |
| `Overflow<X>` | `Endless<X>` (OverflowParticles → EndlessParticles) |

41 renommages de fichiers et dossiers, dont les routes
(`/projects/endlessclient`), les icônes, l'article de blog et les dossiers
d'assets. Vérification finale : **0 occurrence** de polyfrost / oneconfig /
oneclient / onelauncher dans `web/`.

### La collision `brand.*` / `endlessclient.*`

L'organisation (*Polyfrost*) et le client (*OneClient*) convergent tous deux
vers « EndlessClient ». Leurs jeux d'icônes se seraient écrasés. D'où :

- `brand.full` / `brand.minimal` / `brand.minimal_bg` → logo de
  l'**organisation** (ex-`polyfrost.*`), utilisé dans la navbar et le pied de page
- `endlessclient.*` → icônes du **produit** (ex-`oneclient.*`), utilisées sur
  la page produit et dans `getProjects()`

`astro-icon` résout par nom de fichier : une référence sans `.svg`
correspondant fait échouer le **build**, pas seulement l'affichage. Le script
vérifie ce point à chaque exécution.

### Identités externes

Toutes centralisées en tête de
[`site-info.ts`](web/apps/website/src/utils/site-info.ts) :

```ts
const GITHUB_URL     = 'https://github.com/th3darksand8tch/EndlessClient';
const DISCORD_INVITE = '';   // TODO
const YOUTUBE_URL    = '';   // TODO
const MODRINTH_ID    = 'endlessclient';
```

Tant que `DISCORD_INVITE` et `YOUTUBE_URL` sont vides, ces boutons renvoient
vers GitHub plutôt que vers un lien mort — ou, pire, vers le compte d'un autre
projet.

`th3darksand8tch` est un compte **utilisateur**, pas une organisation :
[`downloads.ts`](web/apps/website/src/pages/api/downloads.ts) a été basculé de
`GET /orgs/{org}/repos` vers `GET /users/{username}/repos`, sans quoi l'API
GitHub répondrait 404.

**Seuls `ATTRIBUTION.md` et `LICENSE` restent intouchés** : l'attribution amont
est une obligation de licence, pas du branding.

---

## Points ouverts

Ce qui n'est pas résolu et demandera une action de ta part :

1. **Pages légales vides.** `src/utils/legal.ts` interroge désormais
   `https://data-v2.endlessclient.dev/oneclient/tos.json`, qui n'existe pas.
   `/legal/terms` et `/legal/privacy` s'afficheront vides — le code retombe
   proprement sur `null`, sans planter. Publie ce JSON, ou repointe la
   constante `TOS_URL`.

2. **Redirections `/go/<slug>` en erreur.** `src/utils/plus.ts` pointe vers
   `https://plus.endlessclient.dev`, backend inexistant. Corrige la valeur ou
   définis `PUBLIC_PLUS_BACKEND_URL`.

3. **Comptes externes à créer.** Le dépôt
   `github.com/th3darksand8tch/EndlessClient` doit exister et être public,
   sinon le compteur de téléchargements de la page d'accueil renvoie 502.
   `DISCORD_INVITE` et `YOUTUBE_URL` sont vides. Le type du compte Modrinth
   (`organization` ou `user`) reste à confirmer : le mauvais choix produit une
   URL en 404.

4. **Aucun `.jar` publié.** `mods/jars/` est vide : le catalogue liste les mods
   mais aucun bouton « Télécharger » n'apparaîtra tant que rien n'y est déposé.
   Compiler les 52 mods demande JDK 8/17/21 et du réseau — à faire en CI plutôt
   qu'à la main.

5. **Build jamais exécuté.** Le site n'a pas été compilé ici (ni Node ni pnpm
   sur cette machine). Le premier `install.sh` est donc aussi le premier test
   réel du build ; il s'arrêtera avec le journal en cas d'échec.

6. **3 dépôts vides.** `PackManager`, `PolySnapper` et `PolyWaypoints` ne
   contiennent que `.git` ou un `LICENSE`. Ils sont marqués `empty` et exclus
   de la page publique.

7. **Les dossiers sources gardent leur nom.** Sous `D:\URG`, les dépôts
   s'appellent toujours `PolySprint`, `OneConfig`… Seul le catalogue est
   rebrandé. Le champ `repo` de `mods.json` conserve le nom du dossier : c'est
   la seule clé qui permet de remonter à la source après renommage.

---

## Référence des scripts

| Script | Où | Rôle |
|---|---|---|
| `install.sh` | serveur, root | paquets, Node, utilisateur, build, vhosts, systemd, TLS |
| `deploy.sh` | serveur, root | resync + rebuild + republication, sans toucher au système |
| `scripts/scan-mods.ps1` | Windows | régénère `mods/mods.json` et `mods/meta/` |
| `scripts/rebrand.ps1` | Windows | 1re passe : organisation et domaine |
| `scripts/debrand.ps1` | Windows | 2e passe : produits, fichiers, URL |
| `scripts/recolor-assets.ps1` | Windows | décale les couleurs du bleu au violet |
| `scripts/install-logo.ps1` | Windows | génère les 7 déclinaisons du logo |

Sur une copie neuve du monorepo, enchaîne `rebrand.ps1` puis `debrand.ps1`
dans cet ordre — le second corrige des formes produites par le premier.

Les gabarits `server/nginx/*.conf.template` et
`server/systemd/*.service.template` sont rendus par `install.sh` via `sed`
(jetons `__DOMAIN__`, `__WEB_ROOT__`, `__PORT__`, `__APP_DIR__`,
`__SERVICE_USER__`, `__MODS_ROOT__`). Ils restent en HTTP seul : c'est
`certbot --nginx` qui injecte le bloc 443 et la redirection.

---

## Licences

Le site dérive d'un monorepo sous **AGPL-3.0** ; l'attribution amont est
conservée dans `web/ATTRIBUTION.md` et `web/LICENSE`, volontairement exclus du
rebranding. Les mods sont sous GPL-3.0 (27), LGPL-3.0 (10), AGPL-3.0, MIT,
MPL-2.0.

Renommer un mod ne change pas sa licence. Redistribuer les binaires impose de
garder les sources correspondantes accessibles : le champ `upstream` de chaque entrée
de `mods.json` pointe vers le dépôt d'origine.
