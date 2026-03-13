#!/usr/bin/env bash

set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
repo_root="$(cd -- "${script_dir}/.." && pwd -P)"
source_root="${repo_root}/skills"
agents_home="${AGENTS_HOME:-${HOME}/.agents}"
default_install_root="${agents_home}/skills"
cwd_root="$(pwd -P)"

non_interactive=0
target_arg=""

declare -a SKILL_NAMES=()
declare -a SKILL_DIRS=()

declare -a UI_BASE_STATES=()
declare -a UI_BASE_CURRENTS=()
declare -a UI_SELECTED=()
declare -a UI_RENAMES=()
declare -a UI_INSTALLED_NAMES=()
declare -a UI_INSTALLED_COUNTS=()

UI_PATH_INPUT="${default_install_root}"
UI_APPLIED_PATH_INPUT="${default_install_root}"
UI_PATH_CURSOR=${#default_install_root}
UI_TARGET_ROOT="${default_install_root}"
UI_TARGET_VALID=1
UI_TARGET_ERROR=""
UI_TARGET_KIND="missing"
UI_CURSOR=0
UI_SCROLL=0
UI_FOCUS="path"
UI_MESSAGE=""
UI_MESSAGE_KIND="info"
UI_SCREEN_ACTIVE=0

usage() {
  cat <<'EOF'
Install this repo's skills into a target directory using symlinks.

Usage:
  scripts/install_skills.sh
  scripts/install_skills.sh --target <dir>
  scripts/install_skills.sh --non-interactive [--target <dir>]
  scripts/install_skills.sh --help

Interactive mode:
  - launches a full-screen TUI
  - target path defaults to ~/.agents/skills or $AGENTS_HOME/skills
  - selected rows mirror the skills already linked from this repo in the target dir

Interactive controls:
  Tab           Switch focus between path, list, and rename field
  Up / Down     Move through skills when the list is focused
  Space         Toggle the current skill
  Left / Right  Jump between path and row rename when available
  Home / End    Move the path cursor when the target field is focused
  r             Focus the rename field when the current row has a conflict
  Backspace     Delete one character from the active text field
  Delete        Delete the character under the path cursor
  Ctrl+U        Clear the active text field
  Enter         Refresh path when editing it, or apply the selected install plan
  Ctrl+D        Quit without changing anything

Status meanings:
  installed               The skill is already linked from this repo
  not installed           No entry exists at the default target name
  broken symlink          The default target name is a dangling symlink
  taken by other symlink  The default target name points somewhere else
  taken by real dir/file  The default target name exists as a non-symlink entry

Environment:
  AGENTS_HOME  Override the base agents directory. Default: ~/.agents
EOF
}

set_message() {
  UI_MESSAGE_KIND="$1"
  UI_MESSAGE="$2"
}

ensure_source_root() {
  if [[ ! -d "${source_root}" ]]; then
    echo "Skills directory not found: ${source_root}" >&2
    exit 1
  fi
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -h|--help)
        usage
        exit 0
        ;;
      --non-interactive)
        non_interactive=1
        shift
        ;;
      --target)
        if [[ $# -lt 2 ]]; then
          echo "Missing argument for --target" >&2
          exit 1
        fi
        target_arg="$2"
        shift 2
        ;;
      --target=*)
        target_arg="${1#*=}"
        shift
        ;;
      *)
        echo "Unknown argument: $1" >&2
        usage >&2
        exit 1
        ;;
    esac
  done
}

