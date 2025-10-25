#!/usr/bin/env bash
set -euo pipefail

# Based on https://dev.to/xakrume/configure-touch-id-for-sudo-access-in-terminalapp-without-prompting-for-a-password-to-authenticate-4ijd

readonly PAM_FILE="/etc/pam.d/sudo"
readonly TOUCH_ID_LINE="auth       sufficient     pam_tid.so"
readonly BSD_STAT="/usr/bin/stat"
readonly TOUCH_ID_PATTERN='^[[:space:]]*auth[[:space:]]+sufficient[[:space:]]+pam_tid\.so'

abort() {
    printf '[ERROR] %s\n' "$*" >&2
    exit 1
}

command -v awk >/dev/null 2>&1 || abort "awk is required."
command -v sudo >/dev/null 2>&1 || abort "sudo is required."
[[ -x "${BSD_STAT}" ]] || abort "Expected BSD stat at ${BSD_STAT}."
[[ -f "${PAM_FILE}" ]] || abort "Expected PAM file ${PAM_FILE} does not exist."
[[ "$(uname -s)" == "Darwin" ]] || abort "This script only supports macOS."
ls /usr/lib/pam/pam_tid.so* >/dev/null 2>&1 || abort "Touch ID PAM module not found."

if sudo grep -Eq "${TOUCH_ID_PATTERN}" "${PAM_FILE}"; then
    printf '[INFO] Touch ID already enabled for sudo; no changes made.\n'
    exit 0
fi

tmp_original=$(mktemp)
tmp_modified=$(mktemp)
trap 'rm -f "$tmp_original" "$tmp_modified"' EXIT

sudo cat "${PAM_FILE}" > "${tmp_original}"

timestamp=$(date +%Y%m%d-%H%M%S)
backup_path="${PAM_FILE}.bak-${timestamp}"
sudo cp "${PAM_FILE}" "${backup_path}"
printf '[INFO] Backup created at %s\n' "${backup_path}"

awk -v line="${TOUCH_ID_LINE}" 'NR==1 {print; print line; next} {print}' "${tmp_original}" > "${tmp_modified}"

owner=$("${BSD_STAT}" -f '%Su' "${PAM_FILE}")
group=$("${BSD_STAT}" -f '%Sg' "${PAM_FILE}")
mode=$("${BSD_STAT}" -f '%Lp' "${PAM_FILE}")

sudo /usr/bin/install -o "${owner}" -g "${group}" -m "${mode}" "${tmp_modified}" "${PAM_FILE}"
printf '[INFO] Touch ID line added to %s\n' "${PAM_FILE}"
printf "[INFO] Open a new terminal session and run 'sudo ls' to confirm the Touch ID prompt.\n"
