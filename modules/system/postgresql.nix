{ pkgs, ... }:

{
  # PostgreSQL 18 para desenvolvimento local, com acesso TCP restrito a localhost.
  services.postgresql = {

    enable = true;
    package = pkgs.postgresql_18;

    settings = {
      listen_addresses = "localhost";
      port = 5432;
      password_encryption = "scram-sha-256";
    };

    authentication = "
      host all all 127.0.0.1/32   scram-sha-256
      host all all ::1/128        scram-sha-256
    ";
  };
}
