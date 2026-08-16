#!/usr/bin/env bash
#
# install.sh — deploie EndlessClient (endlessclient.dev) sur un serveur Debian/Ubuntu.
#
# Ce que le script met en place :
#   1. nginx, certbot, rsync, Node.js LTS + pnpm (via corepack)
#   2. un utilisateur systeme dedie et /opt/endlessclient
#   3. le build du site Astro
#   4. deux vhosts : endlessclient.dev (site) et mods.endlessclient.dev (catalogue)
#   5. un service systemd pour le SSR, uniquement si le build en produit un
#   6. les certificats TLS via Let's Encrypt
#
# Le script est idempotent : le relancer met a jour le contenu sans rien casser.
#
# Usage :   sudo ./install.sh --email toi@exemple.fr
#           sudo ./install.sh --help
#
set -Eeuo pipefail

# --- Valeurs par defaut ----------------------------------------------------

DOMAIN="endlessclient.dev"
EMAIL=""
PORT=4321
NODE_MAJOR=22
SERVICE_USER="endlessclient"
APP_DIR="/opt/endlessclient"
SERVICE_NAME="endlessclient-web"

DO_APT=1
DO_BUILD=1
DO_TLS=1

SRC_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

# --- Sortie ----------------------------------------------------------------

if [[ -t 1 ]]; then
	C_RESET=$'\033[0m'; C_BOLD=$'\033[1m'; C_DIM=$'\033[2m'
	C_RED=$'\033[31m'; C_GREEN=$'\033[32m'; C_YELLOW=$'\033[33m'; C_BLUE=$'\033[34m'
else
	C_RESET=''; C_BOLD=''; C_DIM=''; C_RED=''; C_GREEN=''; C_YELLOW=''; C_BLUE=''
fi

TOTAL_STEPS=9
STEP=0
step() { STEP=$((STEP + 1)); printf '\n%s[%d/%d]%s %s%s%s\n' "$C_BLUE" "$STEP" "$TOTAL_STEPS" "$C_RESET" "$C_BOLD" "$1" "$C_RESET"; }
info() { printf '      %s\n' "$1"; }
ok()   { printf '      %s✓%s %s\n' "$C_GREEN" "$C_RESET" "$1"; }
warn() { printf '      %s!%s %s\n' "$C_YELLOW" "$C_RESET" "$1" >&2; }
die()  { printf '\n%serreur:%s %s\n' "$C_RED" "$C_RESET" "$1" >&2; exit 1; }

trap 'die "echec ligne $LINENO : ${BASH_COMMAND}"' ERR

usage() {
	cat <<-EOF
	install.sh — deploiement EndlessClient

	  Usage
	    sudo ./install.sh [options]

	  Options
	    --domain <nom>     Domaine principal            (defaut: ${DOMAIN})
	    --email <adresse>  Contact Let's Encrypt        (requis pour le TLS)
	    --port <n>         Port local du SSR            (defaut: ${PORT})
	    --app-dir <chemin> Racine applicative           (defaut: ${APP_DIR})
	    --user <nom>       Utilisateur systeme          (defaut: ${SERVICE_USER})
	    --node <majeur>    Version majeure de Node.js   (defaut: ${NODE_MAJOR})
	    --no-apt           Ne pas installer de paquets systeme
	    --no-build         Reutiliser le build existant
	    --no-tls           Ne pas demander de certificat (reste en HTTP)
	    -h, --help         Afficher cette aide

	  Prerequis DNS
	    Les enregistrements A/AAAA de ${DOMAIN}, www.${DOMAIN} et
	    mods.${DOMAIN} doivent pointer vers ce serveur AVANT de lancer
	    le script avec le TLS actif, sinon Let's Encrypt refusera.
	EOF
}

# --- Arguments -------------------------------------------------------------

