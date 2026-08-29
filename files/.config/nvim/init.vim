set nocompatible

" encode setting
set encoding=utf-8
" edita setting
set number          " 行番号表示
set splitbelow      " 水平分割時に下に表示
set splitright      " 縦分割時を右に表示
set noequalalways   " 分割時に自動調整を無効化
set wildmenu        " コマンドモードの補完
" cursorl setting
set ruler           " カーソルの位置表示
set cursorline      " カーソルハイライト
" tab setting
set autoindent      " 改行時に自動でインデントする
set expandtab       " tabを複数のspaceに置き換え
set tabstop=2       " tabは半角2文字
set shiftwidth=2    " tabの幅



" Plugins will be downloaded under the specified directory.
call plug#begin()

" Automatically install missing plugins on startup
if !empty(filter(copy(g:plugs), '!isdirectory(v:val.dir)'))
  autocmd VimEnter * PlugInstall | q
endif

" Declare the list of plugins.
Plug 'vim-airline/vim-airline'
Plug 'vim-airline/vim-airline-themes'
Plug 'morhetz/gruvbox'

" List ends here. Plugins become visible to Vim after this call.
call plug#end()

" enable gruvbox theme
autocmd vimenter * ++nested colorscheme gruvbox

set background=dark    " Setting dark mode

nnoremap <silent> [oh :call gruvbox#hls_show()<CR>
nnoremap <silent> ]oh :call gruvbox#hls_hide()<CR>
nnoremap <silent> coh :call gruvbox#hls_toggle()<CR>

nnoremap * :let @/ = ""<CR>:call gruvbox#hls_show()<CR>*
nnoremap / :let @/ = ""<CR>:call gruvbox#hls_show()<CR>/
nnoremap ? :let @/ = ""<CR>:call gruvbox#hls_show()<CR>?
