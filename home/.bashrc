# This script based in part on the one that was distributed with Debian

rc=0

# Bail out if we're not running interactively.
if [[ $- != *i* ]]; then
    return
fi

# Don't add lines that start with a space or which duplicate the previous line
# to the bash history.  Do store a whole load of history; computer memory is a
# lot cheaper than my own.
HISTCONTROL=ignoreboth
HISTSIZE=1000
HISTFILESIZE=5000

# Don't use -S automatically when calling `less` from systemctl commands; I
# find it annoying more often than I find it helpful.
export SYSTEMD_LESS=FRXMK

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
    alias ls='gls --color=auto -h'
    alias dir='gdir --color=auto -h'
    alias vdir='gvdir --color=auto -h'
else
    alias ls='ls --color=auto -h -v'
    alias dir='dir --color=auto -h'
    alias vdir='vdir --color=auto -h'
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

if command -v gh >/dev/null; then
    if [[ "$OSTYPE" = cygwin ]]; then
        # Set up GH_PATH so GitHub CLI knows what to do.
        # https://github.com/cli/cli/issues/6950#issuecomment-1457278881
        export GH_PATH=gh
    fi

    if [[ "$BASH_COMPLETION_VERSINFO" ]]; then
        # Use gh completion.
        eval "$(gh completion -s bash)"
    fi
fi

# bashwrap function: given a function name and code to run before and/or after,
# wrap the existing function with the code that comes before and after.  The
# before and after code is taken literally and eval'd, so it can do things like
# access "$@" and indeed change "$@" by using shift or set or similar.
bashwrap () {
    local command beforecode aftercode funcname type unset_extglob n
    local innerfuncname innerfunccode
    local -n varname

    command="$1"
    beforecode="$2"
    aftercode="$3"

    # Check the current state of extglob: this code needs it to be set,
    # but it should be reset to avoid unexpected changes to the global
    # envirnoment.
    if ! shopt -q extglob; then
        unset_extglob=YesPlease
        shopt -s extglob
    fi

    # Tidy the before and after code: trim whitespace from the start and end,
    # and make sure they end with a single semicolon.
    for varname in beforecode aftercode; do
        varname="${varname##+([$'\n\t '])}"
        varname="${varname%%+([$'\n\t '])}"
        if [[ "$varname" ]]; then
            varname="${varname%%+(;)};"
        fi
    done

    # Now finished with extglob.
    if [[ "$unset_extglob" ]]; then shopt -u extglob; fi

    type="$(type -t "$command")"
    case "$type" in
        alias)
            # TODO
            printf "bashwrap doesn't (yet) know how to handle aliases\n" >&2
            return 69  # EX_UNAVAILABLE
            ;;
        keyword)
            printf 'bashwrap cannot wrap Bash keywords\n' >&2
            return 64  # EX_USAGE
            ;;
        builtin|file)
            eval "$command () { $beforecode command $command \"\$@\"; $aftercode }"
            ;;
        function)
            # Keep generating function names until we get to one that doesn't
            # exist.  This allows a function to be wrapped multiple times; the
            # original function will always have the name
            # _bashwrapped_0_<name>.
            n=0
            innerfuncname="_bashwrapped_${n}_$command"
            while declare -pF -- "$innerfuncname" 2> /dev/null; do
                innerfuncname="_bashwrapped_$((++n))_$command"
            done

            # Define a new function with the new function name and the old function
            # code.
            innerfunccode="$(declare -fp -- "$command")"
            eval "${innerfunccode/#$command /$innerfuncname }"

            # Redefine the existing function to call the new function, in
            # between the wrapper code.
            eval "$command () { $beforecode $innerfuncname \"\$@\"; $aftercode }"
            ;;
        '')
            printf 'Nothing called %q found to wrap\n' "$command" >&2
            return 64  # EX_USAGE
            ;;
        *)
            printf 'Unexpected object type %s\n' "$type" >&2
            return 70  # EX_SOFTWARE
            ;;
    esac
}

# Import local .bashrc files if they exist.
if [[ -d ~/.bashrc.d && -r ~/.bashrc.d && -x ~/.bashrc.d ]]; then
    for file in ~/.bashrc.d/*; do
        if [[ -f "$file" && -r "$file" ]]; then
            . "$file"
        fi
    done
fi

return "$rc"

# vim: ft=bash et ts=4
