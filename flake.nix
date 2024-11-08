{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-24.05";
    vncnt-hugo.url = "github:fncnt/vncnt-hugo";
    vncnt-hugo.flake = false;
  };

  outputs = { self, nixpkgs, vncnt-hugo }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs { inherit system; };
      theme = pkgs.runCommand "move-theme" { } ''
        mkdir -p $out/themes/vncnt-hugo
        cp -r ${vncnt-hugo}/. $out/themes/vncnt-hugo
      '';
    in
    {
      packages.${system} = {
        website = pkgs.stdenv.mkDerivation {
          name = "website";
          version = "1.0.0";
          src = ./.;
          postUnpackPhase = "cp -r ${theme}/. $out";
          buildInputs = with pkgs; [ hugo ];
          buildPhase = "hugo -d $out --noBuildLock && ls $out";
        };

        deploy = pkgs.writeShellScriptBin "deploy" ''
          set -euo pipefail
          export PATH="${pkgs.lib.makeBinPath (with pkgs; [
            coreutils
            gitMinimal
            rsync
            openssh
          ])}"
          export TMPDIR=$(${pkgs.coreutils}/bin/mktemp -d)
          trap "${pkgs.coreutils}/bin/chmod -R +w '$TMPDIR'; ${pkgs.coreutils}/bin/rm -rf '$TMPDIR'" EXIT

          set -x
          cd $TMPDIR
          git clone --branch gh-pages git@github.com:m1-s/homepage .
          rm -rf .
          rsync -r ${self.packages.${system}.website}/ .
          chmod +w -R .
          git add --all
          git commit -m "deploy website - $(date --rfc-3339=seconds)" || :
          git push origin gh-pages
        '';

        devShells.${system}.default = pkgs.mkShell {
          packages = with pkgs; [ hugo ];
          shellHook = ''
            rsync -r ${vncnt-hugo}/. ./themes/vncnt-hugo/
          '';
        };
      };
    };
}
