{
  flake,
  pkgs,
  ...
}: {
  imports = [
    flake.modules.base
    flake.modules.impermanence
    flake.modules.lanzaboote
    ./hardware.nix
  ];

  # Networking
  networking.hostName = "print";

  # NetworkManager
  networking.networkmanager.enable = true;
  environment.persistence."/persist".directories = [
    "/etc/NetworkManager/system-connections"
    "/var/lib/NetworkManager"
  ];

  # ZFS
  networking.hostId = "d015a266";
  services.zfs.autoScrub.enable = true;
  services.zfs.trim.enable = true;

  # Packages
  # environment.systemPackages = with pkgs; [ ];

  # User config
  users.users.mmazzanti = {
    # lp: manage CUPS queues.  scanner: access SANE devices.
    extraGroups = ["networkmanager" "podman" "dialout" "lp" "scanner"];
    packages = [flake.packages."nvim/nix"];
  };

  # ---- Printing (CUPS) ----------------------------------------------------
  # Brother HL-L2300D (mono laser, USB) shared to the LAN. brlaser is the
  # open driver for the HL-L2300 series; it ships a PPD CUPS picks up from
  # services.printing.drivers.
  services.printing = {
    enable = true;
    drivers = [pkgs.brlaser];
    # Share the queue: advertise over the network, allow local subnets only.
    browsing = true;
    defaultShared = true;
    listenAddresses = ["*:631"];
    allowFrom = ["@LOCAL"]; # directly-connected subnets, not the internet
    openFirewall = true; # opens 631/tcp (IPP)
  };

  # mDNS/DNS-SD so clients (incl. AirPrint) auto-discover the shared queue.
  # CUPS registers its shared printers with Avahi when browsing is on.
  services.avahi = {
    enable = true;
    nssmdns4 = true;
    openFirewall = true; # opens 5353/udp (mDNS)
    publish = {
      enable = true;
      userServices = true;
    };
  };

  # Root rolls back to blank every boot (impermanence), so a queue added via
  # the CUPS web UI would not survive -- declare it instead. ensure-printers
  # recreates it with lpadmin on every boot. deviceUri (serial) + model were
  # read off the box with `lpinfo -v` / `lpinfo -m`.
  hardware.printers = {
    ensureDefaultPrinter = "Brother_HL-L2300D";
    ensurePrinters = [
      {
        name = "Brother_HL-L2300D";
        description = "Brother HL-L2300D";
        deviceUri = "usb://Brother/HL-L2300D%20series?serial=U63878K2N151402";
        model = "drv:///brlaser.drv/brl2300d.ppd";
      }
    ];
  };

  # ---- Scanning (SANE, CLI) -----------------------------------------------
  # Fujitsu ScanSnap iX1300 (USB), driven by the stock `fujitsu` backend --
  # `scanimage -L` sees it as `fujitsu:ScanSnap iX1300`, no firmware needed.
  # CLI-only for now: scanimage over SSH. mmazzanti is in `scanner` (below)
  # for device access. A web/network front-end can come later.
  hardware.sane.enable = true;
}
