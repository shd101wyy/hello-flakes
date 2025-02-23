{pkgs, ...}: {
  networking.wg-quick.interfaces = let
    endpoint = "${builtins.readFile /home/yiyiwang/Workspace/hello-flakes/secrets/rv-wireguard-endpoint}";    
    publicKey = "${builtins.readFile /home/yiyiwang/Workspace/hello-flakes/secrets/rv-wireguard-public-key}";
  in {
    rvoffice = {
      # IP address of this machine in the *tunnel network*
      address = [
        "192.168.2.4/32"
      ];

      # To match firewall allowedUDPPorts (without this wg
      # uses random port numbers).
      listenPort = 51820;

      # Path to the private key file.
      privateKeyFile = "/home/yiyiwang/Workspace/hello-flakes/secrets/rv-wireguard-private-key";

      peers = [{
        # Public key of the server (not a file path).
        publicKey = publicKey;
        # Forward all the traffic via VPN.
        allowedIPs = ["192.168.2.1/32" "192.168.2.4/32" "0.0.0.0/0"];
        # Set this to the server IP and port.
        endpoint = endpoint;
        # Send keepalives every 25 seconds. Important to keep NAT tables alive.
        persistentKeepalive = 25;
      }];
    };
  };
}