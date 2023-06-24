# Rust Analyzer
- Requires `rustc` and `cargo` available in path, otherwise fails somewhat
  silently
- Wrapper script sets RUST_SRC_PATH to internal nix reference by default
- Sysroot Path needs to be configured to `""` on the server, otherwise the above
  variables will be used as a base path
