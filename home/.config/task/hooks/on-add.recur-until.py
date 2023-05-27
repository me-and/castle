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

    new_task_str = sys.stdin.readline()
    new_task = json.loads(new_task_str)

    if UDA_UNTIL in new_task:
        if 'due' not in new_task:
            print(f'New task with {UDA_UNTIL} but without due')
            sys.exit(1)
        if new_task['status'] != 'recurring':
            new_task['until'] = calc(new_task['due'] + '+' + new_task[UDA_UNTIL], env)
            messages.append(f'Set until to {new_task["until"]}')
    print(json.dumps(new_task))
    print('; '.join(messages))
