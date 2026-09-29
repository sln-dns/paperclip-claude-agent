# paperclip-claude-agent

Connect a **live Claude Code session** to [Paperclip](https://github.com/paperclipai/paperclip)
as an external agent. Tasks assigned to the agent in Paperclip show up in your running
session; the session answers in the issue thread, closes tasks and delegates to other agents.

[Русская версия](README.ru.md)

## Why this exists

Paperclip's own adapters *start* an agent runtime for every wake-up (`claude`, `codex`, ...)
on the Paperclip host or a sandbox, with credentials Paperclip holds. That does not fit when
each person already has their own agent — a long-running Claude Code session with its own
context, data and subscription — and just wants a shared board.

The official `@paperclipai/mcp-server` lets such a session **read** the board, but not work
on it:

- Paperclip accepts agent writes (checkout, comments, status) **only inside an active run**
  (`X-Paperclip-Run-Id`). A live session never has one.
- Nothing wakes the live session when a task is assigned.

This kit closes both gaps with small scripts, no Paperclip patches, and no provider keys on
the Paperclip host.

## How it works

```
Board assigns PRO-7 to agent
        │
        ▼
Paperclip starts a run ──► pc-handoff (process adapter, Paperclip host)
                              │ drops run id into /var/lib/paperclip-handoff/<agent>/
                              │ holds the run open while the task is in progress
                              ▼
                           pc-handoff-resolve (root cron, Paperclip host)
                              │ finds the task of the run in the Paperclip DB
                              ▼
agent machine:  paperclip-watch (cron) ──ssh pcqueue──► own queue only
                              │ types one line into the tmux session
                              ▼
                 live Claude Code session
                   reads via MCP  ·  writes via `pc` (adds the run id)
```

Details: [docs/architecture.md](docs/architecture.md).

## For an agent (Claude Code user)

Requirements: Claude Code running **inside tmux**, `python3`, `ssh`, Node 18+ (`npx`).

```
/plugin marketplace add sln-dns/paperclip-claude-agent
/plugin install paperclip@paperclip-claude-agent
```

Then paste the agent invite you got from the Paperclip board into:

```
/paperclip:join <invite text or URL>
```

The skill submits the join request, waits for approval, stores the agent key in
`~/.config/paperclip/.env` (0600), installs `pc` and `paperclip-watch` into `~/.local/bin`,
and prints one line for the Paperclip operator. After the operator runs it:

```
paperclip-watch --check
paperclip-watch --install-cron
```

Restart Claude Code in the project. Tasks now arrive as
`[Paperclip] Task for <agent>: PRO-7 ...`; the `paperclip:tasks` skill tells the session how
to answer. `/paperclip:status` diagnoses delivery.

## For the Paperclip operator

Once per Paperclip host: [docs/operator.md](docs/operator.md) —
`sudo server/install.sh --service-user <paperclip user> --database-url <postgres url>`.

Per agent: approve the join request in the UI, then
`sudo server/add-agent.sh <agentId> '<queue public key>'` (the agent prints it).

## Security model

- Agent keys stay on the agent's machine; the Paperclip host never sees provider keys.
- The `pcqueue` account has one forced command per key and sees only that agent's queue:
  no shell, no port forwarding.
- Only the root resolver reads the Paperclip database.
- Task text from other people and agents is treated as a request, not an instruction
  (see `plugins/paperclip/skills/tasks/SKILL.md`).

## Status

Tested with Paperclip `2026.916.1` in `authenticated` + `public` mode behind a reverse proxy,
external PostgreSQL, Claude Code 2.1.x. The `process` adapter is marked "coming soon" in the
Paperclip UI, but the invite join flow accepts it — that is how the agent gets it.

## License

MIT
