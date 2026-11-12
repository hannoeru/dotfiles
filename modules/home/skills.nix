# Portable skills linked at ~/.agents/skills/<category>/<name>.
# Directories are the ones the Skills CLI publishes for this catalogue.
# Sources are flake inputs, so activation does not fetch or install anything.
{
  lib,
  skillInputs,
  ...
}:
let
  inherit (skillInputs)
    mattpocock
    shadcnImprove
    jscpd
    simpleEnglish
    cursorPlugins
    iHaveAdhd
    antfu
    vuejs
    nuxt
    anthropics
    agentBrowser
    herdr
    pstack
    ;

  renderSkill = name: path: ''
    ## ${name}

    Skill source: `${path}`.
    Resolve relative references from this file's directory.
    These instructions are already loaded. Read only the references needed for the task.

    ${lib.concatStringsSep "\n---\n" (lib.tail (lib.splitString "\n---\n" (builtins.readFile path)))}
  '';

  # category/name -> skill directory
  skills = {
    "Workflow/grill-me" = mattpocock + "/skills/productivity/grill-me";
    "Workflow/grilling" = mattpocock + "/skills/productivity/grilling";
    "Workflow/handoff" = mattpocock + "/skills/productivity/handoff";
    "Workflow/to-questionnaire" = mattpocock + "/skills/productivity/to-questionnaire";
    "Workflow/writing-for-agents" = mattpocock + "/skills/productivity/writing-for-agents";
    "Workflow/teach" = mattpocock + "/skills/productivity/teach";
    "Workflow/code-review" = mattpocock + "/skills/engineering/code-review";
    "Workflow/codebase-design" = mattpocock + "/skills/engineering/codebase-design";
    "Workflow/research" = mattpocock + "/skills/engineering/research";
    "Workflow/tdd" = mattpocock + "/skills/engineering/tdd";
    "Workflow/improve" = shadcnImprove + "/skills/improve";
    "Workflow/dry-refactoring" = jscpd + "/skills/dry-refactoring";
    "Workflow/antfu" = antfu + "/skills/antfu";

    "Writing/simple-english" = simpleEnglish + "/skills/simple-english";
    "Writing/unslop" = cursorPlugins + "/pstack/skills/unslop";
    "Writing/bro" = cursorPlugins + "/pstack/skills/bro";
    "Writing/i-have-adhd" = iHaveAdhd + "/skills/i-have-adhd";

    "Vue & Nuxt/vue-best-practices" = vuejs + "/skills/vue-best-practices";
    "Vue & Nuxt/vue-router-best-practices" = vuejs + "/skills/vue-router-best-practices";
    "Vue & Nuxt/vue-pinia-best-practices" = vuejs + "/skills/vue-pinia-best-practices";
    "Vue & Nuxt/vue-testing-best-practices" = vuejs + "/skills/vue-testing-best-practices";
    "Vue & Nuxt/vue-debug-guides" = vuejs + "/skills/vue-debug-guides";
    "Vue & Nuxt/create-adaptable-composable" = vuejs + "/skills/create-adaptable-composable";
    "Vue & Nuxt/nuxt-modules" = nuxt + "/skills/nuxt-modules";

    "Design/frontend-design" = anthropics + "/skills/frontend-design";
    "Browser/agent-browser" = agentBrowser + "/skills/agent-browser";
    "Terminal/herdr" = herdr + "/skills/herdr";

    # Authored in this repository and linked for every machine.
    # Pi also scans ~/.pi/agent/skills; ~/.agents/skills is enough.
    "Workflow/analyze-issue" = ../../home/skills/analyze-issue;
    "Workflow/create-pr" = ../../home/skills/create-pr;
    "Workflow/deslop" = ../../home/skills/deslop;
    "Workflow/review-pr" = ../../home/skills/review-pr;
    "Workflow/wrap-up" = ../../home/skills/wrap-up;
    "Vue & Nuxt/nuxt-cloudflare" = ../../home/skills/nuxt-cloudflare;
  };
in
{
  home.file =
    (lib.mapAttrs' (
      path: source:
      lib.nameValuePair ".agents/skills/${path}" {
        inherit source;
        recursive = true;
      }
    ) skills)
    // {
      ".pi/agent/APPEND_SYSTEM.md".text = ''
        # Preloaded skills

        Nix generates this file from pinned skill sources.
        Follow Poteto Mode by default unless the human disables it.
        Apply Herdr instructions only when `HERDR_ENV=1`.
        Explicit restrictions from the human take precedence over these skill defaults.
        The Herdr section in AGENTS.md authorizes Herdr worktrees and worker agents.
        Preloading applies instructions. It does not set pstack's stored mode state.

        ${renderSkill "Poteto Mode" (pstack + "/skills/poteto-mode/SKILL.md")}
        ${renderSkill "Herdr" (herdr + "/skills/herdr/SKILL.md")}
      '';
    };
}
