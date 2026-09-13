#!/bin/bash
##
# Build a complete local WordPress + Elementor site from source.
#
# Everything is fetched from GitHub rather than wordpress.org, because the
# egress policy in this container blocks wordpress.org, composer.elementor.com
# and assets.elementor.com. The result is a fully working site on SQLite.
#
# Usage: ./setup.sh
##

set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
SITE="$ROOT/site"

WP_VERSION="6.9"
SQLITE_VERSION="v3.0.2"
ELEMENTOR_VERSION="v3.35.9"

ADMIN_USER="admin"
ADMIN_PASS="admin123"
ADMIN_EMAIL="admin@example.com"
SITE_TITLE="Client Dossier"

step() { printf '\n\033[1;36m==> %s\033[0m\n' "$1"; }

command -v php >/dev/null || { echo "php is required" >&2; exit 1; }
command -v npm >/dev/null || { echo "npm is required" >&2; exit 1; }
php -m | grep -q pdo_sqlite || { echo "php pdo_sqlite extension is required" >&2; exit 1; }

if [ -d "$SITE" ]; then
	echo "$SITE already exists. Remove it first to rebuild from scratch." >&2
	exit 1
fi

step "WordPress core ${WP_VERSION}"
git clone --depth 1 --branch "$WP_VERSION" https://github.com/WordPress/WordPress.git "$SITE"
rm -rf "$SITE/.git"

step "SQLite database integration ${SQLITE_VERSION}"
SQLITE_SRC="$SITE/wp-content/plugins/sqlite-src"
git clone --depth 1 --branch "$SQLITE_VERSION" \
	https://github.com/WordPress/sqlite-database-integration.git "$SQLITE_SRC"
bash "$SQLITE_SRC/bin/build-sqlite-plugin-zip.sh" >/dev/null
mv "$SQLITE_SRC/build/plugin-sqlite-database-integration" \
	"$SITE/wp-content/plugins/sqlite-database-integration"
rm -rf "$SQLITE_SRC"

# The drop-in is what actually swaps MySQL for SQLite.
PLUGIN_DIR="$SITE/wp-content/plugins/sqlite-database-integration"
sed -e "s#{SQLITE_IMPLEMENTATION_FOLDER_PATH}#${PLUGIN_DIR}#g" \
	-e "s#{SQLITE_PLUGIN}#sqlite-database-integration/load.php#g" \
	"$PLUGIN_DIR/db.copy" > "$SITE/wp-content/db.php"

step "Hello Elementor theme"
THEME="$SITE/wp-content/themes/hello-elementor"
git clone --depth 1 https://github.com/elementor/hello-theme.git "$THEME"
rm -rf "$THEME/.git"
( cd "$THEME" && npm ci --no-audit --no-fund --ignore-scripts >/dev/null \
	&& npx wp-scripts build --env=production >/dev/null )

step "Elementor ${ELEMENTOR_VERSION} (this builds the editor bundles — several minutes)"
PLUGIN="$SITE/wp-content/plugins/elementor"
git clone --depth 1 --branch "$ELEMENTOR_VERSION" https://github.com/elementor/elementor.git "$PLUGIN"
rm -rf "$PLUGIN/.git"
(
	cd "$PLUGIN"
	export PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD=1 HUSKY=0
	npm ci --no-audit --no-fund --ignore-scripts >/dev/null
	( cd packages && npm ci --no-audit --no-fund --ignore-scripts >/dev/null )
	npm run build:packages >/dev/null
	npx grunt build >/dev/null
)
# composer.elementor.com is blocked, so `composer install` is skipped. Elementor
# guards its vendor/autoload.php with file_exists(), and the only code that needs
# the scoped Twig copy sits behind the (inactive) e_atomic_elements experiment.

