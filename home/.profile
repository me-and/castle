if [ "$BASH_VERSION" ]; then
	echo 'Unexpectedly called .profile rather than .bash_profile' >&2
	. ~/.bash_profile
else
	echo 'Not running in Bash, no profile for this shell!' >&2
fi