while [[ $# -gt 0 ]]; do
	case "$1" in
		--domain)   DOMAIN="${2:?--domain attend une valeur}"; shift 2 ;;
		--email)    EMAIL="${2:?--email attend une valeur}"; shift 2 ;;
		--port)     PORT="${2:?--port attend une valeur}"; shift 2 ;;
		--app-dir)  APP_DIR="${2:?--app-dir attend une valeur}"; shift 2 ;;
		--user)     SERVICE_USER="${2:?--user attend une valeur}"; shift 2 ;;
		--node)     NODE_MAJOR="${2:?--node attend une valeur}"; shift 2 ;;
		--no-apt)   DO_APT=0; shift ;;
		--no-build) DO_BUILD=0; shift ;;
		--no-tls)   DO_TLS=0; shift ;;
		-h|--help)  usage; exit 0 ;;
		*)          usage >&2; die "option inconnue : $1" ;;
	esac
done

MODS_DOMAIN="mods.${DOMAIN}"
WEB_ROOT="/var/www/${DOMAIN}"
MODS_ROOT="/var/www/${MODS_DOMAIN}"

[[ $PORT =~ ^[0-9]+$ ]] || die "--port doit etre un entier (recu: ${PORT})"

if (( DO_TLS )) && [[ -z $EMAIL ]]; then
	warn "aucun --email fourni : le TLS est desactive, le site restera en HTTP."
	warn "relance avec --email toi@exemple.fr pour obtenir un certificat."
	DO_TLS=0
fi

# --- Verifications ---------------------------------------------------------

(( EUID == 0 )) || die "ce script doit tourner en root (utilise sudo)."
command -v apt-get >/dev/null 2>&1 || die "distribution non supportee : apt-get est introuvable."

for required in "$SRC_DIR/web" "$SRC_DIR/mods" "$SRC_DIR/server/nginx" "$SRC_DIR/server/systemd"; do
	[[ -d $required ]] || die "dossier manquant : ${required}. Envoie le dossier endlessclient.dev complet."
done

printf '%s\n' "${C_BOLD}Deploiement EndlessClient${C_RESET}"
printf '%s\n' "${C_DIM}  domaine   ${DOMAIN} + www + ${MODS_DOMAIN}"
printf '%s\n' "  source    ${SRC_DIR}"
printf '%s\n' "  cible     ${APP_DIR}"
printf '%s\n' "  TLS       $( ((DO_TLS)) && echo "oui (${EMAIL})" || echo 'non' )${C_RESET}"

# --- 1. Paquets systeme ----------------------------------------------------

step "Paquets systeme"
if (( DO_APT )); then
	export DEBIAN_FRONTEND=noninteractive
	apt-get update -qq
	apt-get install -y -qq \
		nginx rsync curl ca-certificates gnupg git \
		certbot python3-certbot-nginx >/dev/null
	ok "nginx, certbot, rsync installes"
else
	info "ignore (--no-apt)"
fi

# --- 2. Node.js + pnpm -----------------------------------------------------

step "Node.js ${NODE_MAJOR}.x et pnpm"
current_node_major=0
if command -v node >/dev/null 2>&1; then
	current_node_major="$(node -v | sed 's/^v\([0-9]*\).*/\1/')"
fi

if (( current_node_major >= NODE_MAJOR )); then
	ok "node $(node -v) deja present"
elif (( DO_APT )); then
	info "installation depuis NodeSource..."
	curl -fsSL "https://deb.nodesource.com/setup_${NODE_MAJOR}.x" | bash - >/dev/null
	apt-get install -y -qq nodejs >/dev/null
	ok "node $(node -v) installe"
else
	die "node >= ${NODE_MAJOR} requis mais absent, et --no-apt empeche l'installation."
fi

# corepack fournit pnpm a la version epinglee par le champ packageManager.
if command -v corepack >/dev/null 2>&1; then
	corepack enable >/dev/null 2>&1 || warn "corepack enable a echoue, pnpm sera peut-etre indisponible"
	ok "corepack actif"
else
	command -v pnpm >/dev/null 2>&1 || die "ni corepack ni pnpm disponibles ; installe pnpm manuellement."
fi

# --- 3. Utilisateur et arborescence ---------------------------------------

step "Utilisateur systeme et arborescence"
if id -u "$SERVICE_USER" >/dev/null 2>&1; then
	ok "utilisateur ${SERVICE_USER} deja present"
else
	useradd --system --create-home --home-dir "$APP_DIR" --shell /usr/sbin/nologin "$SERVICE_USER"
	ok "utilisateur ${SERVICE_USER} cree"
