let mapleader = ";"

map <silent> <ScrollWheelUp> 5<C-Y>
map <silent> <ScrollWheelDown> 5<C-E>

" Filetypes
autocmd BufRead,BufNewFile *.conf setfiletype conf
autocmd BufRead,BufNewFile *.nix setfiletype nix
autocmd BufRead,BufNewFile .envrc setfiletype bash

" Vim clipboard improvements
let g:EasyClipUseCutDefaults = 0
nmap x <Plug>MoveMotionPlug
xmap x <Plug>MoveMotionXPlug
nmap xx <Plug>MoveMotionLinePlug
nmap X <Plug>MoveMotionEndOfLinePlug

set clipboard=unnamedplus

" Vim camelcasemotion
map <silent> w <Plug>CamelCaseMotion_w
map <silent> b <Plug>CamelCaseMotion_b
map <silent> e <Plug>CamelCaseMotion_e
sunmap w
sunmap b
sunmap e
omap <silent> iw <Plug>CamelCaseMotion_iw
xmap <silent> iw <Plug>CamelCaseMotion_iw
omap <silent> ib <Plug>CamelCaseMotion_ib
xmap <silent> ib <Plug>CamelCaseMotion_ib
omap <silent> ie <Plug>CamelCaseMotion_ie
xmap <silent> ie <Plug>CamelCaseMotion_ie

"" Vim-sandwich
nmap s <Nop>
xmap s <Nop>

" FZF settings
let $FZF_DEFAULT_COMMAND = "rg --files --hidden --glob='!.git'"
let g:fzf_layout = {
\   'window': {
\     'width': 90,
\     'height': 25,
\     'highlight': 'GruvboxAquaFaded',
\     'border': 'sharp'
\   }}

nmap <silent> <leader>f :FZF --reverse<CR>
nmap <silent> <leader>b :Buffers<CR>

"" Colortheme
let g:gruvbox_italic = 1
let g:gruvbox_bold = 0
set termguicolors
set background=dark
" Hack for clear bg, clean up
au ColorScheme * hi Normal ctermbg=none guibg=none
colorscheme gruvbox

" Lightline
let g:lightline = { 'colorscheme': 'gruvbox' }
let g:lightline.tabline_subseparator = { 'left': '', 'right': ''}
let g:lightline.tabline = { 'right' : [[]] }
let g:lightline.tab = {
    \ 'active': [ 'filename', 'modified' ],
    \ 'inactive': [ 'filename', 'modified' ] }
let g:lightline.active = {
    \ 'left': [ [ 'mode', 'paste'], ['readonly', 'relativepath', 'modified'] ],
    \ 'right': [ [ 'lineinfo' ], [ 'percent' ] ] }

" Javascript/Typescript settings
let g:closetag_filetypes = 'javascriptreact,typescriptreact'
let g:closetag_regions = {
    \ 'typescriptreact': 'jsxRegion,tsxRegion',
    \ 'javascriptreact': 'jsxRegion',
    \ }
