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

  biometria = pkgs.writeShellScriptBin "biometria" ''
    if (( EUID == 0 )); then
      printf 'Cadastre a digital pela própria conta, sem sudo.\n' >&2
      exit 1
    fi
    if (( $# != 0 )) && [[ $# != 2 || $1 != -f ]]; then
      printf 'Uso: biometria [-f DEDO]\n' >&2
      exit 2
    fi
    if ! command -v fprintd-enroll >/dev/null; then
      printf 'fprintd-enroll indisponível. Verifique se o fprintd está habilitado.\n' >&2
      exit 1
    fi

    if ! devices=$(${pkgs.systemd}/bin/busctl --system --timeout=10s call \
      net.reactivated.Fprint /net/reactivated/Fprint/Manager net.reactivated.Fprint.Manager GetDevices); then
      printf 'Falha ao consultar o fprintd. Verifique o serviço e o barramento do sistema.\n' >&2
      exit 1
    fi
    if [[ $devices == 'ao 0' ]]; then
      printf 'Nenhum leitor de digitais compatível foi detectado pelo fprintd.\n' >&2
      exit 1
    fi
    exec fprintd-enroll "$@"
  '';
in
{
  config.environment.systemPackages = [ noir ]
    ++ lib.optionals (config.personalConfig.desktop == "xfce") [ noirSession biometria ]
    ++ lib.optional (lib.elem config.personalConfig.desktop [ "kde" "gnome" "cinnamon" ]) noirSession;
}
