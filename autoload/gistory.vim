" Gistory polls fairly aggressively so that chainging the quickfix item
" updates the diff view when necessary
"
" To ensure that this doesn't run into edge cases we isolate this into a new
" tab and wipe everything when the user leaves the tab
function! SetupGistory(l1, l2, ...)
    tab split
    let t:diff_tab = tabpagenr()
    " augroup GistoryInit
        " au!
        " au QuickFixCmdPre * call AddUncommited()
    " augroup END
    if (a:l1 != 1) || (a:l2 != line("$"))
        exec a:l1 . "," . a:l2 . "Gclog -w " . join(a:000, " ")
    else
        exec "0Gclog -w " . join(a:000, " ")
    endif
    call SetupDiff()
    let g:last_known = getqflist({'id':0, 'changedtick': 0, 'idx': 0})
    augroup Gistory
        au!
        autocmd TabLeave * tabc | augroup Gistory | au! | augroup END
        autocmd BufEnter  * call QueueUpDiff()
        autocmd CursorMoved  * call QueueUpDiff()
    augroup END
endfunc
function! AddUncommited()
    let oldcd = getcwd()
    exec "cd ".FugitiveGitDir()."/.."
    let file = "./".expand('%')

    let idxp = fugitive#Find(":".expand('%'))
    let workp = expand("%:p")
    " if WorkspaceChanged(l:file)
    "     let g:l = [{'filename': l:workp, 'module': '[work] ', 'lnum': line('.')}]
    "     call setqflist(g:l, 'a')
    " endif
    if IndexChanged(l:file)
        let g:r = [{'filename': idxp, 'module': '[index]', 'lnum': line('.')}]
        call setqflist(g:r, 'a')
    endif
    exec "cd ".oldcd
    augroup GistoryInit
        au!
    augroup END
endfunc
function! QueueUpDiff()
    if exists('g:last_known') && g:last_known == getqflist({'id':0, 'changedtick': 0, 'idx': 0})
        return
    endif
    let g:last_known = getqflist({'id':0, 'changedtick': 0, 'idx': 0})
    " SetupDiff must run last otherwise g:last_known is invalidated
    " immediately by other auto commands.
    " we abuse feedkeys as an event queue to ensure we run last.
    call feedkeys(":call SetupDiff()\<cr>", 'n')
endfunc
function! SetupDiff()
    if !exists("t:diff_tab")
        echo "2"
        return
    endif
    if t:diff_tab != tabpagenr()
        echo "setup_diff wrong tabpagenr"
        return
    endif
    let qf = getqflist({'idx':0, 'items': 0})
    if qf['idx'] == len(qf['items'])
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
    cc
    exec 'Gdiffsplit ' . paired_buf_ident
    silent! call NormalizeWhitespace()
    wincmd w
    silent! call NormalizeWhitespace()
endfunc
function! NormalizeWhitespace()
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
    %s/^\s*\n\|\s*$//
    sleep 10m
    call CocAction("format")
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

function! GitBuf(object, title)
    let g:command = "Gread " . a:object
    exec g:command
    exec "set ft=" . expand("%:e", a:title) 
    silent! call NormalizeWhitespace()
    diffthis
    exec "file " . a:title
    setlocal buftype=nofile
    setlocal bufhidden=wipe
    setlocal noswapfile
endfunction
function! WorkspaceChanged(object)
    let work = readfile(a:object)
    let idx = s:content(":".a:object)
    return l:work != l:idx
endfunc
function! IndexChanged(object)
    let head = s:content("@:".a:object)
    let idx = s:content(":".a:object)
    return l:head != l:idx
endfunc
function! GitContent(object)
    return fugitive#readfile(fugitive#Find(a:object))
endfunc

let g:diff_view_buffer = {}
function! DiffViewFor(path, title)
    if (has_key(g:diff_view_buffer, a:path) && bufexists(g:diff_view_buffer[a:path]))
        echom "cached " . a:path . " => " . g:diff_view_buffer[a:path]
        exec "b " . g:diff_view_buffer[a:path]
        return
    endif
    call GitBuf(a:path, a:title)
    let g:diff_view_buffer[a:path] = bufnr()
endfunc
function LoadInPlace(cur_file)
    if WorkspaceChanged(a:cur_file) || IndexChanged(a:cur_file)
        throw "modified buffer or index since last commit " . a:cur_file
    endif
    let g:diff_view_buffer[a:cur_file] = bufnr(".")
    exec "Gread :1:".a:cur_file
    silent! call NormalizeWhitespace()
    w
endfunc
function! DiffView(bang)
    let s:current_file=expand('%:p')
    let s:current_file=expand('%:p')
    let s:title=expand('%:t')
    let s:me = ":2:" . s:current_file
    let s:you = ":3:" . s:current_file
    if a:bang == '!'
        call LoadInPlace(s:current_file)
        let s:now = s:current_file
    else
        let s:now = ":1:" . l:current_file
    endif
    call PopulateDiffViews(s:now, s:me, s:you, s:title)
endfunc
 
function! PopulateDiffViews(past, me, you, title)
    exec "tabnew"
    call DiffViewFor(a:you, "you " . a:title)
    wincmd v
    enew
    call DiffViewFor(a:me, "me " . a:title)

    exec "tabnew"
    call DiffViewFor(a:past, "past " . a:title)
    wincmd v
    enew
    call DiffViewFor(a:me, "me " . a:title)

    exec "tabnew"
    call DiffViewFor(a:past, "past " . a:title)
    wincmd v
    enew
    call DiffViewFor(a:you, "you " . a:title)
endfunction
