def stripkeys(ks): reduce ks[] as $k (.;with_entries(select(.key != $k)));
def fmtdate: strptime("%Y%m%dT%H%M%SZ") | mktime | strftime("%a %d %b %H:%M");
