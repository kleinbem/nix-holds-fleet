{
  description = "Packages the kleinbem fleet holds back from nixos-unstable";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    # Consumers make this follow their own nixpkgs-stable.
    nixpkgs-stable.url = "github:NixOS/nixpkgs/nixos-26.05";
    nix-holds = {
      url = "github:kleinbem-dev/nix-holds";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.nixpkgs-stable.follows = "nixpkgs-stable";
    };
    # Our own packages, for the checks and release checks of their holds:
    # only its overlay.nix, not the flake, whose devshells take their holds
    # from here (a cycle).
    nix-packages = {
      url = "github:kleinbem/nix-packages";
      flake = false;
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      nixpkgs-stable,
      nix-holds,
      nix-packages,
    }:
    let
      inherit (nixpkgs) lib;
      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];
      forAllSystems = f: lib.genAttrs systems f;

      holds =
        extraOverlays:
        nix-holds.lib.mkHolds {
          holds = ./held-packages.json;
          inherit nixpkgs-stable extraOverlays;
        };
      ownPackages = import "${nix-packages}/overlay.nix";
      own = holds [ ownPackages ];

      # Our package set without the holds, as the fleet uses it.
      fleetPkgs =
        system: overlays:
        import nixpkgs {
          inherit system;
          config.allowUnfree = true;
          overlays = [ ownPackages ] ++ overlays;
        };
    in
    {
      # What consumers use: nix-config passes nix-packages' overlay so our
      # own packages can be held too.
      lib.mkOverlay =
        {
          extraOverlays ? [ ],
        }:
        (holds extraOverlays).overlay;
      overlays.default = self.lib.mkOverlay { };
      lib.nixosTests = (holds [ ]).nixosTests;

      # For the release action: what ends each hold.
      releaseChecks = forAllSystems (system: own.releaseChecks (fleetPkgs system [ ]));

      # Evaluates every held package and its NixOS tests. Not a build: a
      # consumer may adjust a held package (the open-webui container fixes
      # its wrapper), so its own CI builds the real thing.
      checks = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          held = fleetPkgs system [ own.overlay ];
          names = builtins.filter (name: held ? ${name}) (
            builtins.attrNames (lib.importJSON ./held-packages.json)
          );
          drvs =
            map (name: "${name} ${held.${name}.drvPath}") names
            ++ lib.mapAttrsToList (test: drv: "nixosTests.${test} ${drv.drvPath}") (own.nixosTests held);
        in
        {
          held-packages = pkgs.writeText "held-packages" (
            builtins.concatStringsSep "\n" (map builtins.unsafeDiscardOutputDependency drvs)
          );
        }
      );

      formatter = forAllSystems (system: nixpkgs.legacyPackages.${system}.nixfmt-tree);
    };
}