step "Envato Market plugin"
# The Envato "Template Kit Import" plugin only ships on wordpress.org, which is
# blocked here. This is the official Envato plugin that does have a public
# source. It needs api.envato.com (also blocked in this container) to fetch
# anything, so here it installs and runs but cannot reach Envato — use
# bin/template-import.php for Template Kit zips instead.
ENVATO="$SITE/wp-content/plugins/envato-market"
git clone --depth 1 https://github.com/envato/wp-envato-market.git "$ENVATO"
rm -rf "$ENVATO/.git"

step "wp-config.php"
SALTS=$(php -r '$c="abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#$%^&*()-_[]{}<>~`+=,.;:/?|";
foreach(["AUTH_KEY","SECURE_AUTH_KEY","LOGGED_IN_KEY","NONCE_KEY","AUTH_SALT","SECURE_AUTH_SALT","LOGGED_IN_SALT","NONCE_SALT"] as $k){$v="";for($i=0;$i<64;$i++){$v.=$c[random_int(0,strlen($c)-1)];}printf("define( %s, %s );\n", var_export($k,true), var_export($v,true));}')

cat > "$SITE/wp-config.php" <<PHPEOF
<?php
/**
 * WordPress configuration — local dev (SQLite).
 */

// Database (unused with the SQLite drop-in, but WordPress expects them).
define( 'DB_NAME', 'wordpress' );
define( 'DB_USER', 'wordpress' );
define( 'DB_PASSWORD', 'wordpress' );
define( 'DB_HOST', 'localhost' );
define( 'DB_CHARSET', 'utf8mb4' );
define( 'DB_COLLATE', '' );

\$table_prefix = 'wp_';

${SALTS}

// URLs follow whatever host the site is served from.
if ( ! empty( \$_SERVER['HTTP_HOST'] ) ) {
	\$scheme = ( ! empty( \$_SERVER['HTTPS'] ) && 'off' !== \$_SERVER['HTTPS'] ) ? 'https' : 'http';
	define( 'WP_HOME', \$scheme . '://' . \$_SERVER['HTTP_HOST'] );
	define( 'WP_SITEURL', \$scheme . '://' . \$_SERVER['HTTP_HOST'] );
}

// No outbound HTTP from this sandbox (wordpress.org is not reachable here).
define( 'WP_HTTP_BLOCK_EXTERNAL', true );
define( 'WP_ACCESSIBLE_HOSTS', 'localhost,127.0.0.1' );

// Development settings.
define( 'WP_DEBUG', true );
define( 'WP_DEBUG_LOG', true );
define( 'WP_DEBUG_DISPLAY', false );
define( 'SCRIPT_DEBUG', true );
define( 'WP_ENVIRONMENT_TYPE', 'local' );
define( 'FS_METHOD', 'direct' );
define( 'AUTOMATIC_UPDATER_DISABLED', true );
define( 'DISALLOW_FILE_EDIT', false );

if ( ! defined( 'ABSPATH' ) ) {
	define( 'ABSPATH', __DIR__ . '/' );
}

require_once ABSPATH . 'wp-settings.php';
PHPEOF

step "mu-plugins"
mkdir -p "$SITE/wp-content/mu-plugins"
cp "$ROOT"/mu-plugins/*.php "$SITE/wp-content/mu-plugins/"

step "Installing WordPress"
WP_TITLE="$SITE_TITLE" WP_ADMIN_USER="$ADMIN_USER" WP_ADMIN_PASS="$ADMIN_PASS" \
	WP_ADMIN_EMAIL="$ADMIN_EMAIL" php "$ROOT/bin/install.php"

step "Activating plugins and theme"
WP_USER_ID=1 php "$ROOT/bin/activate.php"

step "Applying the Client Dossier kit"
WP_USER_ID=1 php "$ROOT/bin/kit-setup.php"

step "Done"
cat <<EOM

Start the site with:

    ./bin/serve.sh

    http://127.0.0.1:8080            front end
    http://127.0.0.1:8080/wp-admin/  ${ADMIN_USER} / ${ADMIN_PASS}

EOM
