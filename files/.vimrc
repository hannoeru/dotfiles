"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

set nocompatible " VI compatible mode is disabled so that VIm things work

" Settings from these blogposts
" https://dougblack.io/words/a-good-vimrc.html

" Colors
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
let g:molokai_original = 1
" colorscheme badwolf         " awesome colorscheme
syntax enable           " enable syntax processing

" Spaces & Tabs
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
set tabstop=4       " number of visual spaces per TAB
set softtabstop=4   " number of spaces in tab when editing
set expandtab       " tabs are spaces, mainly because of python

" UI Config
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
set number              " show line numbers
set relativenumber      " show relative numbering
set showcmd             " show command in bottom bar
set cursorline          " highlight current line
filetype indent on      " load filetype-specific indent files
filetype plugin on      " load filetype specific plugin files
set wildmenu            " visual autocomplete for command menu
set showmatch           " highlight matching [{()}]
set laststatus=2        " Show the status line at the bottom
set mouse+=a            " A necessary evil, mouse support
set noerrorbells visualbell t_vb=    "Disable annoying error noises
set splitbelow          " Open new vertical split bottom
set splitright          " Open new horizontal splits right
" Buffers
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
set hidden              " Allows having hidden buffers (not displayed in any window)

" Sensible stuff 
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
set backspace=indent,eol,start     " Make backspace behave in a more intuitive way
nmap Q <Nop>
" 'Q' in normal mode enters Ex mode. You almost never want this.
map <C-a> <Nop>   " Unbind for tmux
map <C-x> <Nop>


" Leader Shortcuts
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
let mapleader=" "       " leader is space
" jk is escape
"inoremap jk <esc>
" edit vimrc/zshrc and load vimrc bindings
nnoremap <leader>ev :vsp $MYVIMRC<CR>
nnoremap <leader>ez :vsp ~/.zshrc<CR>
nnoremap <leader>sv :source $MYVIMRC<CR>
" save session,  After saving a Vim session, you can reopen it with vim -S.
nnoremap <leader>s :mksession<CR>

"Searching
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
set incsearch           " search as characters are entered
set hlsearch            " highlight matches
set ignorecase          " Ignore case in searches by default
set smartcase           " But make it case sensitive if an uppercase is entered
" turn off search highlight
vnoremap <C-h> :nohlsearch<cr>
nnoremap <C-h> :nohlsearch<cr>

" Undo
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
set undofile " Maintain undo history between sessions
set undodir=~/.vim/undodir


" Folding
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
set foldenable          " enable folding
set foldlevelstart=10   " open most folds by default
set foldnestmax=10      " 10 nested fold max
" space open/closes folds
" nnoremap <space> za
set foldmethod=indent   " fold based on indent level
" This is especially useful for me since I spend my days in Python.
" Other acceptable values are marker, manual, expr, syntax, diff.
" Run :help foldmethod to find out what each of those do.

" Movement
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" move vertically by visual line
nnoremap j gj
nnoremap k gk
" highlight last inserted text
nnoremap gV `[v`]