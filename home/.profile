if [ -d "$HOME/.local/bin" ]; then
	export PATH="$HOME/.local/bin${PATH:+:$PATH}"
fi

export PYTHONPATH="$HOME/.local/lib/python3/my-packages${PYTHONPATH:+:$PYTHONPATH}"

export LANG=en_GB.UTF-8
export LANGUAGE=en_GB:en
export TIME_STYLE=$'+%a %_d %b  %Y\n%a %_d %b %R'  # see ls(1)
