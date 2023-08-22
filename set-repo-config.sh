#!/usr/bin/env bash
#
# Set up a Git scrub/clean filter to ensure Git doesn't report updates to the
# context config in taskrc.

set -euo pipefail

# Change to the directory that contains this script, just in case the script is
# being run from somewhere else.
cd -- "$(dirname -- "${BASH_SOURCE[0]}")"

if git diff --quiet -I'^context=' home/.config/task/taskrc; then
	# No changes to the file other than adding or removing a context line,
	# so it's safe to set up the filter.
	git config filter.taskrc.clean "grep -v '^context='"
	git add --renormalize home/.config/task/taskrc
else
	echo 'Changes exist in .config/task/taskrc.' >&2
	echo 'Revert or commit non-context changes to taskrc first.' >&2
	exit 65  # EX_DATAERR
fi
