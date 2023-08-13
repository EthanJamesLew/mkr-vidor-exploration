{
  description = "Environment for MKR Vidor 4000";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  inputs.rust-overlay.url = "github:oxalica/rust-overlay";

  outputs = { self, nixpkgs, rust-overlay }:
    let
      platforms = [ "x86_64-linux" ];

      pkgs = import nixpkgs { system = "x86_64-linux"; overlays = [ (import rust-overlay) ]; };

      makeBossac = pkgs: pkgs.stdenv.mkDerivation {
        name = "bossac-1.7.0";

        src = pkgs.fetchzip {
          url = "https://github.com/shumatech/BOSSA/archive/1.7.0.zip";
          sha256 = "089h64j4n9cqhfmvmnix2ddrfrshfcmv83ycy12m5jz750vijzya";
        };

        nativeBuildInputs = [ pkgs.unzip pkgs.gawk pkgs.binutils pkgs.readline ];

        buildPhase = ''
          bash arduino/make_package.sh
        '';

        installPhase = ''
          install -D bin/bossac $out/bin/bossac
        '';

        meta = with pkgs.lib; {
          description = "Command line programmer for Atmel SAM ARM microcontrollers";
          longDescription = ''
            BOSSA is a flash programming utility for Atmel's SAM family of flash-based ARM 
            microcontrollers.  The motivation behind BOSSA is to create a simple, 
            easy-to-use, open source utility to replace Atmel's SAM-BA software.  BOSSA is 
            an acronym for Basic Open Source SAM-BA Application to reflect that goal.  What's 
            wrong with using SAM-BA?  Well, there are several reasons to consider an alternative.
          '';
          homepage = "https://www.shumatech.com/web/products/bossa";
        };
      };

      # we build this strangely as the go file is a standalone file and not part of a module
      makeCreateCompositeBinary = pkgs:
        let
          gopath = "vidor-libraries/VidorBitstream";
        in
        pkgs.buildGoPackage rec {
          name = "createCompositeBinary";
          goPackagePath = gopath;

          src = pkgs.fetchFromGitHub {
            owner = "vidor-libraries";
            repo = "VidorBitstream";
            rev = "master";
            sha256 = "sha256-r/0VmWdKgMLMpJ/UXSo5YDpWtzZUJnqy87zeZ5NNkpw=";
          };

          sourceRoot = "source/TOOLS/makeCompositeBinary";

          configurePhase = ''
            mkdir -p go/src/${gopath}
            cp ./*.go go/src/${gopath}/
          '';

          # the go cache config is done to overcome a permissions issue
          buildPhase = ''
            export GOCACHE=$(mktemp -d)
            cd go/src/${gopath}
            go build -o createCompositeBinary make_composite_binary.go
          '';

          installPhase = ''
            install -D createCompositeBinary $out/bin/createCompositeBinary
          '';

          meta = with pkgs.lib; {
            description = "Utility to create composite binary for MKR Vidor 4000";
            longDescription = ''
              Bitstreams produced by Quartus (in ttf format) are not suitable to be 
              directly burned on the flash since their nibble encoding is reverse. 
              This utility helps creating the correct file format, appending other 
              sections if needed.
            '';
            homepage = "https://github.com/vidor-libraries/VidorBitstream/tree/release";
            license = licenses.gpl3;
          };
        };
    in
    {
      # build a list of platform specific packages
      # this was originally done to build for multiple platforms,
      # but bossac is x86_64-linux or x86_64-windows
      packages = builtins.listToAttrs (map
        (platform:
          {
            name = platform;
            value = {
              bossac = makeBossac (nixpkgs.legacyPackages.${platform});
              createCompositeBinary = makeCreateCompositeBinary (nixpkgs.legacyPackages.${platform});
            };
          })
        platforms);

      # stable rust with thumbv6m-none-eabi target
      rust = pkgs.rust-bin.stable.latest.default.override {
        extensions = [ "rust-src" ];
        targets = [ "thumbv6m-none-eabi" ];
      };
	
      # default for testing nix build
      defaultPackage.x86_64-linux = self.packages.x86_64-linux.bossac;

      devShell.x86_64-linux = nixpkgs.legacyPackages.x86_64-linux.mkShell {
        name = "vidor-rs-shell";
        buildInputs = [
          # arm-none-eabi toolchain
          pkgs.gcc-arm-embedded

          # rust with thumbv6m-none-eabi target
          self.rust

          # additional tools
          self.packages.x86_64-linux.bossac
          self.packages.x86_64-linux.createCompositeBinary
        ];
      };
    };
}
