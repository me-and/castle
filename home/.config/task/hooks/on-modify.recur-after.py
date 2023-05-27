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

    original = json.loads(sys.stdin.readline())
    modified_str = sys.stdin.readline()
    modified = json.loads(modified_str)

    if (UDA_DUE in original or UDA_WAIT in original) and original['status'] != 'completed' and modified['status'] == 'completed':
        del original['modified']
        try:
            del original['start']
        except KeyError:
            pass

        if UDA_DUE in original:
            original['due'] = calc(modified['end'] + '+' + original[UDA_DUE], env)
            set_due = True
        else:
            set_due = False

        if UDA_WAIT in original:
            original['wait'] = calc(modified['end'] + '+' + original[UDA_WAIT], env)
            set_wait = True
        else:
            set_wait = False

        original['status'] = 'pending'  # Original code would conditionally set this to "waiting", but a change in 2.6.0 is deprecating that status, so hopefully this is the correct solution...
        original['entry'] = modified['end']
        del original['uuid']  # Taskwarrior will generate a new one

        # Return the modified task so the modification takes effect, plus a message about the new task.
        print(modified_str)
        if set_due and set_wait:
            print(f'Will create new recur-after task due {original["due"]} waiting until {original["wait"]}')
        elif set_due:
            print(f'Will create new recur-after task due {original["due"]}')
        else:
            assert set_wait
            print(f'Will create new recur-after task waiting until {original["wait"]}')

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
            subprocess.run(['task', 'rc.verbose=nothing', 'import', '-'], input=json.dumps(original), encoding='utf-8', check=True)
    else:
        # Return the modified task so the modification takes effect
        print(modified_str)
