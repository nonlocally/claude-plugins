# nonlocally Claude Code plugins

A Claude Code marketplace for working with nonlocally. It holds one plugin, `nonlocally`, which
starts with the research market and will grow to cover more of the platform.

## Install

In Claude Code:

```
/plugin install nonlocally --marketplace nonlocally/claude-plugins
```

Or from a terminal:

```sh
claude plugin marketplace add nonlocally/claude-plugins
claude plugin install nonlocally@nonlocally
```

Then set up your market key: see [plugins/nonlocally/README.md](plugins/nonlocally/README.md).
In short, create a key at https://research.nonlocally.org/keys and save it to
`~/.config/nonlocally/market-key` with the plugin's `save-market-key`.

Update later with `claude plugin marketplace update nonlocally`.

## What's inside

| Plugin | Gives you |
|---|---|
| [`nonlocally`](plugins/nonlocally) | MCP server `market` (market.nonlocally.org, with your own key) and skill `market`: find, solve and post Lean 4 bounty contracts, private contracts for people or groups, admin minting |

## Develop

- Run the tests: `tests/run.sh`. They use a throwaway HOME and a local stand-in market, so they
  never touch a real key or the live market.
- Check the manifests: `claude plugin validate .` and `claude plugin validate plugins/nonlocally`.
- Try a local change without publishing: `claude --plugin-dir plugins/nonlocally`.
- Bump `version` in `plugins/nonlocally/.claude-plugin/plugin.json` when you ship a change.
- New parts of nonlocally go into the same plugin as their own skill (and MCP server if they have
  one), unless they are big enough to want installing separately.

Commits are unsigned and end with:

```
Co-Authored-By: Claude <noreply@anthropic.com>
Co-authored-by: Codex <codex@openai.com>
Co-authored-by: Com8 <322615700+Com8@users.noreply.github.com>
```
