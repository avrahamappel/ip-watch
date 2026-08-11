{
  inputs = {
    flake-parts.url = "github:hercules-ci/flake-parts";
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
  };

  outputs = { self, flake-parts, ... }@inputs:
    let
      cargoToml = fromTOML (builtins.readFile ./Cargo.toml);
    in

    flake-parts.lib.mkFlake { inherit inputs; } ({ withSystem, ... }: {
      imports = [ flake-parts.flakeModules.modules ];

      systems = [ "x86_64-linux" ];

      perSystem = { lib, pkgs, ... }:

        let
          version = builtins.concatStringsSep "-" [
            (builtins.substring 0 4 self.lastModifiedDate)
            (builtins.substring 4 2 self.lastModifiedDate)
            (builtins.substring 6 2 self.lastModifiedDate)
            (self.shortRev or self.dirtyShortRev)
          ];

          src = lib.cleanSource ./.;
        in

        {
          packages.default = pkgs.rustPlatform.buildRustPackage {
            pname = cargoToml.package.name;
            inherit version src;

            cargoDeps = pkgs.rustPlatform.importCargoLock {
              lockFile = ./Cargo.lock;
            };

            meta.mainProgram = cargoToml.package.name;
          };

          devShells.default = pkgs.mkShell {
            packages = with pkgs; [
              bacon
              cargo
              clippy
              rust-analyzer
              rustc
              rustfmt
            ];
          };
        };

      flake.modules.homeManager.default = { lib, pkgs, ... }:
        let
          ip-watch = withSystem pkgs.stdenv.hostPlatform.system
            ({ config, ... }: config.packages.default);
        in
        {
          home.packages = [ ip-watch ];

          systemd.user.services.ip-watch = {
            Unit.Description = cargoToml.package.description;

            Service = {
              ExecStart = lib.getExe ip-watch;
              Restart = "on-failure";
              RestartSec = 5;
            };

            Install.WantedBy = [ "default.target" ];
          };
        };
    });
}
