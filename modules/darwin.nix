# Shared nix-darwin system configuration for all Macs.
# Machine facts come from machines.nix via the `machine` module argument.
{
  config,
  pkgs,
  lib,
  machine,
  nanorc,
  ...
}:

let
  sharedCasks = [
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
    "google-japanese-ime"
    "input-source-pro"
    "ghostty"
    "karabiner-elements"
    "orbstack"
    "qlmarkdown"
    "qlstephen"
    "quicklook-csv"
    "quicklook-video"
    "quicklookase"
    "raycast"
    "slack"
    "stats"
    "switchresx"
    "syntax-highlight"
    "visual-studio-code"
  ];

  personalCasks = [
    "google-drive"
    "keka"
    "spotify"
  ];
in
{
  nixpkgs.hostPlatform = "aarch64-darwin";
  # The host name is not managed when unset; the machine keeps its own.
  networking.hostName = machine.hostname or null;
  system.primaryUser = machine.username;
  system.stateVersion = 7;

  users.users.${machine.username} = {
    name = machine.username;
    home = "/Users/${machine.username}";
    shell = pkgs.zsh;
  };
  environment.shells = [ pkgs.zsh ];

  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];
  nix.optimise.automatic = true;
  nix.gc = {
    automatic = true;
    interval = [
      {
        Weekday = 0;
        Hour = 2;
        Minute = 0;
      }
    ];
    options = "--delete-older-than 30d";
  };

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
      # Absolute path: macOS does not expand ~ in this preference.
      location = "/Users/${machine.username}/Desktop/Screenshots";
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

  # Per-host preference without a typed option. Must run inside one of the
  # enumerated activation scripts; custom names are never invoked.
  system.activationScripts.postActivation.text = ''
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

    casks = sharedCasks ++ lib.optionals machine.personal personalCasks;
  };

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    backupFileExtension = "backup";
    extraSpecialArgs = { inherit machine nanorc; };
    users.${machine.username} = {
      imports = [ ./home ];
    };
  };
}
