{ config, pkgs, ... }:

{
  security.pam.u2f = {
    enable = true;
    control = "sufficient";
  };

  security.protectKernelImage = true;
}
