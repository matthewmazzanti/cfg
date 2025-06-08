{
  python3Packages,
  pkgs,
}:
python3Packages.buildPythonApplication rec {
  pname = "kitty-si";
  version = "0.0.1";
  src = ./.;
  propagatedBuildInputs = with pkgs; [kitty bspwm];
  meta = {
    description = "A launcher for single instance kitty under bspwm";
  };
}
