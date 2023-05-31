#!/usr/bin/env python3

import taskwarrior as tw

if __name__ == '__main__':
    tw.on_add(tw.on_add_recur_after)
