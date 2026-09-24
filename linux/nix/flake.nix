{
  description = "NixOS – Gigabyte G5 KF (i5-12500H + RTX 4060, KDE Plasma 6)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = { nixpkgs, ... }: {
    nixosConfigurations.g5 = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [ ./hosts/g5/configuration.nix ];
    };

    # `nix fmt` formatiert alle .nix-Dateien
    formatter.x86_64-linux = nixpkgs.legacyPackages.x86_64-linux.nixfmt-tree;
  };
}
