#ifndef BASE_DIR
BASE_DIR=/usr/local/bin
#endif

all: help

.PHONY: help
help:
	@echo "Install:     make [BASE_DIR=<target>] install"
	@echo "Uninstall:   make [BASE_DIR=<target>] uninstall"
	@echo "Where BASE_DIR is the target installation directory (by default: /usr/local/bin)"

.PHONY: install
install: $(BASE_DIR)/sdfm

.PHONY: uninstall
uninstall: $(BASE_DIR)/sdfm
	rm -rf $<

$(BASE_DIR)/sdfm: sdfm.sh
	install $< $@
