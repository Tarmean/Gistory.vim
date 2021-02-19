# Gistory - Git History in Vim

Git log has great tools to find commits which are relevant to a file, a span, or a regex. It is also really unweildy.  
Fugitive's diffing is a great tool to compare files but is defeated by git churn.  
Code formatters are really good at removing git churn.

This Vim plugin assembles the pieces to do `git blame`'s job right.

Youtube video example:
[![Gistory Example](https://img.youtube.com/vi/Px45io_pphM/0.jpg)](https://www.youtube.com/watch?v=Px45io_pphM&feature=youtu.be)


- `:Gistory` loads all commits which affect the current file into the quickfix list in a new tab. 
- You always see the diff between the new and previous commit
- Navigate the quickfix list to jump to commits
- Normalize whitespace and run lsp formatters via coc.nvimto clean up diffs


Selecting a range only shows commits that affect that range. Git tries to track how this range changed over time, so if there is too much git churn all changes will be shown.

![gistory range](gistory_range.gif)


Git pickaxe can be used with `Gistory -S regex`. This shows commits where the number of matches of `regex` changed - great if a code formatter made span tracking useless.

![gistory regex](gistory_regex.gif)


Dependencies:

- fugitive
- coc.nvim


The dependency for coc.nvim for formatting is fairly superficial. If it causes problems, please speak up!
