#!/usr/bin/env python3

from asmodeus.hook import on_modify, child_until, recur_after, due_end_of

if __name__ == '__main__':
    on_modify((due_end_of, recur_after, child_until))
