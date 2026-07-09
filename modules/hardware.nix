{ lib, ... }:
{
  imports = [
    (lib.optional (builtins.pathExists /etc/nixos/hardware-configuration.nix) /etc/nixos/hardware-configuration.nix)
  ];
}
