{
  description = "Gaoxy transport runtime development shell";
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/2efa67fd26b6df417c33e4603185c701f260dd83";
  outputs = { self, nixpkgs }:
    let
      systems = [ "x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin" ];
    in {
      devShells = nixpkgs.lib.genAttrs systems (system:
        let pkgs = import nixpkgs { inherit system; };
        in {
          default = pkgs.mkShell {
            packages = [ pkgs.beam.packages.erlang_28.elixir_1_18 pkgs.rustc pkgs.cargo
              pkgs.python3 pkgs.openssl pkgs.git pkgs.pkg-config pkgs.expect ];
          };
        });
    };
}
