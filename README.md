# gravatar-avatar-sync

[![GitHub Sponsors](https://img.shields.io/github/sponsors/KevinTCoughlin)](https://github.com/sponsors/KevinTCoughlin)
[![Ko-fi](https://img.shields.io/badge/Ko--fi-support-ff5e5b?logo=ko-fi&logoColor=white)](https://ko-fi.com/kevintcoughlin)

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

## Support

If this project helps you, consider supporting via [GitHub Sponsors](https://github.com/sponsors/KevinTCoughlin) or [Ko-fi](https://ko-fi.com/kevintcoughlin).
