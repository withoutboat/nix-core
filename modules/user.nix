{ config, pkgs, lib, inputs, spec ? { username = "withoutboat"; }, ... }:

let
  username = spec.username;
in
{
  users.users.${username} = {
    isNormalUser = true;
    description = "Primary User"; 
    extraGroups = [ "networkmanager" "wheel" "video" "audio" ];
    shell = pkgs.zsh;
    password = null;
  };

  security.pam.services.login.u2fAuth = true;
  security.pam.services.sudo.u2fAuth = true;

  home-manager.extraSpecialArgs = { inherit username; };
  home-manager.users.${username} = inputs.nix-home.homeModules.default;
}
