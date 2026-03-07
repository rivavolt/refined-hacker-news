{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
  };

  outputs = { self, nixpkgs }:
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

          manifest = builtins.fromJSON (builtins.readFile "${extension}/share/chromium-extension/manifest.json");

          extId = builtins.readFile (pkgs.runCommand "refined-hacker-news-ext-id" {
            nativeBuildInputs = [ pkgs.python3 pkgs.openssl ];
          } ''
            python3 ${./nix/crx-id.py} ${./keys/signing.pem} > $out
          '');

          crx = pkgs.runCommand "refined-hacker-news-crx" {
            nativeBuildInputs = [ pkgs.python3 pkgs.openssl ];
          } ''
            mkdir -p $out
            python3 ${./nix/pack-crx3.py} ${extension}/share/chromium-extension ${./keys/signing.pem} $out/extension.crx
          '';
        in {
          default = pkgs.linkFarm "refined-hacker-news" [
            { name = "share/chromium/extensions/${extId}.json";
              path = pkgs.writeText "${extId}.json" (builtins.toJSON {
                external_crx = "${crx}/extension.crx";
                external_version = manifest.version;
              });
            }
          ];
        }
      );
    };
}
