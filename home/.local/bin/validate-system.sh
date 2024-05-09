#!/usr/bin/env bash
# A script to check the things that I want to set up are set up.

set -euo pipefail

string_to_array () {
	local string="$1"
	local sep="$2"
	local -n array="$3"
	local IFS="$sep"
	array=($string)
}

# Usage: check_executables_available <executable>...
#
# Will return 0 if all executables are available, 1 if there are one or more
# missing.
check_executables_available () {
	local abort_on_missing=
	if [[ "$1" = -x ]]; then
		# If there's a problem, exit the script, as it indicates we
		# can't carry on.
		abort_on_missing=YesPlease
		shift
	fi

	local -a missing_executables=()
	local -a search_paths
	local arg path

	string_to_array "$PATH" : search_paths

	for arg; do
		for path in "${search_paths[@]}"; do
			if [[ -x "$path/$arg" ]]; then
				continue 2
			fi
		done
		missing_executables+=("$arg")
	done

	if (( "${#missing_executables[*]}" != 0 )); then
		echo "Missing executables:"
		printf -- '- %s\n' "${missing_executables[@]}"
		if [[ "$abort_on_missing" ]]; then
			exit 69  # EX_UNAVAILABLE
		else
			problems=Yes
		fi
	fi
}

check_cygwin_registry_missing () {
	local path="$1"
	local key
	key="${path%/*}"
	key="${key//\//\\}"
	local cyg_reg_path=/proc/registry/"$path"
	if [[ -e "$cyg_reg_path" ]]; then
		printf 'Registry key %s present\n' "$key"
		problems=Yes
	fi
}

check_cygwin_registry () {
	local path="$1"
	local type="$2"
	local data="$3"

	local key
	key="${path%/*}"
	key="${key//\//\\}"
	local value="${path##*/}"

	local cyg_reg_path=/proc/registry/"$path"
	if [[ ! -e "$cyg_reg_path" ]]; then
		printf 'Registry key %s value %s not set to %s %s\n' "$key" "$value" "$type" "$data"
		problems=Yes
		return
	fi

	case "$type" in
		DWORD)
			local value_hex value_hex_le
			# Via https://unix.stackexchange.com/a/321866/2134
			if ! printf -v value_hex '%08x' "$data"; then
				printf 'Cannot convert %s from decimal to hex\n' "$data" >&2
				exit 70  # EX_SOFTWARE
			fi
			value_hex_le="$(dd conv=swab status=none <<<"$value_hex" | rev)"
			if [[ ! "$value_hex_le" =~ ^[0-9a-f]{8}$ ]]; then
				printf 'Cannot convert %q to a valid DWORD (got %q)\n' "$data" "$value_hex_le" >&2
				exit 70  # EX_SOFTWARE
			fi
			if ! cmp -s "$cyg_reg_path" <(xxd -r -p <<<"$value_hex_le"); then
				printf 'Registry key %s value %s not set to %s %s\n' "$key" "$value" "$type" "$data"
				problems=Yes
			fi
			;;
		SZ)  # String
			if ! cmp -s "$cyg_reg_path" <(printf '%s\0' "$data"); then
				printf 'Registry key %s value %s not set to %s %s\n' "$key" "$value" "$type" "$data"
				problems=Yes
			fi
			;;
		*)
			printf 'Unable to check %s registry values!\n' "$type" >&2
			exit 70  # EX_SOFTWARE
			;;
	esac
}

check_onedrive_excludes () {
	local local_app_data="$(cygpath "$LOCALAPPDATA")"
	if [[ ! -d "$local_app_data/Microsoft/OneDrive/settings/Personal" ]]; then
		# If OneDrive Personal isn't set up, don't treat that as an
		# error, but do let the user know.
		printf 'OneDrive Personal not installed\n' >&2
		return
	fi
	local onedrive_excludes_file="$local_app_data/Microsoft/OneDrive/settings/Personal/odignore.txt"
	local exclude
	local rc=0

	for exclude; do
		# Need to use dos2unix to ensure grep -x works, and I want that
		# because I want to be able to use -F while also only matching
		# whole lines.
		if ! dos2unix -q -e -O -- "$onedrive_excludes_file" | grep -qxF "$exclude"; then
			printf '%s missing from OneDrive excludes %s\n' "$exclude" "$onedrive_excludes_file"
			problems=Yes
		fi
	done
}

problems=

check_executables_available jq vipe task less vim curl git fmt gh python3 ssh

