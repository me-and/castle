#!/usr/bin/env python3

from asmodeus.hook import on_add, inbox, child_until, recur_after, due_end_of
from asmodeus.taskwarrior import TaskWarrior

if __name__ == '__main__':
    on_add(TaskWarrior(), (inbox, child_until, recur_after, due_end_of))
