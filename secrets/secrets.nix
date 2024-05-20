let
  user = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIERAQpJ3mjcz+b2Y+Wf598wURIrGU710Sr91HCcwSiXS bombadil@mothership";
  system = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEWzQjg0Tqgw2zDD/KP+jGWs/F9o7DdWqmyAve8fIQX8 root@ip-172-31-43-84.us-east-2.compute.internal";
in {
  "binary-caches.json.age".publicKeys = [user system];
  "cluster-join-token.key.age".publicKeys = [user system];
  "id_ed25519.age".publicKeys = [user system];
}
