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

For other login managers (SDDM, LightDM), log out and back in after a sync to pick up the updated `~/.face` file.

---

## Unable to reach system D-Bus

If you see `Unable to reach system D-Bus to set AccountsService icon`, check that `accounts-daemon` is running:

```bash
systemctl status accounts-daemon
```

On containerised desktops (Toolbox/distrobox), the system D-Bus socket may not be at the default path. The script automatically falls back to `/run/host/run/dbus/system_bus_socket`; ensure that path is accessible from inside the container.

---

## curl errors / network issues

The script fetches the avatar from `https://www.gravatar.com`. Ensure you have internet access and that `curl` is installed:

```bash
curl --version
curl -I "https://www.gravatar.com"
```

A `curl: (22) … 404 Not Found` error when using username-based config means the Gravatar profile could not be found or is private. Verify the username is correct at `https://gravatar.com/<username>`, or switch to email-based config.

---

## Unsupported image type

If the script exits with `Unsupported image type from Gravatar`, Gravatar returned an unexpected response (HTML or a redirect page) instead of an image. Set `GRAVATAR_DEFAULT=404` to get an explicit HTTP error that makes the root cause clearer:

```bash
GRAVATAR_DEFAULT=404 gravatar-avatar-sync
```

Then confirm your identity config is correct (see [Configuration]({{ site.baseurl }}/configuration/)).

---

## Permission denied writing ~/.face

If the script cannot write `~/.face` or `~/.face.icon`, the files may be owned by root or have restrictive permissions:

```bash
chmod 644 ~/.face ~/.face.icon
chown "$USER" ~/.face ~/.face.icon
```

---

## `systemctl --user` commands fail

If `systemctl --user` commands return an error like `Failed to connect to bus: No such file or directory`, the systemd user instance may not be running. Enable lingering for your account:

```bash
loginctl enable-linger "$USER"
```

---

## `file: command not found`

The `file` utility is required to detect the MIME type of the downloaded image. Install it:

```bash
# Fedora / RHEL
sudo dnf install file

# Debian / Ubuntu
sudo apt install file
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
