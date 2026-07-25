#!/usr/bin/env bash
# update.sh — write avatar files and update AccountsService via D-Bus
#
# Exports:
#   install_file_if_changed <source> <dest>
#     Atomically installs <source> at <dest> (mode 0644) when the contents
#     differ. Returns 0 when <dest> was written, 1 when it was already current.
#
#   write_local_files <source> <final_file>
#     Installs <source> at <final_file>, ~/.face and ~/.face.icon.
#     Returns 0 when <final_file> changed, 1 when it was already current.
#
#   update_accounts_service <final_file>
#     Calls org.freedesktop.Accounts.User.SetIconFile via gdbus.
#     Falls back to the host D-Bus socket (Flatpak/container) when the primary
#     call fails. Returns the status of the call that was actually made.

# Writes to a temporary file in the destination directory and renames it into
# place so readers never observe a partially written avatar.
install_file_if_changed() {
  local source="$1"
  local dest="$2"
  local dest_dir staged

  if [[ -f "$dest" ]] && cmp -s "$source" "$dest"; then
    return 1
  fi

  dest_dir="$(dirname "$dest")"
  mkdir -p "$dest_dir"
  staged="$(mktemp "${dest_dir}/.$(basename "$dest").XXXXXX")"
  if ! install -m 0644 "$source" "$staged"; then
    rm -f "$staged"
    return 2
  fi
  if ! mv -f "$staged" "$dest"; then
    rm -f "$staged"
    return 2
  fi
  return 0
}

write_local_files() {
  local source="$1"
  local final_file="$2"
  local rc changed=1

  rc=0
  install_file_if_changed "$source" "$final_file" || rc=$?
  if (( rc > 1 )); then
    return 2
  fi
  if (( rc == 0 )); then
    changed=0
  fi

  local mirror
  for mirror in "$HOME/.face" "$HOME/.face.icon"; do
    rc=0
    install_file_if_changed "$final_file" "$mirror" || rc=$?
    if (( rc > 1 )); then
      return 2
    fi
  done

  return "$changed"
}

_set_icon_file() {
  local user_path="$1" final_file="$2"
  gdbus call --system \
    --dest org.freedesktop.Accounts \
    --object-path "$user_path" \
    --method org.freedesktop.Accounts.User.SetIconFile "$final_file" >/dev/null
}

update_accounts_service() {
  local final_file="$1"
  local user_path host_dbus_socket
  user_path="/org/freedesktop/Accounts/User$(id -u)"
  host_dbus_socket="${HOST_DBUS_SOCKET:-/run/host/run/dbus/system_bus_socket}"

  if _set_icon_file "$user_path" "$final_file"; then
    return 0
  fi

  if [[ -S "$host_dbus_socket" ]]; then
    if DBUS_SYSTEM_BUS_ADDRESS="unix:path=$host_dbus_socket" \
      _set_icon_file "$user_path" "$final_file"; then
      return 0
    fi
  fi

  echo "Unable to reach system D-Bus to set AccountsService icon." >&2
  return 1
}
