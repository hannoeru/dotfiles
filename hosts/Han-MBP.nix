# Personal MacBook Pro.
{ ... }: {
  imports = [
    (import ../modules/darwin.nix {
      hostname = "Han-MBP";
      username = "hanlee";
      languages = [ "ja-JP" "en-JP" "zh-Hant-JP" ];
      personal = true;
      name = "Han";
      email = "me@hanlee.co";
    })
  ];
}
