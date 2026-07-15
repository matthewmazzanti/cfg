# `scan <name.pdf>` -- one-shot ADF batch scan bundled to a PDF.
#
# Two variants share the `scan` command name so it works the same everywhere:
#   host   -> runs on `print` (the scanner's USB host): scanimage + img2pdf.
#   client -> runs on framework/beta: ssh to print, run `scan` there, scp back.
{
  writeShellApplication,
  sane-backends,
  img2pdf,
  openssh,
  coreutils,
  mode ? "host",
}:
writeShellApplication {
  name = "scan";
  runtimeInputs =
    if mode == "host"
    then [sane-backends img2pdf coreutils]
    else [openssh coreutils];
  text = builtins.readFile (
    if mode == "host"
    then ./scan-host.sh
    else ./scan-client.sh
  );
}
