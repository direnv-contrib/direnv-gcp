{
  description = "direnv-gcp - direnv extension for Google Cloud Secret Manager and project selection";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs =
    {
      nixpkgs,
      flake-utils,
      ...
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
      in
      {
        # The helpers are sourced by direnv, so the package only ships the scripts
        packages.default = pkgs.stdenvNoCC.mkDerivation {
          pname = "direnv-gcp";
          version = pkgs.lib.removeSuffix "\n" (builtins.readFile ./version.txt);
          src = pkgs.lib.cleanSource ./.;
          dontBuild = true;
          installPhase = ''
            runHook preInstall
            install -Dm644 -t $out/share/direnv-gcp lib/*.sh
            runHook postInstall
          '';
          meta = with pkgs.lib; {
            description = "direnv extension for Google Cloud Secret Manager and project selection";
            homepage = "https://github.com/direnv-contrib/direnv-gcp";
            license = licenses.mit;
            platforms = platforms.all;
          };
        };

        devShells.default = pkgs.mkShell {
          name = "direnv-gcp";
          packages = with pkgs; [
            bash
            bats
            direnv
            jq
            shellcheck
          ];
        };
      }
    );
}
