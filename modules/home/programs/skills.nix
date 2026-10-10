{
  config,
  lib,
  pkgs,
  ...
}:
let
  specification = pkgs.writeText "dotfiles-skills-sources.json" (
    builtins.toJSON config.programs.skills.sources
  );
  sync = pkgs.writeShellApplication {
    name = "dotfiles-skills-sync";
    runtimeInputs = [
      pkgs.python3
      pkgs.git
    ];
    text = ''
      exec python3 ${./skills-sync.py} \
        --skills-cli ${pkgs.skills}/bin/skills \
        --config ${specification} "$@"
    '';
  };
in
{
  options.programs.skills.sources = lib.mkOption {
    default = [ ];
    description = "Skills CLI sources merged into owned category directories.";
    type = lib.types.listOf (
      lib.types.submodule {
        options = {
          source = lib.mkOption {
            type = lib.types.nonEmptyStr;
            description = "Any source accepted by Skills CLI.";
          };
          category = lib.mkOption {
            type = lib.types.strMatching "[A-Za-z0-9][A-Za-z0-9 &_-]*";
            description = "One safe directory component under ~/.agents/skills.";
          };
          skills = lib.mkOption {
            type = lib.types.nullOr (lib.types.listOf lib.types.nonEmptyStr);
            default = null;
            description = "Original skill names. Null selects all; an empty list selects none.";
          };
        };
      }
    );
  };

  config = {
    home.packages = [ sync ];
    home.activation.skills = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
      if [[ -v DRY_RUN ]]; then
        ${lib.getExe sync} --dry-run
      else
        ${lib.getExe sync}
      fi
    '';
  };
}
