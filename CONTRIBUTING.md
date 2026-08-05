# Contributing to Kaku

## Setup

```bash
# Clone the repository
git clone https://github.com/tw93/Kaku.git
cd Kaku

# Install Rust if it isn't already available (Homebrew keeps rustup keg-only)
brew install rustup
echo "export PATH=\"$(brew --prefix rustup)/bin:\$HOME/.cargo/bin:\$PATH\"" >> ~/.zprofile
exec zsh -l
rustup toolchain install 1.95.0

# Install required tools (cargo-nextest, cargo-watch, nightly rustfmt)
make install-tools

# Install pre-commit hook (format + test before each commit)
make install-hooks
```

## Development

| Command | Purpose |
|---------|---------|
| `make fmt` | Auto-format code (requires nightly) |
| `make fmt-check` | Check formatting without modifying files |
| `make check` | Compile check, catch type/syntax errors |
| `make test` | Run unit tests |
| `make dev` | Fast local debug: build `kaku-gui` and run from `target/debug` |
| `make build` | Compile binaries (no app bundle) |
| `make app` | Build debug app bundle → `dist/Kaku.app` |

**Recommended workflow:**

```bash
make fmt        # format first
make check      # verify it compiles
make test       # run tests
make dev        # fast local run without packaging
```

You can override log level for `make dev`:

```bash
RUST_LOG=debug make dev
```

## Build Release

```bash
# Build application and DMG (release, universal binary)
./scripts/build.sh
# Outputs: dist/Kaku.app and dist/Kaku.dmg

# Build for current architecture only (faster, for local testing)
./scripts/build.sh --native-arch

# Build app bundle only (skip DMG creation)
./scripts/build.sh --native-arch --app-only

# Build and open the app automatically
./scripts/build.sh --native-arch --open
```

## Pull Requests

1. Fork and create a branch from `main`
2. Make changes
3. Run `make fmt && make check && make test`
4. Commit and push
5. Open PR targeting `main`

CI runs format check → unit tests → cargo check → universal build validation in order.
