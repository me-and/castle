if [[ -r ~/.bashrc ]]; then
	. ~/.bashrc
else
	echo 'No .bashrc found!' >&2
fi

# vim: ft=bash noet ts=8
