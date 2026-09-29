# Paperclip operator guide

## Once per Paperclip host

Requirements: root, `python3`, `psql` (postgresql-client), Paperclip running as a
dedicated service user with an external PostgreSQL (`DATABASE_URL`). Public deployments
refuse the embedded database anyway.

```
git clone https://github.com/sln-dns/paperclip-claude-agent
cd paperclip-claude-agent
sudo server/install.sh --service-user paperclip --database-url 'postgres://paperclip:...@127.0.0.1:5432/paperclip'
sudo systemctl restart paperclip        # the service user must pick up group pcqueue
```

If the Paperclip unit uses `ProtectSystem=strict`, add
`ReadWritePaths=/var/lib/paperclip-handoff`. With `ProtectSystem=full` nothing is needed.

Check: `ls -ld /var/lib/paperclip-handoff` → `drwxrws--- <service user> pcqueue`.

## Per agent

1. **Invite.** Agents page → add agent → generate the agent onboarding prompt, join type
   *agent*. Send the prompt to the person; they paste it into `/paperclip:join`.
2. **Approve** the join request in the UI. The agent is created with the `process` adapter
   and the command `/usr/local/bin/pc-handoff`, timeout 3600 s (taken from the join request).
3. **Queue access.** The agent sends you one line; run it from this repository:

   ```
   sudo server/add-agent.sh <agentId> 'ssh-ed25519 AAAA... paperclip-queue'
   ```

4. Make sure the agent's heartbeat timer is **off** (wake on assignment only), and set a
   budget — the process adapter spends nothing, but other agents' runs do.

## Checks

```
# runs waiting for delivery, per agent
sudo ls /var/lib/paperclip-handoff/*/
# what an agent sees
sudo -u pcqueue SSH_ORIGINAL_COMMAND=list /usr/local/bin/pc-queue-read <agentId>
# resolver by hand
sudo /usr/local/sbin/pc-handoff-resolve
```

## Pitfalls we hit

| Symptom | Cause |
|---|---|
| Agent writes return 401 "Agent run id required" | writing outside an active run; use `pc`, not MCP write tools |
| Task goes to "missing disposition", agent never notified | adapter command exits at once (`true`), or the resolver cannot read the DB |
| `This account is currently not available` for pcqueue | the account shell is `nologin`; forced commands need `/bin/sh` (install.sh sets it) |
| The adapter list in the UI has no *Process* | expected: it is "coming soon" in the UI; the invite join flow accepts `process` |
| Onboarding wizard asks for a model sign-in the host cannot do | a CEO agent is required first; any adapter with an API key works (e.g. OpenCode + a capped OpenRouter key) |
| The watcher never types, log says "input line is busy" | the user has text in the Claude Code input; send or clear it |
