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
              hash = "sha256-+s5RBC3XSgb8omTbUNLywZnP6jSxZBKSS1BmXOjRF8M=";
              fetchSubmodules = true;
            };

            propagatedBuildInputs = with pkgs.python3Packages; [
              setuptools
              jinja2
              voluptuous
            ];

            # for dev TODO:
            buildPhase = ''
              echo "Contents of source directory:"
              ls -la
              cat README.md
              # Now call the default pypa build phase
              pypaBuildPhase
            '';
          };

          kani-verifier = pkgs.rustPlatform.buildRustPackage rec {
            pname = "kani-verifier";
            version = "0.56.0";

            buildInputs = with pkgs; [ kissat cbmc ] ++ [ cbmc-viewer ];

            src = pkgs.fetchFromGitHub {
              owner = "model-checking";
              repo = "kani";
              rev = "kani-${version}";
              hash = "sha256-+s5RBC3XSgb8omTbUNLywZnP6jSxZBKSS1BmXOjRF8M=";
              fetchSubmodules = true;
            };

            cargoHash = pkgs.lib.fakeHash;

            # ref: https://github.com/model-checking/kani/blob/52fcc6cc747779c31ba41593b0d0777043540264/.github/actions/build-bundle/action.yml
            buildPhase = ''
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