load_skills() {
  local skill_dir

  SKILL_NAMES=()
  SKILL_DIRS=()

  shopt -s nullglob
  for skill_dir in "${source_root}"/*; do
    if [[ ! -d "${skill_dir}" ]]; then
      continue
    fi

    SKILL_NAMES+=("$(basename -- "${skill_dir}")")
    SKILL_DIRS+=("${skill_dir}")
  done
  shopt -u nullglob
}

expand_user_path() {
  local raw_path="$1"

  case "${raw_path}" in
    "~")
      printf '%s\n' "${HOME}"
      ;;
    "~/"*)
      printf '%s/%s\n' "${HOME}" "${raw_path#~/}"
      ;;
    *)
      printf '%s\n' "${raw_path}"
      ;;
  esac
}

canonicalize_existing_path() {
  local path="$1"
  local dir_path
  local base_name

  if [[ -d "${path}" ]]; then
    (
      cd -- "${path}" &&
      pwd -P
    )
    return
  fi

  dir_path="$(dirname -- "${path}")"
  base_name="$(basename -- "${path}")"
  dir_path="$(
    cd -- "${dir_path}" &&
    pwd -P
  )"
  printf '%s/%s\n' "${dir_path}" "${base_name}"
}

normalize_target_root() {
  local raw_path="$1"
  local expanded_path
  local absolute_path

  expanded_path="$(expand_user_path "${raw_path}")"

  if [[ "${expanded_path}" = /* ]]; then
    absolute_path="${expanded_path}"
  else
    absolute_path="${cwd_root}/${expanded_path}"
  fi

  if [[ -e "${absolute_path}" ]]; then
    canonicalize_existing_path "${absolute_path}"
  else
    printf '%s\n' "${absolute_path}"
  fi
}

resolve_link_target() {
  local link_path="$1"
  local raw_target
  local link_dir
  local absolute_target

  raw_target="$(readlink -- "${link_path}")"
  link_dir="$(
    cd -- "$(dirname -- "${link_path}")" &&
    pwd -P
  )"

  if [[ "${raw_target}" = /* ]]; then
    absolute_target="${raw_target}"
  else
    absolute_target="${link_dir}/${raw_target}"
  fi

  if [[ -e "${absolute_target}" ]]; then
    canonicalize_existing_path "${absolute_target}"
  else
    printf '%s\n' "${absolute_target}"
  fi
}

inspect_named_entry() {
  local install_root="$1"
  local entry_name="$2"
  local source_dir="$3"
  local entry_path="${install_root}/${entry_name}"
  local resolved_target

  if [[ -L "${entry_path}" ]]; then
    resolved_target="$(resolve_link_target "${entry_path}")"

    if [[ ! -e "${entry_path}" ]]; then
      printf 'broken_symlink|%s\n' "${resolved_target}"
      return
    fi

    if [[ "${resolved_target}" == "${source_dir}" ]]; then
      printf 'installed|%s\n' "${resolved_target}"
      return
    fi

    printf 'other_symlink|%s\n' "${resolved_target}"
    return
  fi

  if [[ -e "${entry_path}" ]]; then
    printf 'real_entry|%s\n' "${entry_path}"
    return
  fi

  printf 'missing|\n'
}

_DETECTED_LINK_COUNT=0
_DETECTED_LINK_NAMES=""

detect_installed_entries() {
  local install_root="$1"
  local source_dir="$2"
  local entry_path
  local entry_name
  local resolved_target
  local names=""
  local count=0

  _DETECTED_LINK_COUNT=0
  _DETECTED_LINK_NAMES=""

  if [[ ! -d "${install_root}" ]]; then
    return
  fi

  shopt -s nullglob
  for entry_path in "${install_root}"/*; do
    if [[ ! -L "${entry_path}" || ! -e "${entry_path}" ]]; then
      continue
    fi

    resolved_target="$(resolve_link_target "${entry_path}")"
    if [[ "${resolved_target}" != "${source_dir}" ]]; then
      continue
    fi

    entry_name="$(basename -- "${entry_path}")"
    if [[ -n "${names}" ]]; then
      names="${names}"$'\n'
    fi
    names="${names}${entry_name}"
    count=$((count + 1))
  done
  shopt -u nullglob

  _DETECTED_LINK_COUNT="${count}"
  _DETECTED_LINK_NAMES="${names}"
}

name_list_contains() {
  local list_text="$1"
  local target_name="$2"
  local entry_name

  while IFS= read -r entry_name; do
    if [[ "${entry_name}" == "${target_name}" ]]; then
      return 0
    fi
  done <<< "${list_text}"

  return 1
}

format_name_list() {
  local list_text="$1"

  printf '%s' "${list_text//$'\n'/, }"
}

skill_index_by_name() {
  local target_name="$1"
  local index

  for ((index = 0; index < ${#SKILL_NAMES[@]}; index += 1)); do
    if [[ "${SKILL_NAMES[$index]}" == "${target_name}" ]]; then
      printf '%s\n' "${index}"
      return 0
    fi
  done

  return 1
}

refresh_ui_state() {
  local raw_target="$1"
  local skill_index
  local inspected
  local base_state
  local base_current

  UI_PATH_INPUT="${raw_target}"
  UI_APPLIED_PATH_INPUT="${raw_target}"
  UI_PATH_CURSOR=${#UI_PATH_INPUT}
  UI_TARGET_ROOT="$(normalize_target_root "${raw_target}")"
  UI_TARGET_VALID=1
  UI_TARGET_ERROR=""
  UI_TARGET_KIND="missing"

  if [[ -e "${UI_TARGET_ROOT}" && ! -d "${UI_TARGET_ROOT}" ]]; then
    UI_TARGET_VALID=0
    UI_TARGET_KIND="invalid"
    UI_TARGET_ERROR="Target path exists and is not a directory."
  elif [[ -d "${UI_TARGET_ROOT}" ]]; then
    UI_TARGET_KIND="existing"
  fi

  UI_BASE_STATES=()
  UI_BASE_CURRENTS=()
  UI_SELECTED=()
  UI_RENAMES=()
  UI_INSTALLED_NAMES=()
  UI_INSTALLED_COUNTS=()

  for ((skill_index = 0; skill_index < ${#SKILL_NAMES[@]}; skill_index += 1)); do
    if [[ "${UI_TARGET_VALID}" -eq 1 ]]; then
      inspected="$(inspect_named_entry "${UI_TARGET_ROOT}" "${SKILL_NAMES[$skill_index]}" "${SKILL_DIRS[$skill_index]}")"
      base_state="${inspected%%|*}"
      base_current="${inspected#*|}"
      detect_installed_entries "${UI_TARGET_ROOT}" "${SKILL_DIRS[$skill_index]}"
    else
      base_state="invalid_target"
      base_current="${UI_TARGET_ROOT}"
      _DETECTED_LINK_COUNT=0
      _DETECTED_LINK_NAMES=""
    fi

    UI_BASE_STATES+=("${base_state}")
    UI_BASE_CURRENTS+=("${base_current}")
    if [[ "${_DETECTED_LINK_COUNT}" -gt 0 ]]; then
      UI_SELECTED+=(1)
    else
      UI_SELECTED+=(0)
    fi
    UI_RENAMES+=("")
    UI_INSTALLED_NAMES+=("${_DETECTED_LINK_NAMES}")
    UI_INSTALLED_COUNTS+=("${_DETECTED_LINK_COUNT}")
  done

  if (( UI_CURSOR >= ${#SKILL_NAMES[@]} )); then
    UI_CURSOR=$(( ${#SKILL_NAMES[@]} - 1 ))
  fi
  if (( UI_CURSOR < 0 )); then
    UI_CURSOR=0
  fi
}

path_input_is_dirty() {
  [[ "${UI_PATH_INPUT}" != "${UI_APPLIED_PATH_INPUT}" ]]
}

clamp_path_cursor() {
  local path_length="${#UI_PATH_INPUT}"

  if (( UI_PATH_CURSOR < 0 )); then
    UI_PATH_CURSOR=0
  fi

  if (( UI_PATH_CURSOR > path_length )); then
    UI_PATH_CURSOR="${path_length}"
  fi
}

move_path_cursor_left() {
  if (( UI_PATH_CURSOR > 0 )); then
    UI_PATH_CURSOR=$((UI_PATH_CURSOR - 1))
  fi
}

move_path_cursor_right() {
  if (( UI_PATH_CURSOR < ${#UI_PATH_INPUT} )); then
    UI_PATH_CURSOR=$((UI_PATH_CURSOR + 1))
  fi
}

move_path_cursor_home() {
  UI_PATH_CURSOR=0
}

move_path_cursor_end() {
  UI_PATH_CURSOR=${#UI_PATH_INPUT}
}

insert_path_character() {
  local char_text="$1"

  UI_PATH_INPUT="${UI_PATH_INPUT:0:UI_PATH_CURSOR}${char_text}${UI_PATH_INPUT:UI_PATH_CURSOR}"
  UI_PATH_CURSOR=$((UI_PATH_CURSOR + ${#char_text}))
  set_message info "Path edited. Press Enter to refresh skills for the new target."
}

backspace_path_character() {
  if (( UI_PATH_CURSOR <= 0 )); then
    return
  fi

  UI_PATH_INPUT="${UI_PATH_INPUT:0:UI_PATH_CURSOR-1}${UI_PATH_INPUT:UI_PATH_CURSOR}"
  UI_PATH_CURSOR=$((UI_PATH_CURSOR - 1))
  set_message info "Path edited. Press Enter to refresh skills for the new target."
}

delete_path_character() {
  if (( UI_PATH_CURSOR >= ${#UI_PATH_INPUT} )); then
    return
  fi

  UI_PATH_INPUT="${UI_PATH_INPUT:0:UI_PATH_CURSOR}${UI_PATH_INPUT:UI_PATH_CURSOR+1}"
  set_message info "Path edited. Press Enter to refresh skills for the new target."
}

clear_path_input() {
  UI_PATH_INPUT=""
  UI_PATH_CURSOR=0
  set_message info "Path edited. Press Enter to refresh skills for the new target."
}

path_input_with_cursor() {
  printf '%s|%s\n' "${UI_PATH_INPUT:0:UI_PATH_CURSOR}" "${UI_PATH_INPUT:UI_PATH_CURSOR}"
}

row_allows_rename() {
  local skill_index="$1"

  if [[ "${UI_INSTALLED_COUNTS[$skill_index]}" -gt 0 ]]; then
    return 1
  fi

  case "${UI_BASE_STATES[$skill_index]}" in
    broken_symlink|other_symlink|real_entry)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

get_row_target_name() {
  local skill_index="$1"

  if [[ -n "${UI_RENAMES[$skill_index]}" ]]; then
    printf '%s\n' "${UI_RENAMES[$skill_index]}"
    return
  fi

  printf '%s\n' "${SKILL_NAMES[$skill_index]}"
}

state_label() {
  case "$1" in
    installed)
      printf 'installed\n'
      ;;
    missing)
      printf 'not installed\n'
      ;;
    broken_symlink)
      printf 'broken symlink\n'
      ;;
    other_symlink)
      printf 'taken by other symlink\n'
      ;;
    real_entry)
      printf 'taken by real dir/file\n'
      ;;
    invalid_target)
      printf 'target path invalid\n'
      ;;
    *)
      printf '%s\n' "$1"
      ;;
  esac
}

display_status_for_row() {
  local skill_index="$1"
  local installed_count="${UI_INSTALLED_COUNTS[$skill_index]}"
  local installed_names="${UI_INSTALLED_NAMES[$skill_index]}"
  local default_name="${SKILL_NAMES[$skill_index]}"
  local display_names

  if [[ "${installed_count}" -gt 0 ]]; then
    if [[ "${installed_count}" -eq 1 && "${installed_names}" == "${default_name}" ]]; then
      printf 'installed\n'
      return
    fi

    display_names="$(format_name_list "${installed_names}")"
    if [[ "${installed_count}" -eq 1 ]]; then
      printf 'installed as %s\n' "${display_names}"
      return
    fi

    printf 'installed via %s\n' "${display_names}"
    return
  fi

  state_label "${UI_BASE_STATES[$skill_index]}"
}

describe_effective_action() {
  local skill_index="$1"
  local target_name
  local inspected
  local effective_state
  local installed_names

  if [[ "${UI_SELECTED[$skill_index]}" -ne 1 ]]; then
    if [[ "${UI_INSTALLED_COUNTS[$skill_index]}" -gt 0 ]]; then
      installed_names="$(format_name_list "${UI_INSTALLED_NAMES[$skill_index]}")"
      printf 'will remove %s\n' "${installed_names}"
      return
    fi

    printf 'not selected\n'
    return
  fi

  if [[ "${UI_TARGET_VALID}" -ne 1 ]]; then
    printf 'blocked: target path is not a directory\n'
    return
  fi

  if [[ "${UI_INSTALLED_COUNTS[$skill_index]}" -gt 0 && -z "${UI_RENAMES[$skill_index]}" ]]; then
    printf 'no change; already installed\n'
    return
  fi

  target_name="$(get_row_target_name "${skill_index}")"
  inspected="$(inspect_named_entry "${UI_TARGET_ROOT}" "${target_name}" "${SKILL_DIRS[$skill_index]}")"
  effective_state="${inspected%%|*}"

  case "${effective_state}" in
    installed)
      printf 'no change; %s already points here\n' "${target_name}"
      ;;
    missing)
      printf 'will install at %s\n' "${target_name}"
      ;;
    broken_symlink|other_symlink)
      printf 'will replace symlink at %s\n' "${target_name}"
      ;;
    real_entry)
      printf 'blocked: %s is a real dir/file\n' "${target_name}"
      ;;
    *)
      printf 'unknown action\n'
      ;;
  esac
}

validate_target_name() {
  local target_name="$1"

  if [[ -z "${target_name}" ]]; then
    return 1
  fi

  case "${target_name}" in
    "."|".."|*/*)
      return 1
      ;;
    *)
      return 0
      ;;
  esac
}

