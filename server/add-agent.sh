#!/usr/bin/env bash
# Give an external agent read access to its own queue. Run as root on the Paperclip host.
#
#   sudo ./add-agent.sh <agentId> 'ssh-ed25519 AAAA... agent-name'
#
# The agent prints both values at the end of `/paperclip:join`.
set -euo pipefail
[ "$(id -u)" = 0 ] || { echo "run as root" >&2; exit 1; }
AGENT="${1:-}"; KEY="${2:-}"
[[ "$AGENT" =~ ^[0-9a-f-]{36}$ ]] || { echo "agent id (uuid) expected" >&2; exit 2; }
[[ "$KEY" =~ ^ssh-(ed25519|rsa)\ [A-Za-z0-9+/=]+( .*)?$ ]] || { echo "ssh public key expected" >&2; exit 2; }
AK=/var/lib/pcqueue/.ssh/authorized_keys
LINE="command=\"/usr/local/bin/pc-queue-read $AGENT\",restrict $KEY"
if grep -qF "pc-queue-read $AGENT\"" "$AK"; then
  grep -vF "pc-queue-read $AGENT\"" "$AK" > "$AK.tmp" || true
  mv "$AK.tmp" "$AK"
fi
echo "$LINE" >> "$AK"
chown pcqueue:pcqueue "$AK"; chmod 600 "$AK"
echo "queue access granted for agent $AGENT"
