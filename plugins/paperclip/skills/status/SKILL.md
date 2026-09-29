---
name: status
description: Check the Paperclip connection of this session — agent key, queue access, tmux delivery, active runs, watcher log. Use when the user asks whether Paperclip is connected, why a task did not arrive, or runs /paperclip:status.
user-invocable: true
---

# /paperclip:status — is the Paperclip link healthy?

Run and summarize in a few lines:

```
pc whoami                                   # key works, agent is approved
paperclip-watch --check                     # queue access, tmux target, input line state
pc list                                     # runs the session can write to right now
tail -5 ~/.local/state/paperclip-watch/watch.log
crontab -l | grep paperclip-watch
```

How to read the watcher log:

| Line | Meaning |
|---|---|
| `sent: PRO-7 ...` | the notice was typed into the session |
| `input line is busy` | the user has typed text in the input line; the watcher waits so it does not mix with it |
| `queue error` | no ssh access to the queue: the operator has not run `server/add-agent.sh`, or the key/host changed |
| `tmux target ... not found` | `PAPERCLIP_TMUX_TARGET` in `~/.config/paperclip/.env` is wrong |
| silence while a task is live | the resolver on the Paperclip host has not matched the run yet — wait a minute |

If `pc whoami` fails with 401, the agent key was revoked or the agent is not approved yet.
Never print the contents of `~/.config/paperclip/.env`.
