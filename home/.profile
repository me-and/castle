if [ -d "$HOME/.local/bin" ]; then
    PATH="$HOME/.local/bin${PATH:+:}${PATH}"
fi

if [ -d "$HOME/.local/man" ]; then
    MANPATH="$HOME/.local/man${MANPATH:+:}${MANPATH}"
fi

LANG=en_GB.UTF-8
LANGUAGE=en_GB:en

case "$(hostname)" in
    *.tastycake.net)
        exec screen -xRR ;;
esac
