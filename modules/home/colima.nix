{ lib, machine, ... }:
{
  services.colima = lib.mkIf (machine.os == "darwin") {
    enable = true;
    profiles.default = {
      isActive = true;
      isService = true;
      settings = {
        runtime = "docker";
        vmType = "vz";
        mountType = "virtiofs";
      };
    };
  };
}
