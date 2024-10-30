{
  description = "A very basic flake";

  inputs = {
    nixpkgs.url = "nixpkgs";

    flake-parts = {
      url = "github:hercules-ci/flake-parts";
      inputs.nixpkgs-lib.follows = "nixpkgs";
    };

    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = inputs@{ self, flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [
        "aarch64-darwin"
        "aarch64-linux"
        "i686-linux"
        # "x86_64-darwin" # TODO: cbmc on x86_64-darwin is marked as broken
        "x86_64-linux"
      ];
      perSystem = { config, system, pkgs, ... }: {
        _module.args.pkgs = import inputs.nixpkgs {
          inherit system;
          overlays = [
            inputs.rust-overlay.overlays.default
          ];
        };

        formatter = pkgs.nixfmt-rfc-style;

        packages = rec {
          cbmc-viewer = pkgs.python3Packages.buildPythonApplication rec {
            pname = "cbmc-viewer";
            version = "3.10";
            format = "pyproject";

            src = pkgs.fetchFromGitHub {
              owner = "model-checking";
              repo = pname;
              rev = "viewer-${version}";
              hash = "sha256-t3lR09ZUgyXe/p/dcmA3nIiDeFcmIEpTJtDZnC+n/Mw=";
              fetchSubmodules = true;
            };

            propagatedBuildInputs = with pkgs.python3Packages; [
              setuptools
              jinja2
              voluptuous
            ];
          };

          kani-verifier = let
              rustPlatform = pkgs.makeRustPlatform {
                cargo = pkgs.rust-bin.selectLatestNightlyWith (toolchain: toolchain.default);
                rustc = pkgs.rust-bin.selectLatestNightlyWith (toolchain: toolchain.default);
              };
            in rustPlatform.buildRustPackage rec {
            pname = "kani-verifier";
            version = "0.56.0";

            nativeBuildInputs = with pkgs; [ kissat cbmc rustup ] ++ [ cbmc-viewer ];

            src = pkgs.fetchFromGitHub {
              owner = "model-checking";
              repo = "kani";
              rev = "kani-${version}";
              hash = "sha256-O4zNkhpI0lFFomFzExBnM5y4Rj0Sm5CgQyw6cqek6Pg=";
              fetchSubmodules = true;
            };

            cargoHash = "sha256-chIZp0JOzchMz2CY4pWFXfzRnW0sftw2TKvaFQtVqAc=";

            # ref: https://github.com/model-checking/kani/blob/52fcc6cc747779c31ba41593b0d0777043540264/.github/actions/build-bundle/action.yml
            buildPhase = ''
              export RUSTUP_TOOLCHAIN=nightly
              export CARGO_HOME=$PWD/.cargo
              export RUSTUP_HOME=$PWD/.rustup
              cargo bundle -- ${version}
            '';

            installPhase = ''
              mkdir -p $out/bin
              cp target/release/* $out/bin/
            '';
          };

          default = kani-verifier;
        };
      };
    };
}
