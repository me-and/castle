# Remove a sequence of keys from an object.
#
# jq 'stripkeys("alpha", "beta", "gamma")'
#    {"alpha": 123, "beta": 456, "zeta" 789}
# => {"zeta": 789}
def stripkeys(ks): reduce ks as $k (.;del(.[$k]));

# Format a UTC date in a more human readable format.  This seems to have some
# odd handling of timezones that I've never managed (or needed) to unpick, so
# it enforces the string ending in "Z" to ensure we're really getting something
# in UTC (or at least we're deliberately lying).
#
# jq 'map(fmtutcdate)'
#    ["2023-08-24T12:47:12Z", "20000101T0000Z"]
# => ["Thu 24 Aug 2023 13:47:12", "Sat 01 Jan 2000 00:00"]
def fmtutcdate: gsub("[-:]"; "")
                | if test("T\\d{6}")
                  then strptime("%Y%m%dT%H%M%SZ")
                       | mktime
                       | strftime("%a %d %b %Y %H:%M:%S")
                  else strptime("%Y%m%dT%H%MZ")
                       | mktime
                       | strftime("%a %d %b %Y %H:%M")
                  end;

# Format the date fields in a Taskwarrior export
def task_fmtdates: reduce ("due",
                           "end",
                           "entry",
                           "modified",
                           "reviewed",
                           "scheduled",
                           "start",
                           "until",
                           "wait")
                   as $key (.;
                            if has($key)
                            then .[$key] |= fmtutcdate
                            else .
                            end)
                   | if has("annotations")
                     then .annotations |= map(.entry |= fmtutcdate)
                     else .
                     end;

# Compare two lists of tasks and print out the ones that are different.  Use
# as, for example:
#
#     { task export; ssh user@server task export; } | jq -s 'task_compare'
def task_compare:
        map(group_by(.uuid)
            | INDEX(.[]; .[0].uuid))
        as [$l, $r]
        | reduce ($l + $r | keys)[]
          as $key ({};
                   .[$key] = [($l[$key] // []),
                              ($r[$key] // [])])
        | map_values(select(.[0] != .[1])
                     | map_values(if length == 0 then null else if length > 1 then {problem: "multiple tasks", tasks: .} else .[0] end end)
                     );

# Compare two objects and print the differences between them.
#
# jq 'diffobjs(.[0]; .[1])'
#    [{"alpha": 123, "beta": 456}, {"alpha": 123, "beta": 567, "gamma": 890}]
# => {"beta": [456, 567], "gamma": [null, 890]}
def diffobjs(l; r): [l, r] as [$l, $r]
                    | reduce ($l + $r | keys | .[])
                      as $key ({};
                               if $l[$key] != $r[$key]
                               then .[$key] = [$l[$key], $r[$key]]
                               else .
                               end);

# Compare two lists of tasks and print the differences between them.  Use as, for example:
#
#     { task export; ssh user@server task export; } | jq -s 'task_diffs'
def task_diffs: task_compare | map_values(diffobjs(.[0]; .[1]));

# Compare two tasks, including stripping keys that don't want to be compared.
# Really just a shortcut for `stripkeys` and `task_diffs`.
def task_diffs_strip(ks): map(map(stripkeys(ks))) | task_diffs;
