#!/usr/bin/env bash

# Transactional promotion primitive shared with contract tests. Callers provide
# a verifier function that accepts the promoted bundle path.
promote_release_bundle() {
  local staged_bundle="$1"
  local target_bundle="$2"
  local rollback_bundle="$3"
  local verifier="$4"
  local rejected_bundle="$rollback_bundle.failed"
  local had_previous=false

  [ -d "$staged_bundle" ] && [ ! -L "$staged_bundle" ] || return 1
  [ ! -e "$rollback_bundle" ] && [ ! -L "$rollback_bundle" ] || return 1
  [ ! -e "$rejected_bundle" ] && [ ! -L "$rejected_bundle" ] || return 1

  if [ -e "$target_bundle" ] || [ -L "$target_bundle" ]; then
    [ -d "$target_bundle" ] && [ ! -L "$target_bundle" ] || return 1
    mv "$target_bundle" "$rollback_bundle" >/dev/null 2>&1 || return 1
    had_previous=true
  fi

  if ! mv "$staged_bundle" "$target_bundle" >/dev/null 2>&1; then
    if [ "$had_previous" = true ]; then
      mv "$rollback_bundle" "$target_bundle" >/dev/null 2>&1 || return 1
    fi
    return 1
  fi

  if "$verifier" "$target_bundle"; then
    return 0
  fi

  mv "$target_bundle" "$rejected_bundle" >/dev/null 2>&1 || return 1
  if [ "$had_previous" = true ]; then
    mv "$rollback_bundle" "$target_bundle" >/dev/null 2>&1 || return 1
  fi
  return 1
}
