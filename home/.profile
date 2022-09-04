if [ -d "$HOME/.local/bin" ]; then
    PATH="$HOME/.local/bin${PATH:+:}${PATH}"
fi

if [ -d "$HOME/.local/man" ]; then
    MANPATH="$HOME/.local/man${MANPATH:+:}${MANPATH}"
fi
if [ -d "$HOME/.local/share/man" ]; then
	MANPATH="$HOME/.local/share/man${MANPATH:+:}${MANPATH}"
fi

LANG=en_GB.UTF-8
LANGUAGE=en_GB:en
TIME_STYLE=$'+%a %_d %b  %Y\n%a %_d %b %R'  # see ls(1)
