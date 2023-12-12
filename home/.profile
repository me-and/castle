export PATH="$HOME/.local/bin${PATH:+:$PATH}"

export PYTHONPATH="$HOME/.local/lib/python3/my-packages${PYTHONPATH:+:$PYTHONPATH}"

export LANG=en_GB.UTF-8
export LANGUAGE=en_GB:en
export TIME_STYLE=$'+%a %_d %b  %Y\n%a %_d %b %R'  # see ls(1)

if [ "$OSTYPE" = cygwin ]; then
	# Set up GH_PATH so GitHub CLI knows what to do.
	# https://github.com/cli/cli/issues/6950#issuecomment-1457278881
	export GH_PATH=gh

	# Set BROWSER so programs know how to open websites from Cygwin: delegate
	# to Windows via cygstart.
	export BROWSER=cygstart
fi

export _DOTPROFILE_PROCESSED=Yes
