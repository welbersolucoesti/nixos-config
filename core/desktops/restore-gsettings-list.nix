{ lib, pkgs }:

# Reintroduz os itens administrados no login sem substituir as entradas pessoais.
pkgs.writeShellScript "noir-restore-gsettings-list" ''
  set -eu
  schema=$1 key=$2
  shift 2
  gsettings=${lib.getExe' (lib.getBin pkgs.glib) "gsettings"}
  current=$("$gsettings" get "$schema" "$key")
  case $current in
    '@as []') current='[]' ;;
    '['*']') ;;
    *) exit 1 ;;
  esac

  result=$current
  for item; do
    quoted="'$item'"
    # Os IDs administrados só contêm caracteres simples e GVariant usa aspas simples.
    [[ $result == *"$quoted"* ]] && continue
    if [[ $result == '[]' ]]; then
      result="[$quoted]"
    else
      result="''${result%]}, $quoted]"
    fi
  done
  if [[ $result != "$current" ]]; then
    "$gsettings" set "$schema" "$key" "$result"
  fi
''
