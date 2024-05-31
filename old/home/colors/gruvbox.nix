background: hardness:

let
  neutral = {
    red       = "cc241d";
    green     = "98971a";
    yellow    = "d79921";
    blue      = "458588";
    purple    = "b16286";
    cyan      = "689d6a";
    orange    = "d65d0e";
    gray      = "928374";
  };

  dark = {
    background = {
      bg0_hard  = "1d2021";
      bg0_med   = "282828";
      bg0_soft  = "32302f";
      bg1       = "3c3836";
      bg2       = "504945";
      bg3       = "665c54";
      bg4       = "7c6f64";
    };

    bright = {
      red       = "fb4934";
      green     = "b8bb26";
      yellow    = "fabd2f";
      blue      = "83a598";
      purple    = "d3869b";
      cyan      = "8ec07c";
      orange    = "fe8019";
    };
  };

  light = {
    background = {
      bg0_hard  = "f9f5d7";
      bg0_med   = "fbf1c7";
      bg0_soft  = "f2e5bc";
      bg1       = "ebdbb2";
      bg2       = "d5c4a1";
      bg3       = "bdae93";
      bg4       = "a89984";
    };

    bright = {
      red       = "9d0006";
      green     = "79740e";
      yellow    = "b57614";
      blue      = "076678";
      purple    = "8f3f71";
      cyan      = "427b58";
      orange    = "af3a03";
    };
  };

  base = if background == "dark" then dark else light;
  alt = if background == "dark" then light else dark;
in
  rec {
    bg0_h   = base.background.bg0_hard;
    bg0     = base.background.bg0_med;
    bg0_s   = base.background.bg0_soft;
    bg1     = base.background.bg1;
    bg2     = base.background.bg2;
    bg3     = base.background.bg3;
    bg4     = base.background.bg4;
    gray    = neutral.gray;
    fg4     = alt.background.bg4;
    fg3     = alt.background.bg3;
    fg2     = alt.background.bg2;
    fg1     = alt.background.bg1;
    fg0     = alt.background.bg0_med;

    bg      = if hardness == "hard" then bg0_h
      else if hardness == "soft" then bg0_s
      else bg0;
    red     = neutral.red;
    green   = neutral.green;
    yellow  = neutral.yellow;
    blue    = neutral.blue;
    purple  = neutral.purple;
    cyan    = neutral.cyan;
    orange  = neutral.orange;
    fg      = fg4;

    bright = {
      bg = neutral.gray;
      fg = fg1;
      accent = base.bright.cyan;
    } // base.bright;

    accent = {
      dark = alt.bright.cyan;
      neutral = cyan;
      light = base.bright.cyan;
    };
  }
