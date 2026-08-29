# Shared nix-darwin system configuration for all Macs.
#
# `machine` describes the target machine:
#   hostname  - host name, also the flake configuration name
#   username  - login name of the primary user
#   languages - preferred UI languages, most preferred first
#   personal  - whether this machine may read personal secrets from 1Password
#   name      - git user name
#   email     - git user email
machine:
{ config, pkgs, lib, antidote, nanorc, ... }:

{
  networking.hostName = machine.hostname;
  system.primaryUser = machine.username;

  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  users.users.${machine.username} = {
    name = machine.username;
    shell = pkgs.zsh;
  };
  environment.shells = [ pkgs.zsh ];

  system.defaults = {
    NSGlobalDomain = {
      AppleInterfaceStyle = "Dark";
      AppleMeasurementUnits = "Centimeters";
      AppleTemperatureUnit = "Celsius";
      AppleMetricUnits = true;
      KeyRepeat = 1;
      InitialKeyRepeat = 30;
      AppleKeyboardUIMode = 3;
      AppleShowAllExtensions = true;
    };

    dock = {
      tilesize = 16;
      mineffect = "scale";
      minimize-to-application = true;
      autohide = true;
      autohide-delay = 1000.0;
    };

    finder = {
      ShowPathbar = true;
      FXPreferredViewStyle = "Nlsv";
      _FXSortFoldersFirst = true;
      _FXSortFoldersFirstOnDesktop = true;
      FXDefaultSearchScope = "SCcf";
      FXEnableExtensionChangeWarning = false;
    };

    screencapture = {
      location = "~/Desktop/Screenshots";
      type = "png";
    };

    menuExtraClock.IsAnalog = true;

    ActivityMonitor = {
      OpenMainWindow = true;
      IconType = 5;
      ShowCategory = 0;
      SortColumn = "CPUUsage";
      SortDirection = 0;
    };

    CustomUserPreferences = {
      NSGlobalDomain = {
        AppleLanguages = machine.languages;
        AppleLocale = "ja_JP@currency=JPY";
      };
      "com.apple.dock".no-bouncing = true;
      "com.apple.TimeMachine".DoNotOfferNewDisksForBackup = true;
      "com.apple.appstore" = {
        WebKitDeveloperExtras = true;
        ShowDebugMenu = true;
      };
      "com.apple.SoftwareUpdate" = {
        AutomaticCheckEnabled = true;
        ScheduleFrequency = 1;
        AutomaticDownload = 1;
        CriticalUpdateInstall = 1;
        ConfigDataInstall = 1;
      };
      "com.apple.commerce" = {
        AutoUpdate = true;
        AutoUpdateRestartRequired = true;
      };
      "com.google.Chrome".AppleEnableSwipeNavigateWithScrolls = false;
      "com.google.Chrome.canary".AppleEnableSwipeNavigateWithScrolls = false;
    };
  };

  # Per-host preference, not exposed as a typed option.
  system.activationScripts.userDefaults.text = ''
    uid="$(id -u ${machine.username})"
    launchctl asuser "$uid" sudo -u ${machine.username} \
      defaults -currentHost write com.apple.ImageCapture disableHotPlug -bool true
  '';

  homebrew = {
    enable = true;
    onActivation = {
      autoUpdate = true;
      upgrade = false;
      cleanup = "none";
    };

    # CLI tools come from nixpkgs; Homebrew keeps only what Nix cannot
    # provide (GUI apps, fonts, and keg-only formulae referenced in ~/.envfile).
    brews = [
      "curl"
      "openssl@3"
      "grep"
    ];

    casks = [
      "1password"
      "1password-cli"
      "alt-tab"
      "appcleaner"
      "bettertouchtool"
      "cursor"
      "figma"
      "firefox"
      "firefox@developer-edition"
      "font-input"
      "font-meslo-lg-nerd-font"
      "font-monaspace"
      "gcloud-cli"
      "google-chrome"
      "google-chrome@canary"
      "google-drive"
      "google-japanese-ime"
      "input-source-pro"
      "ghostty"
      "karabiner-elements"
      "keka"
      "orbstack"
      "qlmarkdown"
      "qlstephen"
      "quicklook-csv"
      "quicklook-video"
      "quicklookase"
      "raycast"
      "slack"
      "spotify"
      "stats"
      "switchresx"
      "syntax-highlight"
      "visual-studio-code"
    ];

    vscode = [
      "1yib.rust-bundle"
      "3w36zj6.textlint"
      "42crunch.vscode-openapi"
      "aaron-bond.better-comments"
      "adamhartford.vscode-base64"
      "alexcvzz.vscode-sqlite"
      "anseki.vscode-color"
      "antfu.file-nesting"
      "antfu.goto-alias"
      "antfu.iconify"
      "antfu.icons-carbon"
      "antfu.open-in-github-button"
      "antfu.pnpm-catalog-lens"
      "antfu.slidev"
      "antfu.theme-vitesse"
      "antfu.unocss"
      "aws-scripting-guy.cform"
      "belfz.search-crates-io"
      "bierner.markdown-mermaid"
      "bradlc.vscode-tailwindcss"
      "chakrounanas.turbo-console-log"
      "charliermarsh.ruff"
      "cpylua.language-postcss"
      "csstools.postcss"
      "dbaeumer.vscode-eslint"
      "denoland.vscode-deno"
      "docker.docker"
      "dotjoshjohnson.xml"
      "drblury.protobuf-vsc"
      "drcika.apc-extension"
      "dsznajder.es7-react-js-snippets"
      "dunstontc.viml"
      "dustypomerleau.rust-syntax"
      "eamodio.gitlens"
      "editorconfig.editorconfig"
      "eliostruyf.vscode-typescript-exportallmodules"
      "esbenp.prettier-vscode"
      "esphome.esphome-vscode"
      "fabiospampinato.vscode-open-in-github"
      "figma.figma-vscode-extension"
      "formulahendry.code-runner"
      "fosshaas.fontsize-shortcuts"
      "foxundermoon.shell-format"
      "fwcd.kotlin"
      "github.codespaces"
      "github.github-vscode-theme"
      "github.remotehub"
      "github.vscode-github-actions"
      "github.vscode-pull-request-github"
      "golang.go"
      "grafana.vscode-jsonnet"
      "graphql.vscode-graphql"
      "graphql.vscode-graphql-syntax"
      "gruntfuggly.todo-tree"
      "hashicorp.hcl"
      "hbenl.vscode-test-explorer"
      "hediet.vscode-drawio"
      "humao.rest-client"
      "ibm.output-colorizer"
      "intuita.intuita-vscode-extension"
      "inu1255.easy-snippet"
      "jannisx11.batch-rename-extension"
      "jasonnutter.search-node-modules"
      "jebbs.plantuml"
      "jeff-hykin.better-cpp-syntax"
      "jock.svg"
      "johnsoncodehk.vscode-tsconfig-helper"
      "josetr.cmake-language-support-vscode"
      "kaiwood.endwise"
      "kisstkondoros.vscode-gutter-preview"
      "kokororin.vscode-phpfmt"
      "kumar-harsh.graphql-for-vscode"
      "lokalise.i18n-ally"
      "mamodom.package-json-dependencies-navigation"
      "meganrogge.template-string-converter"
      "mikestead.dotenv"
      "mirone.milkdown"
      "mkxml.vscode-filesize"
      "mongodb.mongodb-vscode"
      "mpontus.tab-cycle"
      "mrmlnc.vscode-json5"
      "ms-azuretools.vscode-azureresourcegroups"
      "ms-azuretools.vscode-containers"
      "ms-azuretools.vscode-docker"
      "ms-dotnettools.csdevkit"
      "ms-dotnettools.csharp"
      "ms-dotnettools.vscode-dotnet-runtime"
      "ms-kubernetes-tools.vscode-kubernetes-tools"
      "ms-ossdata.vscode-pgsql"
      "ms-playwright.playwright"
      "ms-python.debugpy"
      "ms-python.isort"
      "ms-python.python"
      "ms-python.vscode-pylance"
      "ms-python.vscode-python-envs"
      "ms-toolsai.jupyter"
      "ms-toolsai.jupyter-keymap"
      "ms-toolsai.jupyter-renderers"
      "ms-toolsai.vscode-jupyter-cell-tags"
      "ms-toolsai.vscode-jupyter-slideshow"
      "ms-vscode-remote.remote-containers"
      "ms-vscode-remote.remote-ssh"
      "ms-vscode-remote.remote-ssh-edit"
      "ms-vscode-remote.remote-wsl"
      "ms-vscode-remote.vscode-remote-extensionpack"
      "ms-vscode.cmake-tools"
      "ms-vscode.cpp-devtools"
      "ms-vscode.cpptools"
      "ms-vscode.cpptools-extension-pack"
      "ms-vscode.cpptools-themes"
      "ms-vscode.live-server"
      "ms-vscode.makefile-tools"
      "ms-vscode.remote-explorer"
      "ms-vscode.remote-repositories"
      "ms-vscode.remote-server"
      "ms-vscode.test-adapter-converter"
      "ms-vsliveshare.vsliveshare"
      "nhoizey.gremlins"
      "nuxt.mdc"
      "nuxtr.nuxtr-vscode"
      "opentofu.vscode-opentofu"
      "oxc.oxc-vscode"
      "peterschmalfeldt.explorer-exclude"
      "pkief.material-icon-theme"
      "platformio.platformio-ide"
      "pnp.polacode"
      "prisma.prisma"
      "quicktype.quicktype"
      "rangav.vscode-thunder-client"
      "redhat.java"
      "redhat.vscode-yaml"
      "redocly.openapi-vs-code"
      "rust-lang.rust-analyzer"
      "shanoor.vscode-nginx"
      "shd101wyy.markdown-preview-enhanced"
      "shopify.ruby-lsp"
      "skyapps.fish-vscode"
      "sleistner.vscode-fileutils"
      "streetsidesoftware.code-spell-checker"
      "styled-components.vscode-styled-components"
      "stylelint.vscode-stylelint"
      "svelte.svelte-vscode"
      "syler.sass-indented"
      "sysoev.language-stylus"
      "tamasfe.even-better-toml"
      "tim-koehler.helm-intellisense"
      "tomoki1207.pdf"
      "twxs.cmake"
      "tyriar.sort-lines"
      "unifiedjs.vscode-mdx"
      "usernamehw.errorlens"
      "vadimcn.vscode-lldb"
      "vitest.explorer"
      "vmware.vscode-boot-dev-pack"
      "vmware.vscode-spring-boot"
      "vscjava.migrate-java-to-azure"
      "vscjava.vscode-gradle"
      "vscjava.vscode-java-debug"
      "vscjava.vscode-java-dependency"
      "vscjava.vscode-java-pack"
      "vscjava.vscode-java-test"
      "vscjava.vscode-maven"
      "vscjava.vscode-spring-boot-dashboard"
      "vscjava.vscode-spring-initializr"
      "vscodevim.vim"
      "vue.volar"
      "wakatime.vscode-wakatime"
      "wayou.vscode-todo-highlight"
      "wheatjs.vueuse"
      "xabikos.javascriptsnippets"
      "xaver.clang-format"
      "xdebug.php-debug"
      "yoavbls.pretty-ts-errors"
      "yzane.markdown-pdf"
      "yzhang.markdown-all-in-one"
      "zhuangtongfa.material-theme"
      "znck.grammarly"
    ];
  };

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    backupFileExtension = "backup";
    extraSpecialArgs = { inherit antidote nanorc; };
    users.${machine.username} = { config, ... }: {
      imports = [
        (import ./home.nix {
          os = "darwin";
          username = machine.username;
          personal = machine.personal;
          name = machine.name;
          email = machine.email;
        })
      ];
    };
  };
}
