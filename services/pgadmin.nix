{ pkgs, ... }:

# After installation, visit https://localhost:5050 to access pgAdmin.
{
  services.pgadmin = {
    enable = true;
    initialEmail = "shd101wyy@gmail.com";
    initialPasswordFile = "/home/yiyiwang/.pgadmin_password";
  };
}
