{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    systems.url = "github:nix-systems/default";
    flake-compat.url = "github:edolstra/flake-compat";
    flake-parts = {
      url = "github:hercules-ci/flake-parts";
      inputs.nixpkgs-lib.follows = "nixpkgs";
    };
    treefmt-nix = {
      url = "github:numtide/treefmt-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Rust
    crane.url = "github:ipetkov/crane";
    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    inputs:
    inputs.flake-parts.lib.mkFlake { inherit inputs; } {
      systems = import inputs.systems;
      imports = [
        inputs.treefmt-nix.flakeModule
      ];

      perSystem =
        { pkgs, lib, system, ... }:
        let
          # lightmix derivation
          lightmix = pkgs.stdenv.mkDerivation {
            name = "lightmix";
            src = lib.cleanSource ./.;
            doCheck = true;

            nativeBuildInputs = [
              pkgs.zig_0_15.hook
            ];

            postPatch = ''
              ln -s ${pkgs.callPackage ./.deps.nix { }} $ZIG_GLOBAL_CACHE_DIR/p
            '';
          };

          # Rust
          rust = pkgs.rust-bin.fromRustupToolchainFile ./docs/homepage/rust-toolchain.toml;
          craneLib = (inputs.crane.mkLib pkgs).overrideToolchain rust;
          overlays = [ inputs.rust-overlay.overlays.default ];
        in
        {
          _module.args.pkgs = import inputs.nixpkgs {
            inherit system overlays;
          };

          treefmt = {
            projectRootFile = ".git/config";

            # Nix
            programs.nixfmt.enable = true;

            # Zig
            programs.zig.enable = true;
            settings.formatter.zig.command = lib.getExe pkgs.zig_0_15;

            # GitHub Actions
            programs.actionlint.enable = true;

            # Markdown
            programs.mdformat.enable = true;
            settings.formatter.mdformat.excludes = [ "CODE_OF_CONDUCT.md" ];
          };

          packages = {
            inherit lightmix;
            default = lightmix;
          };

          checks = {
            inherit lightmix;
          };

          devShells.default = pkgs.mkShell {
            nativeBuildInputs = [
              # Compiler
              pkgs.zig_0_15

              # LSP
              pkgs.nil
              pkgs.zls

              # Music Player
              pkgs.sox # Use this command as: `play result.wav`

              # zon2nix
              pkgs.zon2nix
            ];

            shellHook = ''
              export ZIG_GLOBAL_CACHE_DIR=$TMPDIR;
            '';
          };

          devShells.homepage = pkgs.mkShell {
            nativeBuildInputs = [
              # Compiler
              rust
              pkgs.dioxus-cli
              pkgs.wasm-bindgen-cli_0_2_105

              # LSP
              pkgs.nil
            ];
          };
        };
    };
}
