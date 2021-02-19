let g:fugitive_summary_format = '%<(20) %an | %<(100) %s| %ar '
vnoremap <space>gl :Gistory<cr>
nnoremap <space>gl :Gistory<cr>
command! -nargs=* -range=% Gistory call SetupGistory(<line1>, <line2>, <f-args>)

