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
  system.stateVersion = 7;

  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  users.users.${machine.username} = {
    name = machine.username;
    home = "/Users/${machine.username}";
    shell = pkgs.zsh;
  };
  environment.shells = [ pkgs.zsh ];

  system.defaults = {
    NSGlobalDomain = {
      AppleInterfaceStyle = "Dark";
      AppleMeasurementUnits = "Centimeters";
      AppleTemperatureUnit = "Celsius";
      AppleMetricUnits = 1;
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
      ShowCategory = 100;
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
  system.activationScripts.imageCaptureDefaults.text = ''
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
    # provide: GUI apps, fonts, and the keg-only formulae whose paths
    # ~/.envfile adds to PATH. VS Code extensions are not managed here.
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

  };

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    backupFileExtension = "backup";
    extraSpecialArgs = { inherit antidote nanorc; };
    users.${machine.username} = { config, ... }: {
      imports = [
        (import ./home.nix (machine // { os = "darwin"; }))
      ];
    };
  };
}
