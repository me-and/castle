if [ -d "$HOME/bin" ]; then
    PATH="$HOME/bin:$PATH"
fi

if [ -d "$HOME/man" ]; then
    MANPATH="$HOME/man:$MANPATH"
fi

if [ -d "$HOME/info" ]; then
    INFOPATH="$HOME/info:$INFOPATH"
fi

LANG=en_GB.UTF-8
LANGUAGE=en_GB:en
