set -e

config_home=${XDG_CONFIG_HOME:-$HOME/.config}
status=0

rewrite_ini() (
    file=$1
    rule=$2
    [[ -f $file && ! -L $file && -O $file ]] || return 0

    temporary=$(mktemp -- "$file.noir.XXXXXXXX") || return
    trap 'rm -f -- "$temporary"' EXIT
    sed -E "$rule" -- "$file" > "$temporary" || return
    if ! cmp -s -- "$file" "$temporary"; then
        chmod --reference="$file" -- "$temporary" || return
        mv -T -- "$temporary" "$file"
    fi
)

# O Bitwarden controla a existência da entrada pessoal conforme a opção do aplicativo.
# Preserve os demais argumentos e chaves, incluindo a desativação via Hidden.
rewrite_ini "$config_home/autostart/bitwarden.desktop" '
    /^\[Desktop Entry\]\r?$/,/^\[/ {
        s@^(Exec|TryExec)="?/nix/store/[a-z0-9]{32}-bitwarden-desktop-[^/]+/bin/bitwarden"?([[:space:]]|$)@\1=/run/current-system/sw/bin/bitwarden\2@
    }
' || status=1

# Só migra o nome reservado que o Noir gerava para seu papel de parede.
rewrite_ini "$config_home/pcmanfm-qt/lxqt/settings.conf" '
    /^\[Desktop\]\r?$/,/^\[/ {
        s@^Wallpaper=/nix/store/[a-z0-9]{32}-noir-wallpaper(\.[[:alnum:]]+)?(\r?)$@Wallpaper=/etc/xdg/pcmanfm-qt/lxqt/noir-wallpaper\2@
    }
' || status=1

exit "$status"
