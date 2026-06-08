#!/usr/bin/env bash
# update.sh — write avatar files and update AccountsService via D-Bus
#
# Exports:
#   write_local_files <tmp_file> <final_file>
#     Copies <tmp_file> to <final_file>, ~/.face, and ~/.face.icon.
#
#   update_accounts_service <final_file>
#     Calls org.freedesktop.Accounts.User.SetIconFile via gdbus.
#     Falls back to the Flatpak host D-Bus socket when the primary call fails.
#     Exits non-zero if the icon cannot be set.

write_local_files() {
  local tmp_file="$1"
  local final_file="$2"
  install -m 0644 "$tmp_file" "$final_file"
  install -m 0644 "$final_file" "$HOME/.face"
  install -m 0644 "$final_file" "$HOME/.face.icon"
}

update_accounts_service() {
  local final_file="$1"
  local user_path host_dbus_socket
  user_path="/org/freedesktop/Accounts/User$(id -u)"
  host_dbus_socket="${HOST_DBUS_SOCKET:-/run/host/run/dbus/system_bus_socket}"
  if ! gdbus call --system \
    --dest org.freedesktop.Accounts \
    --object-path "$user_path" \
    --method org.freedesktop.Accounts.User.SetIconFile "$final_file" >/dev/null; then
    if [[ -S "$host_dbus_socket" ]]; then
      DBUS_SYSTEM_BUS_ADDRESS=unix:path="$host_dbus_socket" \
        gdbus call --system \
        --dest org.freedesktop.Accounts \
        --object-path "$user_path" \
        --method org.freedesktop.Accounts.User.SetIconFile "$final_file" >/dev/null
    else
      echo "Unable to reach system D-Bus to set AccountsService icon." >&2
      return 1
    fi
  fi
}
