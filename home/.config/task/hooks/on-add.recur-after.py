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

    task_str = sys.stdin.readline()
    task = json.loads(task_str)

    if (UDA_DUE in task or UDA_WAIT in task) and task['status'] == 'completed':
        del task['modified']
        try:
            del task['start']
        except KeyError:
            pass

        if UDA_DUE in task:
            task['due'] = calc(task['end'] + '+' + task[UDA_DUE], env)
            set_due = True
        else:
            set_due = False

        if UDA_WAIT in task:
            task['wait'] = calc(task['end'] + '+' + task[UDA_WAIT], env)
            set_wait = True
        else:
            set_wait = False

        task['status'] = 'pending'  # Original code would conditionally set this to "waiting", but a change in 2.6.0 is deprecating that status, so hopefully this is the correct solution...
        task['entry'] = task['end']
        del task['uuid']  # Taskwarrior will generate a new one
        del task['end']

        # Return the task so it gets added, plus a message about the new task.
        print(task_str)
        if set_due and set_wait:
            print(f'Will create new recur-after task due {task["due"]} waiting until {task["wait"]}')
        elif set_due:
            print(f'Will create new recur-after task due {task["due"]}')
        else:
            assert set_wait
            print(f'Will create new recur-after task waiting until {task["wait"]}')

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
            subprocess.run(['task', 'rc.verbose=nothing', 'import', '-'], input=json.dumps(task), encoding='utf-8', check=True)
    else:
        # Return the task unaltered
        print(task_str)
