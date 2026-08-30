{ ... }:

{
  programs.mise = {
    enable = true;
    enableZshIntegration = true;
    # Keep the main config.toml writable by `mise use --global`.
    enableMutableConfig = true;
    globalConfig = {
      tools = {
        "npm:@antfu/ni" = "latest";
        "npm:@earendil-works/pi-coding-agent" = {
          version = "latest";
          trust_policy_excludes = [
            "@smithy/core@3.33.0"
            "@smithy/node-http-handler@4.11.0"
          ];
        };
        "npm:actions-up" = "latest";
        "npm:taze" = "latest";
        "npm:tsx" = "latest";
        bun = "latest";
        node = "lts";
        pnpm = "latest";
        python = "latest";
        yarn = "latest";
      };
      settings = {
        idiomatic_version_file_enable_tools = [
          "pnpm"
          "yarn"
          "npm"
          "node"
        ];
        minimum_release_age = "0";
      };
    };
  };
}
