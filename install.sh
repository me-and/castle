#!/usr/bin/env bash
#
# Install the one (1) binary that needs compiling.
#
# TODO: Set things up to automatically check whether the source code is newer
# than the executable.

set -euo pipefail

# Change to the directory that contains this script, just in case the script is
# being run for somewhere else.
cd -- "$(dirname -- "${BASH_SOURCE[0]}")"

mkdir -p ~/.local/bin

gcc -Wall -O3 -o ~/.local/bin/toil src/toil.c
