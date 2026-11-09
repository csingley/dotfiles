;; extends

; The `in` of a for loop or comprehension is tagged @keyword.repeat (bold italic, like `for`;
; see the colorscheme). The membership test `x in xs` is left as the upright operator.
(for_statement
  "in" @keyword.repeat)

(for_in_clause
  "in" @keyword.repeat)

; break and continue are tagged @keyword.return (bold, upright), like `return`. The bash queries
; do the same for return, exit, break and continue.
[
  "break"
  "continue"
] @keyword.return
