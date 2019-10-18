let
  commonConfig = ./common/letsencrypt/common.nix;
in import ./make-test.nix {
  name = "acme";

  nodes = {
    letsencrypt = ./common/letsencrypt;

    webserver = { config, pkgs, ... }: {
      imports = [ commonConfig ];
      networking.firewall.allowedTCPPorts = [ 80 443 ];

      networking.extraHosts = ''
        ${config.networking.primaryIPAddress} example.com
      '';

      services.nginx.enable = true;
      services.nginx.virtualHosts."example.com" = {
        enableACME = true;
        forceSSL = true;
        locations."/".root = pkgs.runCommand "docroot" {} ''
          mkdir -p "$out"
          echo hello world > "$out/index.html"
        '';
      };
    };

    client = commonConfig;
  };

  testScript = {nodes, ...}:
    let
      newServerSystem = nodes.webserver2.config.system.build.toplevel;
      switchToNewServer = "${newServerSystem}/bin/switch-to-configuration test";
    in
    # Note, waitForUnit does not work for oneshot services that do not have RemainAfterExit=true,
    # this is because a oneshot goes from inactive => activating => inactive, and never
    # reaches the active state. To work around this, we create some mock target units which
    # get pulled in by the oneshot units. The target units linger after activation, and hence we
    # can use them to probe that a oneshot fired. It is a bit ugly, but it is the best we can do
    ''
      $client->start;
      $letsencrypt->start;
      $acmeStandalone->start;

      $letsencrypt->waitForUnit("default.target");
      $letsencrypt->waitForUnit("pebble.service");

      subtest "can request certificate with HTTPS-01 challenge", sub {
        $acmeStandalone->waitForUnit("default.target");
        $acmeStandalone->succeed("systemctl start acme-standalone.com.service");
        $acmeStandalone->waitForUnit("acme-finished-standalone.com.target");
      };

      $client->waitForUnit("default.target");

      $client->succeed('curl https://acme-v02.api.letsencrypt.org:15000/roots/0 > /tmp/ca.crt');
      $client->succeed('curl https://acme-v02.api.letsencrypt.org:15000/intermediate-keys/0 >> /tmp/ca.crt');

      subtest "Can request certificate for nginx service", sub {
        $webserver->waitForUnit("acme-finished-a.example.com.target");
        $client->succeed('curl --cacert /tmp/ca.crt https://a.example.com/ | grep -qF "hello world"');
      };

      subtest "Can add another certificate for nginx service", sub {
        $webserver->succeed("/run/current-system/fine-tune/child-1/bin/switch-to-configuration test");
        $webserver->waitForUnit("acme-finished-b.example.com.target");
        $client->succeed('curl --cacert /tmp/ca.crt https://b.example.com/ | grep -qF "hello world"');
      };
    '';
}
