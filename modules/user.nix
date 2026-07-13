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
    password = "pssword"
  };

  home-manager.extraSpecialArgs = { inherit username; };
  home-manager.users.${username} = inputs.nix-home.homeModules.default;
}
