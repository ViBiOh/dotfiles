" Turnoff vi backward compatibility
set nocompatible

" Vundle Configuration
filetype off
set rtp+=~/.vim/bundle/Vundle.vim
call vundle#begin()

Plugin 'VundleVim/Vundle.vim'

" File browser
Plugin 'scrooloose/nerdtree'

" Status bar
Plugin 'vim-airline/vim-airline'

" GitWrapper
Plugin 'tpope/vim-fugitive'

" Git Gutter
Plugin 'airblade/vim-gitgutter'

" CTRL + P handler
Plugin 'ctrlpvim/ctrlp.vim'

call vundle#end()

" /shrug
filetype plugin indent on

" Syntax highlighting
syntax enable

" Line highlight
set cursorline

" Show line numbers
set number

" Default file encoding
set encoding=utf-8

" Show current command combination on bottom right
set showcmd

" Wrap lines
set wrap

" Spaces tab's width and indent size
set tabstop=2 shiftwidth=2

" Insert spaces instead of tabs
set expandtab

" Backspace behavior for corresponding to most common apps
set backspace=indent,eol,start

" Hightlight search
set hlsearch

" Search as you type character
set incsearch

" Ignore case in search
set ignorecase

" Search with smart case (if uppercase provided, search is case sensitive)
set smartcase

" File browser - NERDTree config
autocmd StdinReadPre * let s:std_in=1
autocmd VimEnter * if argc() == 1 && isdirectory(argv()[0]) && !exists("s:std_in") | exe 'NERDTree' argv()[0] | wincmd p | ene | endif
autocmd bufenter * if (winnr("$") == 1 && exists("b:NERDTree") && b:NERDTree.isTabTree()) | q | endif
map <C-n> :NERDTreeToggle<CR>

