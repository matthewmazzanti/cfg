{ pkgs, lib, config,... }:

with lib;

let
  cfg = config.usage.graphical;
in {
  options.usage.graphical = {
    enable = mkEnableOption "graphical";

    hidpi = mkOption {
      default = false;
      type = types.bool;
      description = "Whether the screen is high dpi";
    };
  };

  config = mkIf cfg.enable {
    users.users.mmazzanti.extraGroups = [ "video" "audio" ];

    services = {
      xserver = {
        enable = true;
        displayManager.startx.enable = true;
        autoRepeatDelay = 300;
        autoRepeatInterval = 40;
        enableCtrlAltBackspace = true;
        videoDrivers = ["amdgpu"];
      };

      dbus.enable = true;

      pipewire.enable = false;
    };

    programs.dconf.enable = true;

    hardware = {
      opengl = {
        enable = true;
        extraPackages = [ pkgs.libva ];
      };
      pulseaudio = {
        enable = true;
        support32Bit = true;
        daemon.config = {
          resample-method = "speex-float-10";
          avoid-resampling = "true";
          default-sample-rate = "48000";
        };
      };
    };
  };
}
