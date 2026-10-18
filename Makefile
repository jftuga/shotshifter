# Build, test and install ShotShifter with Swift Package Manager.
# 'install' only copies a binary built by 'release', so 'sudo make install'
# never runs the Swift build as root.

PREFIX ?= /usr/local
BINARY := shotshifter
RELEASE_DIR = $(shell swift build -c release --arch arm64 --show-bin-path)

.PHONY: build release install test clean

build:
	swift build

release:
	swift build -c release --arch arm64

install:
	@test -f $(RELEASE_DIR)/$(BINARY) || { echo "run 'make release' first"; exit 1; }
	install -d $(PREFIX)/bin
	install -m 0755 $(RELEASE_DIR)/$(BINARY) $(PREFIX)/bin/$(BINARY)

test:
	swift test

clean:
	swift package clean
	rm -rf .build
