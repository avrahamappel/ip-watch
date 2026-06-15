{
  inputs = {
    flake-parts.url = "github:hercules-ci/flake-parts";
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
  };

  outputs = { self, flake-parts, ... }@inputs:
    let
      cargoToml = fromTOML (builtins.readFile ./Cargo.toml);
    in

    flake-parts.lib.mkFlake { inherit inputs; } {
      imports = [ flake-parts.flakeModules.modules ];

      systems = [ "x86_64-linux" ];

      perSystem = { pkgs, lib, config, ... }: {
        packages.default =
          let
            inherit (pkgs) rustPlatform;

            version = builtins.concatStringsSep "-" [
              (builtins.substring 0 4 self.lastModifiedDate)
              (builtins.substring 4 2 self.lastModifiedDate)
              (builtins.substring 6 2 self.lastModifiedDate)
              (self.shortRev or self.dirtyShortRev)
            ];
          in

          rustPlatform.buildRustPackage {
            pname = cargoToml.package.name;
            inherit version;

            src = lib.cleanSource ./.;

            cargoDeps = rustPlatform.importCargoLock { lockFile = ./Cargo.lock; };
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

      flake.modules.homeManager.default = { config, ... }: {
        home.packages = [ config.packages.default ];

        systemd.user.services.ip-watch = {
          Unit.Description = cargoToml.package.description;

          Service = {
            ExecStart = "ip-watch";
            Restart = "on-failure";
          };

          Install.WantedBy = "default.target";
        };
      };
    };
}
