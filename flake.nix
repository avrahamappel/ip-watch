{
  inputs = {
    flake-parts.url = "github:hercules-ci/flake-parts";
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    crane.url = "github:ipetkov/crane";
  };

  outputs = { self, flake-parts, ... }@inputs:
    let
      cargoToml = fromTOML (builtins.readFile ./Cargo.toml);
    in

    flake-parts.lib.mkFlake { inherit inputs; } ({ withSystem, ... }: {
      imports = [ flake-parts.flakeModules.modules ];

      systems = [ "x86_64-linux" ];

      perSystem = { pkgs, ... }:

        let
          craneLib = inputs.crane.mkLib pkgs;

          version = builtins.concatStringsSep "-" [
            (builtins.substring 0 4 self.lastModifiedDate)
            (builtins.substring 4 2 self.lastModifiedDate)
            (builtins.substring 6 2 self.lastModifiedDate)
            (self.shortRev or self.dirtyShortRev)
          ];

          src = craneLib.cleanCargoSource ./.;

          cargoArtifacts = craneLib.buildDepsOnly { inherit src; };
        in

        {
          packages.default = craneLib.buildPackage {
            inherit version src cargoArtifacts;

            meta.mainProgram = cargoToml.package.name;
          };

          devShells.default = craneLib.mkShell {
            packages = with pkgs; [
              bacon
              clippy
              rust-analyzer
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
