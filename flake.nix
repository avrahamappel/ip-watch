{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    cargo2nix = {
      url = "github:cargo2nix/cargo2nix";
      # inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, cargo2nix, ... }:
    let
      inherit (nixpkgs) lib;

      systems = [ "x86_64-linux" ];

      forAllSystems = f: lib.genAttrs systems
        (system: f {
          inherit system;
          pkgs = import nixpkgs { inherit system; };
        });

      cargoToml = fromTOML (builtins.readFile ./Cargo.toml);

      version = builtins.concatStringsSep "-" [
        (builtins.substring 0 4 self.lastModifiedDate)
        (builtins.substring 4 2 self.lastModifiedDate)
        (builtins.substring 6 2 self.lastModifiedDate)
        (self.shortRev or self.dirtyShortRev or "dirty")
      ];

      src = lib.cleanSource ./.;
    in

    {
      packages = forAllSystems ({ pkgs, ... }: {
        default = pkgs.rustPlatform.buildRustPackage {
          pname = cargoToml.package.name;
          inherit version src;

          buildInputs = with pkgs; [ aws-lc.dev ];

          nativeBuildInputs = [ pkgs.pkg-config ];

          cargoDeps = pkgs.rustPlatform.importCargoLock {
            lockFile = ./Cargo.lock;
          };

          meta.mainProgram = cargoToml.package.name;
        };
      });

      devShells = forAllSystems ({ pkgs, system, ... }:
        let
          cargo2nix' = cargo2nix.packages.${system}.default;

          # Automatically call cargo2nix when Cargo.lock changes
          cargo = pkgs.writeShellScriptBin "cargo" ''
            prev_modified="$(stat -c '%Y' Cargo.lock)"

            cargo "$@"

            now_modified="$(stat -c '%Y' Cargo.lock)"

            if [[ $now_modified -gt $prev_modified ]]; then
              cargo2nix
            fi
          '';
        in
        {
          default = pkgs.mkShell {
            packages = with pkgs; [
              bacon
              cargo
              cargo2nix'
              clippy
              rust-analyzer
              rustc
              rustfmt
            ];
          };
        });

      modules.homeManager.default = { lib, pkgs, ... }:
        let
          ip-watch = self.packages.${ pkgs.stdenv.hostPlatform.system}.default;
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
    };
}
