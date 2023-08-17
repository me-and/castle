def stripkeys(ks): with_entries(select([.key] | inside(ks) | not));
def fmtdate: gsub("[-:]|Z$"; "") | strptime("%Y%m%dT%H%M%S") | mktime | strftime("%a %d %b %Y %H:%M");
