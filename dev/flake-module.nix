{ inputs, ... }:
{
  imports = [ inputs.treefmt-nix.flakeModule ];

  perSystem =
    { pkgs, system, ... }:
    let
      zig-pkg = inputs.zig.packages.${system}.master;
    in
    {
      devShells.default = pkgs.mkShell {
        packages =
          [ zig-pkg ]
          ++ (with inputs.nixpkgs.legacyPackages.${system}; [
            spdlog
            spdlog.dev
            pkg-config
          ]);
      };

      treefmt = {
        projectRootFile = "flake.nix";
        programs = {
          nixfmt-rfc-style.enable = true;
          deadnix.enable = true;
          statix.enable = true;
          zig = {
            enable = true;
            package = zig-pkg;
          };
        };
        settings.formatter = {
          statix.excludes = [ "auto-generated.nix" ];
        };
      };
    };
}
