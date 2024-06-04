#!/usr/bin/env bash

set -euo pipefail

for arg; do
	if [[ "$arg" = command:* ]]; then
		if [[ "$arg" != command:context ]]; then
			# Not running a context command, so we don't care.
			exit 0
		fi

		exec git -C ~/.homesick/repos/castle add --renormalize home/.config/task/taskrc
	fi
done

# If we got here, we've not found a command: argument at all, so something very
# strange is going on!
echo 'Failed to find a `command:` argument for on-exit hook!'
exit 1
