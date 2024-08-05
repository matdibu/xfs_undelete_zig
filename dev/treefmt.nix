{
  projectRootFile = "flake.nix";
  programs = {
    nixfmt.enable = true;
    deadnix.enable = true;
    statix.enable = true;
    zig.enable = true;
    clang-format.enable = true;
    ruff.enable = true;
  };
}
