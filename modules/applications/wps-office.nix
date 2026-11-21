{ pkgs, ... }:

{
  # Suíte de escritório. O pacote depende da política de software proprietário.
  environment.systemPackages = [ pkgs.wpsoffice ];
}
