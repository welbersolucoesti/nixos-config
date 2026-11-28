{ config, lib, pkgs, ... }:

let
  noir = pkgs.writeShellScriptBin "noir" ''
    if (( EUID == 0 )); then
      printf 'Execute o Noir na sua conta normal, sem sudo.\n' >&2
      exit 1
    fi
    if [[ -z "''${HOME:-}" ]]; then
      printf 'HOME indisponível. Abra o Noir na sua sessão de usuário.\n' >&2
      exit 1
    fi
    configurator=$HOME/nixos-config/noir
    if [[ ! -f $configurator ]]; then
      printf 'Repositório Noir indisponível. Esperado em %s.\n' "$configurator" >&2
      exit 1
    fi
    if [[ ! -x $configurator ]]; then
      printf 'O configurador não é executável: %s\n' "$configurator" >&2
      exit 1
    fi
    exec "$configurator" "$@"
  '';

  noirSession = pkgs.writeShellScriptBin "noir-session" ''
    status=0
    ${lib.getExe noir} || status=$?
    if (( status != 0 )); then
      printf '\nO Noir saiu com código %s. Pressione Enter para fechar. ' "$status" >&2
      read -r || true
    fi
    exit "$status"
  '';
in
{
  config.environment.systemPackages = [ noir ]
    ++ lib.optional (lib.elem config.personalConfig.desktop [ "kde" "gnome" "cinnamon" ]) noirSession;
}
