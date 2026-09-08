/// <reference types="tree-sitter-cli/dsl" />
// @ts-check

// NCL's own ni/src/ncl/ncl.y is the authority for precedence: unary
// minus/NOT bind above power, power is LEFT associative, OR and XOR tie.
const PREC = { OR: 1, AND: 2, COMPARE: 3, SELECT: 4, ADD: 5, MULTIPLY: 6, POWER: 7, UNARY: 8, ACCESS: 9 };
const commaSep1 = rule => seq(rule, repeat(seq(',', rule)));

module.exports = grammar({
  name: 'ncl',
  word: $ => $.identifier,
  extras: $ => [/[ \t\f]/, $.comment, $.block_comment, $.line_continuation],
  externals: $ => [$._trailing_dot_float],

  rules: {
    // Model an optional final statement explicitly. CLI 0.27's eof() rule
    // requires newer runtime behavior than some Neovim builds provide.
    source_file: $ => seq(repeat(choice($._newline, seq($._statement, $._terminator))), optional($._statement)),
    _newline: _ => /\r?\n/,
    _terminator: $ => $._newline,
    _body: $ => choice(
      repeat1(choice($._newline, seq($._statement, $._terminator))),
      seq(repeat(choice($._newline, seq($._statement, $._terminator))), $._statement),
    ),
    _statement: $ => choice(
      $.assignment_statement, $.call_statement, $.block,
      $.if_statement, $.do_statement, $.while_statement,
      $.function_definition, $.procedure_definition,
      $.load_statement, $.external_statement, $.return_statement,
      $.break_statement, $.continue_statement, $.command_statement,
      $.setvalues_statement, $.getvalues_statement,
    ),

    block: $ => seq('begin', optional($._body), 'end'),
    assignment_statement: $ => seq(
      field('left', $._reference), field('operator', choice('=', ':=')), field('right', $._expression),
    ),
    call_statement: $ => $.application_expression,
    load_statement: $ => seq('load', field('path', $.string)),
    external_statement: $ => seq('external', field('name', $.identifier), field('path', $.string)),
    return_statement: $ => seq('return', optional(field('value', $._expression))),
    break_statement: _ => 'break',
    continue_statement: _ => 'continue',
    command_statement: $ => choice('exit', 'quit', 'Quit', 'QUIT', 'stop', seq('record', $.string), seq('stop', 'record')),

    if_statement: $ => seq(
      'if', field('condition', $._expression), 'then',
      optional($._body), repeat($.elseif_clause), optional($.else_clause), 'end', 'if',
    ),
    // `else if` is a nested if and needs its own `end if`; `elseif` does not.
    elseif_clause: $ => seq('elseif', field('condition', $._expression), 'then', optional($._body)),
    else_clause: $ => seq('else', optional($._body)),
    do_statement: $ => seq(
      'do', field('variable', $.identifier), '=', field('start', $._expression), ',',
      field('end', $._expression), optional(seq(',', field('step', $._expression))),
      optional($._body), 'end', 'do',
    ),
    while_statement: $ => seq(
      'do', 'while', '(', field('condition', $._expression), ')',
      optional($._body), 'end', 'do',
    ),
    function_definition: $ => seq(
      'function', field('name', $.identifier), field('parameters', $.parameter_list),
      repeat($._newline), optional($.local_declaration), field('body', $.block),
    ),
    procedure_definition: $ => seq(
      'procedure', field('name', $.identifier), field('parameters', $.parameter_list),
      repeat($._newline), optional($.local_declaration), field('body', $.block),
    ),
    parameter_list: $ => seq('(', optional(commaSep1($.parameter)), ')'),
    parameter: $ => seq(field('name', $.identifier), repeat($.dimension_size), optional(seq(':', field('type', $.type)))),
    dimension_size: $ => seq('[', choice('*', $.integer), ']'),
    local_declaration: $ => seq('local', commaSep1($.identifier), $._terminator, repeat($._newline)),

    setvalues_statement: $ => seq('setvalues', field('object', $._expression), $._terminator,
      repeat(choice($._newline, seq($.resource_assignment, $._terminator))), 'end', 'setvalues'),
    getvalues_statement: $ => seq('getvalues', field('object', $._expression), $._terminator,
      repeat(choice($._newline, seq($.resource_retrieval, $._terminator))), 'end', 'getvalues'),
    resource_assignment: $ => seq(field('name', $.string), ':', field('value', $._expression)),
    resource_retrieval: $ => seq(field('name', $.string), ':', field('target', $._reference)),
    create_expression: $ => seq('create', field('name', choice($.string, $.identifier)),
      field('class', $.identifier), field('parent', choice($._reference, 'defaultapp', 'noparent')),
      $._terminator, repeat(choice($._newline, seq($.resource_assignment, $._terminator))), 'end', 'create'),

    _expression: $ => choice(
      $._reference, $.integer, $.float, alias($._trailing_dot_float, $.float), $.string, $.boolean, $.missing,
      $.array, $.list, $.parenthesized_expression, $.unary_expression,
      $.binary_expression, $.new_expression, $.create_expression,
    ),
    _reference: $ => choice($.identifier, $.application_expression, $.attribute_expression,
      $.coordinate_expression, $.dimension_expression, $.file_variable_expression,
      $.file_group_expression, $.list_subscript_expression, $.external_reference),
    // f(x) and a(i) are syntactically identical in NCL. A symbol table is
    // required to distinguish them; expose one honest, stable syntax node.
    application_expression: $ => prec.left(PREC.ACCESS, seq(
      field('function', $._reference), field('arguments', $.argument_list),
    )),
    argument_list: $ => seq('(', optional(commaSep1($._subscript)), ')'),
    _subscript: $ => choice($._expression, $.slice, $.coordinate_subscript, $.named_subscript),
    slice: $ => seq(optional(field('start', $._expression)), ':', optional(field('end', $._expression)),
      optional(seq(':', optional(field('step', $._expression))))),
    coordinate_subscript: $ => seq('{', choice($._expression, $.slice, $.named_subscript), '}'),
    named_subscript: $ => seq(field('dimension', choice($.identifier, $.dynamic_identifier)), '|',
      choice($._expression, $.slice, $.coordinate_subscript)),
    list_subscript_expression: $ => prec.left(PREC.ACCESS, seq(field('value', $._reference), '[',
      field('index', choice($._expression, $.slice)), ']')),
    attribute_expression: $ => prec.left(PREC.ACCESS, seq(field('object', $._reference), '@', field('attribute', $._member))),
    coordinate_expression: $ => prec.left(PREC.ACCESS, seq(field('object', $._reference), '&', field('coordinate', $._member))),
    dimension_expression: $ => prec.left(PREC.ACCESS, seq(field('object', $._reference), '!',
      field('dimension', choice($.integer, $.identifier, $.parenthesized_expression, $.dynamic_identifier)))),
    file_variable_expression: $ => prec.left(PREC.ACCESS, seq(field('file', $._reference), '->', field('variable', $._member))),
    file_group_expression: $ => prec.left(PREC.ACCESS, seq(field('file', $._reference), '=>', field('group', $._member))),
    external_reference: $ => prec.left(PREC.ACCESS, seq(field('library', $.identifier), '::', field('name', $.identifier))),
    _member: $ => choice($.identifier, $.dynamic_identifier),
    dynamic_identifier: $ => seq('$', $._expression, '$'),

    new_expression: $ => seq('new', '(', field('dimensions', $._expression), ',',
      field('type', choice($.type, $._expression)), optional(seq(',', field('fill_value', $._expression))), ')'),
    array: $ => seq('(/', commaSep1($._expression), '/)'),
    list: $ => seq('[/', optional(commaSep1($._expression)), '/]'),
    parenthesized_expression: $ => seq('(', $._expression, ')'),
    unary_expression: $ => prec(PREC.UNARY, seq(field('operator', choice('-', '.not.', '.NOT.')), field('argument', $._expression))),
    binary_expression: $ => choice(...[
      [PREC.OR, ['.or.', '.OR.', '.xor.', '.XOR.']],
      [PREC.AND, ['.and.', '.AND.']],
      [PREC.COMPARE, ['.eq.', '.ne.', '.lt.', '.le.', '.gt.', '.ge.', '.EQ.', '.NE.', '.LT.', '.LE.', '.GT.', '.GE.']],
      [PREC.SELECT, ['<', '>']], [PREC.ADD, ['+', '-']],
      [PREC.MULTIPLY, ['*', '/', '%', '#']], [PREC.POWER, ['^']],
    ].map(([precedence, operators]) => prec.left(precedence, seq(
      field('left', $._expression), field('operator', operators.length === 1 ? operators[0] : choice(...operators)), field('right', $._expression),
    )))),

    identifier: _ => /[A-Za-z_][A-Za-z0-9_]*/,
    integer: _ => /[0-9]+[bBChHiIlLqQ]?/,
    float: _ => token(choice(
      /[0-9]*\.[0-9]+/,
      /[0-9]+\.?[0-9]*[eEdD][+-]?[0-9]+/,
      /\.[0-9]+[eEdD][+-]?[0-9]+/,
      /[0-9]+\.?[0-9]*[dD]/,
      /\.[0-9]+[dD]/,
    )),
    string: $ => seq('"', repeat(choice($.escape_sequence, $.string_content)), '"'),
    string_content: _ => token.immediate(/[^"\\\r\n]+/),
    escape_sequence: _ => token.immediate(/\\[^\r\n]/),
    boolean: _ => choice('True', 'False'),
    missing: _ => 'Missing',
    type: _ => choice('byte', 'ubyte', 'character', 'short', 'ushort', 'integer', 'uint',
      'long', 'ulong', 'int64', 'uint64', 'float', 'double', 'string', 'logical',
      'numeric', 'enumeric', 'snumeric', 'graphic', 'file', 'list', 'group'),
    comment: _ => token(seq(';', /[^\r\n]*/)),
    block_comment: _ => token(seq('/;', /[^;]*;+([^/;][^;]*;+)*/, '/')),
    line_continuation: _ => token(prec(-1, /\\[^\r\n]*\r?\n/)),
  },
});
