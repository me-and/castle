#!/usr/bin/env bash
#
# Install the one (1) binary that needs compiling.
set -euo pipefail

# Change to the directory that contains this script, just in case the script is
# being run for somewhere else.
cd -- "$(dirname -- "${BASH_SOURCE[0]}")"

mkdir -p ~/.local/bin

gcc -Wall -O3 -o ~/.local/bin/toil toil.c
