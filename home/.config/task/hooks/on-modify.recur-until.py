#!/usr/bin/env python3

import taskwarrior as tw

if __name__ == '__main__':
    tw.on_modify(tw.on_modify_child_until)
