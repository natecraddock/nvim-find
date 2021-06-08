if exists('g:loaded_nvim_find')
	finish
endif

let s:save_cpo = &cpo
set cpo&vim

command! NvimFindFiles lua require("nvim-find").files()
command! NvimFindBuffers lua require("nvim-find").buffers()
command! NvimFindSearch lua require("nvim-find").search()

let &cpo = s:save_cpo
unlet s:save_cpo

let g:loaded_nvim_find = 1
