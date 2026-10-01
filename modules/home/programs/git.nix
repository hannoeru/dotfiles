{ machine, ... }:

{
  programs.delta = {
    enable = true;
    enableGitIntegration = true;
    options = {
      navigate = true;
      line-numbers = true;
    };
  };

  programs.git = {
    enable = true;
    # Written to ~/.config/git/ignore (git's default excludes file).
    ignores = [
      "# Folder view configuration files"
      ".DS_Store"
      "Desktop.ini"
      ""
      "# Thumbnail cache files"
      "._*"
      "Thumbs.db"
      ""
      "# Files that might appear on external disks"
      ".Spotlight-V100"
      ".Trashes"
      ""
      "# Compiled Python files"
      "*.pyc"
      ""
      "# Compiled C++ files"
      "*.out"
      ""
      "# Application specific files"
      "venv"
      "node_modules"
      ".sass-cache"
      ""
      "# AI stuff"
      ".pi-lens"
      ".pi-subagents"
      "**/.claude/settings.local.json"
    ];

    # ~/.config/git/signing.gitconfig is written by
    # home.activation.signingKey when 1Password is available; git
    # silently ignores missing include files.
    includes = [
      { path = "~/.config/git/signing.gitconfig"; }
      {
        path = "~/projects/.gitconfig";
        condition = "gitdir:~/projects/";
      }
    ];

    settings = {
      user = {
        name = machine.name;
        email = machine.email;
      };
      core = {
        editor = "code --wait";
        autocrlf = "input";
        safecrlf = true;
      };
      column.ui = "auto";
      branch.sort = "-committerdate";
      tag.sort = "version:refname";
      init.defaultBranch = "main";
      diff = {
        algorithm = "histogram";
        colorMoved = "plain";
        mnemonicPrefix = true;
        renames = true;
      };
      merge.conflictstyle = "zdiff3";
      pull.rebase = true;
      push = {
        default = "simple";
        autoSetupRemote = true;
        followTags = true;
      };
      fetch = {
        prune = true;
        pruneTags = true;
        all = true;
      };
      help.autocorrect = "prompt";
      commit.verbose = true;
      rerere = {
        enabled = true;
        autoupdate = true;
      };
      rebase = {
        autosquash = true;
        autostash = true;
        updateRefs = true;
      };
      credential."https://dev.azure.com".useHttpPath = true;
      url."https://github.com/".insteadOf = "git@github.com:";
      filter.lfs = {
        process = "git-lfs filter-process";
        required = true;
        clean = "git-lfs clean -- %f";
        smudge = "git-lfs smudge -- %f";
      };
      alias = {
        co = "checkout";
        ci = "commit";
        st = "status";
        br = "branch";
        hist = "log --pretty=format:'%h %ad | %s%d [%an]' --graph --date=short";
        type = "cat-file -t";
        dump = "cat-file -p";
        ac = "commit -am";
        fpush = "push --force-with-lease";
      };
    };
  };
}
