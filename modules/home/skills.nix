# Portable skills linked at ~/.agents/skills/<category>/<name>.
# Directories are the ones the Skills CLI publishes for this catalogue.
# Pins are explicit so activation does not fetch or install anything.
{
  lib,
  pkgs,
  ...
}:
let
  github =
    {
      owner,
      repo,
      rev,
      hash,
    }:
    pkgs.fetchFromGitHub {
      inherit
        owner
        repo
        rev
        hash
        ;
    };

  mattpocock = github {
    owner = "mattpocock";
    repo = "skills";
    rev = "49dd158d1076134a641b33efb035946536778336";
    hash = "sha256-NljCSZNI3sZ+vbCw7pRdrwR7try4BxOFp4gdjuWYtzs=";
  };
  shadcnImprove = github {
    owner = "shadcn";
    repo = "improve";
    rev = "cac56e1ebd3c279aa9153616cfeac7b174ab90f9";
    hash = "sha256-czQV2LzhVddiT6kz0Wf3z+hHqGBgl4Zh/qw6hN3qEQw=";
  };
  jscpd = github {
    owner = "kucherenko";
    repo = "jscpd";
    rev = "19f2c88515a5d3089f27de98e17d5dc6bb47985b";
    hash = "sha256-mQBlSyxRz2O9qL3txXbExR0rDIvpoaw6hLYI+JXrv1Q=";
  };
  simpleEnglish = github {
    owner = "AminBlg";
    repo = "SimpleEnglish";
    rev = "a6fcb4fde098b33617cc1578d151ebf58774b883";
    hash = "sha256-p1ffLp/3Yg1yBfCikBwua3ieVBCNyZfTZH6GBAxNREA=";
  };
  cursorPlugins = github {
    owner = "cursor";
    repo = "plugins";
    rev = "5108b719a7aa484ef1a9781f587c7bbeac793f92";
    hash = "sha256-oHxsrzvuQPGri0QFZpL0WVX++4a3OV2SEcuYRbkm4XU=";
  };
  iHaveAdhd = github {
    owner = "ayghri";
    repo = "i-have-adhd";
    rev = "1ecea1993b7fce257ffbd686c070948b5e07eda6";
    hash = "sha256-GTqrnZxQvzo/ogAuUrffkOaMK1BYm/4rAZsnfmDt7DU=";
  };
  antfu = github {
    owner = "antfu";
    repo = "skills";
    rev = "feb0f3aba6566426f12230e7fc7a10d97c1293bb";
    hash = "sha256-o/OH4HGRhBH9p08UfUX8K31JuISSIDO9O4zZDrwzJL4=";
  };
  vuejs = github {
    owner = "vuejs-ai";
    repo = "skills";
    rev = "c9d355ff23f654309dd02006be671859df0a134c";
    hash = "sha256-h/4Zbs/c9a7EiglvTTzZ9hpHIsK5tiwl5sZH7ptGkdM=";
  };
  nuxt = github {
    owner = "onmax";
    repo = "nuxt-skills";
    rev = "46aaca09d588767c26e13781318a1593a7260fb5";
    hash = "sha256-95Jkm3p5/ukFnsy9BUEb6OpXSFkLWIlPoEEVnuZfIZ4=";
  };
  anthropics = github {
    owner = "anthropics";
    repo = "skills";
    rev = "dbd4588f9e1033efb41dad4bef2f7947c8993d44";
    hash = "sha256-+UIqBnzyeIOvJSKYaDaE3GYPEpLw7qQqyUw5S971AfU=";
  };
  agentBrowser = github {
    owner = "vercel-labs";
    repo = "agent-browser";
    rev = "1165952d74ceed98fdc2dd97190ad41f44dd0e24";
    hash = "sha256-WIg6WAnk3728NrZVh8JYtu2iRoHi8lYT2e5CDgOg2Sc=";
  };

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
    "Workflow/antfu-create-pr" = antfu + "/skills/antfu-create-pr";

    "Writing/simple-english" = simpleEnglish + "/skills/simple-english";
    "Writing/unslop" = cursorPlugins + "/pstack/skills/unslop";
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

    # Authored in this repository and linked for every machine.
    # Pi also scans ~/.pi/agent/skills; ~/.agents/skills is enough.
    "Writing/bro" = ../../home/skills/bro;
    "Vue & Nuxt/nuxt-cloudflare" = ../../home/skills/nuxt-cloudflare;
  };
in
{
  home.file = lib.mapAttrs' (
    path: source:
    lib.nameValuePair ".agents/skills/${path}" {
      inherit source;
      recursive = true;
    }
  ) skills;
}
