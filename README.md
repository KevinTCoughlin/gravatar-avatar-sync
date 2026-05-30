# gravatar-avatar-sync

[![GitHub Sponsors](https://img.shields.io/github/sponsors/KevinTCoughlin)](https://github.com/sponsors/KevinTCoughlin)
[![Ko-fi](https://img.shields.io/badge/Ko--fi-support-ff5e5b?logo=ko-fi&logoColor=white)](https://ko-fi.com/kevintcoughlin)
[![CI](https://github.com/KevinTCoughlin/gravatar-avatar-sync/actions/workflows/ci.yml/badge.svg)](https://github.com/KevinTCoughlin/gravatar-avatar-sync/actions/workflows/ci.yml)
[![Docs](https://img.shields.io/badge/docs-GitHub%20Pages-blue)](https://kevintcoughlin.github.io/gravatar-avatar-sync/)

📖 **Full documentation:** <https://kevintcoughlin.github.io/gravatar-avatar-sync/>

Small Linux utility to sync your local account avatar from Gravatar on a schedule.

It updates:

- `~/.face`
- `~/.face.icon`
- AccountsService icon via D-Bus (used by GNOME lock/login screens and other consumers)

## Requirements

- `bash`
- `curl`
- `gdbus`
- `file`
- `systemd --user`

## Install

One-liner (Fedora/Linux):

```bash
git clone https://github.com/KevinTCoughlin/gravatar-avatar-sync.git && cd gravatar-avatar-sync && ./install.sh && mkdir -p ~/.config/gravatar-avatar-sync && printf '%s\n' 'your-gravatar-username' > ~/.config/gravatar-avatar-sync/username && systemctl --user start gravatar-avatar-sync.service
```

Step-by-step:

```bash
git clone https://github.com/KevinTCoughlin/gravatar-avatar-sync.git
cd gravatar-avatar-sync
./install.sh
```

Then set either username (recommended for profile photos) or email:

```bash
mkdir -p ~/.config/gravatar-avatar-sync
printf '%s\n' 'your-gravatar-username' > ~/.config/gravatar-avatar-sync/username
# or:
printf '%s\n' 'your-email@example.com' > ~/.config/gravatar-avatar-sync/email
systemctl --user start gravatar-avatar-sync.service
```

## Configuration

Identity source priority:

1. Username: `GRAVATAR_USERNAME`
2. Username: `~/.config/gravatar-avatar-sync/username`
3. Email: first CLI argument
4. Email: `GRAVATAR_EMAIL`
5. Email: `~/.config/gravatar-avatar-sync/email`
6. Email: `git config --global user.email`

Optional environment variables:

- `GRAVATAR_DEFAULT` (default: `mp`)
- `GRAVATAR_SIZE` (default: auto-detected, capped at `2048`)
- `GRAVATAR_PROVIDER` (default: `gravatar`) — name of the active provider (see below)

### Image size behavior

- By default, the script uses lightweight display heuristics (`xrandr` + GNOME scaling settings when available) to request a sharper size.
- Auto mode is capped to Gravatar's max supported size (`2048`).
- Set `GRAVATAR_SIZE` explicitly to force a fixed value.

## Timer schedule

- First run: 2 minutes after boot
- Repeat: every 12 hours
- Missed runs: caught up on next login (`Persistent=true`)

## Testing

Unit tests cover identity-source precedence and URL resolution. They use [bats-core](https://github.com/bats-core/bats-core) and mock all network/system calls.

Install bats-core (Fedora/Debian):

```bash
# Fedora
sudo dnf install bats
# Debian / Ubuntu
sudo apt-get install bats
```

Run the test suite:

```bash
bats tests/
```

## Uninstall

```bash
./uninstall.sh
```

## CI

Every push and pull request runs the following checks via [GitHub Actions](.github/workflows/ci.yml):

| Stage | What it does |
|---|---|
| **ShellCheck** | Lints all shell scripts (including `lib/` modules) with [ShellCheck](https://www.shellcheck.net/) |
| **Unit Tests** | Runs `tests/unit.sh` — tests pure functions (avatar-size detection, email normalisation, hash generation, URL construction) |
| **Integration Tests** | Runs `tests/integration.sh` — exercises the full script with mocked network and D-Bus calls (CI-safe, no real internet or display required) |

All three stages must pass before a PR can be merged.

## Architecture

The script is organised into focused library modules installed under
`~/.local/lib/gravatar-avatar-sync/`:

| Module | Responsibility |
|---|---|
| `display.sh` | Auto-detect avatar pixel size from display/DPI settings |
| `identity.sh` | Resolve username/email from environment, config files, or git |
| `fetch.sh` | Download avatar image; validate MIME type |
| `update.sh` | Write `~/.face`, `~/.face.icon`, and `AVATAR_DIR`; call AccountsService |
| `providers/gravatar.sh` | Gravatar-specific URL resolution (username JSON or email hash) |

`bin/gravatar-avatar-sync` is a thin orchestrator that sources these modules
and calls them in order.

## Adding a new provider

A *provider* is a single Bash script placed in
`lib/gravatar-avatar-sync/providers/` that implements one function:

```bash
<provider_name>_resolve_url <username> <email> <size> <default_style>
```

### Contract

| Requirement | Detail |
|---|---|
| Set URL | Assign the resolved image URL to the global **`PROVIDER_URL`** |
| Source label | Set the global `SOURCE_LABEL` to a human-readable identity string |
| Success | Return exit code `0` |
| Failure | Print a human-readable message to **stderr**; return non-zero |

### Example: libravatar provider

```bash
# lib/gravatar-avatar-sync/providers/libravatar.sh

libravatar_resolve_url() {
  local username="$1"
  local email="$2"
  local size="$3"
  local default_style="$4"

  if [[ -z "$email" ]]; then
    echo "libravatar provider requires an email address" >&2
    return 1
  fi

  local hash
  hash="$(printf '%s' "$email" | md5sum | awk '{print $1}')"
  SOURCE_LABEL="$email"
  PROVIDER_URL="https://seccdn.libravatar.org/avatar/${hash}?s=${size}&d=${default_style}"
}
```

Then activate it:

```bash
export GRAVATAR_PROVIDER=libravatar
gravatar-avatar-sync
```

Or add it to the systemd service override:

```ini
[Service]
Environment=GRAVATAR_PROVIDER=libravatar
```

## Support

If this project helps you, consider supporting via [GitHub Sponsors](https://github.com/sponsors/KevinTCoughlin) or [Ko-fi](https://ko-fi.com/kevintcoughlin).
