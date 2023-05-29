#!/usr/bin/env python3

# Based on https://github.com/JensErat/task-relative-recur/blob/master/on-modify.relative-recur

import json
import sys
import subprocess
import os
import tempfile

import psutil

UDA_DUE = 'recurAfterDue'
UDA_WAIT = 'recurAfterWait'

def calc(statement, env):
    p = subprocess.run(['task', 'rc.verbose=nothing', 'rc.date.iso=yes', 'calc', statement], stdout=subprocess.PIPE, check=True, encoding='utf-8', env=env)
    return p.stdout.rstrip() + 'Z'

if __name__ == '__main__':
    env = os.environ.copy()
    env['TZ'] = 'UTC0'

    old_task = json.loads(sys.stdin.readline())
    new_task_str = sys.stdin.readline()
    new_task = json.loads(new_task_str)

    if (UDA_DUE in new_task or UDA_WAIT in new_task) and old_task['status'] != 'completed' and new_task['status'] == 'completed':
        del old_task['modified']
        try:
            del old_task['start']
        except KeyError:
            pass

        if UDA_DUE in old_task:
            old_task['due'] = calc(new_task['end'] + '+' + new_task[UDA_DUE], env)
            set_due = True
        else:
            set_due = False

        if UDA_WAIT in old_task:
            old_task['wait'] = calc(new_task['end'] + '+' + new_task[UDA_WAIT], env)
            set_wait = True
        else:
            set_wait = False

        old_task['status'] = 'pending'  # Original code would conditionally set this to "waiting", but a change in 2.6.0 is deprecating that status, so hopefully this is the correct solution...
        old_task['entry'] = new_task['end']
        del old_task['uuid']  # Taskwarrior will generate a new one

        # Return the modified task so the modification takes effect, plus a message about the new task.
        print(new_task_str)
        if set_due and set_wait:
            print(f'Will create new recur-after task due {old_task["due"]} waiting until {old_task["wait"]}')
        elif set_due:
            print(f'Will create new recur-after task due {old_task["due"]}')
        else:
            assert set_wait
            print(f'Will create new recur-after task waiting until {old_task["wait"]}')

        # Wait for taskwarrior to finish so the new task can be created
        sys.stdout.flush()
        if (0 < os.fork()):
            sys.exit(0)
        else:
            # Taskwarrior waits for stdout to close
            try:
                os.close(sys.stdout.fileno())
            except OSError:  # Expected
                pass

            psutil.Process().parent().wait()

            # Import the new task
            subprocess.run(['task', 'rc.verbose=nothing', 'import', '-'], input=json.dumps(old_task), encoding='utf-8', check=True)
    else:
        # Return the modified task so the modification takes effect
        print(new_task_str)
