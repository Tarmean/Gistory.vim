" Gistory polls fairly aggressively so that chainging the quickfix item
" updates the diff view when necessary
"
" To ensure that this doesn't run into edge cases we isolate this into a new
" tab and wipe everything when the user leaves the tab
function! SetupGistory(l1, l2, ...)
    tab split
    let t:diff_tab = tabpagenr()
    augroup GistoryInit
        au!
        " au QuickFixCmdPre * call AddWorkspace(expand('%:p'))
    augroup END
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
function! AddWorkspace(filename)
    call setqflist([{'filename': a:filename, 'module': 'working', 'lnum': line('.')}], 'a')
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

