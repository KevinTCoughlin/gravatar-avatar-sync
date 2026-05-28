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

### Image size behavior

- By default, the script uses lightweight display heuristics (`xrandr` + GNOME scaling settings when available) to request a sharper size.
- Auto mode is capped to Gravatar's max supported size (`2048`).
- Set `GRAVATAR_SIZE` explicitly to force a fixed value.

## Timer schedule

- First run: 2 minutes after boot
- Repeat: every 12 hours
- Missed runs: caught up on next login (`Persistent=true`)

## Testing

Run the CI-safe integration tests locally with:

```bash
bash tests/integration/run.sh
```

## Uninstall

```bash
./uninstall.sh
```

## Support

If this project helps you, consider supporting via [GitHub Sponsors](https://github.com/sponsors/KevinTCoughlin) or [Ko-fi](https://ko-fi.com/kevintcoughlin).
