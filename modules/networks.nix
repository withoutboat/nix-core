{ config, lib, spec ? {}, ... }:

let
  hasWifi = (spec ? wifiSSID) && (spec ? wifiPass)
    && spec.wifiSSID != "" && spec.wifiPass != "";
in
{
  networking.networkmanager.ensureProfiles = lib.mkIf hasWifi {
    profiles.home-wifi = {
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