validate_selected_plan() {
  local seen_names=""
  local skill_index
  local target_name
  local inspected
  local state_name
  local display_name
  local seen_entry
  local installed_name

  if [[ "${UI_TARGET_VALID}" -ne 1 ]]; then
    set_message error "${UI_TARGET_ERROR}"
    return 1
  fi

  for ((skill_index = 0; skill_index < ${#SKILL_NAMES[@]}; skill_index += 1)); do
    if [[ "${UI_SELECTED[$skill_index]}" -eq 1 && "${UI_INSTALLED_COUNTS[$skill_index]}" -gt 0 && -z "${UI_RENAMES[$skill_index]}" ]]; then
      while IFS= read -r installed_name; do
        if [[ -z "${installed_name}" ]]; then
          continue
        fi

        while IFS= read -r seen_entry; do
          if [[ -z "${seen_entry}" ]]; then
            continue
          fi
          if [[ "${seen_entry}" == "${installed_name}" ]]; then
            set_message error "Multiple selections want the same target name: ${installed_name}"
            return 1
          fi
        done <<< "${seen_names}"

        if [[ -n "${seen_names}" ]]; then
          seen_names="${seen_names}"$'\n'
        fi
        seen_names="${seen_names}${installed_name}"
      done <<< "${UI_INSTALLED_NAMES[$skill_index]}"
      continue
    fi

    if [[ "${UI_SELECTED[$skill_index]}" -ne 1 ]]; then
      continue
    fi

    target_name="$(get_row_target_name "${skill_index}")"
    if ! validate_target_name "${target_name}"; then
      set_message error "Invalid target name for ${SKILL_NAMES[$skill_index]}: ${target_name}"
      return 1
    fi

    while IFS= read -r seen_entry; do
      if [[ -z "${seen_entry}" ]]; then
        continue
      fi
      if [[ "${seen_entry}" == "${target_name}" ]]; then
        set_message error "Multiple selections want the same target name: ${target_name}"
        return 1
      fi
    done <<< "${seen_names}"

    if [[ -n "${seen_names}" ]]; then
      seen_names="${seen_names}"$'\n'
    fi
    seen_names="${seen_names}${target_name}"

    inspected="$(inspect_named_entry "${UI_TARGET_ROOT}" "${target_name}" "${SKILL_DIRS[$skill_index]}")"
    state_name="${inspected%%|*}"
    if [[ "${state_name}" == "real_entry" ]]; then
      display_name="${target_name}"
      set_message error "${SKILL_NAMES[$skill_index]} is blocked because ${display_name} is a real dir/file. Rename it first."
      return 1
    fi
  done

  set_message info "Applying the selected install plan."
  return 0
}

print_summary() {
  local installed="$1"
  local updated="$2"
  local unchanged="$3"
  local removed="$4"
  local conflicts="$5"

  echo
  echo "Summary: installed=${installed} updated=${updated} unchanged=${unchanged} removed=${removed} conflicts=${conflicts}"
}

remove_installed_entries() {
  local install_root="$1"
  local installed_names="$2"
  local removed_count=0
  local installed_name

  while IFS= read -r installed_name; do
    if [[ -z "${installed_name}" ]]; then
      continue
    fi

    rm -- "${install_root}/${installed_name}"
    removed_count=$((removed_count + 1))
  done <<< "${installed_names}"

  printf '%s\n' "${removed_count}"
}

run_non_interactive_install() {
  local install_root="$1"
  local installed=0
  local updated=0
  local unchanged=0
  local removed=0
  local conflicts=0
  local skill_index
  local target_name
  local inspected
  local state_name

  if [[ -e "${install_root}" && ! -d "${install_root}" ]]; then
    echo "Target path exists and is not a directory: ${install_root}" >&2
    exit 1
  fi

  mkdir -p "${install_root}"

  for ((skill_index = 0; skill_index < ${#SKILL_NAMES[@]}; skill_index += 1)); do
    target_name="${SKILL_NAMES[$skill_index]}"
    inspected="$(inspect_named_entry "${install_root}" "${target_name}" "${SKILL_DIRS[$skill_index]}")"
    state_name="${inspected%%|*}"

    case "${state_name}" in
      installed)
        echo "up-to-date ${target_name}"
        unchanged=$((unchanged + 1))
        ;;
      missing)
        ln -s -- "${SKILL_DIRS[$skill_index]}" "${install_root}/${target_name}"
        echo "installed ${target_name}"
        installed=$((installed + 1))
        ;;
      broken_symlink|other_symlink)
        rm -- "${install_root}/${target_name}"
        ln -s -- "${SKILL_DIRS[$skill_index]}" "${install_root}/${target_name}"
        echo "updated ${target_name}"
        updated=$((updated + 1))
        ;;
      real_entry)
        echo "conflict ${target_name}: ${install_root}/${target_name} exists and is not a symlink" >&2
        conflicts=$((conflicts + 1))
        ;;
    esac
  done

  print_summary "${installed}" "${updated}" "${unchanged}" "${removed}" "${conflicts}"

  if [[ "${conflicts}" -gt 0 ]]; then
    exit 1
  fi
}

apply_interactive_install() {
  local install_root="$1"
  local installed=0
  local updated=0
  local unchanged=0
  local removed=0
  local conflicts=0
  local skill_index
  local target_name
  local inspected
  local state_name
  local display_name
  local removed_now

  mkdir -p "${install_root}"

  for ((skill_index = 0; skill_index < ${#SKILL_NAMES[@]}; skill_index += 1)); do
    if [[ "${UI_SELECTED[$skill_index]}" -ne 1 ]]; then
      if [[ "${UI_INSTALLED_COUNTS[$skill_index]}" -gt 0 ]]; then
        removed_now="$(remove_installed_entries "${install_root}" "${UI_INSTALLED_NAMES[$skill_index]}")"
        removed=$((removed + removed_now))
        display_name="$(format_name_list "${UI_INSTALLED_NAMES[$skill_index]}")"
        echo "removed ${SKILL_NAMES[$skill_index]} (${display_name})"
      fi
      continue
    fi

    if [[ "${UI_INSTALLED_COUNTS[$skill_index]}" -gt 0 && -z "${UI_RENAMES[$skill_index]}" ]]; then
      echo "up-to-date ${SKILL_NAMES[$skill_index]}"
      unchanged=$((unchanged + 1))
      continue
    fi

    target_name="$(get_row_target_name "${skill_index}")"
    inspected="$(inspect_named_entry "${install_root}" "${target_name}" "${SKILL_DIRS[$skill_index]}")"
    state_name="${inspected%%|*}"

    case "${state_name}" in
      installed)
        echo "up-to-date ${SKILL_NAMES[$skill_index]}"
        unchanged=$((unchanged + 1))
        ;;
      missing)
        ln -s -- "${SKILL_DIRS[$skill_index]}" "${install_root}/${target_name}"
        display_name="${SKILL_NAMES[$skill_index]}"
        if [[ "${target_name}" != "${display_name}" ]]; then
          display_name="${display_name} -> ${target_name}"
        fi
        echo "installed ${display_name}"
        installed=$((installed + 1))
        ;;
      broken_symlink|other_symlink)
        rm -- "${install_root}/${target_name}"
        ln -s -- "${SKILL_DIRS[$skill_index]}" "${install_root}/${target_name}"
        display_name="${SKILL_NAMES[$skill_index]}"
        if [[ "${target_name}" != "${display_name}" ]]; then
          display_name="${display_name} -> ${target_name}"
        fi
        echo "updated ${display_name}"
        updated=$((updated + 1))
        ;;
      real_entry)
        echo "conflict ${SKILL_NAMES[$skill_index]}: ${install_root}/${target_name} exists and is not a symlink" >&2
        conflicts=$((conflicts + 1))
        ;;
    esac
  done

  print_summary "${installed}" "${updated}" "${unchanged}" "${removed}" "${conflicts}"

  if [[ "${conflicts}" -gt 0 ]]; then
    return 1
  fi

  return 0
}

clip_text() {
  local width="$1"
  local text="$2"

  if (( width <= 0 )); then
    printf '\n'
    return
  fi

  if (( ${#text} <= width )); then
    printf '%s\n' "${text}"
    return
  fi

  if (( width <= 3 )); then
    printf '%s\n' "${text:0:width}"
    return
  fi

  printf '%s...\n' "${text:0:width-3}"
}

terminal_size() {
  local size_text

  size_text="$(stty size 2>/dev/null || printf '24 80')"
  printf '%s\n' "${size_text}"
}

sync_scroll_window() {
  local term_rows
  local term_cols
  local list_rows

  read -r term_rows term_cols <<< "$(terminal_size)"
  list_rows=$((term_rows - 14))
  if (( list_rows < 3 )); then
    list_rows=3
  fi

  if (( UI_CURSOR < UI_SCROLL )); then
    UI_SCROLL="${UI_CURSOR}"
  fi

  if (( UI_CURSOR >= UI_SCROLL + list_rows )); then
    UI_SCROLL=$((UI_CURSOR - list_rows + 1))
  fi

  if (( UI_SCROLL < 0 )); then
    UI_SCROLL=0
  fi
}

focus_next_field() {
  if [[ "${UI_FOCUS}" == "path" ]]; then
    UI_FOCUS="list"
    return
  fi

  if [[ "${UI_FOCUS}" == "list" ]]; then
    if row_allows_rename "${UI_CURSOR}" || [[ -n "${UI_RENAMES[$UI_CURSOR]}" ]]; then
      UI_FOCUS="rename"
    else
      UI_FOCUS="path"
    fi
    return
  fi

  UI_FOCUS="path"
}

ensure_focus_valid() {
  if [[ "${UI_FOCUS}" == "rename" ]] && ! row_allows_rename "${UI_CURSOR}" && [[ -z "${UI_RENAMES[$UI_CURSOR]}" ]]; then
    UI_FOCUS="list"
  fi
}

controls_line() {
  local control_text

  case "${UI_FOCUS}" in
    path)
      if path_input_is_dirty; then
        control_text="Controls (Target): Type path | Left/Right/Home/End move | Backspace/Delete edit | Enter refresh | Tab disabled until refresh | Ctrl+D quit"
      else
        control_text="Controls (Target): Type path | Left/Right/Home/End move | Backspace/Delete edit | Enter refresh | Tab skills | Ctrl+D quit"
      fi
      ;;
    list)
      control_text="Controls (Skills): Up/Down move | Space toggle | Left path | Enter apply | Tab next"
      if row_allows_rename "${UI_CURSOR}" || [[ -n "${UI_RENAMES[$UI_CURSOR]}" ]]; then
        control_text="${control_text} | Right rename | r rename"
      fi
      control_text="${control_text} | Ctrl+D quit"
      ;;
    rename)
      control_text="Controls (Rename): Type name | Backspace edit | Ctrl+U clear | Left/Right/Tab switch | Up/Down move row | Enter apply | Ctrl+D quit"
      ;;
  esac

  printf '%s\n' "${control_text}"
}

render_ui() {
  local term_rows
  local term_cols
  local list_rows
  local list_end
  local skill_index
  local row_marker
  local checked_marker
  local focus_marker
  local row_label
  local row_label_with_checkbox
  local row_status
  local rename_prompt=""
  local installed_names=""
  local details_state
  local current_target
  local path_state
  local path_hint
  local label_width=0
  local max_label_width
  local min_status_width=16
  local show_details=1
  local show_message=1

  read -r term_rows term_cols <<< "$(terminal_size)"
  list_rows=$((term_rows - 14))
  if (( list_rows < 3 )); then
    list_rows=3
  fi

  sync_scroll_window
  list_end=$((UI_SCROLL + list_rows))
  if (( list_end > ${#SKILL_NAMES[@]} )); then
    list_end=${#SKILL_NAMES[@]}
  fi

  case "${UI_TARGET_KIND}" in
    existing)
      path_state="existing directory"
      ;;
    missing)
      path_state="directory will be created on install"
      ;;
    invalid)
      path_state="invalid target path"
      ;;
  esac

  if path_input_is_dirty; then
    path_hint="pending refresh; press Enter to reload skills for this path"
  else
    path_hint="active target"
  fi

  if [[ "${UI_FOCUS}" == "path" ]]; then
    show_details=0
  fi

  if [[ "${UI_FOCUS}" == "list" && "${UI_MESSAGE_KIND}" == "info" ]]; then
    show_message=0
  fi

  printf '\033[H\033[2J'
  clip_text "${term_cols}" "Interactive Skills Installer"
  clip_text "${term_cols}" "$(controls_line)"
  printf '\n'

  clip_text "${term_cols}" "Target:"
  if [[ "${UI_FOCUS}" == "path" ]]; then
    focus_marker=">"
  else
    focus_marker=" "
  fi
  if [[ "${UI_FOCUS}" == "path" ]]; then
    clip_text "${term_cols}" "${focus_marker} Target path: $(path_input_with_cursor)"
  else
    clip_text "${term_cols}" "${focus_marker} Target path: ${UI_PATH_INPUT}"
  fi
  clip_text "${term_cols}" "  Resolved: ${UI_TARGET_ROOT}"
  clip_text "${term_cols}" "  Path state: ${path_state} (${path_hint})"
  printf '\n'
  clip_text "${term_cols}" "Skills:"

  max_label_width=$((term_cols - min_status_width - 4))
  if (( max_label_width < 12 )); then
    max_label_width=12
  fi

  for ((skill_index = 0; skill_index < ${#SKILL_NAMES[@]}; skill_index += 1)); do
    row_label="${SKILL_NAMES[$skill_index]}"
    if [[ -n "${UI_RENAMES[$skill_index]}" ]]; then
      row_label="${row_label} => ${UI_RENAMES[$skill_index]}"
    fi

    row_label_with_checkbox="[ ] ${row_label}"
    if (( ${#row_label_with_checkbox} > label_width )); then
      label_width="${#row_label_with_checkbox}"
    fi
  done

  if (( label_width > max_label_width )); then
    label_width="${max_label_width}"
  fi

  for ((skill_index = UI_SCROLL; skill_index < list_end; skill_index += 1)); do
    if (( skill_index == UI_CURSOR )) && [[ "${UI_FOCUS}" == "list" ]]; then
      row_marker=">"
    else
      row_marker=" "
    fi

    if [[ "${UI_SELECTED[$skill_index]}" -eq 1 ]]; then
      checked_marker="[x]"
    else
      checked_marker="[ ]"
    fi

    row_label="${SKILL_NAMES[$skill_index]}"
    if [[ -n "${UI_RENAMES[$skill_index]}" ]]; then
      row_label="${row_label} => ${UI_RENAMES[$skill_index]}"
    fi
    row_label_with_checkbox="${checked_marker} ${row_label}"

    row_status="$(display_status_for_row "${skill_index}")"
    printf '%s ' "${row_marker}"
    clip_text $((term_cols - 2)) "$(printf '%-*s %s' "${label_width}" "${row_label_with_checkbox}" "${row_status}")"
  done

  if (( list_end < ${#SKILL_NAMES[@]} )); then
    clip_text "${term_cols}" "  ..."
  fi

  if [[ "${show_details}" -eq 1 ]]; then
    printf '\n'
    clip_text "${term_cols}" "Details:"
    row_status="$(display_status_for_row "${UI_CURSOR}")"
    clip_text "${term_cols}" "  Skill: ${SKILL_NAMES[$UI_CURSOR]}"
    clip_text "${term_cols}" "  Status: ${row_status}"

    if [[ "${UI_INSTALLED_COUNTS[$UI_CURSOR]}" -gt 0 ]]; then
      installed_names="$(format_name_list "${UI_INSTALLED_NAMES[$UI_CURSOR]}")"
      clip_text "${term_cols}" "  Installed names: ${installed_names}"
    else
      current_target="${UI_BASE_CURRENTS[$UI_CURSOR]}"
      details_state="${UI_BASE_STATES[$UI_CURSOR]}"
      if [[ "${details_state}" == "other_symlink" || "${details_state}" == "broken_symlink" ]]; then
        clip_text "${term_cols}" "  Current link target: ${current_target}"
      elif [[ "${details_state}" == "real_entry" ]]; then
        clip_text "${term_cols}" "  Current entry: ${current_target}"
      else
        clip_text "${term_cols}" "  Current entry: none"
      fi
    fi

    if row_allows_rename "${UI_CURSOR}" || [[ -n "${UI_RENAMES[$UI_CURSOR]}" ]]; then
      if [[ "${UI_FOCUS}" == "rename" ]]; then
        rename_prompt=">"
      else
        rename_prompt=" "
      fi
      clip_text "${term_cols}" "${rename_prompt} Rename target: ${UI_RENAMES[$UI_CURSOR]}"
    fi

    clip_text "${term_cols}" "  Effective action: $(describe_effective_action "${UI_CURSOR}")"
  fi

  if [[ "${show_message}" -eq 1 && -n "${UI_MESSAGE}" ]]; then
    printf '\n'
    clip_text "${term_cols}" "Message (${UI_MESSAGE_KIND}): ${UI_MESSAGE}"
  fi
}

ui_enter() {
  if [[ "${UI_SCREEN_ACTIVE}" -eq 1 ]]; then
    return
  fi

  UI_SCREEN_ACTIVE=1
  printf '\033[?1049h\033[?25l'
}

ui_leave() {
  if [[ "${UI_SCREEN_ACTIVE}" -ne 1 ]]; then
    return
  fi

  UI_SCREEN_ACTIVE=0
  printf '\033[?25h\033[?1049l'
}

read_key() {
  local key=""
  local key2=""
  local key3=""

  IFS= read -rsn1 key || {
    printf 'eof\n'
    return
  }

  case "${key}" in
    $'\t')
      printf 'tab\n'
      ;;
    '')
      printf 'enter\n'
      ;;
    $'\n'|$'\r')
      printf 'enter\n'
      ;;
    ' ')
      printf 'space\n'
      ;;
    $'\177'|$'\b')
      printf 'backspace\n'
      ;;
    $'\025')
      printf 'clear\n'
      ;;
    $'\004')
      printf 'quit\n'
      ;;
    $'\033')
      if IFS= read -rsn1 -t 0.01 key2; then
        if [[ "${key2}" == "[" ]]; then
          IFS= read -rsn1 -t 0.01 key3 || key3=""
          case "${key3}" in
            A) printf 'up\n' ;;
            B) printf 'down\n' ;;
            C) printf 'right\n' ;;
            D) printf 'left\n' ;;
            H) printf 'home\n' ;;
            F) printf 'end\n' ;;
            3)
              IFS= read -rsn1 -t 0.01 key3 || key3=""
              printf 'delete\n'
              ;;
            *)
              printf 'escape\n'
              ;;
          esac
        else
          printf 'escape\n'
        fi
      else
        printf 'escape\n'
      fi
      ;;
    *)
      printf '%s\n' "${key}"
      ;;
  esac
}

