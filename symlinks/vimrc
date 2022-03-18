" Turnoff vi backward compatibility
set nocompatible

" Enable syntax color if exist
if exists(":syntax")
  syntax on
endif

" Set color width
set t_Co=256

" Setting colorscheme to ensure it
set background=dark
colorscheme slate

" Show status line
set laststatus=2

highlight StatusLine ctermfg=235 ctermbg=11
highlight User1 ctermfg=11 ctermbg=238
highlight User2 ctermfg=232 ctermbg=154
highlight User3 ctermfg=2 ctermbg=235
highlight clear SignColumn

set statusline=
set statusline+=%1*\ \%f " Filename
set statusline+=%2*\%m" Modified
set statusline+=%*\%R " Read-Only indicator
set statusline+=%=
set statusline+=%3*\%y " Type of file
set statusline+=\ %{&fileencoding?&fileencoding:&encoding}
set statusline+=\[%{&fileformat}\]
set statusline+=%1*\ %p%% " Percentage of the file
set statusline+=\ %l:%c " Line Number and Total Line
set statusline+=\  " Empty space at end

" Line highlight
set cursorline

" Show line numbers
set number

" Default file encoding
set encoding=utf-8

" Show current command combination on bottom right
set showcmd

" Confirm change save
set confirm

" Wrap lines
set wrap

" Spaces tab's width and indent size
set tabstop=2 shiftwidth=2
if exists(':filetype')
  filetype indent on
  filetype plugin on
endif

" Show matching parenthesis
set showmatch

" Insert spaces instead of tabs
set expandtab

" Backspace behavior for corresponding to most common apps
set backspace=indent,eol,start

" Hightlight search
set hlsearch

" SignColumn configuration
if has(':signcolumn')
  set signcolumn=number
endif

" Keep search matches in the middle of the window.
nnoremap n nzzzv
nnoremap N Nzzzv

" Search as you type character
set incsearch

" Ignore case in search
set ignorecase

" Search with smart case (if uppercase provided, search is case sensitive)
set smartcase

" Omni completion
set completeopt=longest,menuone,noselect,noinsert
set omnifunc=syntaxcomplete#Complete

" Enter select completion
inoremap <expr> <CR> pumvisible() ? "\<C-y>" : "\<C-g>u\<CR>"

" Auto reload file
set autoread

" Disable folding
set nofoldenable

" No bell
set visualbell
set noerrorbells

" Disable backup files
set nobackup
set nowritebackup
set noswapfile

" Increase update time
set updatetime=300

" Change map leader if possible
if exists(":let")
  let mapleader=","
endif

" Navigation shortcut
nmap <silent> gb <C-o>

" Disabling viminfo
set viminfo=""

" Turn on the Wild menu, better suggestion
set wildmenu

" Be lazy when redrawing screen
set lazyredraw

" Printing whitespace characters differently
set list
set listchars=tab:>.,trail:.,extends:#,nbsp:.

" Share clipboard with system
" set clipboard=unnamed

" Autoformat code with ctrl+f
noremap <C-f> gg=G<return>

" Smarter tab completion trigger
function! SuperTab()
  let l:part = strpart(getline('.'),col('.')-2,1)
  if (l:part =~ '^\s\?$')
    return "\<Tab>"
  endif

  if (l:part =~ '\/')
    return "\<C-X>\<C-F>"
  endif

  return "\<C-X>\<C-O>"
endfunction

inoremap <Tab> <C-R>=SuperTab()<CR>

" Using ripgrep for searching
if executable("rg")
  set grepprg=rg\ --vimgrep\ --no-heading
  nnoremap <Leader>* :lgrep -P --<Space>
endif

if exists(':autocmd') && exists(':augroup')
  augroup quick_fix
    autocmd!
    " Opening quickfix automatically
    autocmd QuickFixCmdPost [^l]* nested cwindow
    autocmd QuickFixCmdPost    l* nested lwindow
  augroup END

  " Format using external program
  augroup format_config
    autocmd!

    if executable('terraform')
      autocmd FileType tf setlocal equalprg=terraform\ fmt\ -no-color\ -\ 2>/dev/null
    endif

    if executable('black')
      autocmd FileType python setlocal equalprg=black\ --quiet\ -\ 2>/dev/null
    endif

    if executable('prettier')
      autocmd FileType markdown setlocal equalprg=prettier\ --no-color\ --stdin-filepath\ file.md\ 2>/dev/null
      autocmd FileType yaml setlocal equalprg=prettier\ --no-color\ --stdin-filepath\ file.yaml\ 2>/dev/null
      autocmd FileType json setlocal equalprg=prettier\ --no-color\ --stdin-filepath\ file.json\ 2>/dev/null
      autocmd FileType js setlocal equalprg=prettier\ --no-color\ --stdin-filepath\ file.js\ 2>/dev/null
      autocmd FileType jsx setlocal equalprg=prettier\ --no-color\ --stdin-filepath\ file.jsx\ 2>/dev/null
    endif

    if executable('goimports')
      autocmd FileType go setlocal equalprg=goimports\ 2>/dev/null
    endif

    if executable('shfmt')
      autocmd FileType sh setlocal equalprg=shfmt\ -s\ -\ 2>/dev/null
    endif
  augroup END
endif

" Save file with sudo permission
if exists(':execute')
  command W :execute ':silent w !sudo tee % > /dev/null' | :edit!
endif

" Search using ctrl-p and fzf
set rtp+=~/opt/fzf
noremap <C-p> :FZF<return>
