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
  };

  outputs =
    inputs:
    inputs.flake-parts.lib.mkFlake { inherit inputs; } {
      systems = import inputs.systems;
      imports = [
        inputs.treefmt-nix.flakeModule
      ];

      perSystem =
        { pkgs, lib, ... }:
        let
          lightmix = pkgs.stdenv.mkDerivation {
            name = "lightmix";
            src = lib.cleanSource ./.;
            doCheck = true;

            nativeBuildInputs = [
              pkgs.zig_0_14.hook
            ];
          };
        in
        {
          treefmt = {
            projectRootFile = ".git/config";

            # Nix
            programs.nixfmt.enable = true;

            # Rust
            programs.rustfmt.enable = true;

            # TOML
            programs.taplo.enable = true;

            # GitHub Actions
            programs.actionlint.enable = true;

            # Markdown
            programs.mdformat.enable = true;

            # ShellScript
            programs.shellcheck.enable = true;
            programs.shfmt.enable = true;
          };

          packages = {
            inherit lightmix;
            default = lightmix;
          };

          checks = {
            inherit lightmix;
          };

          devShells.default = pkgs.mkShell {
            packages = [
              # Zig
              pkgs.zig_0_14
              pkgs.zls

              # Nix
              pkgs.nil

              # Music Player
              pkgs.sox # Use this command as: `play result.wav`
            ];
          };
        };
    };
}
