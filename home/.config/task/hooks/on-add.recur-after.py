#!/usr/bin/env python3

# Based on https://github.com/JensErat/task-relative-recur/blob/master/on-modify.relative-recur
#
# Includes an option for new tasks to handle the case where tasks are created
# using `task log` rather than `task add`.

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

    new_task_str = sys.stdin.readline()
    new_task = json.loads(new_task_str)

    if (UDA_DUE in new_task or UDA_WAIT in new_task) and new_task['status'] == 'completed':
        del new_task['modified']
        try:
            del new_task['start']
        except KeyError:
            pass

        if UDA_DUE in new_task:
            new_task['due'] = calc(new_task['end'] + '+' + new_task[UDA_DUE], env)
            set_due = True
        else:
            set_due = False

        if UDA_WAIT in new_task:
            new_task['wait'] = calc(new_task['end'] + '+' + new_task[UDA_WAIT], env)
            set_wait = True
        else:
            set_wait = False

        new_task['status'] = 'pending'  # Original code would conditionally set this to "waiting", but a change in 2.6.0 is deprecating that status, so hopefully this is the correct solution...
        new_task['entry'] = new_task['end']
        del new_task['uuid']  # Taskwarrior will generate a new one
        del new_task['end']

        # Return the task so it gets added, plus a message about the new task.
        print(new_task_str)
        if set_due and set_wait:
            print(f'Will create new recur-after task due {new_task["due"]} waiting until {new_task["wait"]}')
        elif set_due:
            print(f'Will create new recur-after task due {new_task["due"]}')
        else:
            assert set_wait
            print(f'Will create new recur-after task waiting until {new_task["wait"]}')

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
            subprocess.run(['task', 'rc.verbose=nothing', 'import', '-'], input=json.dumps(new_task), encoding='utf-8', check=True)
    else:
        # Return the task unaltered
        print(new_task_str)
