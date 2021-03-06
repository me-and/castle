override_git_prompt_colors() {
    GIT_PROMPT_THEME_NAME="Custom"

    case "$(hostname)" in
        PC5819)
            if [[ "$(uname -s)" = CYGWIN* ]]; then
                # Cygwin gets one colour scheme...
                HOST_COLOUR="${Green}"
                PWD_COLOUR="${Yellow}"
                TIME_COLOUR="${Blue}"
            elif [[ "$(uname -s)" = Linux ]]; then
                # ...WSL gets another.
                HOST_COLOUR="${Red}"
                PWD_COLOUR="${Yellow}"
                TIME_COLOUR="${Blue}"
            else
                HOST_COLOUR="${White}"
                PWD_COLOUR="${White}"
                TIME_COLOUR="${White}"
            fi
            ;;

        pc5819-new-dev-env|pc5819-new-dev-env.*)
            HOST_COLOUR="${Yellow}"
            PWD_COLOUR="${Red}"
            TIME_COLOUR="${Green}"
            ;;

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

    GIT_PROMPT_START_USER="\n_LAST_COMMAND_INDICATOR_ ${HOST_COLOUR}\u@\h ${PWD_COLOUR}\w${ResetColor}"
    GIT_PROMPT_START_ROOT="$GIT_PROMPT_START_USER"

    GIT_PROMPT_END_USER="\n${TIME_COLOUR}\D{%a %e %b %R}${ResetColor} \$ "
    GIT_PROMPT_END_ROOT="$GIT_PROMPT_END_USER"


    # The Git prompt on Cygwin and WSL is painfully slow, so disable it.
    if [[ "$(uname -s)" == CYGWIN* ]] || grep -qi microsoft /proc/version; then
        GIT_PROMPT_DISABLE=1
    fi
}

prompt_callback() {
    gp_set_window_title "\h:\w"
}

reload_git_prompt_colors "Custom"