if [[ "$OSTYPE" = cygwin ]]; then
	check_executables_available -x cygpath cmp dos2unix

	# Want this because it ensures Start Menu searches are much quicker.
	check_cygwin_registry HKEY_CURRENT_USER/Software/Policies/Microsoft/Windows/Explorer/DisableSearchBoxSuggestions DWORD 1

	# Disable the taskbar search box.
	check_cygwin_registry HKEY_CURRENT_USER/Software/Microsoft/Windows/CurrentVersion/Search/SearchboxTaskbarMode DWORD 0

	# Disable the taskbar Copilot button.
	check_cygwin_registry HKEY_CURRENT_USER/Software/Microsoft/Windows/CurrentVersion/Explorer/Advanced/ShowCopilotButton DWORD 0

	# Disable the taskbar task view button.
	check_cygwin_registry HKEY_CURRENT_USER/Software/Microsoft/Windows/CurrentVersion/Explorer/Advanced/ShowTaskViewButton DWORD 0

	# Align the taskbar to the left.
	check_cygwin_registry HKEY_CURRENT_USER/Software/Microsoft/Windows/CurrentVersion/Explorer/Advanced/TaskbarAl DWORD 0

	# Disable the taskbar widget button.
	check_cygwin_registry HKEY_CURRENT_USER/Software/Microsoft/Windows/CurrentVersion/Explorer/Advanced/TaskbarDa DWORD 0

	# Only show windows on the taskbar of the display they're open on.
	check_cygwin_registry HKEY_CURRENT_USER/Software/Microsoft/Windows/CurrentVersion/Explorer/Advanced/MMTaskbarMode DWORD 2

	# Don't combine taskbar buttons unnecessarily, on either the main taskbar or on other displays.
	check_cygwin_registry HKEY_CURRENT_USER/Software/Microsoft/Windows/CurrentVersion/Explorer/Advanced/TaskbarGlomLevel DWORD 1
	check_cygwin_registry HKEY_CURRENT_USER/Software/Microsoft/Windows/CurrentVersion/Explorer/Advanced/MMTaskbarGlomLevel DWORD 1

	# Only show windows, not tabs within windows, in Alt+Tab.
	check_cygwin_registry HKEY_CURRENT_USER/Software/Microsoft/Windows/CurrentVersion/Explorer/Advanced/MultiTaskingAltTabFilter DWORD 3

	# Make cursors a bit easier to see.  CAUTION: I *think* just changing
	# this registry entry is insufficient, and the config needs to be
	# changed through the control panel, because there are a bunch of other
	# clearly related changes that happen when this config is set and which
	# aren't checked here.
	check_cygwin_registry HKEY_CURRENT_USER/Software/Microsoft/Accessibility/CursorSize DWORD 2

	# Check that the Alt+Shift and Ctrl+Shift hotkeys for switching
	# languages and keyboard layouts are disabled.  I hit them by accident
	# too much, and Win+Space does the job of switching layouts just as
	# well without the accidental invocations.  It looks like either
	# removing the `Control Panel/Input Method/Hot Keys` values or adding
	# the `Keyboard Layout/Toggle` values is sufficient, but doing both
	# seems to be the norm.
	check_cygwin_registry_missing HKEY_CURRENT_USER/Control\ Panel/Input\ Method/Hot\ Keys/00000104
	check_cygwin_registry HKEY_CURRENT_USER/Keyboard\ Layout/Toggle/Language\ Hotkey DWORD 3
	check_cygwin_registry HKEY_CURRENT_USER/Keyboard\ Layout/Toggle/Layout\ Hotkey DWORD 3
	check_cygwin_registry HKEY_CURRENT_USER/Keyboard\ Layout/Toggle/Hotkey DWORD 3

	# Enable various "developer mode" settings.
	check_cygwin_registry HKEY_CURRENT_USER/Software/Microsoft/Windows/CurrentVersion/Explorer/Advanced/Hidden DWORD 1
	check_cygwin_registry HKEY_CURRENT_USER/Software/Microsoft/Windows/CurrentVersion/Explorer/Advanced/HideFileExt DWORD 0
	check_cygwin_registry HKEY_CURRENT_USER/Software/Microsoft/Windows/CurrentVersion/Explorer/Advanced/HideDrivesWithNoMedia DWORD 0
	check_cygwin_registry HKEY_CURRENT_USER/Software/Microsoft/Windows/CurrentVersion/Explorer/Advanced/TaskbarDeveloperSettings/TaskbarEndTask DWORD 1

	# Ensure OneDrive is configured to skip files I want it to skip.
	check_onedrive_excludes '*.crdownload' '*.aux' '*.fls' '*.fdb_latexmk' '*.swp'
fi

[[ -z "$problems" ]]
