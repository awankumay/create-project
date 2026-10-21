#!/usr/bin/env bash
# Bash launcher: local checkout or curl ... | bash -s -- NAME.
set -euo pipefail
command -v php >/dev/null 2>&1 || { printf '%s\n' 'PHP CLI 8.4+ is required for the Laravel installer.' >&2; exit 1; }
local_root=''
if [[ -n "${BASH_SOURCE[0]:-}" && -f "${BASH_SOURCE[0]}" ]]; then
    local_root="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
fi
if [[ -n "$local_root" && -f "$local_root/installer/install.php" ]]; then
    exec php "$local_root/create-project.php" "$@"
fi
command -v git >/dev/null 2>&1 || { printf '%s\n' 'Git is required.' >&2; exit 1; }
installer_temp="$(mktemp -d)"
trap 'rm -rf "$installer_temp"' EXIT
# Override with a release tag for a fixed installer version.
installer_ref="${CREATE_PROJECT_REF:-main}"
git clone --quiet --depth 1 --branch "$installer_ref" https://github.com/awankumay/create-project.git "$installer_temp/installer"
php "$installer_temp/installer/create-project.php" "$@"
