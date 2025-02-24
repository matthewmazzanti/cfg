" Gruvbox
set termguicolors
set background=dark
au ColorScheme * hi Normal ctermbg=none guibg=none
let g:gruvbox_contrast_dark="hard"
colorscheme gruvbox

" Relativenumber may be a bit heavy on low-power systems
set number
set relativenumber

" Remove neovim status bar
set laststatus=0

" Movement stuff
set mouse=a
set nostartofline
set backspace=indent,eol,start

" Line wrapping
set colorcolumn=101
set nowrap

" Indentation stuff
set tabstop=4
set shiftwidth=4
set expandtab
set softtabstop=0
set smarttab
set autoindent
set smartindent

" Incremental search and better caps handling
set incsearch
set ignorecase
set smartcase

" Nice visualization of trailing space
set listchars=tab:>\ ,trail:-,extends:>,precedes:<,nbsp:+ 
set list

set autoread
