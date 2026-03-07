{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    nix-crx.url = "github:andreivolt/nix-crx";
  };

  outputs = { self, nixpkgs, nix-crx }:
    let
      forAllSystems = nixpkgs.lib.genAttrs [ "x86_64-linux" "aarch64-linux" "aarch64-darwin" ];
    in {
      packages = forAllSystems (system:
        let
          pkgs = import nixpkgs { inherit system; };

          extension = pkgs.buildNpmPackage {
            pname = "refined-hacker-news";
            version = "0.0.1";
            src = self;

            npmDepsHash = "sha256-eMpSQQTYJgInbFaK/XHX0COOMuSoTJCEGvs7h/Hob9c=";
            makeCacheWritable = true;
            npmFlags = [ "--ignore-scripts" ];

            buildPhase = ''
              runHook preBuild
              npx webpack --mode=production
              npx stylus ./src/*.styl --out ./dist/ --compress
              runHook postBuild
            '';

            installPhase = ''
              runHook preInstall
              mkdir -p $out/share/chromium-extension
              cp -r dist/* $out/share/chromium-extension/
              runHook postInstall
            '';

            dontNpmInstall = true;
          };

          crxPkg = nix-crx.lib.mkCrxPackage {
            inherit pkgs extension;
            key = ./keys/signing.pem;
          };

        in {
          default = crxPkg.package;
        }
      );
    };
}
