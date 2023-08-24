def stripkeys(ks): reduce ks as $k (.;del(.[$k]));
def fmtdate: gsub("[-:]|Z$"; "") | strptime("%Y%m%dT%H%M%S") | mktime | strftime("%a %d %b %Y %H:%M");
def task_fmtdates: reduce ("due", "end", "entry", "modified", "reviewed", "scheduled", "start", "until", "wait") as $key (.; if has($key) then .[$key] |= fmtdate else . end);
