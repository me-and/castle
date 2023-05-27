#!/usr/bin/env python3

import subprocess
import json
import re
import sys


DATETIME_CALC_RE = re.compile(r'^\d\d\d\d-\d\d-\d\dT\d\d:\d\d:\d\d$')


# Based on https://github.com/JensErat/task-relative-recur/blob/master/on-modify.relative-recur
def calc(statement):
    p = subprocess.run(['task', 'rc.verbose=nothing', 'rc.date.iso=yes', 'calc', statement], stdout=subprocess.PIPE, check=True, encoding='utf-8')
    return p.stdout.rstrip()


def calc_datetime(statement):
    calc_str = calc(statement)
    if not DATETIME_CALC_RE.match(calc_str):
        raise RuntimeError(f"{calc_str:r} doesn't look like a calculated datetime")
    return calc(statement)


def calc_bool(statement):
    calc_str = calc(statement)
    if calc_str == 'false':
        return False
    elif calc_str == 'true':
        return True
    else:
        raise RuntimeError(f"{calc_str:r} neither 'false' nor 'true'")


if __name__ == '__main__':
    original = json.loads(sys.stdin.readline())
    modified = json.loads(sys.stdin.readline())

    messages = []

    for time_field in ('due', 'until'):
        if time_field in modified:
            # Convert the JSON time to local time
            datetime_str = calc_datetime(modified[time_field])
            date_str, time_str = datetime_str.split('T')

            if time_field == 'due' and time_str == '00:00:00':
                # If the task is due at midnight, pull it back to 23:59:59 the day
                # before.
                modified[time_field] = calc_datetime(f'{datetime_str} - PT1S')
                messages.append(f'Changed {time_field} from {datetime_str} to {modified[time_field]}')
    print(json.dumps(modified))
    print('; '.join(messages))
