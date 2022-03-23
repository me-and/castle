This repo tracks the [Homeshick][] files for my dotfiles.

I don't expect anyone other than me to want to use this repo as-is, although you're welcome to if you want!  I suspect it's more useful for people to browse the repo and copy bits they think might be useful to them.  That said, if you _do_ want to use my setup wholesale, you'll need to set up Homeshick and the other repos this builds on.  To do that, from a Bash prompt, run:

    git clone https://github.com/andsens/homeshick ~/.homesick/repos/homeshick
    . ~/.homesick/repos/homeshick
    homeshick clone me-and/castle
    homeshick clone magicmonty/bash-git-prompt
    homeshick clone junegunn/vim-plug
    . ~/.bashrc
    refresh-vim-plugins

[Homeshick]: https://github.com/andsens/homeshick
