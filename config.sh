#!/usr/bin/env bash
set -euo pipefail

command -v dirname >/dev/null || { printf 'Erro: Comando necessário ausente: dirname.\n' >&2; exit 1; }
# shellcheck source=install.sh
source "$(dirname -- "${BASH_SOURCE[0]}")/install.sh"
main dialog "$@"
