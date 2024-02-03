#!/usr/bin/env bash
# A script to check the things that I want to set up are set up.

set -euo pipefail

# Returns 0 for true, 1 for false.
executable_available () {
	local path
	for path in "${EXECUTABLE_PATHS[@]}"; do
		if [[ -x "$path/$1" ]]; then
			return 0
		fi
	done
	return 1
}

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
		for arg in "${missing_executables[@]}"; do
			printf '%s\n' "- $arg"
		done
		return 1
	fi
}

check_cygwin_registry () {
	local key="$1"
	local hex_value="$2"
	if [[ -e "$key" ]] && cmp -s "$key" <(xxd -r -p <<<"$hex_value"); then
		return 0
	else
		printf 'Registry %s not set to %s\n' "$key" "$hex_value"
		return 1
	fi
}

check_onedrive_excludes () {
	local local_app_data="$(cygpath "$LOCALAPPDATA")"
	local onedrive_excludes_file="$local_app_data/Microsoft/OneDrive/settings/Personal/odignore.txt"
	local exclude
	local rc=0

	for exclude; do
		# Need to use dos2unix to ensure grep -x works, and I want that
		# because I want to be able to use -F while also only matching
		# whole lines.
		if ! dos2unix -q -e -O -- "$onedrive_excludes_file" | grep -qxF "$exclude"; then
			printf '%s missing from OneDrive excludes %s\n' "$exclude" "$onedrive_excludes_file"
			rc=1
		fi
	done

	return "$rc"
}

rc=0

check_executables_available jq vipe task less vim curl git fmt gh python3 ssh || rc="$?"

if [[ "$OSTYPE" = cygwin ]]; then
	check_executables_available cygpath cmp dos2unix || exit 69  # EX_UNAVAILABLE

	# Want this because it ensures Start Menu searches are much quicker.
	check_cygwin_registry /proc/registry/HKEY_CURRENT_USER/Software/Policies/Microsoft/Windows/Explorer/DisableSearchBoxSuggestions 01000000 || rc="$?"

	# Ensure OneDrive is configured to skip files I want it to skip.
	check_onedrive_excludes '*.crdownload' '*.aux' '*.fls' '*.fdb_latexmk' || rc="$?"
fi

exit "$rc"
