# Remove a sequence of keys from an object.
#
# jq 'stripkeys("alpha", "beta", "gamma")'
#    {"alpha": 123, "beta": 456, "zeta" 789}
# => {"zeta": 789}
def stripkeys(ks): reduce ks as $k (.;del(.[$k]));

# Format a UTC date in a more human readable format.  This seems to have some
# odd handling of timezones that I've never managed (or needed) to unpick.
#
# jq 'map(fmtutcdate)'
#    ["2023-08-24T12:47:12Z", "20000101T0000"]
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
                            end);
