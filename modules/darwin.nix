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
    "orbstack"
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

  # Nix is installed by the Determinate installer, which manages the
  # daemon itself; nix-darwin must not manage it.
  nix.enable = false;

  system.defaults = {
    NSGlobalDomain = {
      AppleInterfaceStyle = "Dark";
      KeyRepeat = 1;
      InitialKeyRepeat = 30;
      AppleKeyboardUIMode = 3;
      AppleShowAllExtensions = true;
      # Key repeat instead of the accent-character popup.
      ApplePressAndHoldEnabled = false;
    };

    dock = {
      tilesize = 16;
      mineffect = "scale";
      minimize-to-application = true;
      autohide = true;
      autohide-delay = 1000.0;
      launchanim = false;
      show-recents = false;
      expose-group-apps = true;
    };

    finder = {
      ShowPathbar = true;
      ShowStatusBar = true;
      FXPreferredViewStyle = "Nlsv";
      _FXSortFoldersFirst = true;
      _FXSortFoldersFirstOnDesktop = true;
      FXDefaultSearchScope = "SCcf";
      FXEnableExtensionChangeWarning = false;
      NewWindowTarget = "Home";
    };

    screencapture = {
      # Absolute path: macOS does not expand ~ in this preference.
      location = "/Users/${machine.username}/Desktop/Screenshots";
    };

    WindowManager.EnableStandardClickToShowDesktop = false;

    menuExtraClock = {
      ShowDate = 1;
      ShowDayOfWeek = true;
      ShowSeconds = true;
    };

    ActivityMonitor.IconType = 5;

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
        # Daily, not the factory weekly.
        ScheduleFrequency = 1;
      };
      "com.apple.commerce".AutoUpdateRestartRequired = true;
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
