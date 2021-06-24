" Gistory polls fairly aggressively so that chainging the quickfix item
" updates the diff view when necessary
"
" To ensure that this doesn't run into edge cases we isolate this into a new
" tab and wipe everything when the user leaves the tab
if (!exists("g:gistory_skip_options"))
    set diffopt+=hiddenoff,iblank,iwhiteeol,algorithm:histogram
endif
function! gistory#setup(l1, l2, ...)
    if !exists('g:gistory_no_format') && !exists("*CocAction")
      echohl WarningMsg
      echo "Warning"
      echohl None
      echon ': CocAction not found, install coc.nvim or set g:gistory_no_format=1 to silence warning'
      call getchar()
    endif
    tab split
    let t:diff_tab = tabpagenr()
    " augroup GistoryInit
        " au!
        " au QuickFixCmdPre * call gistory#add_uncomitted()
    " augroup END
    if (a:l1 != 1) || (a:l2 != line("$"))
        exec a:l1 . "," . a:l2 . "Gclog -w " . join(a:000, " ")
        let g:gistory#sparse = 1
    else
        let g:gistory#sparse = a:0 > 0
        exec "0Gclog -w " . join(a:000, " ")
    endif
    call gistory#setup_diff()
    let g:last_known = getqflist({'id':0, 'changedtick': 0, 'idx': 0})
    augroup Gistory
        au!
        autocmd TabLeave * tabc | augroup Gistory | au! | augroup END
        autocmd BufEnter  * call gistory#queue_diff()
        autocmd CursorMoved  * call gistory#queue_diff()
    augroup END
endfunc
function! gistory#add_uncomitted()
    let oldcd = getcwd()
    exec "cd ".FugitiveGitDir()."/.."
    let file = "./".expand('%')

    let idxp = fugitive#Find(":".expand('%'))
    let workp = expand("%:p")
    " if gistory#check_workspace_dirty(l:file)
    "     let g:l = [{'filename': l:workp, 'module': '[work] ', 'lnum': line('.')}]
    "     call setqflist(g:l, 'a')
    " endif
    if gistory#index_changed(l:file)
        let g:r = [{'filename': idxp, 'module': '[index]', 'lnum': line('.')}]
        call setqflist(g:r, 'a')
    endif
    exec "cd ".oldcd
    augroup GistoryInit
        au!
    augroup END
endfunc


function! gistory#queue_diff()
    if exists('g:last_known') && g:last_known == getqflist({'id':0, 'changedtick': 0, 'idx': 0})
        return
    endif
    let g:last_known = getqflist({'id':0, 'changedtick': 0, 'idx': 0})
    " gistory#setup_diff must run last otherwise g:last_known is invalidated
    " immediately by other auto commands.
    " we abuse feedkeys as an event queue to ensure we run last.
    call feedkeys(":call gistory#setup_diff()\<cr>", 'n')
endfunc
" sparse is true => we always diff with the parent commit
" sparse is false => we diff with the previous commit in the qflist
" sparse gives better results´when we filter on range or pickaxe
" but worse results when we have multi-parent commits in the qflist
function! gistory#setup_diff()
    let sparse = g:gistory#sparse
    if !exists("t:diff_tab")
        echo "2"
        return
    endif
    if t:diff_tab != tabpagenr()
        echo "setup_diff wrong tabpagenr"
        return
    endif
    let qf = getqflist({'idx':0, 'items': 0})

    if l:sparse || qf['idx'] == len(qf['items'])
        let paired_buf_ident = '!^'
    else
        let paired_buf = qf['items'][qf['idx']]['bufnr']
        let paired_buf_name = bufname(paired_buf)
        let paired_fug_data = FugitiveBufferIdent(paired_buf_name)
        if len(paired_fug_data) != 0
            let paired_buf_path = s:Slash(paired_fug_data[1][0:-6] . paired_fug_data[3])
            let paired_buf_ident = paired_fug_data[2] . ':' . paired_buf_path
            let g:ident = paired_buf_ident
        else
            let g:last_known = getqflist({'id':0, 'changedtick': 0, 'idx': 0})
            return
        endif
    endif
    only
    cw
    wincmd w
    exec 'Gdiffsplit ' . paired_buf_ident
    silent! call gistory#normalize_whitespace()
    wincmd w
    silent! call gistory#normalize_whitespace()
