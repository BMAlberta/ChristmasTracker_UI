#!/bin/bash
# scripts/lib/destination.sh — sourced by scripts/build.sh and scripts/test.sh.
# Defines resolve_destination, which prints an xcodebuild -destination value.
#
#   DEST     If set and non-empty it is printed unchanged (a user override always wins).
#   SIMCTL   Command used to list simulators (default: "xcrun simctl"). Tests point it
#            at a stub so the real simctl is never called.
#
# Otherwise: the newest iOS runtime that has an available device whose name starts with
# "iPhone" is chosen. "iPhone 17 Pro" is preferred when present on that runtime version,
# else the first iPhone by name. Prints: platform=iOS Simulator,id=<udid>
# Runtimes that share a version (for example a device-specific variant) are pooled.
# Failure: a message on stderr and a non-zero return. Never prints secrets.

resolve_destination() {
  if [ -n "${DEST:-}" ]; then
    printf '%s\n' "$DEST"
    return 0
  fi

  local -a simctl_cmd
  read -r -a simctl_cmd <<< "${SIMCTL:-xcrun simctl}"

  local devices_json
  if ! devices_json="$("${simctl_cmd[@]}" list devices available -j 2>/dev/null)"; then
    echo "error: could not list simulators with: ${simctl_cmd[*]} list devices available -j" >&2
    return 1
  fi

  local picked
  if ! picked="$(printf '%s' "$devices_json" | jq -r '
    [ .devices | to_entries[]
      | select(.key | test("\\.iOS-[0-9]"))
      | .key as $runtime
      | ($runtime | capture("\\.iOS-(?<v>[0-9]+(-[0-9]+)*)") | .v | split("-") | map(tonumber)) as $ver
      | .value[]
      | select(.isAvailable == true and (.name | startswith("iPhone")))
      | {ver: $ver, name: .name, udid: .udid}
    ]
    | if length == 0 then empty else
        (map(.ver) | max) as $max
        | map(select(.ver == $max))
        | ( (map(select(.name == "iPhone 17 Pro")) | sort_by(.udid) | .[0])
            // (sort_by([.name, .udid]) | .[0]) )
        | "\(.udid)\t\(.name)\tiOS \($max | map(tostring) | join("."))"
      end
  ' 2>/dev/null)"; then
    echo "error: could not parse the simulator list (malformed JSON from simctl)" >&2
    return 1
  fi

  if [ -z "$picked" ]; then
    echo "error: no available iOS simulator runtime with an iPhone was found." >&2
    echo "Install one in Xcode Settings, Components (iOS Simulator runtime), then retry," >&2
    echo "or set DEST=\"platform=iOS Simulator,name=...\" to choose a destination." >&2
    return 1
  fi

  local udid name runtime
  IFS=$'\t' read -r udid name runtime <<< "$picked"
  local destination="platform=iOS Simulator,id=${udid}"
  echo "destination: ${destination} (${name}, ${runtime})" >&2
  printf '%s\n' "$destination"
}
