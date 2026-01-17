{ pkgs, ...}: {
  environment.systemPackages = with pkgs; [ nrfutil ];
}
