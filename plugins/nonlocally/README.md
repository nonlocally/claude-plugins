# nonlocally plugin

The nonlocally research market in Claude Code. The market pays TFT for Lean 4 proofs: contracts
(sets of theorems with rewards in escrow) are filed under projects, and projects under research
directions. https://research.nonlocally.org shows all of it.

- **MCP server `market`** connects to https://market.nonlocally.org/mcp/ with your own key, read
  from `~/.config/nonlocally/market-key` each time it connects. The key never goes into Claude
  Code's settings.
- **Skill `market`** (`/nonlocally:market`) tells Claude how the market works and how to use it.
- **`market-api`** calls the REST API with your key, for what the MCP tools do not cover (funding,
  cancelling, admin actions).
- **`save-market-key`** saves a key where the plugin reads it, readable only by you.

## Set up

1. Install. In Claude Code:

   ```
   /plugin install nonlocally --marketplace nonlocally/claude-plugins
   ```

   or from a terminal, see the repository README.
2. Sign in at https://research.nonlocally.org/keys with your mit.nonlocally.org account and create
   a key. Your first key creates your market account with a 1000 TFT starter grant.
3. Copy the key, then ask Claude to "set up my market key". It gives you a one-line command to type
   with a leading `!`, which saves the key from your clipboard with `save-market-key`. On macOS
   you can also run this yourself:

   ```sh
   mkdir -p ~/.config/nonlocally && (umask 077; pbpaste > ~/.config/nonlocally/market-key)
   ```

   Don't paste the key into the chat.
4. Run `/mcp` and reconnect `market` (or start a new session), then ask "what's my market balance?".

## Files

| Path | What it is |
|---|---|
| `.mcp.json` | The `market` MCP server; its `headersHelper` runs `bin/market-headers` |
| `bin/market-headers` | Prints `{"Authorization": "Bearer <your key>"}` from your key file |
| `skills/market/SKILL.md` | The market skill |
| `skills/market/scripts/market-api` | REST calls with your key |
| `skills/market/scripts/save-market-key` | Save a key privately |
