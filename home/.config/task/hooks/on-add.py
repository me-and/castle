#!/usr/bin/env python3
import subprocess

import asmodeus.hook as h
from asmodeus.taskwarrior import TaskWarrior

if __name__ == '__main__':
    tw = TaskWarrior()
    hooks: list[h.OnAddHook] = [h.child_until,
                                h.recur_after,
                                h.due_end_of,
                                h.reviewed_to_entry,
                                ]
    try:
        # Work systems have a tickets report set up.
        tw.get_dom('rc.report.tickets.filter')
    except subprocess.CalledProcessError:
        # Not work, meaning I want to tag anything as "inbox" if it doesn't
        # already have a tag.
        hooks.append(h.inbox_if_no_tag)
    else:
        # Work, meaning I want to tag anything as "inbox" if it
        # doesn't already have a project.
        hooks.append(h.inbox_if_no_proj)

    h.on_add(tw, hooks)
