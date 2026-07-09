{ config, pkgs, lib, inputs, ... }:

let
  userContextPath = ../user-context.nix;
  username = if builtins.pathExists userContextPath
             then (import userContextPath).username
             else "withoutboat";
in
{
  users.users.${username} = {
    isNormalUser = true;
    description = builtins.concatStringsSep "" [ 
      (lib.toUpper (builtins.substring 0 1 username)) 
      (builtins.substring 1 (builtins.stringLength username) username) 
    ];
    extraGroups = [ "networkmanager" "wheel" "video" "audio" ];
    shell = pkgs.zsh;
  };

  home-manager.extraSpecialArgs = { inherit username; };
  home-manager.users.${username} = inputs.nix-home.homeModules.default;
}
