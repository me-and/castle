# This script based in part on the one that was distributed with Debian

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
if [[ -z "$BASH_COMPLETION" ]] && ! shopt -oq posix; then
    if [[ -r /etc/bash_completion ]]; then
        . /etc/bash_completion
    elif [[ -r /usr/local/etc/bash_completion ]]; then
        . /usr/local/etc/bash_completion
    else
        echo 'bash_completion unavailable' >&2
    fi
fi

# Enable fzf.
[[ -r ~/.fzf.bash ]] && . ~/.fzf.bash

# Make less more friendly.
if command -v lesspipe >/dev/null; then  # Debian
    eval "$(lesspipe)"
elif command -v lesspipe.sh >/dev/null; then  # Cygwin
    eval "$(lesspipe.sh)"
else
    echo 'lesspipe unavailable' >&2
fi

# Set up PS1.
if [[ -f ~/.homesick/repos/bash-git-prompt/gitprompt.sh ]]; then
    . ~/.homesick/repos/bash-git-prompt/gitprompt.sh
elif [[ -f /usr/local/opt/bash-git-prompt/share/gitprompt.sh ]]; then
    . /usr/local/opt/bash-git-prompt/share/gitprompt.sh
else
    echo 'bash-git-prompt unavailable' >&2
    PS1='\[\e]0;\h:\w\a\]\n\u@\h \w\n\$ '
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
alias ls='ls --color=auto'
alias dir='dir --color=auto'
alias vdir='vdir --color=auto'
alias grep='grep --color=auto'
alias egrep='egrep --color=auto'
alias fgrep='fgrep --color=auto'

# Editors.
export EDITOR=vim
export VISUAL=vim

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

# Fast downloads.
alias snarf='aria2c -x16 -s16'

# Set up ssh-agent.  Based on
# https://www.cygwin.com/ml/cygwin/2001-06/msg00537.html
if command -v ssh-agent &>/dev/null; then
    function start_ssh_agent {
        (
            umask 0177
            ssh-agent | sed 's/^echo/#echo/' >~/.ssh/ssh-agent
        )
        . ~/.ssh/ssh-agent
        ssh-add
    }

    function ensure_ssh_agent_running {
        if [[ -r ~/.ssh/ssh-agent ]]; then
            . ~/.ssh/ssh-agent
            if [[ $(pgrep ssh-agent) != "$SSH_AGENT_PID" ]]; then
                start_ssh_agent
            fi
        else
            start_ssh_agent
        fi
    }

    ensure_ssh_agent_running
fi

# Import the local bashrc, if it exists.
[[ -r ~/.bashrc_local ]] && . ~/.bashrc_local
