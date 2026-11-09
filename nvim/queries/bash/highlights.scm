;; extends

; return, exit, break and continue are tagged @keyword.return (bold, upright; see
; the colorscheme), the same as `return` in the other languages, instead of being plain
; builtins.
((command_name
  (word) @keyword.return)
  (#any-of? @keyword.return "return" "exit" "break" "continue"))
