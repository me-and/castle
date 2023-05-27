#!/usr/bin/env python3

import os
import subprocess
import json
import sys

UDA_UNTIL = 'recurTaskUntil'

# Based on https://github.com/JensErat/task-relative-recur/blob/master/on-modify.relative-recur
def calc(statement, env):
    p = subprocess.run(['task', 'rc.verbose=nothing', 'rc.date.iso=yes', 'calc', statement], stdout=subprocess.PIPE, check=True, encoding='utf-8', env=env)
    return p.stdout.rstrip() + 'Z'


if __name__ == '__main__':
    env = os.environ.copy()
    env['TZ'] = 'UTC0'

    messages = []

    original = json.loads(sys.stdin.readline())
    modified = json.loads(sys.stdin.readline())

    if UDA_UNTIL in modified and modified['status'] == 'pending':
        if 'due' in modified:
            modified['until'] = calc(modified['due'] + '+' + modified[UDA_UNTIL], env)
            messages.append(f'Set until to {modified["until"]}')
        else:
            print(f'Task with {UDA_UNTIL} but without due')
            sys.exit(1)
    print(json.dumps(modified))
    print('; '.join(messages))
