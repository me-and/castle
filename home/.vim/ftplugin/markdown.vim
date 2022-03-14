" Markdown seems pretty standard on four-spaces for everything.
set expandtab
set tabstop=4

" Only need to set shiftwidth and softtabstop on Vim 7.3 or later; it'll be
" automatically set in vimrc to match tabstop on Vim 7.4.
if version < 704
	set shiftwidth=4
	set softtabstop=4
endif

"Check spelling
set spell
