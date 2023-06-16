#!/usr/bin/env python3

import taskwarrior as tw

if __name__ == '__main__':
    tw.on_add((tw.due_end_of, tw.recur_after, tw.child_until, tw.reviewed, tw.inbox))
