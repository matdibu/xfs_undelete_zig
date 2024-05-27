{
  projectRootFile = "flake.nix";
  programs = {
    nixfmt-rfc-style.enable = true;
    deadnix.enable = true;
    statix.enable = true;
    zig.enable = true;
    clang-format.enable = true;
  };
}
