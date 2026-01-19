{ pkgs, ...}: let
  nrfutilExtensions = pkgs.nrfutil.withExtensions [
    "nrfutil-device"
    "nrfutil-trace"
    "nrfutil-ble-sniffer"
    "nrfutil-completion"
    "nrfutil-mcu-manager"
    "nrfutil-npm"
    "nrfutil-nrf5sdk-tools"
    "nrfutil-sdk-manager"
    "nrfutil-suit"
    "nrfutil-toolchain-manager"
  ];

  nrfutil = nrfutilExtensions.override {
    segger-jlink-headless = (pkgs.segger-jlink-headless.override {
      acceptLicense = true;
    });
  };
in {
  environment.systemPackages = [
    nrfutil
    pkgs.nrf-command-line-tools
  ];
}
