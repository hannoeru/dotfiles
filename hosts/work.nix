# Work MacBook. The host name is set by the employer's device management
# and is intentionally not declared here.
{ ... }: {
  imports = [
    (import ../modules/darwin.nix {
      username = "hanlee";
      languages = [ "en-US" "ja-JP" "zh-Hant-JP" ];
      personal = false;
      name = "";
      email = "";
    })
  ];
}