endfunc
function! gistory#normalize_whitespace()
    let oldmodifiable = &modifiable
    let oldreadonly = &readonly
    let oldwinid = win_getid()
    set modifiable
    set noreadonly
    let buf = getline(1, '$')
    let ft= &ft
    vsplit enew
    call setline(1, buf)
    let &ft = ft
    sleep 100m
    retab
    sleep 10m
    if !exists('g:gistory_no_format') && exists("*CocAction")
        call CocAction("format")
    endif
    let buf = getline(1, '$')
    bw!
    0,$d
    call setline(1, buf)
    set nomodified
    let &modifiable = oldmodifiable
    let &readonly = oldreadonly
    call win_gotoid(oldwinid)
endfunc
function! s:Slash(path) abort
  if exists('+shellslash')
    return tr(a:path, '\', '/')
  else
    return a:path
  endif
endfunction


function! gistory#load_git_buf(oft, object, title)
    let g:command = "Gread " . a:object
    exec g:command
    exec "set ft=" . a:oft
    silent! call gistory#normalize_whitespace()
    diffthis
    exec "file " . a:title
    setlocal buftype=nofile
    setlocal bufhidden=wipe
    setlocal noswapfile
endfunction
function! gistory#check_workspace_dirty(object)
    let work = readfile(a:object)
    let idx = s:content(":".a:object)
    return l:work != l:idx
endfunc
function! gistory#index_changed(object)
    let head = s:content("@:".a:object)
    let idx = s:content(":".a:object)
    return l:head != l:idx
endfunc
function! s:content(object)
    return fugitive#readfile(fugitive#Find(a:object))
endfunc

let g:diff_view_buffer = {}
function! gistory#diff_for(oft, path, title)
    if (has_key(g:diff_view_buffer, a:path) && bufexists(g:diff_view_buffer[a:path]))
        echom "cached " . a:path . " => " . g:diff_view_buffer[a:path]
        exec "b " . g:diff_view_buffer[a:path]
        diffthis
        return
    endif
    call gistory#load_git_buf(a:oft, a:path, a:title)
    echom "not cached " a:oft . ", ". a:path . " => " . bufnr()
    let g:diff_view_buffer[a:path] = bufnr()
endfunc
function! gistory#reset_to_common_ancestor(cur_file)
    " if gistory#check_workspace_dirty(a:cur_file) || gistory#index_changed(a:cur_file)
    "     throw "modified buffer or index since last commit " . a:cur_file
    " endif
    let g:diff_view_buffer[a:cur_file] = bufnr()
    exec "Gread :1:".a:cur_file
    silent! call gistory#normalize_whitespace()
    w
endfunc
function! gistory#threeway(bang)
    let g:diff_view_buffer = {}
    exec "cd ".expand('%:h')
    let s:current_file=expand('%:p')
    let s:title=expand('%:t')
    let s:me = ":2:" . s:current_file
    let s:you = ":3:" . s:current_file
    if a:bang == '!'
        if &modified
            " todo - figuring out if users changed the file since the parent
            " commit is tricky since git modified it with conflict markers
            throw "Changes will be overwritten"
        endif
        call gistory#reset_to_common_ancestor(s:current_file)
        let s:now = s:current_file
    else
        let s:now = ":1:" . s:current_file
    endif
    let oft = &ft
    call s:open_diffs(oft, s:now, s:me, s:you, s:title)
endfunc
 
function! s:open_diffs(oft, past, me, you, title)

    tabnew
    let past_buf = g:diff_view_buffer[a:past]
    call gistory#diff_for(a:oft, a:you, "you " . a:title)
    call s:set_diff_put(l:past_buf)
    wincmd v
    enew
    call gistory#diff_for(a:oft, a:past, "past " . a:title)
    wincmd v
    enew
    call gistory#diff_for(a:oft, a:me, "me " . a:title)
    call s:set_diff_put(l:past_buf)
    tabnew
    call gistory#diff_for(a:oft, a:past, "past " . a:title)
    wincmd v
    enew
    call gistory#diff_for(a:oft, a:you, "you " . a:title)
    tabnew
    call gistory#diff_for(a:oft, a:past, "past " . a:title)
    wincmd v
    enew
    call gistory#diff_for(a:oft, a:me, "me " . a:title)
endfunction

function! s:set_diff_put(buf)
    exec "nnoremap <buffer> dp :diffput " . a:buf . "<cr>"
    exec "vnoremap <buffer> dp :diffput " . a:buf . "<cr>"
endfunc
