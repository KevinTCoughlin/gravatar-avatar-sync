---
layout: page
title: Overview
nav_order: 1
permalink: /
---

# gravatar-avatar-sync

[![GitHub Sponsors](https://img.shields.io/github/sponsors/KevinTCoughlin)](https://github.com/sponsors/KevinTCoughlin)
[![Ko-fi](https://img.shields.io/badge/Ko--fi-support-ff5e5b?logo=ko-fi&logoColor=white)](https://ko-fi.com/kevintcoughlin)

Small Linux utility to sync your local account avatar from Gravatar on a schedule.

## What it does

`gravatar-avatar-sync` fetches your avatar from [Gravatar](https://gravatar.com) and keeps your local Linux account picture up to date automatically. It runs as a **systemd user service + timer**, so it works in the background without any manual intervention.

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

## Source

The project is hosted on GitHub at [KevinTCoughlin/gravatar-avatar-sync](https://github.com/KevinTCoughlin/gravatar-avatar-sync).

## Support

If this project helps you, consider supporting via [GitHub Sponsors](https://github.com/sponsors/KevinTCoughlin) or [Ko-fi](https://ko-fi.com/kevintcoughlin).
