{ ... }: {
  fileSystems = {
    "/var/lib/samba" = {
      device = "root-pool/state/services/samba";
      fsType = "zfs";
      options = [ "noatime" "nodiratime" ];
    };
    "/srv/files" = {
      device = "data-pool/share/files";
      fsType = "zfs";
      options = [ "noatime" "nodiratime" ];
    };
  };

  systemd.services.samba = {
    after = [ "var-lib-samba.mount" "srv-files.mount" ];
    requires = [ "var-lib-samba.mount" "srv-files.mount" ];
  };

  services.samba = {
    enable = true;
    openFirewall = false;
    nmbd.enable = false;
    winbindd.enable = false;

    settings = {
      global = {
        # Network binding
        "interfaces" = "lo enp7s0";
        "bind interfaces only" = "yes";

        # Protocol and Transport Hardening
        "server min protocol" = "SMB3_11";
        "client min protocol" = "SMB3_11";
        "client signing"      = "mandatory";
        "server signing"      = "mandatory";
        "smb encrypt"         = "required";

        # Disable Legacy Protocols
        "disable netbios" = "yes";
        "smb ports"       = "445";
        "ntlm auth"       = "no";

        # Fully Disable Guest / Anonymous Access
        "map to guest"     = "never";
        "guest account"    = "nobody";
        "restrict anonymous" = "2";

        # Disable Browsing and Printer Exposure
        "disable spoolss" = "yes";
        "load printers"   = "no";
        "printing"        = "bsd";
        "printcap name"   = "/dev/null";

        # Filesystem + macOS compatibility
        "vfs objects"        = "catia fruit streams_xattr acl_xattr";
        "fruit:metadata"     = "stream";
        "fruit:resource"     = "stream";
        "fruit:locking"      = "netatalk";
        "fruit:posix_rename" = "yes";
        "fruit:aapl"         = "yes";

        # Extended attributes / metadata control
        "ea support"      = "yes";
        "unix extensions" = "yes";
        "map acl inherit" = "yes";
        "inherit acls"    = "yes";

        # Disable Windows-style ACLs and metadata
        "nt acl support"       = "no";
        "dos filemode"         = "no";
        "store dos attributes" = "no";
        "map archive"          = "no";
        "map hidden"           = "no";
        "map system"           = "no";

        # Performance
        "write cache size" = "262144";  # 16 MB
        "strict sync" = "no";
        "sync always" = "no";

        # Default security posture — overridden per-share
        "writeable"  = "no";
        "browseable" = "no";
      };

      files = {
        "path" = "/srv/files";

        # Per-share access and security
        "writable"    = "yes";
        "browseable"  = "yes";
        "valid users" = "mmazzanti";
        "force user"  = "samba";
        "force group" = "samba";

        # Permissions
        "create mask"          = "0660";
        "force create mode"    = "0660";
        "directory mask"       = "0770";
        "force directory mode" = "0770";
        "inherit permissions"  = "yes";
      };

      /*
      timemachine = {
        path = "/srv/timemachine";
        writable  = "yes";
        browseable = "no";

        # Time Machine–specific settings
        "unix extensions" = "no";
        "nt acl support" = "yes";
        "store dos attributes" = "yes";
        "ea support" = "yes";
        "fruit:aapl" = "yes";
        "fruit:time machine" = "yes";
        "fruit:time machine max size" = "1099511627776";  # 1TiB
        "vfs objects" = "catia fruit streams_xattr";
      };
      */
    };
  };

  networking.firewall.allowedTCPPorts = [ 445 ];

  users.users = {
    samba = {
      isSystemUser = true;
      group = "samba";
      description = "Samba file share owner";
    };
    mmazzanti.extraGroups = [ "samba" ];
  };
  users.groups.samba = {};
}
