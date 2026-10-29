#!/usr/bin/env bash
# Read the same Interface/Language setting as ui_language.pas.
# This file is sourced, so it does not change the caller's shell options.
devcpp_language_file=${HOME:+"$HOME/.config/"}dev-cpp.ini
if [[ -z ${HOME:-} ]]; then
  devcpp_language_file="$(dirname -- "${BASH_SOURCE[0]}")/dev-cpp.ini"
fi
# Use the previous preference until the application migrates it.
if [[ ! -r "$devcpp_language_file" && -n ${HOME:-} ]]; then
  for legacy_config in "$HOME/.config/dev-cpp-linux.ini" "$HOME/.config/devcpp-noi.ini"; do
    if [[ -r "$legacy_config" ]]; then devcpp_language_file="$legacy_config"; break; fi
  done
fi
devcpp_ui_language=zh
if [[ -r "$devcpp_language_file" ]]; then
  devcpp_saved_language=$(awk '
    /^[[:space:]]*\[/ {
      section=tolower($0); gsub(/[[:space:]]/, "", section); next
    }
    section == "[interface]" && /^[[:space:]]*[Ll][Aa][Nn][Gg][Uu][Aa][Gg][Ee][[:space:]]*=/ {
      value=$0; sub(/^[^=]*=/, "", value); gsub(/[[:space:]]/, "", value)
      print tolower(value); exit
    }' "$devcpp_language_file")
  if [[ "$devcpp_saved_language" != zh && "$devcpp_saved_language" != zh_cn && "$devcpp_saved_language" != chinese && -n "$devcpp_saved_language" ]]; then
    devcpp_ui_language=en
  fi
fi
