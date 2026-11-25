# A operação é chamada pelo fluxo compartilhado do Noir no perfil Cinnamon.

cinnamon_shortcut_offline() {
  if '@pgrep@' -u "$EUID" -x 'cinnamon|cinnamon2d|\.cinnamon.*' >/dev/null; then
    die 'Encerre a sessão Cinnamon e abra o Noir em um TTY.'
  else
    local status=$?
    (( status == 1 )) || die 'Não foi possível verificar se a sessão Cinnamon está encerrada.'
  fi
}

cinnamon_shortcut_personal() {
  DCONF_PROFILE=/dev/fd/3 '@dconf@' read "$1" 3< <(printf '%s\n' "$user_db")
}

cinnamon_shortcut_get_list() {
  local value
  value=$('@gsettings@' get "$@") || return
  [[ $value != '@as []' ]] || value='[]'
  # As listas consultadas contêm IDs e descritores de applets, sem texto livre.
  '@jq@' -r '.[]' <<< "${value//\'/\"}"
}

cinnamon_shortcut_json() {
  local uuid=$1 id=$2 config=${XDG_CONFIG_HOME:-$HOME/.config} path legacy
  path=$config/cinnamon/spices/$uuid/$id.json
  legacy=$HOME/.cinnamon/configs/$uuid/$id.json
  if [[ ! -e $path && -e $legacy ]]; then path=$legacy; fi
  realpath -m -- "$path"
}

