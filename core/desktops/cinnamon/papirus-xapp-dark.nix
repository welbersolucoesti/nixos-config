{ stdenvNoCC, fetchurl }:

let
  rev = "3787e8fc9dd82b607783c84a671937d401f20a7a";
in
stdenvNoCC.mkDerivation {
  pname = "papirus-xapp-dark";
  version = "unstable-2026-11-09";

  src = fetchurl {
    name = "papirus-xapp-symbolic-icons-${rev}.tar.gz";
    url = "https://codeload.github.com/zquestz/papirus-xapp-symbolic-icons/tar.gz/${rev}";
    hash = "sha256-qeaCtst+15zFWzFoZNbGWBmc7Bf53DNiuIjbxG63j40=";
  };

  dontBuild = true;

  installPhase = ''
    runHook preInstall

    theme="$out/share/icons/Papirus-XApp-Dark"
    directories=()
    for directory in icons/Papirus/*/symbolic/*; do
      relative="''${directory#icons/Papirus/}"
      directories+=("$relative")
      install -d "$theme/$relative"
      install -m644 "$directory"/*.svg "$theme/$relative/"
    done

    {
      cat <<'EOF'
    [Icon Theme]
    Name=Papirus-XApp-Dark
    Comment=Papirus-Dark with Papirus XApp symbolic icons
    Inherits=Papirus-Dark
    Example=folder
    FollowsColorScheme=true
    EOF
      printf 'Directories=%s\n' "$(IFS=,; printf '%s' "''${directories[*]}")"
      for directory in "''${directories[@]}"; do
        printf '\n[%s]\nSize=%s\nType=Fixed\n' "$directory" "''${directory%%x*}"
      done
    } > "$theme/index.theme"

    install -m644 LICENSE "$theme/COPYING"

    runHook postInstall
  '';
}
