{
  description = "Environment for MKR Vidor 4000";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = { self, nixpkgs }:
    let
      platforms = [ "x86_64-linux" ];
      makePackage = pkgs: pkgs.stdenv.mkDerivation {
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
      };

    makeCreateCompositeBinary = pkgs: let
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

      buildPhase = ''
        export GOCACHE=$(mktemp -d)
        cd go/src/${gopath}
        go build -o createCompositeBinary make_composite_binary.go
      '';

      installPhase = ''
        install -D createCompositeBinary $out/bin/createCompositeBinary
      '';

      meta = {
        description = "Tool to create composite binary for Vidor";
      };
    };
    in
    {
      packages = builtins.listToAttrs (map (platform: 
        { 
          name = platform; 
          value = { 
            bossac = makePackage (nixpkgs.legacyPackages.${platform}); 
            createCompositeBinary = makeCreateCompositeBinary (nixpkgs.legacyPackages.${platform});
          };
        }) platforms);

      defaultPackage.x86_64-linux = self.packages.x86_64-linux.createCompositeBinary;

      devShells.x86_64-linux = nixpkgs.legacyPackages.x86_64-linux.mkShell {
        name = "vidor-rs-shell";
        buildInputs = [ 
          self.packages.x86_64-linux.bossac 
          self.packages.x86_64-linux.createCompositeBinary
        ];
      };
    };
}
