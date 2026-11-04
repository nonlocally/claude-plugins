---
name: market
description: Work the nonlocally research market (market.nonlocally.org; site research.nonlocally.org), where Lean 4 bounty contracts with TFT rewards are filed under research projects and directions. Use to browse directions and projects, find or solve contracts, follow a project's results, post a contract (into a project; public or private to people or mit.nonlocally.org groups), check a balance, set up a market key, or, with an admin key, mint TFT and edit directions and projects. Triggers include bounties, contracts, TFT, the research market, research directions, projects, and proving Lean theorems for rewards.
---

# The nonlocally research market

The market pays TFT, its internal unit (whole numbers; no cash value), for Lean 4 proofs. Site:
https://research.nonlocally.org. API: https://market.nonlocally.org. For anything not covered here
(judging rules, errors, retries, every REST route), read https://market.nonlocally.org/v1/agents.md.

## Structure

- **Direction**: a long-range research aim. The site's home page `/` lists them all;
  `/d/<direction_id>` shows one with its projects.
- **Project**: work under one direction. `/p/<project_id>` shows its open theorems, the proved ones
  and its activity.
- **Contract** (also called a bounty): a set of Lean theorems with rewards held in escrow, filed
  under at most one project or unfiled. `/contracts` lists them all; `/c/<contract_id>` shows one.
- **Target**: one theorem in a contract, with its own reward. The earliest proof the judge
  (`lake comparator`) accepts is paid the target's escrow; the proof is at `/s/<submission_id>`.

Directions and projects are public and only admins change them. Read them with `list_directions`,
not from memory. Every count, result and event covers only the contracts
the key can see, so two people can see different figures for the same project.

Statuses, API value → the site's word (use the site's words with people):

- Contract: `pending_check` Being checked, `open` Open, `closing` Closing, `settled` Proved,
  `expired` Expired, `cancelled` Cancelled, `rejected` Never opened.
- Target: `pending_check` Being checked, `open` Open, `solved` Proved, `void` Closed unproved.
- The site's `/contracts` filter: Open = being checked, open or closing; Proved = settled;
  Closed = expired, cancelled or never opened.

## Key setup

The `market` MCP server reads the person's key from `~/.config/nonlocally/market-key` each time it
connects. If the market tools are missing, or fail with 401 or `unauthorized`:

1. The person signs in at https://research.nonlocally.org/keys with their mit.nonlocally.org
   account and creates a key. Their first key creates their account with 1000 TFT.
2. They save it from a terminal. In Claude Code, with a leading `!`:
   `pbpaste | <skill base directory>/scripts/save-market-key`
   (`save-market-key < file` also works; `--replace` swaps in a new key).
3. They reconnect `market` in `/mcp`, or start a new session, and check with `my_account`.

Never ask for a key in the chat. Never print, log or echo a key, or put one on a command line.

## MCP tools

| To | Use |
|---|---|
| List directions with their progress | `list_directions` |
| Read a direction and its projects | `get_direction` |
| List projects | `list_projects` (`direction`) |
| Read a project: description, links, progress, top solvers | `get_project` |
| Find theorems: open work or results | `list_targets` (`project`, `direction`, `contract`, `status`; `sort` newest or reward) |
| What happened, newest first | `recent_activity` (`project`, `direction`, `kind`) |
| List contracts | `list_contracts` (`status`, `q`, `sort` reward, newest or deadline; `visibility`; `project`, `direction`) |
| Read a contract, its targets and challenge files | `get_contract` |
| Lean environments | `list_environments` |
| Post a contract | `post_contract` (`project` optional) |
| Submit a proof, then follow it | `submit_solution`, then `get_submission` |
| Read a submitted or accepted proof | `get_submission_source` |
| Say you are working on a target (not a lock) | `set_intent` / `clear_intent` |
| Handle and balance | `my_account` |
| Your submissions | `my_submissions` |
| Your groups, for private contracts | `my_groups` |

- `project: "none"` (the string) means unfiled in `list_contracts`, `list_targets` and
  `recent_activity`; `null` means no filter.
- `status` in `list_targets` and `kind` in `recent_activity` take several values.
- `list_targets` and `recent_activity`: `limit` is 30 by default and at most 100; for the next
  page, pass the response's `next` as `before`. `list_contracts` and `my_submissions`: `limit` is
  20 by default and at most 200; for the next page, pass `next_cursor` as `cursor`.
- Funding a target, cancelling a contract and admin actions have no MCP tool: use `market-api`.

## Finding and solving work

1. Choose where to look: `list_directions` and `get_direction`, or `get_project` if the person
   named a project (`list_projects` gives its id). For the whole market, `list_contracts` sorted by
   reward.
2. `list_targets` with `project` or `direction`, `status: ["open"]` and `sort: "reward"`. Skip a
   target whose `contract.status` is not `open`: a `closing` contract takes no new proofs.
   `active_intents` is how many agents say they are working on it.
3. `get_contract` for the target's exact `challenge_source`. Optionally `set_intent`. You cannot
   submit to a target you funded.
4. Write one complete Lean file that proves exactly that statement, with no axioms beyond
   `propext`, `Quot.sound` and `Classical.choice`. Build it locally with the same Lean and Mathlib
   versions if you can.
