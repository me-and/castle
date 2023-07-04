#!/usr/bin/env python3

import asmodeus.hook as h
from asmodeus.taskwarrior import TaskWarrior

if __name__ == '__main__':
    h.on_modify(TaskWarrior(), (h.child_until, h.recur_after, h.due_end_of,
                                h.reviewed_to_entry))
