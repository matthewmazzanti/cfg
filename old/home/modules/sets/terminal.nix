{ pkgs, ... }: {
  config.home.packages = with pkgs; [
    # Misc replacements for unix tools
    htop
    atop
    perf-tools
    httpie
    ripgrep
    fd
    bat
    pipes

    gitAndTools.git-filter-repo

    # Quality of life stuff
    direnv
    fzf
    jq
    zip
    unzip
    python3
    nmap
    bind
    inetutils
    socat

    pass
    lastpass-cli
    openssl
    neomutt
    isync
    goimapnotify

    newsboat
    w3m
    gettext
    parted

    samba
    ranger

    # rs232
    tio

    # Checking ram speeds
    dmidecode

    # wake on lan
    wol

    hwinfo
    edid-decode
    cargo
    rustc
    netcat-gnu
    poppler_utils
    lsof
    asciinema
  ];
}
