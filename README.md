# nix-holds-fleet

The packages the kleinbem fleet holds back from nixos-unstable, with
[nix-detour](https://github.com/kleinbem-dev/nix-detour). The format of
`held-packages.json` and the lifecycle are described there.

Used by nix-config (`base.nix`, container-factory), nix-presets and
nix-devshells: `overlays.default`, or `lib.mkOverlay { extraOverlays }` with
nix-packages' overlay so our own packages can be held too.

- Hold: a PR adding an entry, with the reason and the upstream link.
- Release: the weekly `release` workflow opens a PR removing each hold whose
  cause builds from nixos-unstable again, and alerts via ntfy for holds older
  than 14 days.
