{
	description = "st-flexipatch development workspace";

	inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

	outputs = {
		self,
		nixpkgs,
	}: let
		supportedSystems = ["x86_64-linux" "aarch64-linux"];
		forAllSystems = nixpkgs.lib.genAttrs supportedSystems;
	in {
		packages = forAllSystems (system: let
			pkgs = nixpkgs.legacyPackages.${system};
		in {
			default = pkgs.stdenv.mkDerivation {
				pname = "st-flexipatch";
				version = "0.9.3";
				src = self;

				nativeBuildInputs = [pkgs.pkg-config];
				buildInputs = with pkgs; [
					fontconfig
					freetype
					harfbuzz
					libx11
					libxft
					libxinerama
				];

				installFlags = ["PREFIX=$(out)"];
			};
		});

		devShells = forAllSystems (system: let
			pkgs = nixpkgs.legacyPackages.${system};
		in {
			default = pkgs.mkShell {
				inputsFrom = [self.packages.${system}.default];
				packages = with pkgs; [
					bear
					clang-tools
					gnumake
					jq
					pkg-config
				];
			};
		});
	};
}
