# This script based in part on the one that was distributed with Debian

rc=0

# Bail out if we're not running interactively.
if [[ $- != *i* ]]; then
    return
fi

# Don't add lines that start with a space or which duplicate the previous line
# to the bash history.
HISTCONTROL=ignoreboth

# Append to the history file rather than overwriting it.
shopt -s histappend

# Check the window size after each command, updating LINES and COLUMNS.
shopt -s checkwinsize

# Expand ** for directory parsing.
shopt -s globstar

# Don't exit if there are running jobs.
shopt -s checkjobs

# Enable bash completion, but only if it hasn't been enabled already -- it's
# done automatically in Cygwin and is slow, so we don't want it twice!
if [[ -z "$BASH_COMPLETION" &&
            -z "$BASH_COMPLETION_COMPAT_DIR" &&
            -z "$BASH_COMPLETION_VERSINFO" ]] &&
        ! shopt -oq posix; then
    enabled_bash_completion=
    for f in /etc/bash_completion \
        /usr/local/share/bash-completion/bash_completion \
        /usr/local/etc/bash_completion \
        /usr/share/bash-completion/bash_completion
    do
        if [[ -r "$f" ]]; then
            . "$f"
            enabled_bash_completion=yes
            break
        fi
    done

    if [[ -z $enabled_bash_completion ]]; then
        echo 'bash_completion unavailable' >&2
        (( rc |= 0x1 ))
    fi
fi
unset f
unset enabled_bash_completion

# Enable fzf, but only if it hasn't been enabled already, and this isn't Cygwin
# (where support is sufficiently limited that I'd rather not have it).
if [[ $OSTYPE != "cygwin" ]] && ! type -t fzf-file-widget >/dev/null 2>&1; then
    if [[ -r ~/.fzf.bash ]]; then
        . ~/.fzf.bash
    elif [[ -r /usr/share/doc/fzf/examples/key-bindings.bash ]]; then
        # Debian's fzf package, rather than a user-local install.
        . /usr/share/doc/fzf/examples/key-bindings.bash
    else
        echo 'fzf unavailable' >&2
        (( rc |= 0x20 ))
    fi
fi

# Enable GAM (https://github.com/jay0lee/GAM) in the unlikely event it's
# installed.
[[ -d ~/.gam && -x ~/.gam/gam ]] && gam() { "/home/adam/.gam/gam" "$@" ; }

# Check for the existance of pgrep, since a bunch of other things rely on it
# and it's easier to complain once than complain every time.
if ! command -v pgrep >/dev/null; then
    echo 'pgrep unavailable' >&2
    (( rc |= 0x40 ))
fi

# Make less more friendly.
if command -v lesspipe >/dev/null; then
    # Seen on Debian.
    eval "$(lesspipe)"
elif command -v lesspipe.sh >/dev/null; then
    # Seen on CentOS.
    LESSOPEN="| $(command -v lesspipe.sh) %s"
    export LESSOPEN
elif [[ "$(uname -s)" = CYGWIN* ]]; then
    # We know it doesn't exist on Cygwin, so don't bother erroring.
    :
else
    echo 'lesspipe unavailable' >&2
    (( rc |= 0x2 ))
fi

# Set up Homeshick.
if [[ -r ~/.homesick/repos/homeshick/homeshick.sh ]]; then
    . ~/.homesick/repos/homeshick/homeshick.sh
else
    echo 'homeshick unavailable' >&2
    (( rc |= 0x4 ))
fi

# Set up PS1.
if [[ -f ~/.homesick/repos/bash-git-prompt/gitprompt.sh ]]; then
    . ~/.homesick/repos/bash-git-prompt/gitprompt.sh
elif [[ -f /usr/local/opt/bash-git-prompt/share/gitprompt.sh ]]; then
    . /usr/local/opt/bash-git-prompt/share/gitprompt.sh
else
    echo 'bash-git-prompt unavailable' >&2
    PS1='\[\e]0;\h:\w\a\]\n\u@\h \w\n\$ '
    (( rc |= 0x8 ))
fi

