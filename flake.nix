{
  inputs = {
    agenix.url = "github:ryantm/agenix";
    deploy-rs.url = "github:serokell/deploy-rs";
    devenv.url = "github:cachix/devenv";
    flake-parts.url = "github:hercules-ci/flake-parts";
    git-hooks.url = "github:cachix/git-hooks.nix";
    hercules-ci-agent.url = "github:hercules-ci/hercules-ci-agent/stable";
    hercules-ci-effects.url = "github:hercules-ci/hercules-ci-effects";
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    terraform-nixos.url = "github:nix-community/terraform-nixos";
    terraform-nixos.flake = false;

    devenv.inputs.pre-commit-hooks.follows = "git-hooks";
  };

  nixConfig = {
    extra-substituters = [
      "https://hercules-ci.cachix.org"
    ];
    extra-trusted-public-keys = [
      "hercules-ci.cachix.org-1:ZZeDl9Va+xe9j+KqdzoBZMFJHVQ42Uu/c/1/KMC5Lw0="
    ];
  };

  outputs = inputs @ {
    self,
    flake-parts,
    nixpkgs,
    ...
  }:
    flake-parts.lib.mkFlake {inherit inputs;} {
      imports = [
        inputs.devenv.flakeModule
        inputs.hercules-ci-effects.flakeModule
        ./tf.nix
      ];
      systems = ["x86_64-linux"];
      perSystem = {
        config,
        lib,
        system,
        inputs',
        self',
        ...
      }: let
        pkgs = import inputs.nixpkgs {
          inherit system;
          config = {
            allowUnfree = true;
          };
        };
      in {
        _module.args.pkgs = pkgs;

        checks = inputs.deploy-rs.lib.${system}.deployChecks self.deploy;

        devenv.shells.default = {
          containers = lib.mkForce {};
          packages = with pkgs; [
            inputs'.agenix.packages.default
            inputs'.deploy-rs.packages.default
            just
            terraform
          ];
          pre-commit.hooks = {
            alejandra.enable = true;
            terraform-format.enable = true;
          };
        };
      };

      hercules-ci.flake-update = {
        enable = true;
        when = {
          hour = [08];
          dayOfWeek = ["Mon"];
        };
      };

      flake = {
        deploy.nodes.hercules-ci-agent = {
          hostname = "3.20.206.250";
          profiles.system = {
            sshUser = "root";
            # sshOpts = ["-i" "./id_ed25519"];
            user = "root";
            path = inputs.deploy-rs.lib.x86_64-linux.activate.nixos self.nixosConfigurations.hercules-ci-agent;
          };
        };

        nixosConfigurations.hercules-ci-agent = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          modules = [
            ({
              config,
              lib,
              modulesPath,
              pkgs,
              ...
            }: {
              imports = [
                inputs.agenix.nixosModules.default
                inputs.hercules-ci-agent.nixosModules.agent-profile
                "${modulesPath}/virtualisation/amazon-image.nix"
              ];

              age.secrets = {
                binary-caches = {
                  file = ./secrets/binary-caches.json.age;
                  mode = "0400";
                  owner = "hercules-ci-agent";
                  path = "/var/lib/hercules-ci-agent/secrets/binary-caches.json";
                };
                cluster-join-token = {
                  file = ./secrets/cluster-join-token.key.age;
                  owner = "hercules-ci-agent";
                  mode = "0400";
                  path = "/var/lib/hercules-ci-agent/secrets/cluster-join-token.key";
                };
              };

              services.hercules-ci-agent.enable = true;
              services.openssh = {
                enable = true;
              };

              users.users.root.openssh.authorizedKeys.keys = [
                "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEWXJHDkOTwqq+3W5JgBxGWyDNlhxVcQB/2lwBRwg8/f bombadil@ecthelion"
                "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIERAQpJ3mjcz+b2Y+Wf598wURIrGU710Sr91HCcwSiXS bombadil@mothership"
              ];

              system.stateVersion = "24.05";
            })
          ];
        };
      };
    };
}
