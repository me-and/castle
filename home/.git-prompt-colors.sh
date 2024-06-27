override_git_prompt_colors() {
	GIT_PROMPT_THEME_NAME="Custom"

	case "$HOSTNAME" in
		*.tastycake.net)
			HOST_COLOUR="${Blue}"
			PWD_COLOUR="${Green}"
			TIME_COLOUR="${Cyan}"
			;;

		*)
			HOST_COLOUR="${White}"
			PWD_COLOUR="${White}"
			TIME_COLOUR="${White}"
			;;

	esac

	if [[ "$OSTYPE" = cygwin ]]; then
		# The Git prompt is painfully slow, particularly for larger repos, so
		# disable it.
		GIT_PROMPT_DISABLE=1

		# Admin prompts on Cygwin don't have EUID 0, so the built-in Bash
		# checks don't work.  Check by testing the output of `id` instead.
		local prompt='$'
		if [[ " $(id -G) " = *' 544 '* ]]; then
			prompt="${Red}#${ResetColor}"
		else
			prompt='$'
		fi

		GIT_PROMPT_END_USER='\n'"$TIME_COLOUR"'\D{%a %e %b %R}'"$ResetColor $SHLVL$prompt "
		GIT_PROMPT_END_ROOT="$GIT_PROMPT_END_USER"
	else
		# '\$' means show '#' if we're root, and '$' otherwise.
		GIT_PROMPT_END_USER='\n'"$TIME_COLOUR"'\D{%a %e %b %R}'"$ResetColor"' $SHLVL\$ '
		GIT_PROMPT_END_ROOT='\n'"$TIME_COLOUR"'\D{%a %e %b %R}'" $Red$SHLVL"'\$'"$ResetColor "
	fi

	GIT_PROMPT_START_USER='\n_LAST_COMMAND_INDICATOR_ '"$HOST_COLOUR"'\u@\h '"$PWD_COLOUR"'\w'"$ResetColor"
	GIT_PROMPT_START_ROOT="$GIT_PROMPT_START_USER"
}

prompt_callback() {
	gp_set_window_title '\h:\w'
}

reload_git_prompt_colors Custom

# vim: ft=bash noet ts=4
