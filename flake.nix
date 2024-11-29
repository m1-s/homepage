{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-24.05";
    hugo-profile.url = "github:gurusabarish/hugo-profile";
    hugo-profile.flake = false;
  };

  outputs = { self, nixpkgs, hugo-profile }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs { inherit system; };
      theme = pkgs.runCommand "move-theme" { } ''
        mkdir -p $out/themes/hugo-profile
        cp -r ${hugo-profile} $out/themes/hugo-profile
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
          buildPhase = "hugo -d $out --noBuildLock";
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
      };

      devShells.${system}.default = pkgs.mkShell {
        packages = with pkgs; [ hugo ];
        shellHook = ''
          sudo rsync --mkpath -r ${hugo-profile}/. ./themes/hugo-profile/
        '';
      };
    };
}
