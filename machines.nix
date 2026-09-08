# Machine facts. Keys are the flake configuration names:
#   darwinConfigurations.<key> for os = "darwin"
#   homeConfigurations.<key> (+ "-aarch64") for os = "linux"
#
# Per machine:
#   os        - "darwin" or "linux"
#   username  - login name of the primary user
#   personal  - whether this machine may read personal secrets from 1Password
#   name      - git user name
#   email     - git user email
#   sshSigningKeyItem - optional 1Password item UUID for the SSH signing key
#
# darwin only:
#   hostname  - host name to manage; omit to leave the machine's own name
#   languages - preferred UI languages, most preferred first
{
  "Han-MBP" = {
    os = "darwin";
    hostname = "Han-MBP";
    username = "hanlee";
    languages = [
      "ja-JP"
      "en-JP"
      "zh-Hant-JP"
    ];
    personal = true;
    sshSigningKeyItem = "ansddacrnp3ibgfs3sfbg3unt4";
    name = "Han";
    email = "me@hanlee.co";
  };

  # Work MacBook. The host name is set by the employer's device management
  # and is intentionally not declared here.
  work = {
    os = "darwin";
    username = "hanlee";
    languages = [
      "en-US"
      "ja-JP"
      "zh-Hant-JP"
    ];
    personal = false;
    sshSigningKeyItem = "xr5pzbrwuzuuh24ksg5g3n34oy";
    name = "";
    email = "";
  };

  # Personal headless Linux box.
  "hanlee@ubuntu" = {
    os = "linux";
    username = "hanlee";
    personal = true;
    sshSigningKeyItem = "ansddacrnp3ibgfs3sfbg3unt4";
    name = "Han";
    email = "me@hanlee.co";
  };

  # Ephemeral machines (containers, devcontainers, WSL).
  ephemeral = {
    os = "linux";
    username = "hanlee";
    personal = false;
    name = "Han";
    email = "me@hanlee.co";
  };
}
