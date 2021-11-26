# Gistory - Git History in Vim

Git log has great tools to find commits which are relevant to a file, a span, or a regex. It is also really unweildy.  
Fugitive's diffing is a great tool to compare files but is defeated by git churn.  
Code formatters are really good at removing git churn.

This Vim plugin assembles the pieces to do `git blame`'s job right.


## Installation

With  [vim-plug](https://github.com/junegunn/vim-plug):

    Plug 'Tarmean/Gistory'
    Plug 'tpope/vim-fugitive'
    Plug 'neoclide/coc.nvim', {'branch': 'release', 'do': 'yarn install --frozen-lockfile'}


## Usage

[Youtube video example](https://www.youtube.com/watch?v=Px45io_pphM&feature=youtu.be)

- `:Gistory` loads all commits which affect the current file into the quickfix list in a new tab. 
- You always see the diff between the new and previous commit
- Navigate the quickfix list to jump to commits
- Gistory normalizes whitespace and runs lsp formatters via coc.nvim to clean up diffs


Selecting a range only shows commits that affect that range. Git tries to track how this range changed over time, so if there is too much git churn all changes will be shown.

![gistory range](gistory_range.gif)


Git pickaxe can be used with `Gistory -S string`. This shows commits where the number of matches of `string` changed - great if a code formatter made span tracking useless. To use a regex, try `--pickaxe-regex`. `Gistory -G regex` finds commits where regex matches in a diff hunk, showing commits with nearby changes even if the pattern itself wasn't changed.

![gistory regex](gistory_regex.gif)


Dependencies:

- fugitive
- coc.nvim


The plugin works without coc.nvim but you lose lsp based formatting which can *significantly* help with git churn.


## Three Way Merge

 
The plugin has a `ThreeWayMerge` command to help with merges. This opens both versions and the common ancestor as diffs in three tabs:

- you & past & me
- past & me
- past & you

The opened files are named accordingly.  Note that this runs code formatters and retab to normalize whitespace.

`ThreeWayMerge!` replaces the workspace buffer by the common ancestor, allowing quick merging with diffput and diffget.

Video example: https://www.youtube.com/watch?v=LPqTLjO88yA&feature=youtu.be


## Config

Gistory defaults to fairly aggressive diff settings to ignore whitespace with `set diffopt+=hiddenoff,iblank,iwhiteeol,algorithm:histogram`. Set `g:gistory_skip_options` to configure your own.  
There are situations where e.g. trailing whitespace can affect semantics so be careful when merging.

Set `g:gistory_no_format` to skip the warning if you do not have coc.nvim installed.

The following mappings are recommended to make quickfix navigation easier:

    augroup QuickFixMappings
      autocmd!
      autocmd BufReadPost quickfix nnoremap <buffer> <CR> <CR>
      autocmd BufReadPost quickfix nnoremap <buffer> J :cnext<cr>
      autocmd BufReadPost quickfix nnoremap <buffer> K :cprev<cr>
    augroup end

In the `:Gistory` view the newer version opens on the right by default. This can be disabled by

    let g:gistory#new_diff_right = 0

## Known Issues


Fugitive's `Gclog` has breaks when you filter out commits which renamed/copied the file. This is a fairly niche problem, but it is fixable with the git `--name-only` flag at the cost of adding yet more special cases to fugitive. If this problem affects you enought ot motivate a change please open an issue!
