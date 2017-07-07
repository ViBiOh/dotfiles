" Turnoff vi backward compatibility
set nocompatible

" Vundle Configuration
filetype off
set rtp+=~/.vim/bundle/Vundle.vim
call vundle#begin()

Plugin 'VundleVim/Vundle.vim'

" Status bar
Plugin 'vim-airline/vim-airline'

" Git Gutter
Plugin 'airblade/vim-gitgutter'

" Autocompletion
Plugin 'valloric/youcompleteme'

" Oceanic Next Theme
Plugin 'mhartington/oceanic-next'

" Fuzzy File Finder
Plugin 'junegunn/fzf'

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

" Activate color scheme
colorscheme OceanicNext

" Ctrl + P Open fuzzy file finder
map <C-p> :FZF<CR>