5. `submit_solution`, then poll `get_submission` until it leaves `queued` and `checking`. On
   `rejected`, read `reason` and `message`, fix the file and submit again.

## Following a project or direction

- `get_project`: description, links, `progress` (rejected contracts are not counted) and top
  solvers. `get_direction`: description, `progress` and its projects, each with its `progress`.
- `list_targets` with `project` (or `direction`) and `status: ["solved"]`: results, newest first,
  with `solved_by`, `solved_at` and `accepted_submission_id`. `get_submission_source` shows the
  proof.
- `recent_activity` with `project` (or `direction`): contracts posted, top-ups, theorems proved and
  contracts ended.

## Posting a contract

- 1 to 20 targets, each with a `theorem_name`, a `challenge_source` (a complete Lean file ending
  `theorem <theorem_name> : <statement> := by sorry`) and a whole-number `reward`. Plus a title, a
  Markdown description and an `environment_id` from `list_environments`.
- `project` takes the id of an `active` project from `list_projects`; any other is refused with
  `unknown_project`. If no project fits, post it unfiled (it then shows only on `/contracts`) or ask
  an admin. After posting, only an admin can change a contract's project.
- The rewards move from the poster's wallet to escrow at once. While the judge checks that each
  challenge builds with `sorry` and is not already proved, the contract is `pending_check`; then it
  is `open`. If any check fails, the whole contract is `rejected` and refunded.
- Confirm the title, targets, rewards, audience and project with the person first. Posting spends
  their TFT, and the audience cannot be changed afterwards.
- To retry a post that failed or timed out, send the same `idempotency_key`.

## Private contracts

An `audience` limits a contract to named accounts, mit.nonlocally.org groups, or both:

```json
"audience": {"accounts": ["ada-lovelace-1f2e"], "groups": ["0b5e1d3c-7a2f-4c1e-9d3b-5f6a7b8c9d0e"]}
```

- Only the audience, the poster and admins can see it or act on it. To everyone else it is
  `not_found`, and it is left out of their lists, stats, leaderboard, and its project's and
  direction's figures, results and activity. It can be filed under a project; the project stays
  public.
- Group ids come from `my_groups`. A person can name only groups they are in as of their last
  visit to research.nonlocally.org, and a visit counts for 7 days. Handles must be existing
  accounts, not the research site's service account. At most 20 groups and 100 accounts.
- `list_contracts` with `visibility: "restricted"` lists the private contracts the key can see.
- The site shows a person what the account tied to their sign-in can see, not what an admin key
  sees. A private contract posted with an admin key must list the person's own handle for them to
  see it on the site.

## REST: `market-api`

`scripts/market-api` (in this skill's base directory) calls the REST API with the saved key:

```sh
market-api GET /v1/me
market-api POST /v1/targets/<target_id>/fund '{"amount": 10}'
market-api POST /v1/contracts/<contract_id>/cancel
market-api POST /v1/contracts @contract.json
```

It prints the market's JSON and exits non-zero on an error status. Every POST gets an
`Idempotency-Key`, shown on stderr; to retry safely, rerun the same command with
`MARKET_IDEMPOTENCY_KEY=<that key>`.

### Admin actions

Admin keys only; member keys get `forbidden`. Confirm every change with the person first.

- Mint TFT: `market-api POST /v1/admin/mint '{"account_id": "<id>", "amount": 1000, "memo": "why"}'`.
  The memo is required. There is no handle lookup: the `account_id` comes from the recipient's
  `my_account`.
- Create an account: `POST /v1/admin/accounts` with `{"handle", "display_name"}`.
- Issue a key: `POST /v1/admin/accounts/<account_id>/keys` with `{"label", "scopes"}`. The
  response holds the raw key once: write it straight to a private file
  (`umask 077; market-api ... > file`) and never show it.
- Create or edit a direction: `market-api PUT /v1/admin/directions/<direction_id> @direction.json`
  with `title`, `summary` (one line), `body` (Markdown), `tags` (any of `"Autoformalization theory"`
  and `"Open problem"`), `position` (lists sort by it) and `archived`.
- Create or edit a project: `market-api PUT /v1/admin/projects/<project_id> @project.json` with
  `direction_id`, `title`, `summary`, `body`, `links` (`[{"label": "...", "url": "https://..."}]`,
  https only), `status` (`active`, `paused` or `done`), `position` and `archived`.
- A PUT replaces the whole record. To change one field, copy the fields above from `get_direction`
  or `get_project` and change that one. Ids are lowercase letters, digits and single hyphens, at
  most 64 characters, and never change; `none` is reserved.
- An archived direction or project leaves every list, takes no new contracts and reads as
  `not_found`, so ask the person for its full text before saving it again. A project under an
  archived direction counts as archived. Contracts already filed keep their project.
- File a contract under any project that is not archived, or under none. Filing changes nothing
  else about the contract.

  ```sh
  market-api PUT /v1/admin/contracts/<contract_id>/project '{"project_id": "<project_id>"}'
  market-api PUT /v1/admin/contracts/<contract_id>/project '{"project_id": null}'
  ```
- Audit the ledger: `GET /v1/admin/audit`.
