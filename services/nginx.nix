{ pkgs, ... }:

{
  services.nginx = {
    enable = true;
    virtualHosts = {
      "localhost" = {
        extraConfig = ''
    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Connection "Upgrade";
    proxy_set_header Host $host;
    proxy_set_header Authorization $http_authorization;
    proxy_pass_header Authorization;
    proxy_http_version 1.1;
        '';

        locations."/" = {
          proxyPass = "http://127.0.0.1:3000";
          # Basic authentication configuration
          basicAuth = {
            "admin" = "admin"; # Replace with your desired username and password
          };
        };
        locations."~ ^/(socket.io|api|graphql)(.*?)$" = {
          proxyPass = "http://127.0.0.1:5000/$1$2$is_args$args"; # Replace 8080 with your actual backend port
        };
      };
    };
  };
}
