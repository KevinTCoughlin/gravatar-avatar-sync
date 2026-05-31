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

## Quick Start

Complete install-and-validate in one pass:

```bash
# 1. Clone and install
git clone https://github.com/KevinTCoughlin/gravatar-avatar-sync.git
cd gravatar-avatar-sync
./install.sh

# 2. Set your Gravatar username (recommended) or email
mkdir -p ~/.config/gravatar-avatar-sync
printf '%s\n' 'your-gravatar-username' > ~/.config/gravatar-avatar-sync/username

# 3. Run a first sync immediately and verify
systemctl --user start gravatar-avatar-sync.service
systemctl --user status gravatar-avatar-sync.service

# 4. Confirm the avatar was written
ls -lh ~/.face ~/.face.icon
```

After step 4 you should see two image files in your home directory. If the service shows `active (exited)` with no errors, setup is complete.

**One-liner alternative (Fedora/Linux):**

```bash
git clone https://github.com/KevinTCoughlin/gravatar-avatar-sync.git && cd gravatar-avatar-sync && ./install.sh && mkdir -p ~/.config/gravatar-avatar-sync && printf '%s\n' 'your-gravatar-username' > ~/.config/gravatar-avatar-sync/username && systemctl --user start gravatar-avatar-sync.service
```

## Configuration

### Identity sources (in priority order)

| Priority | Source |
|----------|--------|
| 1 | Environment variable `GRAVATAR_USERNAME` |
| 2 | File `~/.config/gravatar-avatar-sync/username` |
| 3 | First CLI argument (treated as email) |
| 4 | Environment variable `GRAVATAR_EMAIL` |
| 5 | File `~/.config/gravatar-avatar-sync/email` |
| 6 | `git config --global user.email` |

Username-based lookup fetches your full Gravatar profile JSON and resolves the canonical photo URL, which is more reliable than the MD5 email hash used by the email path.

**Set username (recommended):**

```bash
printf '%s\n' 'your-gravatar-username' > ~/.config/gravatar-avatar-sync/username
```

**Set email (alternative):**

```bash
printf '%s\n' 'your-email@example.com' > ~/.config/gravatar-avatar-sync/email
```

### Optional environment variables

