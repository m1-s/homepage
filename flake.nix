{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-23.11";
  };

  outputs = { self, nixpkgs }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs { inherit system; };
    in
    {
      packages.${system} = {
        website = pkgs.runCommand "website" { nativeBuildInputs = [ pkgs.hugo ]; } ''
          cp -r ${./.} ./source
          chmod -R +w ./source
          cd ./source
          hugo
          mv public $out
        '';

        deploy = pkgs.writeShellScriptBin "deploy" ''
          set -euo pipefail
          export PATH="${pkgs.lib.makeBinPath [
            pkgs.coreutils
            pkgs.gitMinimal
            pkgs.rsync
            pkgs.openssh
          ]}"
          export TMPDIR=$(${pkgs.coreutils}/bin/mktemp -d)
          trap "${pkgs.coreutils}/bin/chmod -R +w '$TMPDIR'; ${pkgs.coreutils}/bin/rm -rf '$TMPDIR'" EXIT

          set -x
          cd $TMPDIR
          git clone --depth 1 --branch gh-pages git@github.com:m1-s/homepage ./site
          cd ./site
          rm -rf $(ls .)
          rsync -r ${self.packages.${system}.website}/ .
          git checkout gh-pages CNAME
          chmod +w -R .
          git add .
          git commit -m "deploy website - $(date --rfc-3339=seconds)" || :
          git push origin gh-pages
        '';
      };

      devShells.${system}.default = pkgs.mkShell {
        packages = with pkgs; [ hugo ];
      };
    };
}