fi

install -d -o "$SERVICE_USER" -g "$SERVICE_USER" -m 755 "$APP_DIR"
install -d -o www-data -g www-data -m 755 "$WEB_ROOT" "$MODS_ROOT"
ok "${APP_DIR}, ${WEB_ROOT}, ${MODS_ROOT} prets"

# --- 4. Synchronisation des sources ---------------------------------------

step "Copie des sources vers ${APP_DIR}"
rsync -a --delete \
	--exclude '.git/' \
	--exclude 'node_modules/' \
	--exclude '.astro/' \
	--exclude 'dist/' \
	"$SRC_DIR/web/" "$APP_DIR/web/"

rsync -a --delete "$SRC_DIR/mods/"   "$APP_DIR/mods/"
rsync -a --delete "$SRC_DIR/server/" "$APP_DIR/server/"

if [[ -d "$SRC_DIR/scripts" ]]; then
	rsync -a --delete "$SRC_DIR/scripts/" "$APP_DIR/scripts/"
fi

chown -R "$SERVICE_USER:$SERVICE_USER" "$APP_DIR"
ok "sources synchronisees"

# --- 5. Build du site ------------------------------------------------------

WEBSITE_DIR="$APP_DIR/web/apps/website"
DIST_DIR="$WEBSITE_DIR/dist"

step "Build du site Astro"
if (( DO_BUILD )); then
	PKG_NAME="$(node -p "require('${WEBSITE_DIR}/package.json').name")"
	info "paquet : ${PKG_NAME}"

	# Le build tourne sous l'utilisateur de service : rien dans APP_DIR ne doit
	# finir en root, sinon le service ne pourrait plus lire son propre dist/.
	runuser -u "$SERVICE_USER" -- env \
		HOME="$APP_DIR" \
		PATH="$PATH" \
		CI=1 \
		bash -c "cd '$APP_DIR/web' && pnpm install --frozen-lockfile && pnpm --filter '${PKG_NAME}' build"

	ok "build termine"
else
	info "ignore (--no-build)"
fi

[[ -d $DIST_DIR ]] || die "aucun build trouve dans ${DIST_DIR}. Relance sans --no-build."

# Astro produit dist/client + dist/server en mode hybride, dist/ seul en statique.
if [[ -f "$DIST_DIR/server/entry.mjs" ]]; then
	HYBRID=1
	STATIC_SRC="$DIST_DIR/client"
	info "build hybride detecte (statique + SSR)"
else
	HYBRID=0
	STATIC_SRC="$DIST_DIR"
	info "build entierement statique detecte"
fi

# --- 6. Publication du contenu --------------------------------------------

step "Publication du contenu"
rsync -a --delete "$STATIC_SRC/" "$WEB_ROOT/"
chown -R www-data:www-data "$WEB_ROOT"
ok "site publie dans ${WEB_ROOT}"

rsync -a --delete --exclude '.gitkeep' "$APP_DIR/mods/" "$MODS_ROOT/"
chown -R www-data:www-data "$MODS_ROOT"
jar_count="$(find "$MODS_ROOT/jars" -maxdepth 1 -name '*.jar' 2>/dev/null | wc -l || true)"
ok "catalogue publie dans ${MODS_ROOT} (${jar_count} fichier(s) .jar)"

# --- 7. Service SSR --------------------------------------------------------

step "Service systemd"
if (( HYBRID )); then
	sed -e "s|__APP_DIR__|${APP_DIR}|g" \
	    -e "s|__SERVICE_USER__|${SERVICE_USER}|g" \
	    -e "s|__PORT__|${PORT}|g" \
	    "$APP_DIR/server/systemd/endlessclient-web.service.template" \
	    > "/etc/systemd/system/${SERVICE_NAME}.service"

	systemctl daemon-reload
	systemctl enable "$SERVICE_NAME" >/dev/null 2>&1
	systemctl restart "$SERVICE_NAME"

	sleep 2
	if systemctl is-active --quiet "$SERVICE_NAME"; then
		ok "${SERVICE_NAME} actif sur 127.0.0.1:${PORT}"
	else
		journalctl -u "$SERVICE_NAME" -n 30 --no-pager >&2 || true
		die "${SERVICE_NAME} n'a pas demarre (journal ci-dessus)."
	fi
