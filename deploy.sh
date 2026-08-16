#!/usr/bin/env bash
#
# deploy.sh — remet en ligne le contenu sans retoucher au systeme.
#
# A utiliser apres install.sh, quand seul le contenu change :
# nouveaux .jar dans mods/jars/, mods.json regenere, modification du site.
#
# Contrairement a install.sh, ce script n'installe aucun paquet, ne cree ni
# utilisateur ni vhost, et ne touche pas aux certificats. Il se contente de :
#   1. resynchroniser les sources vers APP_DIR
#   2. rebuilder le site (sauf --no-build)
#   3. republier le statique et le catalogue
#   4. redemarrer le SSR s'il existe
#
# Usage :   sudo ./deploy.sh
#           sudo ./deploy.sh --mods-only     # ne republie que le catalogue
#
set -Eeuo pipefail

DOMAIN="endlessclient.dev"
SERVICE_USER="endlessclient"
APP_DIR="/opt/endlessclient"
SERVICE_NAME="endlessclient-web"

DO_BUILD=1
MODS_ONLY=0

SRC_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

if [[ -t 1 ]]; then
	C_RESET=$'\033[0m'; C_BOLD=$'\033[1m'
	C_RED=$'\033[31m'; C_GREEN=$'\033[32m'
else
	C_RESET=''; C_BOLD=''; C_RED=''; C_GREEN=''
fi

ok()  { printf '  %s✓%s %s\n' "$C_GREEN" "$C_RESET" "$1"; }
die() { printf '\n%serreur:%s %s\n' "$C_RED" "$C_RESET" "$1" >&2; exit 1; }
trap 'die "echec ligne $LINENO : ${BASH_COMMAND}"' ERR

usage() {
	cat <<-EOF
	deploy.sh — republication du contenu EndlessClient

	  Usage
	    sudo ./deploy.sh [options]

	  Options
	    --domain <nom>     Domaine principal      (defaut: ${DOMAIN})
	    --app-dir <chemin> Racine applicative     (defaut: ${APP_DIR})
	    --user <nom>       Utilisateur systeme    (defaut: ${SERVICE_USER})
	    --mods-only        Ne republier que le catalogue et les .jar
	    --no-build         Republier le build existant sans le refaire
	    -h, --help         Afficher cette aide
	EOF
}

while [[ $# -gt 0 ]]; do
	case "$1" in
		--domain)     DOMAIN="${2:?--domain attend une valeur}"; shift 2 ;;
		--app-dir)    APP_DIR="${2:?--app-dir attend une valeur}"; shift 2 ;;
		--user)       SERVICE_USER="${2:?--user attend une valeur}"; shift 2 ;;
		--mods-only)  MODS_ONLY=1; shift ;;
		--no-build)   DO_BUILD=0; shift ;;
		-h|--help)    usage; exit 0 ;;
		*)            usage >&2; die "option inconnue : $1" ;;
	esac
done

MODS_DOMAIN="mods.${DOMAIN}"
WEB_ROOT="/var/www/${DOMAIN}"
MODS_ROOT="/var/www/${MODS_DOMAIN}"

(( EUID == 0 )) || die "ce script doit tourner en root (utilise sudo)."
[[ -d $APP_DIR ]] || die "${APP_DIR} introuvable : lance d'abord ./install.sh"

printf '%s\n' "${C_BOLD}Republication ${DOMAIN}${C_RESET}"

# --- Catalogue -------------------------------------------------------------

rsync -a --delete "$SRC_DIR/mods/" "$APP_DIR/mods/"
chown -R "$SERVICE_USER:$SERVICE_USER" "$APP_DIR/mods"

install -d -o www-data -g www-data -m 755 "$MODS_ROOT"
rsync -a --delete --exclude '.gitkeep' "$APP_DIR/mods/" "$MODS_ROOT/"
chown -R www-data:www-data "$MODS_ROOT"

jar_count="$(find "$MODS_ROOT/jars" -maxdepth 1 -name '*.jar' 2>/dev/null | wc -l || true)"
mod_count="$(node -p "require('${MODS_ROOT}/mods.json').count" 2>/dev/null || echo '?')"
ok "catalogue republie — ${mod_count} entree(s), ${jar_count} fichier(s) .jar"

if (( MODS_ONLY )); then
	printf '\n%sTermine (--mods-only).%s\n' "$C_GREEN" "$C_RESET"
	exit 0
fi

# --- Site ------------------------------------------------------------------

rsync -a --delete \
	--exclude '.git/' \
	--exclude 'node_modules/' \
	--exclude '.astro/' \
	--exclude 'dist/' \
	"$SRC_DIR/web/" "$APP_DIR/web/"
rsync -a --delete "$SRC_DIR/server/" "$APP_DIR/server/"
chown -R "$SERVICE_USER:$SERVICE_USER" "$APP_DIR/web" "$APP_DIR/server"
ok "sources synchronisees"

WEBSITE_DIR="$APP_DIR/web/apps/website"
DIST_DIR="$WEBSITE_DIR/dist"

if (( DO_BUILD )); then
	PKG_NAME="$(node -p "require('${WEBSITE_DIR}/package.json').name")"
	runuser -u "$SERVICE_USER" -- env \
		HOME="$APP_DIR" \
		PATH="$PATH" \
		CI=1 \
		bash -c "cd '$APP_DIR/web' && pnpm install --frozen-lockfile && pnpm --filter '${PKG_NAME}' build"
	ok "build termine"
fi

[[ -d $DIST_DIR ]] || die "aucun build dans ${DIST_DIR}."

if [[ -f "$DIST_DIR/server/entry.mjs" ]]; then
	STATIC_SRC="$DIST_DIR/client"
	HYBRID=1
else
	STATIC_SRC="$DIST_DIR"
	HYBRID=0
fi

rsync -a --delete "$STATIC_SRC/" "$WEB_ROOT/"
chown -R www-data:www-data "$WEB_ROOT"
ok "site republie dans ${WEB_ROOT}"

if (( HYBRID )) && systemctl list-unit-files 2>/dev/null | grep -q "^${SERVICE_NAME}.service"; then
	systemctl restart "$SERVICE_NAME"
	sleep 2
	systemctl is-active --quiet "$SERVICE_NAME" \
		|| { journalctl -u "$SERVICE_NAME" -n 30 --no-pager >&2 || true; die "${SERVICE_NAME} n'a pas redemarre."; }
	ok "${SERVICE_NAME} redemarre"
fi

systemctl reload nginx
ok "nginx recharge"

printf '\n%s%sTermine.%s  https://%s  |  https://%s\n' "$C_GREEN" "$C_BOLD" "$C_RESET" "$DOMAIN" "$MODS_DOMAIN"
