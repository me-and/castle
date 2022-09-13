if [ -d "$HOME/.local/bin" ]; then
    export PATH="$HOME/.local/bin${PATH:+:$PATH}"
fi

if [ -d "$HOME/.local/share/man" ]; then
    export MANPATH="$HOME/.local/share/man${MANPATH:+:$MANPATH}"
fi
if [ -d "$HOME/.local/man" ]; then
    export MANPATH="$HOME/.local/man${MANPATH:+:$MANPATH}"
fi

export LANG=en_GB.UTF-8
export LANGUAGE=en_GB:en
export TIME_STYLE=$'+%a %_d %b  %Y\n%a %_d %b %R'  # see ls(1)
