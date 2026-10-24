#!/usr/bin/env bash
# Read the same Interface/Language setting as ui_language.pas.
# This file is sourced, so it does not change the caller's shell options.
devcpp_language_file=${HOME:+"$HOME/.config/"}devcpp-noi.ini
if [[ -z ${HOME:-} ]]; then
  devcpp_language_file="$(dirname -- "${BASH_SOURCE[0]}")/devcpp-noi.ini"
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
  if [[ "$devcpp_saved_language" == en || "$devcpp_saved_language" == english ]]; then
    devcpp_ui_language=en
  fi
fi
