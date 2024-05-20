default: deploy

apply:
    nix build .#main-tf
    terraform apply

build:
    nix build .#nixosConfigurations.hercules-ci-agent.config.system.build.toplevel

check:
    nix flake check --impure

deploy: build
    deploy --skip-checks .
