#!/usr/bin/env bash
# Compares two flake.lock files and prints a markdown table of what changed.
# Usage: flake-lock-diff.sh <old-lock> <new-lock>
set -euo pipefail

OLD_LOCK="$1"
NEW_LOCK="$2"

echo "### Flake input updates"
echo
echo "| Input | Before | After | Compare |"
echo "|---|---|---|---|"

changed_any=false

# Iterate every node in the new lock (skip the synthetic "root" node)
for name in $(jq -r '.nodes | keys[] | select(. != "root")' "$NEW_LOCK"); do
  old_locked=$(jq -c --arg n "$name" '.nodes[$n].locked // empty' "$OLD_LOCK" 2>/dev/null || true)
  new_locked=$(jq -c --arg n "$name" '.nodes[$n].locked // empty' "$NEW_LOCK" 2>/dev/null || true)

  if [ -z "$new_locked" ] || [ "$old_locked" = "$new_locked" ]; then
    continue
  fi
  changed_any=true

  old_rev=$(jq -r '.rev // empty' <<<"$old_locked" 2>/dev/null || true)
  new_rev=$(jq -r '.rev // empty' <<<"$new_locked")
  old_ts=$(jq -r '.lastModified // empty' <<<"$old_locked" 2>/dev/null || true)
  new_ts=$(jq -r '.lastModified // empty' <<<"$new_locked")
  owner=$(jq -r '.owner // empty' <<<"$new_locked")
  repo=$(jq -r '.repo // empty' <<<"$new_locked")
  type=$(jq -r '.type // empty' <<<"$new_locked")

  old_date="unknown"
  new_date="unknown"
  [ -n "$old_ts" ] && old_date=$(date -u -d "@$old_ts" +"%b %-d")
  [ -n "$new_ts" ] && new_date=$(date -u -d "@$new_ts" +"%b %-d")

  if [ -n "$old_rev" ]; then
    before="\`${old_rev:0:7}\` ($old_date)"
  else
    before="_new input_"
  fi
  after="\`${new_rev:0:7}\` ($new_date)"

  link="-"
  if [ "$type" = "github" ] && [ -n "$owner" ] && [ -n "$old_rev" ] && [ -n "$new_rev" ]; then
    link="[view commits](https://github.com/$owner/$repo/compare/$old_rev...$new_rev)"
  fi

  echo "| **$name** | $before | $after | $link |"
done

if [ "$changed_any" = "false" ]; then
  echo "| _no input changes detected_ |  |  |  |"
fi