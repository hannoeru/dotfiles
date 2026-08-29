# Work MacBook.
{ ... }: {
  imports = [
    (import ../modules/darwin.nix {
      hostname = "LX-240047";
      username = "hanlee";
      languages = [ "en-US" "ja-JP" "zh-Hant-JP" ];
      personal = false;
      name = "";
      email = "";
    })
  ];
}
