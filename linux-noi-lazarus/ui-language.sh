#!/usr/bin/env bash
# Read the same Interface/Language setting as ui_language.pas.
# This file is sourced, so it does not change the caller's shell options.
devcpp_language_file=${HOME:+"$HOME/.config/"}dev-cpp-linux.ini
if [[ -z ${HOME:-} ]]; then
  devcpp_language_file="$(dirname -- "${BASH_SOURCE[0]}")/dev-cpp-linux.ini"
fi
# Read the legacy preference until the application copies it on first launch.
if [[ ! -r "$devcpp_language_file" && -n ${HOME:-} && -r "$HOME/.config/devcpp-noi.ini" ]]; then
  devcpp_language_file="$HOME/.config/devcpp-noi.ini"
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
