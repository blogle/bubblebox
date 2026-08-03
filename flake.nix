{
  description = "Ephemeral Bubblewrap workspaces";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = { self, nixpkgs }:
    let
      systems = [ "x86_64-linux" "aarch64-linux" ];
      forAllSystems = nixpkgs.lib.genAttrs systems;
    in
    {
      packages = forAllSystems (system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          box = pkgs.writeShellApplication {
            name = "box";
            runtimeInputs = [ pkgs.bubblewrap pkgs.coreutils pkgs.yq-go ];
            text = builtins.readFile ./box;
          };
        in
        {
          default = box;
          inherit box;
        });

      apps = forAllSystems (system: {
        default = {
          type = "app";
          program = "${self.packages.${system}.default}/bin/box";
        };
      });

      checks = forAllSystems (system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        {
          box-syntax = pkgs.runCommand "box-syntax" {
            nativeBuildInputs = [ pkgs.bash pkgs.shellcheck ];
          } ''
            bash -n ${./box}
            bash -n ${./tests/test-box.sh}
            shellcheck ${./tests/test-box.sh}
            touch $out
          '';
        });
    };
}
