{ pkgs ? import <nixpkgs> { }, compiler ? "ghc882", hoogle ? true }:

let
  src = pkgs.nix-gitignore.gitignoreSource [ ] ./.;

  compiler' = if compiler != null then
    compiler
  else
    "ghc" + pkgs.lib.concatStrings
    (pkgs.lib.splitVersion pkgs.haskellPackages.ghc.version);

  # Any overrides we require to the specified haskell package set
  haskellPackages = with pkgs.haskell.lib;
    pkgs.haskell.packages.${compiler'}.override {
      overrides = self: super:
        {
          th-desugar = self.callCabal2nix "" (pkgs.fetchFromGitHub {
            owner = "goldfirere";
            repo = "th-desugar";
            rev = "f075206882ce4e554c37537e624b4be7409d74a3";
            sha256 = "0747xggx2q8yphag2wv06dj0pgi9zvadi069c2d6lckg26chhnlk";
          }) { };
        } // pkgs.lib.optionalAttrs hoogle {
          ghc = super.ghc // { withPackages = super.ghc.withHoogle; };
          ghcWithPackages = self.ghc.withPackages;
        };
    };

  # Any packages to appear in the environment provisioned by nix-shell
  extraEnvPackages = with haskellPackages; [ ];

  # Generate a haskell derivation using the cabal2nix tool on `package.yaml`
  drv = let old = haskellPackages.callCabal2nix "" src { };
  in old // {
    # Insert the extra environment packages into the environment generated by
    # cabal2nix
    env = pkgs.lib.overrideDerivation old.env (attrs:
      {
        buildInputs = attrs.buildInputs ++ extraEnvPackages;
      } // pkgs.lib.optionalAttrs hoogle {
        shellHook = attrs.shellHook + ''
          export HIE_HOOGLE_DATABASE="$(cat $(${pkgs.which}/bin/which hoogle) | sed -n -e 's|.*--database \(.*\.hoo\).*|\1|p')"
        '';
      });
  };

in if pkgs.lib.inNixShell then drv.env else drv
