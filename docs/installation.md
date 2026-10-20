# Installation

[Back to README](../README.md)

## Requirements

- macOS 26 or later on Apple Silicon
- Xcode or the Swift 6.2 (or later) toolchain

## Install

With Homebrew:

```
brew install jftuga/tap/shotshifter
```

Release tarballs with SHA-256 checksums are also on the [releases page](https://github.com/jftuga/shotshifter/releases). The binary is not notarized, so if the tarball was downloaded with a browser, clear the quarantine flag before running it: `xattr -d com.apple.quarantine shotshifter`.

To build from source, build the release binary as your own user first:

```
make release
```

Then install it system-wide into `/usr/local/bin`:

```
sudo make install
```

or into your home directory without `sudo`:

```
make install PREFIX=$HOME/.local
```

`make install` never builds anything; it fails with "run 'make release' first" if there is no release binary. Other targets: `make build` (debug build, the default), `make test` and `make clean`.
