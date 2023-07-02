#!/usr/bin/env python3

from asmodeus.hook import on_modify, child_until, recur_after, due_end_of
from asmodeus.taskwarrior import TaskWarrior

if __name__ == '__main__':
    on_modify(TaskWarrior(), (child_until, recur_after, due_end_of))
