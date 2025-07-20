{ pkgs }:
let
  script = pkgs.writeShellScriptBin "git-auth-shell" (builtins.readFile ./git-auth-shell.sh);
in pkgs.symlinkJoin {
  name = "git-auth-shell";
  paths = [ script pkgs.git ];
  buildInputs = [ pkgs.makeWrapper ];
  postBuild = "wrapProgram $out/bin/git-auth-shell --prefix PATH : $out/bin";
}
