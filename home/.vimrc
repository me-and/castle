" Stop using vi-compatible settings!
set nocompatible

" Keep using the current indent level when starting a new line.
set autoindent

" Make backspace useful.
set backspace=indent,eol,start

" Always have a status line and the current position in the file.
set laststatus=2
set ruler

" Always have some context above and below the cursor.
set scrolloff=3

" Show details of selected text when selecting it.
set showcmd

" Use incremental search.
set incsearch

" Tab completion of Vim commands.
set wildmenu
set wildmode=longest,list

" Put the relative line number in the margin, with the current line listed
" with its current line number.
set number
set relativenumber
highlight LineNr ctermfg=gray

" Default shell syntax, per `:help ft-sh-syntax`
let g:is_bash = 1

" Allow toggling between relative numbers and absolute line numbers by
" pressing ^N.
function! NumberToggle()
  if(&relativenumber == 1)
    set norelativenumber
    set number
    highlight LineNr ctermfg=darkgray
  else
    set relativenumber
    highlight LineNr ctermfg=gray
  endif
endfunc
nnoremap <C-n> :call NumberToggle()<CR>

" Show whitespace in a useful fashion.  Note this disables the `linebreak`
" setting, so to `set linebreak` you'll also need to `set nolist`.
set list listchars=tab:\ \ ,trail:-

" When entering a bracket, show its partner.
set showmatch

" Insert the comment leader when hitting Enter within a comment in Insert
" mode, or when hitting o/O in Normal mode.
set formatoptions+=r formatoptions+=o

" Syntax higlighting is big and clever.
syntax enable

" If using the spell checker, we're writing in British English.
set spelllang=en_gb

" Set features that only work in Vim 7.4 or higher.
if version >= 704
	" Have the value of shiftwidth follow that of tabstop, and the value
	" of softtabstop follow shiftwidth.
	set shiftwidth=0
	set softtabstop=-1
endif

" Search for selected text, forwards or backwards (taken from
" <http://vim.wikia.com/wiki/Search_for_visually_selected_text>).
vnoremap <silent> * :<C-U>
  \let old_reg=getreg('"')<Bar>let old_regtype=getregtype('"')<CR>
  \gvy/<C-R><C-R>=substitute(
  \escape(@", '/\.*$^~['), '\_s\+', '\\_s\\+', 'g')<CR><CR>
  \gV:call setreg('"', old_reg, old_regtype)<CR>
vnoremap <silent> # :<C-U>
  \let old_reg=getreg('"')<Bar>let old_regtype=getregtype('"')<CR>
  \gvy?<C-R><C-R>=substitute(
  \escape(@", '?\.*$^~['), '\_s\+', '\\_s\\+', 'g')<CR><CR>
  \gV:call setreg('"', old_reg, old_regtype)<CR>

" Plugins!
call plug#begin('~/.vim/bundle')

" Rainbow parentheses.  Using this version not least because it does
" "parentheses" higlighting for shell if/then loops and the like.
"
" This also requires g:sh_no_error, as without that some things get
" inexplicably highlighted as errors even though they're blatantly not.
Plug 'luochen1990/rainbow'
let g:rainbow_active = 1
let g:sh_no_error = 1

" fzf
Plug 'junegunn/fzf.vim'

" Ag
Plug 'mileszs/ack.vim'
let g:ackprg = 'ag --nogroup --nocolor --column'

" OpenSCAD syntax highlighting
Plug 'sirtaj/vim-openscad'

for path in split(globpath('~/.vim/localbundles/', '*.vim'), '\n')
  exe 'source' path
endfor

" VimTeX
Plug 'lervag/vimtex'

" Finished adding plugins
call plug#end()
