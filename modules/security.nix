{ config, pkgs, ... }:

{
  services.pcscd.enable = true;

  security.pam.u2f = {
    enable = true;
    control = "sufficient";
  };

  hardware.gpgSmartcards.enable = true;

  security.protectKernelImage = true;
}