# Colours for ls
if command -v dircolors >/dev/null; then
    if [[ -r ~/.dircolors ]]; then
        eval "$(dircolors -b ~/.dircolors)"
    else
        eval "$(dircolors -b)"
    fi
fi

# Set up aliases to use colours.
if command -v gls >/dev/null; then
    # On macOS with coreutils installed with "g" prefix (as is the default for
    # Brew's coreutils package), default to using that.
    alias ls='gls --color=auto'
    alias dir='gdir --color=auto'
    alias vdir='gvdir --color=auto'
else
    alias ls='ls --color=auto'
    alias dir='dir --color=auto'
    alias vdir='vdir --color=auto'
fi
alias grep='grep --color=auto'
alias egrep='egrep --color=auto'
alias fgrep='fgrep --color=auto'

# Editors.
if command -v vim >/dev/null; then
    export EDITOR=vim
    export VISUAL=vim
else
    export EDITOR=vi
    export VISUAL=vi
fi

# Set up an alias for viewing diffs with columns at screen width.
alias coldiff='diff -yW$COLUMNS'

# When calling cscope, I generally want some useful default arguments: -k
# ignores the standard include directories (I'm rarely interested in those
# anyway), -R recurses into directories, -q builds a reverse-lookup indices for
# speed, and -b stops cscope launching its interactive mode (why would I want
# that when I can launch vim directly!?).
alias cscope='cscope -kRqb'

# Simple random number generator.  Not even vaguely secure.
function rand {
    echo $(( (RANDOM % $1) + 1 ))
}

# https://twitter.com/chris__martin/status/420992421673988096
alias such=git
alias very=git
alias wow='git status'

# Important
alias fucking=sudo

# Fast downloads.
alias snarf='aria2c -x16 -s16'

set_terminal_title () {
    echo -ne '\e]0;'"$*"'\a'
}

# Set up ssh-agent.  Based on
# https://www.cygwin.com/ml/cygwin/2001-06/msg00537.html
if [[ "$HOSTTYPE" ]]; then
    ssh_agent_pid_file=~/.ssh/ssh-agent."$HOSTTYPE".pid
else
    ssh_agent_pid_file=~/.ssh/ssh-agent.pid
fi

if command -v ssh-agent &>/dev/null; then
    function start_ssh_agent {
        # Set up the terminal title so KeePass can recognise the window and
        # thus the correct password to use when prompted by ssh-add.
        set_terminal_title "$(hostname):"

        rm -f "$ssh_agent_pid_file" || return 1

        # Create the file with a umask to ensure only the current user can
        # read/write to it.  The ssh-agent call must be outside the umask as
        # otherwise (at least on CentOS) it won't work.
        ssh-agent | ( umask 0177 && sed 's/^echo/#echo/' >"$ssh_agent_pid_file" )

        . "$ssh_agent_pid_file"
        ssh-add
    }

    function ensure_ssh_agent_running {
        if [[ -r "$ssh_agent_pid_file" ]]; then
            . "$ssh_agent_pid_file"
            command -v pgrep >/dev/null || return 1  # Can't check w/o pgrep
            ssh_agent_running=
            while read -r ssh_agent_pid; do
                if [[ "$ssh_agent_pid" = "$SSH_AGENT_PID" ]]; then
                    # The recorded ssh-agent PID in the $ssh_agent_pid_file
                    # corresponds with a running ssh-agent instance.
                    ssh_agent_running=Yes
                    break
                fi
            done < <(pgrep ssh-agent)
            [[ -n "$ssh_agent_running" ]] || start_ssh_agent
            unset ssh_agent_running
        else
            start_ssh_agent
        fi
    }

    ensure_ssh_agent_running
else
    echo 'ssh-agent unavailable' >&2
    (( rc |= 0x10 ))
fi

# Import local .bashrc files if they exist.
if [[ -d ~/.bashrc.d && -r ~/.bashrc.d && -x ~/.bashrc.d ]]; then
    for file in ~/.bashrc.d/*; do
        if [[ -f "$file" && -r "$file" ]]; then
            . "$file"
        fi
    done
fi

# WSL will start in the wrong directory.  Fix that.
cd ~

return "$rc"
