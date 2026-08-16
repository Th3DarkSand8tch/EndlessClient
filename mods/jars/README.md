# Dépôt des fichiers `.jar`

Ce dossier est le seul endroit où déposer les binaires compilés.
Il est publié tel quel sur `https://mods.endlessclient.dev/jars/`.

## Rattachement automatique

`scripts/scan-mods.ps1` associe un `.jar` à une entrée du catalogue en
comparant le **début du nom de fichier** à l'`id` puis au `name` du mod,
sans tenir compte de la casse. Le séparateur doit être `-`, `_` ou `.`.

Attention : le catalogue est **rebrandé**. `PolySprint` s'appelle désormais
`EndlessSprint`, d'identifiant `endlesssprint`. C'est ce nom-là que le fichier
doit porter, pas celui produit par Gradle. Renomme le `.jar` après compilation.

| Nom du fichier               | Rattaché à      | Pourquoi |
|------------------------------|-----------------|----------|
| `chatting-3.1.3+1.21.8.jar`  | Chatting        | préfixe `chatting` + `-` |
| `EndlessSprint_1.2.0.jar`    | EndlessSprint   | préfixe `EndlessSprint` + `_` |
| `endlessblur-1.0.0.jar`      | EndlessBlur     | préfixe `endlessblur` + `-` |
| `crashpatch.jar`             | CrashPatch      | nom exact |
| `PolySprint_1.2.0.jar`       | *rien*          | ancien nom, plus dans le catalogue |
| `mon-super-chatting.jar`     | *rien*          | `chatting` n'est pas en tête |
| `chattingv2.jar`             | *rien*          | pas de séparateur après `chatting` |

Quand plusieurs fichiers correspondent, le dernier par ordre alphabétique
décroissant est retenu — ce qui donne la version la plus haute tant que la
numérotation est cohérente.

## Procédure

1. Compiler le mod : `./gradlew build` dans son dépôt.
2. Récupérer le `.jar` dans `build/libs/` (ignorer les variantes `-sources`,
   `-dev` et `-shadow`).
3. Le copier ici.
4. Régénérer le catalogue : `pwsh -File scripts/scan-mods.ps1`.
5. Republier : `sudo ./deploy.sh --mods-only`.

## Licences

Les mods sont majoritairement sous **GPL-3.0** et **LGPL-3.0**. Redistribuer
un binaire impose de rendre la source correspondante disponible. Le champ
`upstream` de chaque entrée de `mods.json` pointe vers le dépôt d'origine,
ce qui couvre cette obligation tant que le lien reste valide.
