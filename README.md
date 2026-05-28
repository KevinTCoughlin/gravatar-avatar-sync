# gravatar-avatar-sync

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

```bash
git clone https://github.com/KevinTCoughlin/gravatar-avatar-sync.git
cd gravatar-avatar-sync
./install.sh
```

Then set your email:

```bash
mkdir -p ~/.config/gravatar-avatar-sync
printf '%s\n' 'your-email@example.com' > ~/.config/gravatar-avatar-sync/email
systemctl --user start gravatar-avatar-sync.service
```

## Configuration

Email source priority:

1. First CLI argument
2. `GRAVATAR_EMAIL` environment variable
3. `~/.config/gravatar-avatar-sync/email`
4. `git config --global user.email`

Optional environment variables:

- `GRAVATAR_DEFAULT` (default: `mp`)
- `GRAVATAR_SIZE` (default: `512`)

## Timer schedule

- First run: 2 minutes after boot
- Repeat: every 12 hours
- Missed runs: caught up on next login (`Persistent=true`)

## Uninstall

```bash
./uninstall.sh
```
