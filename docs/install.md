---
layout: page
title: Install
nav_order: 2
permalink: /install/
---

# Install

## One-liner (Fedora/Linux)

```bash
git clone https://github.com/KevinTCoughlin/gravatar-avatar-sync.git && cd gravatar-avatar-sync && ./install.sh && mkdir -p ~/.config/gravatar-avatar-sync && printf '%s\n' 'your-gravatar-username' > ~/.config/gravatar-avatar-sync/username && systemctl --user start gravatar-avatar-sync.service
```

## Step-by-step

**1. Clone the repository:**

```bash
git clone https://github.com/KevinTCoughlin/gravatar-avatar-sync.git
cd gravatar-avatar-sync
```

**2. Run the installer:**

```bash
./install.sh
```

This installs the sync script, systemd service, and timer into your home directory (`~/.local/bin` and `~/.config/systemd/user/`).

**3. Set your Gravatar identity:**

Set either a username (recommended for profile photos) or email:

```bash
mkdir -p ~/.config/gravatar-avatar-sync

# Option A – Gravatar username (recommended):
printf '%s\n' 'your-gravatar-username' > ~/.config/gravatar-avatar-sync/username

# Option B – Email address:
printf '%s\n' 'your-email@example.com' > ~/.config/gravatar-avatar-sync/email
```

**4. Start the service:**

```bash
systemctl --user start gravatar-avatar-sync.service
```

The timer is already enabled by the installer and will run automatically every 12 hours after the first 2-minute delay post-boot.

## Uninstall

```bash
./uninstall.sh
```

This stops and disables the timer and removes installed files. Your config directory (`~/.config/gravatar-avatar-sync/`) is preserved.