| Variable | Default | Description |
|----------|---------|-------------|
| `GRAVATAR_DEFAULT` | `mp` | Fallback image style when no avatar exists (see [Gravatar docs](https://docs.gravatar.com/api/avatars/images/)) |
| `GRAVATAR_SIZE` | auto-detected | Force a fixed pixel size (max `2048`) |
| `GRAVATAR_PROVIDER` | `gravatar` | Name of the active provider (see [Adding a new provider](#adding-a-new-provider)) |

### Image size behavior

- By default, the script uses lightweight display heuristics (`xrandr` + GNOME scaling settings when available) to request an appropriately sharp image.
- The auto-detected value is capped to Gravatar's maximum supported size (`2048`).
- Set `GRAVATAR_SIZE` explicitly to force a fixed value (useful in headless/CI environments):

  ```bash
  GRAVATAR_SIZE=512 gravatar-avatar-sync
  ```

## Timer / Service Lifecycle

The installer registers both a one-shot service and a periodic timer.

| Command | Purpose |
|---------|---------|
| `systemctl --user status gravatar-avatar-sync.timer` | Check whether the timer is active |
| `systemctl --user status gravatar-avatar-sync.service` | Check the last sync result |
| `systemctl --user start gravatar-avatar-sync.service` | Run a sync immediately |
| `systemctl --user stop gravatar-avatar-sync.timer` | Pause automatic syncing |
| `systemctl --user start gravatar-avatar-sync.timer` | Resume automatic syncing |
| `systemctl --user restart gravatar-avatar-sync.timer` | Restart the timer (resets the next-run clock) |
| `journalctl --user -u gravatar-avatar-sync.service` | View sync logs |
| `journalctl --user -u gravatar-avatar-sync.service -f` | Follow logs in real time |

### Timer schedule

- **First run:** 2 minutes after boot
- **Repeat:** every 12 hours
- **Missed runs:** caught up on next login (`Persistent=true`)

## Desktop Environment Compatibility

### GNOME

- AccountsService icon is set via D-Bus and is picked up automatically by GDM, the GNOME lock screen, and GNOME user settings.
- Avatar changes appear without logout.
- Requires `gdbus` (ships with GLib, installed on all standard GNOME desktops).
- If you run GNOME inside a Toolbox/distrobox container, the system D-Bus socket may be at `/run/host/run/dbus/system_bus_socket`; the script handles this fallback automatically.

### KDE Plasma

- `~/.face` is read by SDDM (the default KDE login manager) for the login screen avatar.
- KDE's user account settings may also reference `~/.face.icon`.
- AccountsService D-Bus updates are written but may not be reflected in Plasma's user settings panel until you log out and back in.
- Tested on Plasma 5 and Plasma 6 with SDDM.

### Other display/login managers

| Login manager | Avatar source | Notes |
|---------------|--------------|-------|
| GDM (GNOME) | AccountsService D-Bus + `~/.face` | Fully supported |
| SDDM (KDE) | `~/.face` | Supported via file update |
| LightDM | `~/.face` | Supported via file update; AccountsService plugin required for D-Bus path |
| LXDM | `~/.face` | Supported via file update |

If your login manager is not listed, check its documentation for which file it reads for the user avatar; `~/.face` is the most common convention.

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

Run the CI-safe integration side-effect tests with:

```bash
bash tests/integration/run.sh
```

## Uninstall

```bash
./uninstall.sh
```

This disables the timer, removes the service and timer unit files, and deletes the installed binary. Your configuration files in `~/.config/gravatar-avatar-sync/` and cached avatar in `~/.local/share/avatars/` are preserved.

## Troubleshooting

### Error matrix

| Symptom | Likely cause | Fix |
|---------|-------------|-----|
| `curl: (22) … 404 Not Found` | Gravatar username not found or profile is private | Verify the username at `https://gravatar.com/<username>`. Use email-based config as a fallback. |
| `Could not find photo URL in Gravatar profile` | Profile JSON has no photo set | Upload a photo at [gravatar.com](https://gravatar.com) or switch to email-based config. |
| `No identity found` | No username, email, or git email configured | Create `~/.config/gravatar-avatar-sync/username` or `…/email` (see [Configuration](#configuration)). |
| `Unable to reach system D-Bus` | `accountsservice` not running, or D-Bus socket missing | Ensure `accounts-daemon` is running: `systemctl status accounts-daemon`. On containerised desktops (Toolbox/distrobox), the socket is at `/run/host/run/dbus/system_bus_socket`; the script falls back to this path automatically. |
| `Unsupported image type from Gravatar` | Gravatar returned HTML or a non-image (e.g. default page) | The `GRAVATAR_DEFAULT` style may be returning unexpected content. Try `GRAVATAR_DEFAULT=404` to get an explicit error, then confirm your identity config is correct. |
| Avatar updated in `~/.face` but login screen unchanged | Login manager caches the old icon | Log out and back in. For GDM, run `systemctl restart gdm` (as root) if the issue persists. |
| `Permission denied` writing `~/.face` | File is owned by root or has restrictive permissions | Run `chmod 644 ~/.face ~/.face.icon` and `chown $USER ~/.face ~/.face.icon`. |
| `systemctl --user` commands fail | Systemd user instance not running | Ensure `loginctl enable-linger $USER` has been run (required on some minimal installs). |
| `file: command not found` | `file` utility not installed | Install via `sudo dnf install file` (Fedora) or `sudo apt install file` (Debian/Ubuntu). |

### View detailed logs

```bash
journalctl --user -u gravatar-avatar-sync.service --since "1 hour ago"
```

### Run manually for debugging

You can invoke the script directly to see its output in the terminal:

```bash
~/.local/bin/gravatar-avatar-sync
```

Or with verbose curl output to diagnose network issues:

```bash
GRAVATAR_USERNAME=your-gravatar-username bash -x ~/.local/bin/gravatar-avatar-sync
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

## Releases & Versioning

This project follows [Semantic Versioning](https://semver.org/).
See [docs/RELEASING.md](docs/RELEASING.md) for the full release checklist and
[CHANGELOG.md](CHANGELOG.md) for a history of changes.

## Packaging

Packages for Fedora/RHEL (COPR), Arch (AUR), Homebrew, and Debian/Ubuntu are
planned.  See [docs/PACKAGING.md](docs/PACKAGING.md) for the prioritized
roadmap.

## Support

If this project helps you, consider supporting via [GitHub Sponsors](https://github.com/sponsors/KevinTCoughlin) or [Ko-fi](https://ko-fi.com/kevintcoughlin).
