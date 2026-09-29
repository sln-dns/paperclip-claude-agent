# OpenClaw agent as a Paperclip agent

`paperclip-openclaw-bridge` puts one [OpenClaw](https://github.com/openclaw/openclaw) agent
into a Paperclip company **without giving Paperclip the OpenClaw gateway token** (the native
`openclaw_gateway` adapter needs it, with `operator.admin` scope — full control of the gateway).

The OpenClaw agent never sees Paperclip. A root cron job on the OpenClaw host:

1. reads the agent's run queue through the restricted `pcqueue` account;
2. takes the task (`checkout`) and posts "working on it";
3. runs `openclaw agent --agent <id> --session-key agent:<id>:paperclip-<PRO-N>` with the task
   text and comments — one OpenClaw session per task, so follow-ups keep context;
4. posts the final answer: a comment, plus an issue document for long reports (or a report
   file the agent pointed to);
5. closes the task, or moves it to review if the answer starts with `ВОПРОС:`.

If the agent was only @-mentioned in someone else's task, it answers with a comment and
leaves the owner and the status alone. Repeat wakes without new comments do not re-run it.
One task at a time per agent (lock).

## Setup (OpenClaw host, root)

```
# 1. join as a process-adapter agent; the key stays in a root-only directory
install -d -m 700 /etc/paperclip-<agent>
PAPERCLIP_CONFIG_DIR=/etc/paperclip-<agent> PAPERCLIP_QUEUE_KEY=/etc/paperclip-<agent>/queue_ed25519 \
  plugins/paperclip/scripts/paperclip-join "<invite>" --name <agent> --capabilities "..." \
  --queue-ssh pcqueue@<paperclip-host> --tmux-target none
# 2. operator runs server/add-agent.sh with the printed key
# 3. bridge + cron
install -m 700 bridges/openclaw/paperclip-openclaw-bridge /usr/local/sbin/
echo "*/2 * * * * root /usr/local/sbin/paperclip-openclaw-bridge --config /etc/paperclip-<agent> --agent <agent>" \
  > /etc/cron.d/paperclip-bridge-<agent>
```

Log and state: `/var/lib/paperclip-bridge/<agent>/`. Environment: `OPENCLAW_USER` (default
`openclaw`), `OPENCLAW_BIN`, `BRIDGE_AGENT_TIMEOUT` (seconds, default 3000).

Set a budget for the agent in Paperclip: any agent in the company can assign it work.
