# Normally this is run only for non-login interactive shells, but this script
# is also called from .bash_profile, which is run for all login shells, so it
# should be ready to handle all scenarios.  There's more in common than there
# is different!

# If Home Manager session variables are configured, use them before doing
# anything else.  In particular, it can set things like PYTHONPATH, so I want
# to make sure my PYTHONPATH is set later.
if [[ -f ~/.nix-profile/etc/profile.d/hm-session-vars.sh && -r ~/.nix-profile/etc/profile.d/hm-session-vars.sh ]]; then
	. ~/.nix-profile/etc/profile.d/hm-session-vars.sh
fi

# Set up standard paths and language information that I want regardless of
# whether this is an interactive session or not.
add_to_path () {
	# This is a bit convoluted to ensure that paths are added to the front of
	# PATH in the order they're given as arguments.
	local -n path="$1"
	shift
	local p
	local to_prepend
	for p; do
		if [[ :"$path": != *:"$p":* ]]; then
			to_prepend="${to_prepend:+$to_prepend:}$p"
		fi
	done
	if [[ "$to_prepend" ]]; then
		path="$to_prepend${path:+:$path}"
	fi
}
add_to_path PATH ~/.local/bin ~/.nix-profile/bin

add_to_path PYTHONPATH ~/.local/lib/python3/my-packages

: "${LANG:=en_GB.UTF-8}"
: "${LANGUAGE:=en_GB:en}"
: "${TIME_STYLE:=$'+%a %_d %b  %Y\n%a %_d %b %R'}"  # see ls(1)

if [[ "$OSTYPE" = cygwin ]]; then
	# Set up GH_PATH so GitHub CLI knows what to do.
	# https://github.com/cli/cli/issues/6950#issuecomment-1457278881
	: "${GH_PATH:=gh}"

	# Set BROWSER so programs know how to open websites from Cygwin: delegate
	# to Windows via cygstart.
	: "${BROWSER:=cygstart}"
elif [[ -e /proc/sys/fs/binfmt_misc/WSLInterop || -e /proc/sys/fs/binfmt_misc/WSLInterop-late ]]; then
	# If BROWSER hasn't already been set somehow, check wslview is available,
	# and set BROWSER to delegate to that.
	if [[ ! -v BROWSER ]] && command -v wslview >/dev/null; then
		BROWSER=wslview
	fi
fi

export PATH PYTHONPATH LANG LANGUAGE TIME_STYLE GH_PATH BROWSER

# If this isn't an interactive session, bail out before doing anything more
# expensive.
if [[ "$-" != *i* ]]; then
	return
fi

# Function for neater wrapping of messages various.  Use with a here document
# or here string.
: "${MAX_MESSAGE_WIDTH:=79}"
if command -v fmt >/dev/null; then
	wrap_message () {
		if [[ -t 0 ]]; then
			wrap_message <<<'wrap_message has a terminal on stdin, did you miss a redirect?'
			return 1
		fi
		local -i target_width screen_width
		screen_width="${COLUMNS:-79}"
		target_width="$((screen_width>MAX_MESSAGE_WIDTH ? MAX_MESSAGE_WIDTH : screen_width))"
		fmt -cuw"$target_width"
	}
else
	wrap_message () {
		if [[ -t 0 ]]; then
			wrap_message <<<'wrap_message has a terminal on stdin, did you miss a redirect?'
			return 1
		fi
		cat
	}
	wrap_message <<<'fmt unavailable' >&2
fi

# Function for truncating a message so it fits on one line.
cut_message () {
	if (( "${#1}" > COLUMNS )); then
		printf '%s\n' "${1::COLUMNS-3}..."
	else
		printf '%s\n' "$1"
	fi
}

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

# Source the first file of a list.  Return the return code of the sourced file
# if one was found, or 69 otherwise.
_bashrc_source_first () {
	local f rc
	for f; do
		if [[ -r "$f" ]]; then
			. "$f"
			rc="$?"
			if (( rc != 0 )); then
				wrap_message <<<"$f returned $rc" >&2
			fi
			return "$rc"
		fi
	done
	return 69  # EX_UNAVAILABLE
}

# Enable bash completion, but only if it hasn't been enabled already -- it's
# done automatically in Cygwin and is slow, so we don't want it twice!
if [[ -z "$BASH_COMPLETION" &&
			-z "$BASH_COMPLETION_COMPAT_DIR" &&
			-z "$BASH_COMPLETION_VERSINFO" ]] &&
		! shopt -oq posix; then
	_bashrc_source_first /etc/bash_completion \
			/usr/local/share/bash-completion/bash_completion \
			/usr/local/etc/bash_completion \
			/usr/share/bash-completion/bash_completion ||
		wrap_message <<<'bash_completion unavailable' >&2
fi

# Enable fzf, but only if it hasn't been enabled already, and this isn't Cygwin
# (where support is sufficiently limited that I'd rather not have it).
if [[ "$OSTYPE" != cygwin ]] && ! type -t fzf-file-widget >/dev/null 2>&1; then
	_bashrc_source_first \
			~/.fzf.bash \
			/usr/share/doc/fzf/examples/key-bindings.bash \
			"$(fzf-share 2>/dev/null)/key-bindings.bash" ||  # NixOS
		wrap_message <<<'fzf unavailable' >&2
