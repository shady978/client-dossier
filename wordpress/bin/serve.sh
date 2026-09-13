#!/bin/bash
# Start (or restart) the local WordPress dev server.
# Usage: bin/serve.sh [port]
set -e
PORT="${1:-8080}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

if [ ! -f "$ROOT/site/wp-config.php" ]; then
	echo "No site yet — run ./setup.sh first." >&2
	exit 1
fi

pkill -f "php -S 127.0.0.1:${PORT}" 2>/dev/null || true
sleep 1

nohup php -S "127.0.0.1:${PORT}" -t "$ROOT/site" "$ROOT/bin/router.php" > /tmp/wp-php-server.log 2>&1 &

echo "WordPress:  http://127.0.0.1:${PORT}"
echo "Admin:      http://127.0.0.1:${PORT}/wp-admin/  (admin / admin123)"
