#!/usr/bin/env bash

set -euo pipefail

usage() {
  cat <<'EOF'
Install this repo's skills into ~/.agents/skills using symlinks.

Usage:
  scripts/install_skills.sh

Environment:
  AGENTS_HOME  Override the base agents directory. Default: ~/.agents
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
repo_root="$(cd -- "${script_dir}/.." && pwd -P)"
source_root="${repo_root}/skills"
agents_home="${AGENTS_HOME:-${HOME}/.agents}"
install_root="${agents_home}/skills"

if [[ ! -d "${source_root}" ]]; then
  echo "Skills directory not found: ${source_root}" >&2
  exit 1
fi

mkdir -p "${install_root}"

installed=0
updated=0
unchanged=0
conflicts=0

for skill_dir in "${source_root}"/*; do
  if [[ ! -d "${skill_dir}" ]]; then
    continue
  fi

  skill_name="$(basename -- "${skill_dir}")"
  target_link="${install_root}/${skill_name}"

  if [[ -L "${target_link}" ]]; then
    current_target="$(readlink "${target_link}")"
    if [[ "${current_target}" == "${skill_dir}" ]]; then
      echo "up-to-date ${skill_name}"
      unchanged=$((unchanged + 1))
      continue
    fi

    rm -- "${target_link}"
    ln -s -- "${skill_dir}" "${target_link}"
    echo "updated ${skill_name}"
    updated=$((updated + 1))
    continue
  fi

  if [[ -e "${target_link}" ]]; then
    echo "conflict ${skill_name}: ${target_link} exists and is not a symlink" >&2
    conflicts=$((conflicts + 1))
    continue
  fi

  ln -s -- "${skill_dir}" "${target_link}"
  echo "installed ${skill_name}"
  installed=$((installed + 1))
done

echo
echo "Summary: installed=${installed} updated=${updated} unchanged=${unchanged} conflicts=${conflicts}"

if [[ "${conflicts}" -gt 0 ]]; then
  exit 1
fi
