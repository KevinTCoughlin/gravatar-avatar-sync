---
layout: page
title: Configuration
nav_order: 3
permalink: /configuration/
---

# Configuration

## Identity source priority

The script resolves your Gravatar identity in the following order (first match wins):

| Priority | Source |
|----------|--------|
| 1 | `GRAVATAR_USERNAME` environment variable |
| 2 | `~/.config/gravatar-avatar-sync/username` file |
| 3 | First CLI argument (treated as email) |
| 4 | `GRAVATAR_EMAIL` environment variable |
| 5 | `~/.config/gravatar-avatar-sync/email` file |
| 6 | `git config --global user.email` |

## Environment variables

| Variable | Default | Description |
|----------|---------|-------------|
| `GRAVATAR_USERNAME` | _(unset)_ | Your Gravatar username (takes priority over email) |
| `GRAVATAR_EMAIL` | _(unset)_ | Your email address registered with Gravatar |
| `GRAVATAR_DEFAULT` | `mp` | Default avatar style when no Gravatar is found (e.g. `mp`, `identicon`, `retro`) |
| `GRAVATAR_SIZE` | auto-detected | Pixel size of the downloaded avatar image |

## Image size behavior

By default, the script uses lightweight display heuristics (`xrandr` + GNOME scaling settings when available) to request a sharper image:

| Display resolution | Base size |
|-------------------|-----------|
| ≥ 3840 px (4K) | 1536 |
| ≥ 2560 px (2K) | 1280 |
| ≥ 1920 px (FHD) | 1024 |
| < 1920 px | 768 |

The detected size is scaled by any active GNOME text/display scale factors, capped to Gravatar's maximum of **2048 px**.

Set `GRAVATAR_SIZE` explicitly to bypass auto-detection:

```bash
export GRAVATAR_SIZE=512
```

## Timer schedule

The systemd timer controls when the sync runs:

- **First run:** 2 minutes after boot
- **Repeat:** every 12 hours
- **Missed runs:** caught up on next login (`Persistent=true`)