cinnamon_shortcut_conflicts() {
  local id schema entries line kind uuid ignored data_dir xlet metadata file override result proposed
  local match="['\"](<super>|<mod4>|<meta>|super\\+)n['\"]"
  local -a dirs
  for id in "${custom_ids[@]}"; do
    [[ $id != custom1000 && $id != __dummy__ ]] || continue
    line=$('@dconf@' read "$root/custom-keybindings/$id/binding") || return 1
    if [[ ${line,,} =~ $match ]]; then printf 'Atalho personalizado %s\n' "$id"; fi
  done
  for schema in org.cinnamon.desktop.keybindings{,.wm,.media-keys} org.cinnamon.muffin{,.x11,.keybindings}; do
    entries=$('@gsettings@' list-recursively "$schema") || return 1
    while IFS= read -r line; do
      if [[ ${line,,} =~ $match ]]; then printf '%s\n' "${line% *}"; fi
    done <<< "$entries"
  done

  IFS=: read -r -a dirs <<< "${XDG_DATA_DIRS:-/run/current-system/sw/share}"
  for kind in applets desklets extensions; do
    entries=$(cinnamon_shortcut_get_list org.cinnamon "enabled-$kind") || return 1
    while IFS= read -r line; do
      [[ -n $line ]] || continue
      case $kind in
        applets) IFS=: read -r ignored ignored ignored uuid id ignored <<< "$line" ;;
        desklets) IFS=: read -r uuid id ignored <<< "$line" ;;
        extensions) uuid=$line; id='' ;;
      esac
      uuid=${uuid#!}
      [[ $uuid =~ ^[[:alnum:]_@.+-]+$ && $id =~ ^[0-9]*$ ]] || return 1
      xlet=${XDG_DATA_HOME:-$HOME/.local/share}/cinnamon/$kind/$uuid
      if [[ ! -d $xlet ]]; then
        for data_dir in "${dirs[@]}" '@cinnamonData@'; do
          xlet=$data_dir/cinnamon/$kind/$uuid
          [[ ! -d $xlet ]] || break
        done
        [[ -d $xlet ]] || continue
      fi
      metadata=$('@jq@' -er '."max-instances" // 1 | tonumber' "$xlet/metadata.json") || return 1
      if [[ $uuid == notifications@cinnamon.org && $xlet != '@cinnamonData@/cinnamon/applets/notifications@cinnamon.org' ]]; then
        if [[ $(realpath -e -- "$xlet") != '@cinnamonData@/cinnamon/applets/notifications@cinnamon.org' ]]; then
          printf 'Cópia alternativa do applet de notificações em %s\n' "$xlet"
        fi
      fi
      if [[ $kind == extensions || $metadata == 1 || ( $kind == desklets && $metadata -lt 1 ) ]]; then id=$uuid; fi
      file=$(cinnamon_shortcut_json "$uuid" "$id") || return 1
      override=/dev/null
      if [[ -f $file ]]; then
        proposed='null'
        if [[ $uuid == notifications@cinnamon.org && $file == "$json" && -n $new ]]; then proposed=$new; fi
        result=$('@jq@' -r --argjson proposed "$proposed" '
          to_entries[] | select(.value | type == "object") |
          select(.value.type == "keybinding") |
          (if .key == "keyOpen" and $proposed != null then $proposed
           else .value.value // empty end) | strings | split("::")[]' "$file") || return 1
      elif [[ -f $xlet/settings-schema.json ]]; then
        if [[ -f $xlet/settings-override.json ]]; then override=$xlet/settings-override.json; fi
        result=$('@jq@' -r --slurpfile override "$override" '
          to_entries[] | .key as $key |
          ($override[0][$key] // null) as $change |
          (if $change == null then .value
           elif $change | has("override-props") then .value + $change
           else $change end) |
          objects | select(.type == "keybinding") | .default | strings | split("::")[]' \
          "$xlet/settings-schema.json") || return 1
      else
        continue
      fi
      while IFS= read -r line; do
        if [[ "'${line,,}'" =~ $match ]]; then printf '%s (%s)\n' "$uuid" "$line"; fi
      done <<< "$result"
    done <<< "$entries"
  done
}

cinnamon_shortcut_write_json() (
  local target=$1 input=$2 temporary
  temporary=$(mktemp -- "$target.noir.XXXXXXXX") || return
  trap 'rm -f -- "$temporary"' EXIT
  cat -- "$input" > "$temporary" &&
    chmod --reference="$target" "$temporary" &&
    mv -T -- "$temporary" "$target"
)

cinnamon_shortcut_identity() {
  '@dconf@' read "$entry/name" && '@dconf@' read "$entry/command"
}

cinnamon_shortcut_review() {
  if [[ $1 != "$2" ]]; then ui_fields 'Notificações' "${1:-(ausente)} → ${2:-(ausente)}"; fi
  if [[ $3 != "$4" ]]; then ui_fields 'Atalho Noir' "${3:-(padrão)} → $4"; fi
}

cinnamon_shortcut_migrate() {
  local name command default id ids old='' new='' previous collisions backup key
  local -a custom_ids=()
  local expected="^'/nix/store/[^/]+-gnome-terminal-[^/]+/bin/gnome-terminal -- /run/current-system/sw/bin/noir-session'$"
  name=$('@dconf@' read -d "$entry/name")
  command=$('@dconf@' read -d "$entry/command")
  default=$('@dconf@' read -d "$entry/binding")
  ids=$(cinnamon_shortcut_get_list org.cinnamon.desktop.keybindings custom-list) ||
    die 'Não foi possível consultar a lista de atalhos do Cinnamon.'
  while IFS= read -r id; do
    [[ -n $id ]] || continue
    [[ $id == __dummy__ || $id =~ ^custom[0-9]+$ ]] || die 'A lista de atalhos contém um identificador inesperado.'
    custom_ids+=("$id")
  done <<< "$ids"
  if [[ $name != "'Noir'" || ! $command =~ $expected || $default != "['<Super>n']" ||
        $(cinnamon_shortcut_identity) != "$name"$'\n'"$command" || $'\n'"$ids"$'\n' != *$'\ncustom1000\n'* ]]; then
    die 'custom1000 não corresponde ao Noir ativo. Confira a lista e os atalhos pessoais.'
  fi
  if [[ -e $json ]]; then
    old=$('@jq@' -ce '.keyOpen.value | strings' "$json") ||
      die 'Não foi possível ler o atalho no JSON de notificações.'
    new=$('@jq@' -c 'split("::") | map(select(test("^(<super>|super\\+)n$"; "i") | not)) | join("::")' <<< "$old")
  fi
  previous=$(cinnamon_shortcut_personal "$entry/binding")
  if [[ -n $previous && $previous != "$default" && $previous != '@as []' ]]; then
    die 'O Noir tem uma combinação pessoal. Revise essa escolha no editor de atalhos.'
  fi
  collisions=$(cinnamon_shortcut_conflicts) || die 'Não foi possível verificar os demais atalhos do Cinnamon.'
  [[ -z $collisions ]] || die "Super+N pode estar em uso por outra ação. Revise estes atalhos: $collisions"
  if [[ $old == "$new" && ( -z $previous || $previous == "$default" ) ]]; then
    shortcut_result='O atalho Noir já usa o padrão.'
    ui_info "$shortcut_result"
    return
  fi

  ui_review 'Revisar migração de Super+N' cinnamon_shortcut_review "$old" "$new" "${previous:-$default}" "$default" || cancel "$?"
  ui_confirm 'Migrar o atalho Super+N desta conta?' || cancel "$?"
  cinnamon_shortcut_offline
  [[ $(cinnamon_shortcut_identity) == "$name"$'\n'"$command" &&
     $(cinnamon_shortcut_personal "$entry/binding") == "$previous" &&
     $(cinnamon_shortcut_get_list org.cinnamon.desktop.keybindings custom-list) == "$ids" ]] ||
    die 'Os atalhos mudaram durante a revisão. Tente novamente.'
  if [[ -n $old ]]; then
    [[ $('@jq@' -ce '.keyOpen.value | strings' "$json") == "$old" ]] ||
      die 'O JSON mudou durante a revisão. Tente novamente.'
  fi
  collisions=$(cinnamon_shortcut_conflicts) || die 'Não foi possível verificar os demais atalhos do Cinnamon.'
  [[ -z $collisions ]] || die "Surgiu outro conflito com Super+N: $collisions"

  backup=$(mktemp -d -- "$state/backup.XXXXXXXX")
  printf '%s' "$user_db" > "$backup/user-db"
  for key in "$root/custom-list" "$entry/"{name,command,binding}; do
    cinnamon_shortcut_personal "$key" > "$backup/${key##*/}"
  done
  if [[ -e $json ]]; then
    cp -p -- "$json" "$backup/notifications.json"
  fi
  if [[ $old != "$new" ]]; then
    printf '%s\n' "$json" > "$backup/json-path"
    '@jq@' --argjson value "$new" '.keyOpen.value = $value' "$backup/notifications.json" > "$backup/notifications-after.json"
  fi
  if [[ -n $previous && $previous != "$default" ]]; then : > "$backup/reset-binding"; fi
  printf '%s\n' "$name" "$command" > "$backup/noir-entry"
  shortcut_backup=$backup
  shortcut_result='Migração interrompida. Use Reverter migração para recuperar as preferências.'
  ui_fields 'Cópia de segurança' "$backup"
  local recovery="Migração interrompida. Use Reverter migração com o backup $backup."
  if [[ -f $backup/json-path ]]; then
    cinnamon_shortcut_write_json "$json" "$backup/notifications-after.json" || die "$recovery"
  fi
  if [[ -f $backup/reset-binding ]]; then
    '@dconf@' reset "$entry/binding" && [[ -z $(cinnamon_shortcut_personal "$entry/binding") ]] || die "$recovery"
  fi
  shortcut_result='Migração concluída. Entre no Cinnamon e teste Super+N.'
  ui_success "$shortcut_result"
}

cinnamon_shortcut_restore() {
  local dir choice backup old='' current='' migrated='' saved='' previous='' replacement
  local -a backups=() labels=()
  for dir in "$state"/backup.*; do
    [[ -f $dir/noir-entry && -f $dir/user-db ]] || continue
    backups+=("$dir")
    labels+=("${dir##*/}")
  done
  if (( ${#backups[@]} == 0 )); then
    shortcut_result='Nenhuma cópia de segurança encontrada.'
    ui_info "$shortcut_result"
    return
  fi
  choice=$(ui_choose 'Selecione a cópia de segurança.' "${labels[@]}") || cancel "$?"
  [[ $choice =~ ^[1-9][0-9]{0,8}$ ]] && (( choice <= ${#backups[@]} )) || die 'Cópia de segurança inválida.'
  backup=${backups[choice - 1]}
  [[ $(<"$backup/user-db") == "$user_db" ]] || die 'O banco pessoal mudou. Confira a cópia de segurança.'
  if [[ -f $backup/reset-binding ]]; then
    [[ $(cinnamon_shortcut_identity) == "$(<"$backup/noir-entry")" ]] ||
      die 'custom1000 mudou de identidade. Confira a cópia de segurança.'
    saved=$(<"$backup/binding")
    previous=$(cinnamon_shortcut_personal "$entry/binding")
    [[ -n $saved && ( -z $previous || $previous == "$saved" ) ]] ||
      die 'O binding tem outra escolha pessoal. Confira a cópia de segurança.'
  fi
  if [[ -f $backup/json-path ]]; then
    [[ $(<"$backup/json-path") == "$json" && -f $json ]] ||
      die 'O caminho do JSON mudou. Confira a cópia de segurança.'
    old=$('@jq@' -ce '.keyOpen.value | strings' "$backup/notifications.json")
    migrated=$('@jq@' -ce '.keyOpen.value | strings' "$backup/notifications-after.json")
    current=$('@jq@' -ce '.keyOpen.value | strings' "$json")
    [[ $current == "$old" || $current == "$migrated" ]] ||
      die 'O atalho de notificações mudou. Confira a cópia de segurança.'
  fi
  if [[ $old == "$current" && $saved == "$previous" ]]; then
    shortcut_result='As alterações deste backup já foram revertidas.'
    ui_info "$shortcut_result"
    return
  fi
  ui_fields 'Cópia de segurança' "$backup"
  ui_review 'Revisar reversão de Super+N' cinnamon_shortcut_review "$current" "$old" "$previous" "$saved" || cancel "$?"
  ui_confirm 'Reverter as mudanças deste backup?' || cancel "$?"
  cinnamon_shortcut_offline
  local recovery="Reversão interrompida. Corrija a falha e repita com o backup $backup."
  shortcut_backup=$backup
  shortcut_result='Reversão interrompida. Confira a cópia de segurança e repita a operação.'
  if [[ $current != "$old" ]]; then
    [[ $('@jq@' -ce '.keyOpen.value | strings' "$json") == "$current" ]] ||
      die 'O JSON mudou durante a revisão. Tente novamente.'
  fi
  if [[ $previous != "$saved" ]]; then
    [[ $(cinnamon_shortcut_identity) == "$(<"$backup/noir-entry")" &&
       $(cinnamon_shortcut_personal "$entry/binding") == "$previous" ]] ||
      die 'O atalho mudou durante a revisão. Tente novamente.'
  fi
  if [[ $current != "$old" ]]; then
    replacement=$backup/notifications.json
    if ! cmp -s -- "$json" "$backup/notifications-after.json"; then
      replacement=$backup/notifications-restore.json
      '@jq@' --argjson value "$old" '.keyOpen.value = $value' "$json" > "$replacement" || die "$recovery"
    fi
    cinnamon_shortcut_write_json "$json" "$replacement" || die "$recovery"
  fi
  if [[ $previous != "$saved" ]]; then
    '@dconf@' write "$entry/binding" "$saved" && [[ $(cinnamon_shortcut_personal "$entry/binding") == "$saved" ]] || die "$recovery"
  fi
  shortcut_result='Reversão concluída.'
  ui_success "$shortcut_result"
}

manage_cinnamon_shortcut() {
  local action state profile user_db lock json root=/org/cinnamon/desktop/keybindings
  local entry=$root/custom-keybindings/custom1000 uuid=notifications@cinnamon.org
  (( EUID != 0 )) || die 'Execute pela própria conta, sem sudo.'
  cinnamon_shortcut_offline
  [[ -n ${DBUS_SESSION_BUS_ADDRESS:-} ]] || die 'Abra o Noir no TTY com dbus-run-session.'
  profile=${DCONF_PROFILE:-user}
  [[ $profile = /* ]] || profile=/etc/dconf/profile/$profile
  [[ -r $profile ]] || die 'O perfil dconf do Cinnamon Noir não está disponível.'
  user_db=$(sed -n '/^user-db:/{p;q;}' "$profile")
  [[ -n $user_db ]] || die 'O perfil dconf não tem banco pessoal.'
  state=${XDG_STATE_HOME:-$HOME/.local/state}/noir/cinnamon-super-n
  umask 077
  mkdir -p -- "$state"
  exec {lock}< "$state"
  '@flock@' -nx "$lock" || die 'Outra operação de Super+N já está em andamento.'
  json=$(cinnamon_shortcut_json "$uuid" "$uuid")
  case $1 in
    migrate) cinnamon_shortcut_migrate ;;
    restore) cinnamon_shortcut_restore ;;
  esac
}
