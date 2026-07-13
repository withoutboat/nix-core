{ config, lib, spec ? {}, ... }:

let
  hasWifi = (spec ? wifiSSID) && (spec ? wifiPass)
    && spec.wifiSSID != "" && spec.wifiPass != "";
in
{
  networking.networkmanager.ensureProfiles = lib.mkIf hasWifi {
    profiles.${spec.wifiSSID} = {
      connection = {
        id = spec.wifiSSID;
        type = "wifi";
        autoconnect = "true";
      };
      wifi = {
        mode = "infrastructure";
        ssid = spec.wifiSSID;
      };
      wifi-security = {
        auth-alg = "open";
        key-mgmt = "wpa-psk";
        # psk is sourced from the machine-local hardware.nix (gitignored)
        psk = spec.wifiPass;
      };
      ipv4 = {
        method = "auto";
      };
      ipv6 = {
        addr-gen-mode = "stable-privacy";
        method = "auto";
      };
    };
  };
}
