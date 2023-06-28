#!/usr/bin/env python3

import taskwarrior as tw

if __name__ == '__main__':
    tw.on_modify((tw.due_end_of, tw.recur_after, tw.child_until, tw.reject_colon_in_project))
