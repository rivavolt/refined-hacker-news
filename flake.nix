{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    nix-webext.url = "github:rivavolt/nix-webext";
  };

  outputs = { self, nixpkgs, nix-webext }:
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

          manifest = builtins.fromJSON (builtins.readFile ./src/manifest.json);
        in
        # Chrome-only; build is keyless (CRX signed at activation from sops).
        # extId is the stable Chrome ID the old committed key derived.
        nix-webext.lib.mkBrowserExtension {
          inherit pkgs extension;
          pname = "refined-hacker-news";
          version = manifest.version;
          extId = "igpocngikdjgleildhmagpibbmkopbeo";
          firefox = false;
          transformManifest = false;
        }
      );
    };
}