update_path_input() {
  UI_PATH_INPUT="$1"
  clamp_path_cursor
  set_message info "Path edited. Press Enter to refresh skills for the new target."
}

apply_path_input_refresh() {
  refresh_ui_state "${UI_PATH_INPUT}"
  ensure_focus_valid
  UI_PATH_CURSOR=${#UI_PATH_INPUT}
  set_message info "Refreshed install state for ${UI_TARGET_ROOT}"
}

interactive_key_loop() {
  local key_name
  local current_value
  local new_value

  while true; do
    render_ui
    key_name="$(read_key)"

    case "${UI_FOCUS}" in
      path)
        case "${key_name}" in
          quit|eof|escape)
            ui_leave
            echo "Cancelled."
            return 0
            ;;
          enter)
            apply_path_input_refresh
            ;;
          tab)
            if path_input_is_dirty; then
              set_message error "Press Enter in the path field to refresh skills for the new target."
            else
              UI_FOCUS="list"
            fi
            ;;
          left)
            move_path_cursor_left
            ;;
          right)
            move_path_cursor_right
            ;;
          home)
            move_path_cursor_home
            ;;
          end)
            move_path_cursor_end
            ;;
          backspace)
            backspace_path_character
            ;;
          delete)
            delete_path_character
            ;;
          clear)
            clear_path_input
            ;;
          *)
            if [[ "${key_name}" =~ ^[[:print:]]$ ]]; then
              insert_path_character "${key_name}"
            fi
            ;;
        esac
        ;;
      list)
        case "${key_name}" in
          quit|eof|escape)
            ui_leave
            echo "Cancelled."
            return 0
            ;;
          enter)
            if validate_selected_plan; then
              ui_leave
              apply_interactive_install "${UI_TARGET_ROOT}"
              return $?
            fi
            ;;
          tab)
            focus_next_field
            ;;
          up)
            if (( UI_CURSOR > 0 )); then
              UI_CURSOR=$((UI_CURSOR - 1))
            fi
            ;;
          down)
            if (( UI_CURSOR + 1 < ${#SKILL_NAMES[@]} )); then
              UI_CURSOR=$((UI_CURSOR + 1))
            fi
            ;;
          left)
            UI_FOCUS="path"
            ;;
          right|r)
            if row_allows_rename "${UI_CURSOR}" || [[ -n "${UI_RENAMES[$UI_CURSOR]}" ]]; then
              UI_FOCUS="rename"
              set_message info "Editing rename for ${SKILL_NAMES[$UI_CURSOR]}"
            else
              set_message error "Rename is only available when the default target name is already occupied."
            fi
            ;;
          space)
            if [[ "${UI_SELECTED[$UI_CURSOR]}" -eq 1 ]]; then
              UI_SELECTED[$UI_CURSOR]=0
            else
              UI_SELECTED[$UI_CURSOR]=1
            fi
            ;;
        esac
        ;;
      rename)
        case "${key_name}" in
          quit|eof|escape)
            ui_leave
            echo "Cancelled."
            return 0
            ;;
          enter)
            if validate_selected_plan; then
              ui_leave
              apply_interactive_install "${UI_TARGET_ROOT}"
              return $?
            fi
            ;;
          tab|left|right)
            focus_next_field
            ensure_focus_valid
            ;;
          up)
            if (( UI_CURSOR > 0 )); then
              UI_CURSOR=$((UI_CURSOR - 1))
            fi
            ensure_focus_valid
            ;;
          down)
            if (( UI_CURSOR + 1 < ${#SKILL_NAMES[@]} )); then
              UI_CURSOR=$((UI_CURSOR + 1))
            fi
            ensure_focus_valid
            ;;
          backspace|delete)
            current_value="${UI_RENAMES[$UI_CURSOR]}"
            if [[ -n "${current_value}" ]]; then
              UI_RENAMES[$UI_CURSOR]="${current_value%?}"
            fi
            ;;
          clear)
            UI_RENAMES[$UI_CURSOR]=""
            ;;
          *)
            if [[ "${key_name}" =~ ^[[:print:]]$ ]]; then
              new_value="${UI_RENAMES[$UI_CURSOR]}${key_name}"
              UI_RENAMES[$UI_CURSOR]="${new_value}"
            fi
            ;;
        esac
        ;;
    esac

    ensure_focus_valid
  done
}

