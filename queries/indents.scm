; Consumed by nvim-treesitter's indentexpr(), not by the parser itself.
[(block) (if_statement) (do_statement) (while_statement)
 (create_expression) (setvalues_statement) (getvalues_statement)
 (array) (list) (argument_list) (parameter_list)
 (parenthesized_expression)] @indent.begin

; Function headers and local declarations stay at the same level as begin.
; Only their block contributes an indentation level.
["end" "else" "elseif" ")" "/)" "/]"] @indent.branch
["end" ")" "/)" "/]"] @indent.end
(if_statement "if" @indent.end)
(do_statement "do" @indent.end)

; Retain the user's formatting inside multiline comments and strings.
[(block_comment) (string)] @indent.auto

; While a block is still being typed, its complete syntax node may not exist.
(ERROR ["begin" "then" "do" "create" "setvalues" "getvalues"]) @indent.begin
