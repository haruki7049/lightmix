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
              pkgs.zig_0_15.hook
            ];

            postPatch = ''
              ln -s ${pkgs.callPackage ./.deps.nix { }} $ZIG_GLOBAL_CACHE_DIR/p
            '';
          };
        in
        {
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

              # C library manager
              pkgs.pkg-config

              # LSP
              pkgs.nil
              pkgs.zls

              # Music Player
              pkgs.sox # Use this command as: `play result.wav`

              # zon2nix
              pkgs.zon2nix
            ];

            buildInputs = [
              pkgs.portaudio
              pkgs.libsndfile
            ];
          };

          devShells.website = pkgs.mkShell {
            nativeBuildInputs = [
              # Runtime
              pkgs.bun

              # LSP
              pkgs.nil # Nix
              pkgs.typescript-language-server # Typescript
            ];
          };
        };
    };
}
