#!/usr/bin/env bash

release_safety_fail() {
  echo "release safety check failed: $*" >&2
  return 1
}

PINNED_LEGACY_LOCAL_PATH_VERSION="1.0.0"
PINNED_LEGACY_LOCAL_PATH_SHA256="21d1eb306b3b3211c1911636e6cf3544bf94064af160b6f061949595b369229a"

assert_release_version() {
  local version="$1"
  if [[ ! "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    release_safety_fail "release version must be strict semver: ${version:-<empty>}"
    return 1
  fi
}

assert_legacy_local_path_exception() {
  local enabled="$1"
  local version="$2"
  local expected_sha256="${3:-}"

  if [[ "$enabled" != "0" && "$enabled" != "1" ]]; then
    release_safety_fail "ALLOW_LEGACY_LOCAL_PATHS must be 0 or 1"
    return 1
  fi
  if [[ "$enabled" == "0" ]]; then
    return 0
  fi
  if [[ "$version" != "$PINNED_LEGACY_LOCAL_PATH_VERSION" ||
        "$expected_sha256" != "$PINNED_LEGACY_LOCAL_PATH_SHA256" ]]; then
    release_safety_fail \
      "legacy local-path exception requires v$PINNED_LEGACY_LOCAL_PATH_VERSION at fixed SHA-256 $PINNED_LEGACY_LOCAL_PATH_SHA256"
    return 1
  fi
}

assert_safe_release_root() {
  local allowed_root="${1%/}"

  if [[ -z "$allowed_root" || "$allowed_root" != /* ]]; then
    release_safety_fail "release root must be absolute"
    return 1
  fi
  if [[ "$allowed_root" == "/" || "$allowed_root" == "$HOME" ]]; then
    release_safety_fail "refusing dangerous release root"
    return 1
  fi
  case "$allowed_root" in
    *"/../"*|*/..|*"/./"*|*/.|*"//"*|*$'\n'*|*$'\r'*)
      release_safety_fail "release root is not lexically normalized: $allowed_root"
      return 1
      ;;
  esac
  if [[ ! -d "$allowed_root" || -L "$allowed_root" ]]; then
    release_safety_fail "release root must be a real directory: $allowed_root"
    return 1
  fi
}

assert_safe_release_path() {
  local path="$1"
  local allowed_root="${2%/}"
  local expected_basename="$3"

  assert_safe_release_root "$allowed_root" || return 1
  if [[ -z "$path" || "$path" != /* ]]; then
    release_safety_fail "release path must be absolute"
    return 1
  fi
  if [[ "$path" == "/" || "$path" == "$HOME" ]]; then
    release_safety_fail "refusing dangerous release path"
    return 1
  fi
  case "$path" in
    *"/../"*|*/..|*"/./"*|*/.|*"//"*|*$'\n'*|*$'\r'*)
      release_safety_fail "release path is not lexically normalized: $path"
      return 1
      ;;
  esac
  if [[ "$(dirname "$path")" != "$allowed_root" ||
        "$(basename "$path")" != "$expected_basename" ]]; then
    release_safety_fail "release path must be the expected direct child $allowed_root/$expected_basename"
    return 1
  fi
  if [[ -L "$path" ]]; then
    release_safety_fail "release path is a symbolic link: $path"
    return 1
  fi
}

safe_remove_release_path() {
  local path="$1"
  local allowed_root="$2"
  local expected_basename="$3"
  assert_safe_release_path "$path" "$allowed_root" "$expected_basename" || return 1
  rm -rf -- "$path"
}

assert_safe_app_path() {
  local path="$1"
  local expected_basename="$2"
  shift 2

  if [[ -z "$path" || "$path" != /* ]]; then
    release_safety_fail "app path must be absolute: ${path:-<empty>}"
    return 1
  fi
  if [[ "$path" == "/" || "$path" == "$HOME" ]]; then
    release_safety_fail "refusing dangerous app path: $path"
    return 1
  fi
  case "$path" in
    *"/../"*|*/..|*"/./"*|*/.|*"//"*|*$'\n'*|*$'\r'*)
      release_safety_fail "app path is not lexically normalized: $path"
      return 1
      ;;
  esac
  if [[ "$(basename "$path")" != "$expected_basename" ]]; then
    release_safety_fail "expected app basename $expected_basename: $path"
    return 1
  fi

  local allowed=false
  local root
  for root in "$@"; do
    root="${root%/}"
    if [[ -n "$root" && "$root" == /* && "$path" == "$root/"* ]]; then
      allowed=true
      break
    fi
  done
  if [[ "$allowed" != true ]]; then
    release_safety_fail "app path is outside the allowed roots: $path"
    return 1
  fi

  local current=""
  local remainder="${path#/}"
  local component
  local components=()
  IFS='/' read -r -a components <<< "$remainder"
  for component in "${components[@]}"; do
    current="$current/$component"
    if [[ -L "$current" ]]; then
      release_safety_fail "app path contains a symbolic link: $current"
      return 1
    fi
  done
}

safe_remove_app_bundle() {
  local path="$1"
  local expected_basename="$2"
  shift 2
  assert_safe_app_path "$path" "$expected_basename" "$@" || return 1
  rm -rf -- "$path"
}

contains_local_absolute_path() {
  strings "$1" | grep -E '/Users/[^/[:space:]]+|/home/[^/[:space:]]+|/(private/)?var/folders/'
}

assert_no_local_absolute_paths() {
  local binary="$1"
  if [[ ! -f "$binary" ]]; then
    release_safety_fail "path-scan binary is missing: $binary"
    return 1
  fi
  if contains_local_absolute_path "$binary"; then
    release_safety_fail "local absolute path found in $(basename "$binary")"
    return 1
  fi
}

sha256_of() {
  shasum -a 256 "$1" | awk '{ print $1 }'
}

assert_file_sha256() {
  local file="$1"
  local expected="$2"
  local label="${3:-$(basename "$file")}"
  if [[ ! "$expected" =~ ^[0-9a-f]{64}$ ]]; then
    release_safety_fail "invalid expected SHA-256 for $label"
    return 1
  fi
  local actual
  actual="$(sha256_of "$file")"
  if [[ "$actual" != "$expected" ]]; then
    release_safety_fail "SHA-256 mismatch for $label: expected $expected, found $actual"
    return 1
  fi
}

assert_launch_agent_contract() {
  local agent="$1"
  local app="$2"

  if [[ ! -f "$agent" || -L "$agent" ]]; then
    release_safety_fail "LaunchAgent must be a regular plist: $agent"
    return 1
  fi
  if ! plutil -lint "$agent" >/dev/null; then
    release_safety_fail "LaunchAgent plist is invalid: $agent"
    return 1
  fi
  if [[ "$(plutil -extract Label raw "$agent")" != "com.codex-pet.limit-rings" ||
        "$(plutil -extract ProgramArguments.0 raw "$agent")" != "/usr/bin/open" ||
        "$(plutil -extract ProgramArguments.1 raw "$agent")" != "-W" ||
        "$(plutil -extract ProgramArguments.2 raw "$agent")" != "$app" ||
        "$(plutil -extract RunAtLoad raw "$agent")" != "true" ||
        "$(plutil -extract LimitLoadToSessionType raw "$agent")" != "Aqua" ]]; then
    release_safety_fail "LaunchAgent does not match the LaunchServices startup contract"
    return 1
  fi
  if plutil -extract ProgramArguments.3 raw "$agent" >/dev/null 2>&1; then
    release_safety_fail "LaunchAgent has unexpected program arguments"
    return 1
  fi
}

localization_keys() {
  sed -n 's/^[[:space:]]*"\([^"]*\)"[[:space:]]*=.*/\1/p' "$1"
}

localization_contracts() {
  local file="$1"
  local line
  local key
  local placeholders
  while IFS= read -r line; do
    key="$(printf '%s\n' "$line" | sed -n 's/^[[:space:]]*"\([^"]*\)"[[:space:]]*=.*/\1/p')"
    [[ -n "$key" ]] || continue
    placeholders="$(
      printf '%s\n' "$line" |
        grep -oE '%([0-9]+\$)?[-+#0 ]*([0-9]+|\*)?(\.[0-9]+|\.\*)?(hh|h|ll|l|q|z|t|j)?[@diuoxXfFeEgGaAcCsSp]' |
        LC_ALL=C sort |
        tr '\n' ',' || true
    )"
    printf '%s\t%s\n' "$key" "$placeholders"
  done < "$file"
}

verify_localization_contract() {
  local english="$1"
  local japanese="$2"
  local temporary_root="${3:-${TMPDIR:-/tmp}}"
  local english_keys="$temporary_root/localization-en-keys.$$"
  local japanese_keys="$temporary_root/localization-ja-keys.$$"
  local english_contracts="$temporary_root/localization-en-contracts.$$"
  local japanese_contracts="$temporary_root/localization-ja-contracts.$$"
  local duplicates="$temporary_root/localization-duplicates.$$"

  localization_keys "$english" | LC_ALL=C sort > "$english_keys"
  localization_keys "$japanese" | LC_ALL=C sort > "$japanese_keys"

  if ! diff -u "$english_keys" "$japanese_keys"; then
    rm -f "$english_keys" "$japanese_keys" "$english_contracts" "$japanese_contracts" "$duplicates"
    release_safety_fail "English and Japanese localization keys differ"
    return 1
  fi

  for file in "$english_keys" "$japanese_keys"; do
    uniq -d "$file" > "$duplicates"
    if [[ -s "$duplicates" ]]; then
      cat "$duplicates" >&2
      rm -f "$english_keys" "$japanese_keys" "$english_contracts" "$japanese_contracts" "$duplicates"
      release_safety_fail "duplicate localization keys found"
      return 1
    fi
  done

  localization_contracts "$english" | LC_ALL=C sort > "$english_contracts"
  localization_contracts "$japanese" | LC_ALL=C sort > "$japanese_contracts"
  if ! diff -u "$english_contracts" "$japanese_contracts"; then
    rm -f "$english_keys" "$japanese_keys" "$english_contracts" "$japanese_contracts" "$duplicates"
    release_safety_fail "English and Japanese format placeholders differ"
    return 1
  fi

  rm -f "$english_keys" "$japanese_keys" "$english_contracts" "$japanese_contracts" "$duplicates"
}