fi

# Make less more friendly.
if command -v lesspipe >/dev/null; then
	# Seen on Debian.
	eval "$(lesspipe)"
elif command -v lesspipe.sh >/dev/null; then
	# Seen on CentOS.
	LESSOPEN="| $(command -v lesspipe.sh) %s"
	export LESSOPEN
elif [[ "$OSTYPE" = cygwin ]]; then
	# We know it doesn't exist on Cygwin, so don't bother erroring.
	:
else
	wrap_message <<<'lesspipe unavailable' >&2
fi

# Set up Homeshick.
if [[ -r ~/.homesick/repos/homeshick/homeshick.sh ]]; then
	. ~/.homesick/repos/homeshick/homeshick.sh
else
	wrap_message <<<'homeshick unavailable' >&2
fi

# Set up PS1.
if [[ -f ~/.homesick/repos/bash-git-prompt/gitprompt.sh ]]; then
	. ~/.homesick/repos/bash-git-prompt/gitprompt.sh
elif [[ -f /usr/local/opt/bash-git-prompt/share/gitprompt.sh ]]; then
	. /usr/local/opt/bash-git-prompt/share/gitprompt.sh
else
	wrap_message <<<'bash-git-prompt unavailable' >&2
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
alias ls='ls --color=auto -hv'
alias grep='grep --color=auto'

# Set up jq to look for my library files.
alias jq='jq -L ~/.local/lib/jq'

# Editors.
if command -v vim >/dev/null; then
	export EDITOR=vim
	export VISUAL=vim
else
	export EDITOR=vi
	export VISUAL=vi
fi

# Utility function to make tracing other Bash functions easier.
tracewrap () {
	local -
	set -x
	"$@"
}

# When calling cscope, I generally want some useful default arguments: -k
# ignores the standard include directories (I'm rarely interested in those
# anyway), -R recurses into directories, -q builds a reverse-lookup indices for
# speed, and -b stops cscope launching its interactive mode (why would I want
# that when I can launch vim directly!?).
alias cscope='cscope -kRqb'

# Simple random number generator.
rand () {
	local -i lo hi range
	case "$#" in
		1)	lo=1
			hi="$1"
			;;
		2)	lo="$1"
			hi="$2"
			;;
		*)	wrap_message >&2 <<-'EOF'
				Specify either `rand <lo> <hi>` to choose a number between <lo>
				and <hi>, or `rand <hi>` to choose a number between 1 and <hi>.
				EOF
			return 64  # EX_USAGE
			;;
	esac
	(( range = hi - lo + 1 ))
	echo $(( (SRANDOM % range) + lo ))
}
rand_ephemeral_port () { rand 49152 65535; }

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

if command -v gh >/dev/null && [[ "$BASH_COMPLETION_VERSINFO" ]]; then
	# Use gh completion.
	eval "$(gh completion -s bash)"
fi

# bashwrap function: given a function name and code to run before and/or after,
# wrap the existing function with the code that comes before and after.  The
# before and after code is taken literally and eval'd, so it can do things like
# access "$@" and indeed change "$@" by using shift or set or similar.
bashwrap () {
	local command beforecode aftercode type unset_extglob n
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
			wrap_message <<<"bashwrap doesn't (yet) know how to handle aliases" >&2
			return 69  # EX_UNAVAILABLE
			;;
		keyword)
			wrap_message <<<'bashwrap cannot wrap Bash keywords' >&2
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
			while declare -Fp -- "$innerfuncname" &>/dev/null; do
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
			wrap_message <<<"Nothing called ${command@Q} found to wrap" >&2
			return 64  # EX_USAGE
			;;
		*)
			wrap_message <<<"Unexpected object type $type" >&2
			return 70  # EX_SOFTWARE
			;;
	esac
}

# Wrapper to provide an editor function that will work even if the executable
# doesn't exist.
editor () {
	local cmd

	for cmd in "$VISUAL" "$EDITOR"; do
		if [[ "$cmd" ]]; then
			if [[ "$cmd" = editor ]]; then
				# Handle `editor` specially, as otherwise we get infinite
				# recursion into this function.
				command editor "$@"
			else
				"$cmd" "$@"
			fi
			return "$?"
		fi
	done

	if command -v editor >/dev/null; then
		# There's an editor executable, so use that.
		command editor "$@"
		return "$?"
	fi

	for cmd in vim vi nano pico; do
		if type -t "$cmd" >/dev/null; then
			"$cmd" "$@"
			return "$?"
		fi
	done

	# If we get to this point, we haven't found any editor to run!
	wrap_message <<<'No editor found!' >&2
	return 127
}

# Import local .bashrc files if they exist.
if [[ -d ~/.bashrc.d && -r ~/.bashrc.d && -x ~/.bashrc.d ]]; then
	for file in ~/.bashrc.d/*; do
		if [[ -f "$file" && -r "$file" ]]; then
			. "$file"
		fi
	done
fi

# vim: ft=bash noet ts=4
