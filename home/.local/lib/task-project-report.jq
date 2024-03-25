def csi: "\u001b[";
def sgr(attrs): csi + ([attrs] | join(";")) + "m";
def colour(c): sgr(c) + . + sgr(0);
def red: colour(31);
def green: colour(32);
def yellow: colour(33);
def blue: colour(34);
def bwhite: colour(97);
def bold: colour(1);

def task_ident:
        if (.id // 0) == 0
        then .uuid[:8]
        else .id | tostring
        end;

def parse_date: strptime("%Y%m%dT%H%M%SZ");

# Not sure why this works, but it seems to...
def fix_dst: mktime | gmtime;
def fix_dst_and_round_up_end_of_day:
        (mktime | gmtime) as $fixed
        | if $fixed[3:6] == [23, 59, 59]
          then mktime + 1 | gmtime
          else $fixed
          end;

def format_date:
        if .[3:6] == [0, 0, 0]
        then strftime("%a %-d %b %Y")
        else strftime("%a %-d %b %Y %R")
        end;
def format_tags:
        if has("tags")
        then .tags
             | map("+" + .)
             | join(" ")
             | yellow
        else ""
        end;
def format_due:
        if has("due")
        then .due | parse_date | fix_dst_and_round_up_end_of_day | format_date | red
        else ""
        end;
def format_wait:
        if has("wait")
        then .wait
             | parse_date
             | if mktime < now
               then ""
               else fix_dst | format_date | green
               end
        else ""
        end;
def format_annotations:
        if has("annotations")
        then .annotations | "[\(length)]"
        else ""
        end;
def format_dep(by_uuid):
        by_uuid[.] // {ident: .[:8]}
        | if has("description")
          then .result = .ident + " " + .description
          else .result = .ident
          end
        | if .status == "completed" or .status == "deleted"
          then .result | green
          elif .status == "pending"
          then .result | yellow
          else .result | red
          end;
def format_deps(by_uuid):
        if has("depends")
        then "["
             + (.depends
                | map(by_uuid[.] // {ident: .[:8]}
                      | if has("description")
                        then .result = .ident + " " + .description
                        else .result = .ident
                        end
                      | if .status == "completed" or .status == "deleted"
                        then .result |= green | .sortorder = 2
                        elif .status == "pending"
                        then .result |= yellow | .sortorder = 1
                        else .result |= red | .sortorder = 0
                        end
                      )
                | sort_by(.sortorder)
                | map(.result)
                | join("; "))
             + "]"
        else ""
        end;
def format_ident: .ident | lpad(10) | green;
def format_description:
        if .priority == null
        then .
        elif .priority == "L"
        then .description |= blue
        elif .priority == "M"
        then .description |= yellow
        elif .priority == "H"
        then .description |= red
        else error("Unexpected priority \(.priority)")
        end
        | if .tags // [] | contains(["next"])
          then .description |= bold
          else .
          end
        | .description;

map(.ident = task_ident)
| INDEX(.[]; .uuid) as $by_uuid
| map(select(.status != "completed"
             and .status != "deleted"
             and .status != "recurring")
      | {project: (.project // "No project"),
         description: [format_ident,
                       format_description,
                       format_annotations,
                       format_tags,
                       format_wait,
                       format_due,
                       format_deps($by_uuid)
                       ]
                      | map(select(length > 0))
                      | join(" ")
        }
      )
| index_by(.project)
| map_values(map(.description) | join("\n"))
| to_entries[]
| .key |= bwhite
| "\(.key)\n\(.value)\n"

# vim: et
