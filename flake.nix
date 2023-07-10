{
  description = "Docker utils for multiarch builds";
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
  };
  outputs = {
    self,
    nixpkgs,
  }: let
    forAllSystems = function: systems:
      nixpkgs.lib.genAttrs systems (system: function nixpkgs.legacyPackages.${system});
    genSystems = systems: app: nixpkgs.lib.genAttrs systems (_: app);
    imageNames = images:
      builtins.concatStringsSep " "
      (builtins.attrValues (builtins.mapAttrs (
          arch: image: "${image.imageName}:${image.imageTag}-${image.system}"
        )
        images));
    defaultSystems = ["x86_64-linux" "x86_64-darwin" "aarch64-linux" "aarch64-darwin"];
    allImages = systems: app: forAllSystems (pkgs: pkgs.linkFarm "all" {inherit app;}) systems;
    loadAndPush = systems: image:
      builtins.concatStringsSep "\n" (nixpkgs.lib.mapAttrsToList
        (system: value: ''
          docker load -i ${value}
          docker push ${image.imageName}:${image.imageTag}-${system}
        '') (allImages systems image));
  in {
    lib =
      forAllSystems (
        pkgs: {
          inherit allImages;
          pushAll = {
            name,
            systems,
            dockerImage,
          }:
            pkgs.writeShellScriptBin name
            ''
              docker=${pkgs.docker}/bin/docker
              ${loadAndPush systems dockerImage}
              $docker manifest create --amend ${dockerImage.imageName}:${dockerImage.imageTag} ${imageNames (genSystems systems dockerImage)}
                $docker manifest push ${dockerImage.imageName}:${dockerImage.imageTag}
            '';
        }
      )
      defaultSystems;
  };
}
