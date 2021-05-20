if exists('g:loaded_nvim_find')
	finish
endif

let s:save_cpo = &cpo
set cpo&vim

command! Find lua require("nvim-find").files()

let &cpo = s:save_cpo
unlet s:save_cpo

let g:loaded_nvim_find = 1
