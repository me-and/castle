if [ -d "$HOME/bin" ]; then
    PATH="$HOME/bin:$PATH"
fi

if [ -d "$HOME/man" ]; then
    MANPATH="$HOME/man:$MANPATH"
fi

if [ -d "$HOME/info" ]; then
    INFOPATH="$HOME/info:$INFOPATH"
fi

if [ -d "$HOME/lib/python3" ]; then
    PYTHONPATH="$HOME/lib/python3/dist-packages:$PYTHONPATH"
fi

LANG=en_GB.UTF-8
LANGUAGE=en_GB:en

case "$(hostname)" in
    *.tastycake.net)
        exec screen -xRR ;;
    *-dev-env.ad.datcon.co.uk)
        exec script -f ~/consolelogs/"$(date +"%Y-%m-%dT%H-%M-%S")"."$USER"."$RANDOM".log
esac
