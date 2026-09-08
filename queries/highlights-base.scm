(identifier) @variable
(comment) @comment
(block_comment) @comment
(string) @string
(escape_sequence) @string.escape
(integer) @number
(float) @number.float
(boolean) @boolean
(missing) @constant.builtin
(type) @type.builtin

["begin" "end" "local" "record" "stop" "quit" "Quit" "QUIT" "exit"] @keyword
["if" "then" "else" "elseif"] @keyword.conditional
["do" "while"] @keyword.repeat
[(break_statement) (continue_statement)] @keyword.repeat
["function" "procedure"] @keyword.function
["load" "external"] @keyword.import
"return" @keyword.return
["new" "create" "setvalues" "getvalues"] @keyword
["defaultapp" "noparent"] @constant.builtin

(function_definition name: (identifier) @function)
(procedure_definition name: (identifier) @function)
(parameter name: (identifier) @variable.parameter)
(call_statement (application_expression function: (identifier) @function.call))
(external_reference name: (identifier) @function.call)
(attribute_expression attribute: (identifier) @property)
(coordinate_expression coordinate: (identifier) @property)
(dimension_expression dimension: (identifier) @property)
(file_variable_expression variable: (identifier) @property)
(file_group_expression group: (identifier) @property)
(named_subscript dimension: (identifier) @property)
(resource_assignment name: (string) @property)
(resource_retrieval name: (string) @property)
(create_expression class: (identifier) @type)

["=" ":=" "+" "-" "*" "/" "%" "#" "^" "<" ">"
 ".eq." ".ne." ".lt." ".le." ".gt." ".ge."
 ".EQ." ".NE." ".LT." ".LE." ".GT." ".GE."
 ".and." ".or." ".xor." ".not." ".AND." ".OR." ".XOR." ".NOT."
 "->" "=>" "@" "&" "!" "|" "::"] @operator
["(" ")" "[" "]" "{" "}" "(/" "/)" "[/" "/]" "$"] @punctuation.bracket
["," ":"] @punctuation.delimiter
(line_continuation) @punctuation.special
