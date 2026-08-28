#!/usr/bin/env bash

# Shared validation for release workflows. Callers provide fail().
validate_release_signing_keychain() {
  local requested_keychain="$1"
  local requested_identity="$2"
  local keychain_name
  local identity_output

  [[ "$requested_keychain" == /* ]] || fail 'the signing keychain path must be absolute'
  [[ "$requested_keychain" =~ ^[/A-Za-z0-9._-]+$ ]] || \
    fail 'the signing keychain path contains unsupported characters'

  keychain_name="$(basename "$requested_keychain")"
  case "$keychain_name" in
    login.keychain|login.keychain-db|System.keychain)
      fail 'release automation must not use a login or system keychain'
      ;;
  esac

  [ -f "$requested_keychain" ] || fail 'the signing keychain does not exist'
  [ ! -L "$requested_keychain" ] || fail 'the signing keychain must not be a symbolic link'

  [[ "$requested_identity" =~ ^[[:xdigit:]]{40}$ ]] || \
    fail 'the signing identity must be a 40-character certificate fingerprint'

  release_signing_keychain="$requested_keychain"
  release_signing_identity="$(printf '%s' "$requested_identity" | tr '[:lower:]' '[:upper:]')"

  identity_output="$(security find-identity -v -p codesigning "$release_signing_keychain")" || \
    fail 'the dedicated signing keychain could not be inspected without interaction'

  if ! printf '%s\n' "$identity_output" | rg -Fq \
    "$release_signing_identity \"Developer ID Application: Patrick LaClair (N8A5T2PZY9)\""; then
    fail 'the dedicated signing keychain does not contain the approved Developer ID identity'
  fi
}
