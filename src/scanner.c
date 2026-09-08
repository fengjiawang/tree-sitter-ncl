#include "tree_sitter/parser.h"

// A regular lexer would greedily consume `1.` in `1.eq.2`. NCL's lexer
// uses trailing context for this case. Only bare trailing-dot floats need
// lookahead; the other numeric forms remain in grammar.js.
enum TokenType { TRAILING_DOT_FLOAT };

void *tree_sitter_ncl_external_scanner_create(void) { return NULL; }
void tree_sitter_ncl_external_scanner_destroy(void *payload) { (void)payload; }
unsigned tree_sitter_ncl_external_scanner_serialize(void *payload, char *buffer) {
  (void)payload;
  (void)buffer;
  return 0;
}
void tree_sitter_ncl_external_scanner_deserialize(void *payload, const char *buffer, unsigned length) {
  (void)payload;
  (void)buffer;
  (void)length;
}

bool tree_sitter_ncl_external_scanner_scan(void *payload, TSLexer *lexer, const bool *valid_symbols) {
  (void)payload;
  if (!valid_symbols[TRAILING_DOT_FLOAT]) return false;
  while (lexer->lookahead == ' ' || lexer->lookahead == '\t' || lexer->lookahead == '\f') {
    lexer->advance(lexer, true);
  }
  if (lexer->lookahead < '0' || lexer->lookahead > '9') return false;
  do {
    lexer->advance(lexer, false);
  } while (lexer->lookahead >= '0' && lexer->lookahead <= '9');
  if (lexer->lookahead != '.') return false;
  lexer->advance(lexer, false);
  if ((lexer->lookahead >= '0' && lexer->lookahead <= '9') ||
      (lexer->lookahead >= 'a' && lexer->lookahead <= 'z') ||
      (lexer->lookahead >= 'A' && lexer->lookahead <= 'Z') || lexer->lookahead == '_') {
    return false;
  }
  lexer->mark_end(lexer);
  lexer->result_symbol = TRAILING_DOT_FLOAT;
  return true;
}
