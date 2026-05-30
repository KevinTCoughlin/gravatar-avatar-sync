---
layout: page
title: Troubleshooting
nav_order: 4
permalink: /troubleshooting/
---

# Troubleshooting

## Avatar is not updating

**Check the service status:**

```bash
systemctl --user status gravatar-avatar-sync.service
```

**View recent logs:**

```bash
journalctl --user -u gravatar-avatar-sync.service -n 50
```

**Run manually to see live output:**

```bash
gravatar-avatar-sync
```

---

## No Gravatar identity configured

If the service exits without fetching an avatar, it likely cannot resolve your identity. Verify at least one identity source is set:

```bash
# Check username file
cat ~/.config/gravatar-avatar-sync/username

# Check email file
cat ~/.config/gravatar-avatar-sync/email

# Check global git email
git config --global user.email
```

See [Configuration]({{ site.baseurl }}/configuration/) for all supported identity sources.

---

## Avatar is downloaded but GNOME does not reflect it

The script updates AccountsService via D-Bus. If the GNOME lock screen or user menu still shows the old avatar, try:

```bash
# Restart the service to force a fresh sync
systemctl --user restart gravatar-avatar-sync.service
```

If the problem persists, confirm `gdbus` is installed and the D-Bus session is available:

```bash
gdbus call --session --dest org.freedesktop.Accounts --object-path /org/freedesktop/Accounts --method org.freedesktop.Accounts.FindUserByName "$USER"
```

---

## curl errors / network issues

The script fetches the avatar from `https://www.gravatar.com`. Ensure you have internet access and that `curl` is installed:

```bash
curl --version
curl -I "https://www.gravatar.com"
```

---

## Timer not running

Check that the timer is enabled and active:

```bash
systemctl --user list-timers gravatar-avatar-sync.timer
systemctl --user status gravatar-avatar-sync.timer
```

If the timer is missing, re-run the installer:

```bash
./install.sh
```

---

## Reinstalling after uninstall

If you previously ran `./uninstall.sh` and want to reinstall:

```bash
git clone https://github.com/KevinTCoughlin/gravatar-avatar-sync.git
cd gravatar-avatar-sync
./install.sh
```

Your config files in `~/.config/gravatar-avatar-sync/` are preserved across uninstall/reinstall cycles.
