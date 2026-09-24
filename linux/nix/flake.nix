{
  description = "NixOS – Gigabyte G5 KF (i5-12500H + RTX 4060, KDE Plasma 6)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    # Spotify mit Spicetify – das Installer-Skript kann Spotify im
    # schreibgeschützten /nix/store nicht patchen
    spicetify-nix = {
      url = "github:Gerg-L/spicetify-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { nixpkgs, ... }@inputs: {
    nixosConfigurations.g5 = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      specialArgs = { inherit inputs; };
      modules = [ ./hosts/g5/configuration.nix ];
    };

    # `nix fmt` formatiert alle .nix-Dateien
    formatter.x86_64-linux = nixpkgs.legacyPackages.x86_64-linux.nixfmt-tree;
  };
}