run_interactive_install() {
  if [[ ! -t 0 || ! -t 1 ]]; then
    echo "Interactive mode requires a TTY. Use --non-interactive for scripting." >&2
    exit 1
  fi

  if [[ ${#SKILL_NAMES[@]} -eq 0 ]]; then
    echo "No skills found under ${source_root}" >&2
    exit 1
  fi

  if [[ -n "${target_arg}" ]]; then
    UI_PATH_INPUT="${target_arg}"
  fi

  refresh_ui_state "${UI_PATH_INPUT}"
  UI_FOCUS="path"
  UI_CURSOR=0
  UI_SCROLL=0
  UI_PATH_CURSOR=${#UI_PATH_INPUT}
  set_message info "Edit the path, press Enter to refresh it, then toggle skills and press Enter to install."

  trap 'ui_leave' EXIT INT TERM
  ui_enter
  interactive_key_loop
}

main() {
  parse_args "$@"
  ensure_source_root
  load_skills

  if [[ -z "${target_arg}" ]]; then
    target_arg="${default_install_root}"
  fi

  if [[ "${non_interactive}" -eq 1 ]]; then
    run_non_interactive_install "$(normalize_target_root "${target_arg}")"
    return
  fi

  UI_PATH_INPUT="${target_arg}"
  run_interactive_install
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  main "$@"
fi
