#!/usr/bin/env python3

from asmodeus.hook import on_add, inbox, child_until, recur_after, due_end_of

if __name__ == '__main__':
    on_add(due_end_of, recur_after, child_until, inbox)