else
	info "build statique : aucun service necessaire"
	if systemctl list-unit-files 2>/dev/null | grep -q "^${SERVICE_NAME}.service"; then
		systemctl disable --now "$SERVICE_NAME" >/dev/null 2>&1 || true
		rm -f "/etc/systemd/system/${SERVICE_NAME}.service"
		systemctl daemon-reload
		info "ancien service retire"
	fi
fi

# --- 8. nginx --------------------------------------------------------------

step "Configuration nginx"
[[ -d /etc/nginx/sites-available ]] || die "/etc/nginx/sites-available absent : layout nginx inattendu."

sed -e "s|__DOMAIN__|${DOMAIN}|g" \
    -e "s|__WEB_ROOT__|${WEB_ROOT}|g" \
    -e "s|__PORT__|${PORT}|g" \
    "$APP_DIR/server/nginx/site.conf.template" \
    > "/etc/nginx/sites-available/${DOMAIN}.conf"

sed -e "s|__DOMAIN__|${DOMAIN}|g" \
    -e "s|__MODS_ROOT__|${MODS_ROOT}|g" \
    "$APP_DIR/server/nginx/mods.conf.template" \
    > "/etc/nginx/sites-available/${MODS_DOMAIN}.conf"

ln -sfn "/etc/nginx/sites-available/${DOMAIN}.conf"      "/etc/nginx/sites-enabled/${DOMAIN}.conf"
ln -sfn "/etc/nginx/sites-available/${MODS_DOMAIN}.conf" "/etc/nginx/sites-enabled/${MODS_DOMAIN}.conf"

# Le vhost par defaut de Debian capte le port 80 et masque le notre.
if [[ -L /etc/nginx/sites-enabled/default ]]; then
	rm -f /etc/nginx/sites-enabled/default
	info "vhost 'default' desactive"
fi

nginx -t 2>&1 | sed 's/^/      /'
systemctl reload nginx
ok "nginx recharge"

if command -v ufw >/dev/null 2>&1 && ufw status 2>/dev/null | grep -q '^Status: active'; then
	ufw allow 'Nginx Full' >/dev/null 2>&1 || true
	info "regle ufw 'Nginx Full' appliquee"
fi

# --- 9. TLS ----------------------------------------------------------------

step "Certificat TLS"
if (( DO_TLS )); then
	# --nginx modifie les vhosts en place pour y injecter le bloc 443 et la
	# redirection. C'est pour cela que les gabarits restent en HTTP seul.
	if certbot --nginx \
		-d "$DOMAIN" -d "www.${DOMAIN}" -d "$MODS_DOMAIN" \
		--agree-tos -m "$EMAIL" --non-interactive --redirect --keep-until-expiring
	then
		systemctl reload nginx
		ok "certificat installe et renouvellement automatique actif"
	else
		warn "certbot a echoue. Verifie que les DNS pointent bien ici, puis relance :"
		warn "  certbot --nginx -d ${DOMAIN} -d www.${DOMAIN} -d ${MODS_DOMAIN} -m ${EMAIL} --agree-tos --redirect"
	fi
else
	info "ignore (--no-tls ou --email absent)"
fi

# --- Recapitulatif ---------------------------------------------------------

scheme="$( ((DO_TLS)) && echo https || echo http )"
cat <<-EOF

	${C_GREEN}${C_BOLD}Deploiement termine.${C_RESET}

	  Site       ${scheme}://${DOMAIN}
	  Catalogue  ${scheme}://${MODS_DOMAIN}
	  API JSON   ${scheme}://${MODS_DOMAIN}/mods.json

	  Sources    ${APP_DIR}
	  Site       ${WEB_ROOT}
	  Mods       ${MODS_ROOT}

	Ensuite
	  - depose tes .jar dans ${SRC_DIR}/mods/jars/ puis relance ./deploy.sh
	  - secrets facultatifs (GITHUB_PAT) dans ${APP_DIR}/.env
	  - logs du SSR : journalctl -u ${SERVICE_NAME} -f
	  - logs nginx  : tail -f /var/log/nginx/${DOMAIN}.error.log
EOF
