#!/usr/bin/env bash
# Install the run-holder side on the Paperclip host. Run as root, once.
#
#   sudo ./install.sh --service-user paperclip --database-url 'postgres://user:pass@127.0.0.1:5432/paperclip'
#
# What it does:
#   * user `pcqueue` (read-only queue access over ssh, one forced command per key);
#   * group `pcqueue`, the Paperclip service user joins it;
#   * queue directory /var/lib/paperclip-handoff (setgid, group pcqueue);
#   * /usr/local/bin/pc-handoff, /usr/local/bin/pc-queue-read, /usr/local/sbin/pc-handoff-resolve;
#   * /etc/pc-handoff.conf with DATABASE_URL (root only) and a cron entry for the resolver.
# Restart the Paperclip service afterwards so it picks up the new group.
set -euo pipefail

SERVICE_USER=""
DATABASE_URL=""
while [ $# -gt 0 ]; do
  case "$1" in
    --service-user) SERVICE_USER="$2"; shift 2 ;;
    --database-url) DATABASE_URL="$2"; shift 2 ;;
    *) echo "unknown option: $1" >&2; exit 2 ;;
  esac
done
[ "$(id -u)" = 0 ] || { echo "run as root" >&2; exit 1; }
[ -n "$SERVICE_USER" ] && id "$SERVICE_USER" >/dev/null || { echo "--service-user: the user Paperclip runs as" >&2; exit 2; }
[ -n "$DATABASE_URL" ] || { echo "--database-url: Paperclip Postgres URL" >&2; exit 2; }
command -v psql >/dev/null || { echo "psql is required (postgresql-client)" >&2; exit 1; }
psql "$DATABASE_URL" -tAc "select 1 from heartbeat_runs limit 1" >/dev/null || { echo "cannot query heartbeat_runs with this DATABASE_URL" >&2; exit 1; }

HERE="$(cd "$(dirname "$0")" && pwd)"
id pcqueue >/dev/null 2>&1 || useradd --system --create-home --home-dir /var/lib/pcqueue --shell /bin/sh pcqueue
usermod -aG pcqueue "$SERVICE_USER"
install -d -o "$SERVICE_USER" -g pcqueue -m 2770 /var/lib/paperclip-handoff
install -d -o pcqueue -g pcqueue -m 700 /var/lib/pcqueue/.ssh
touch /var/lib/pcqueue/.ssh/authorized_keys
chown pcqueue:pcqueue /var/lib/pcqueue/.ssh/authorized_keys; chmod 600 /var/lib/pcqueue/.ssh/authorized_keys
install -o root -g root -m 755 "$HERE/pc-handoff" /usr/local/bin/pc-handoff
install -o root -g root -m 755 "$HERE/pc-queue-read" /usr/local/bin/pc-queue-read
install -o root -g root -m 700 "$HERE/pc-handoff-resolve" /usr/local/sbin/pc-handoff-resolve
umask 077; printf 'DATABASE_URL=%s\n' "$DATABASE_URL" > /etc/pc-handoff.conf; chmod 600 /etc/pc-handoff.conf
echo "* * * * * root /usr/local/sbin/pc-handoff-resolve >/dev/null 2>&1" > /etc/cron.d/pc-handoff-resolve
chmod 644 /etc/cron.d/pc-handoff-resolve

echo "Installed. Now:"
echo "  1. restart the Paperclip service (it must see group pcqueue);"
echo "  2. if the service uses ProtectSystem=strict, add ReadWritePaths=/var/lib/paperclip-handoff;"
echo "  3. for each external agent: ./add-agent.sh <agentId> '<agent queue public key>'."
