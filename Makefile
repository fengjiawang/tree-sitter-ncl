CC ?= cc
CFLAGS ?= -O2
SHARED_FLAGS = -shared
ifeq ($(shell uname -s),Darwin)
SHARED_FLAGS = -dynamiclib
endif

.PHONY: all clean
all: ncl.so

ncl.so: src/parser.c src/scanner.c src/tree_sitter/parser.h src/tree_sitter/alloc.h src/tree_sitter/array.h
	$(CC) $(CPPFLAGS) $(CFLAGS) -std=c11 -fPIC $(SHARED_FLAGS) -Isrc src/parser.c src/scanner.c $(LDFLAGS) -o $@

clean:
	rm -f ncl.so
