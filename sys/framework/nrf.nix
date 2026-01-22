{ pkgs, ...}: {
  environment.systemPackages = with pkgs; [
    nrfutil
    wireshark
  ];
  users.users.mmazzanti.extraGroups = [ "wireshark" "dialout" ];
}
