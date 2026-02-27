PREFIX ?= $(HOME)/.local
BINDIR ?= $(PREFIX)/bin
BINARY := _build/default/bin/main.exe
NAME   := link_verifier

.PHONY: all build test install uninstall release clean

all: build

build:
	dune build

test:
	dune runtest

install: build
	@mkdir -p $(BINDIR)
	rm -f $(BINDIR)/$(NAME)
	cp $(BINARY) $(BINDIR)/$(NAME)
	chmod +x $(BINDIR)/$(NAME)
	@echo "installed $(BINDIR)/$(NAME)"

uninstall:
	rm -f $(BINDIR)/$(NAME)

release: build
	rm -f $(NAME)
	cp $(BINARY) $(NAME)
	chmod +x $(NAME)
	shasum -a 256 $(NAME) > $(NAME).sha256

clean:
	dune clean
	rm -f $(NAME) $(NAME).sha256
