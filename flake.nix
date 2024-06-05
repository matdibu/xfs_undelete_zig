{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    systems.url = "github:nix-systems/default";
    treefmt-nix = {
      url = "github:numtide/treefmt-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    flake-utils = {
      url = "github:numtide/flake-utils";
      inputs.systems.follows = "systems";
    };
    zig-overlay = {
      url = "github:mitchellh/zig-overlay";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        flake-utils.follows = "flake-utils";
      };
    };
    zls-flake = {
      url = "github:zigtools/zls";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        zig-overlay.follows = "zig-overlay";
        flake-utils.follows = "flake-utils";
      };
    };
    gitignore = {
      url = "github:hercules-ci/gitignore.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      zig-overlay,
      zls-flake,
      treefmt-nix,
      gitignore,
      systems,
      ...
    }@inputs:
    let
      eachSystem = f: nixpkgs.lib.genAttrs (import systems) (system: f nixpkgs.legacyPackages.${system});
      treefmtEval = eachSystem (pkgs: treefmt-nix.lib.evalModule pkgs ./dev/treefmt.nix);
      inherit (gitignore.lib) gitignoreSource;
    in
    {
      # for `nix fmt`
      formatter = eachSystem (pkgs: treefmtEval.${pkgs.system}.config.build.wrapper);

      # for `nix flake check`
      checks = eachSystem (pkgs: {
        formatting = treefmtEval.${pkgs.system}.config.build.check self;
      });

      # for `nix build`
      packages = eachSystem (pkgs: let zig = inputs.zig-overlay.packages.${pkgs.system}.master; in {
        default = self.packages.${pkgs.system}.xfs_undelete;
        "xfs_undelete" = pkgs.stdenvNoCC.mkDerivation {
          name = "xfs_undelete";
          version = "master";
          src = gitignoreSource ./.;
          strictDeps = true;
          nativeBuildInputs = [ zig pkgs.libuuid.dev pkgs.libxfs.dev pkgs.pkg-config ];
          buildInputs = [ zig pkgs.libuuid.dev pkgs.libxfs.dev pkgs.pkg-config ];
          dontConfigure = true;
          dontInstall = true;
          doCheck = true;
          patchPhase = ''
            substituteInPlace build.zig \
                --replace-fail "/nix/store/1s5mym5ar49hwqmxn9baasyw0kbckgmf-xfsprogs-6.8.0-dev/" \
                "${pkgs.libxfs.dev}/"

            substituteInPlace build.zig \
                --replace-fail "/nix/store/sw3a1cypmpgh8gvlhhxby0wl9f80wg53-util-linux-minimal-2.40.1-dev/" \
                "${pkgs.libuuid.dev}/"
          '';
          buildPhase = ''
            mkdir -p .cache
            ln -s \
                ${pkgs.callPackage ./deps.nix { inherit zig; }} \
                .cache/p
            zig build \
                --verbose \
                -freference-trace \
                --prefix $out \
                --cache-dir $(pwd)/.zig-cache \
                --global-cache-dir $(pwd)/.cache \
                -Dcpu=baseline
          '';
          checkPhase = ''
            zig build test \
                -freference-trace \
                --cache-dir $(pwd)/.zig-cache \
                --global-cache-dir $(pwd)/.cache \
                -Dcpu=baseline
          '';
        };
      });

      # for `nix develop`
      devShells = eachSystem (pkgs: {
        default = pkgs.mkShellNoCC {
          packages = with pkgs; [
            # build
            zig-overlay.packages.${pkgs.system}.master
            pkg-config
            libuuid.dev
            libxfs.dev

            # dev
            zls-flake.packages.${pkgs.system}.zls
            python3
            ruff-lsp
          ];
        };
      });
    };
}
