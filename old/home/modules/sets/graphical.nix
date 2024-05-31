{ pkgs, lib, ... }: {
  config.home.packages = with pkgs; [
    # Misc graphical
    discord
    escrotum
    gimp
    inkscape
    firefox
    google-chrome
    zathura
    qrencode
    freerdp
    gerbv
    arandr
    zoom-us
    qbittorrent
    slack

    # ardour
    (spotify.override {
      deviceScaleFactor = 1.75;
      # spotify-unwrapped = pkgs.callPackage ../spicetify {};
    })
    audacity

    libcec
    libnotify

    xorg.xkbcomp
    # kicad
    xdotool

    imwheel
    libinput
    libreoffice
    maim
    xclip
    slop
    font-manager
    _1password-gui
  ];
}
