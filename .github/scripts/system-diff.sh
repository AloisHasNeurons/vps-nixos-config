#!/usr/bin/env bash
# Compares the NixOS system of two checkouts of this flake and prints markdown:
#   1. a "Services" table (versions + changelog links, from lock-diff-services.nix)
#   2. the full package diff of the two system closures (nvd), collapsed
# Usage: system-diff.sh <old-flake-dir> <new-flake-dir>
# Needs both systems built (mostly substituted), i.e. ~15 GB of free disk.
set -euo pipefail

OLD="$(realpath "$1")"
NEW="$(realpath "$2")"
SERVICES_NIX="$(realpath "$(dirname "$0")/lock-diff-services.nix")"
SYSTEM="nixosConfigurations.vps"

# name -> {version, changelog, homepage} for one checkout
service_versions() {
  nix eval --impure --json "path:$1#$SYSTEM" --apply "
    nixos: let
      lib = nixos.pkgs.lib;
      # Entries are either a package or { package; changelog = version: url; }
      normalize = e: if e ? package then e else { package = e; };
      describe = e: let p = e.package; v = p.version or null; in {
        version = v;
        changelog =
          if e ? changelog && v != null then e.changelog v
          else p.meta.changelog or null;
        homepage = let h = p.meta.homepage or null; in
          if builtins.isList h then builtins.head h else h;
      };
      entries = lib.mapAttrs (_: normalize) (import $SERVICES_NIX nixos);
    in lib.mapAttrs (_: describe) (lib.filterAttrs (_: e: e.package != null) entries)
  "
}

service_versions "$OLD" > /tmp/services-old.json
service_versions "$NEW" > /tmp/services-new.json

echo "### Services"
echo
echo "| Service | Before | After | Notes |"
echo "|---|---|---|---|"
# One row per service whose version changed. ⚠️ on a major bump
# (first component, or the second one for 0.x versions).
jq -r --slurpfile old /tmp/services-old.json '
  def major: split(".") as $p | if $p[0] == "0" then $p[0:2] else $p[0:1] end;
  to_entries
  | map(.key as $k | .value as $n | ($old[0][$k].version // "-") as $before
      | select($before != $n.version)
      | [ (if $k == "Linux kernel" then "reboot expected" else empty end),
          (if $n.changelog then "[changelog](\($n.changelog))"
           elif $n.homepage then "[homepage](\($n.homepage))"
           else empty end) ] as $notes
      | "| **\($k)** | \($before) | \($n.version)\(
            if $before != "-" and ($before | major) != ($n.version | major) then " ⚠️ major" else "" end
          ) | \($notes | join(" · ")) |")
  | if length == 0 then ["| _no service version changes_ | | | |"] else . end
  | .[]
' /tmp/services-new.json
echo

# Full closure diff. Both systems are built; nearly everything comes from
# cache.nixos.org, only the config-specific bits (units, /etc) are built here.
old_sys=$(nix build --no-link --print-out-paths "path:$OLD#$SYSTEM.config.system.build.toplevel")
new_sys=$(nix build --no-link --print-out-paths "path:$NEW#$SYSTEM.config.system.build.toplevel")

# GitHub comments are capped at 65536 characters
nvd_out=$(nix run --inputs-from "path:$NEW" nixpkgs#nvd -- --color never diff "$old_sys" "$new_sys")
echo "$nvd_out" >&2 # full list in the job log
if [ "${#nvd_out}" -gt 55000 ]; then
  nvd_out="${nvd_out:0:55000}
... (truncated, see the job log for the full list)"
fi

echo "<details><summary><b>All package changes</b> (nvd)</summary>"
echo
echo '```text'
echo "$nvd_out"
echo '```'
echo
echo "</details>"
