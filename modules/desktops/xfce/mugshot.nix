{ config, lib, pkgs, ... }:

let
  # A revisão local do Nixpkgs não oferece o Mugshot.
  mugshot = pkgs.python3Packages.buildPythonApplication {
    pname = "mugshot";
    version = "0.4.3";
    format = "setuptools";

    src = pkgs.fetchurl {
      url = "https://deb.debian.org/debian/pool/main/m/mugshot/mugshot_0.4.3.orig.tar.gz";
      sha256 = "2f66869a58bf45de29e065dfdaa591f32a88ec91682c0fa15accfd9f58c3c19c";
    };

    nativeBuildInputs = with pkgs; [
      gettext
      glib
      gobject-introspection
      gtk3
      intltool
      wrapGAppsHook3
      writableTmpDirAsHomeHook
      python3Packages.distutils-extra
    ];

    dependencies = with pkgs.python3Packages; [ pexpect pycairo pygobject3 ];

    postPatch = ''
      substituteInPlace setup.py \
        --replace-fail 'data_dir =' "data_dir = '$out/share/mugshot' #" \
        --replace-fail 'update_desktop_file(desktop_file, script_path)' ""
    '';

    postInstall = ''
      glib-compile-schemas "$out/share/glib-2.0/schemas"
    '';
  };
in
{
  config = lib.mkIf (config.personalConfig.desktop == "xfce") {
    environment.systemPackages = [ (pkgs.mugshot or mugshot) ];
  };
}
