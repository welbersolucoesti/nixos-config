{ pkgs, ... }:

{
  # PostgreSQL 18 para desenvolvimento. Amplie a escuta só após revisar autenticação e firewall.
  services.postgresql = {

    enable = true;
    package = pkgs.postgresql_18;

    settings = {
      listen_addresses = "localhost";
      port = 5432;
      password_encryption = "scram-sha-256";
    };

    # Estas regras TCP cobrem os endereços de loopback IPv4 e IPv6.
    authentication = "
      host all all 127.0.0.1/32   scram-sha-256
      host all all ::1/128        scram-sha-256
    ";
  };
}
