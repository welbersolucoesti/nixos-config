{ config, lib, pkgs, ... }:

let
  # A configuração de sistema introduz o canal. Permita que a migração nativa
  # ainda leia um terminalrc antigo quando o usuário não tem o próprio XML.
  terminal = pkgs.xfce4-terminal.overrideAttrs (old: {
    postPatch = (old.postPatch or "") + ''
      substituteInPlace terminal/terminal-preferences.c \
        --replace-fail '  gchar **channels;' '  gchar *user_config;' \
        --replace-fail '  channels = xfconf_list_channels ();' \
          '  user_config = g_build_filename (g_get_user_config_dir (), "xfce4", "xfconf", "xfce-perchannel-xml", "xfce4-terminal.xml", NULL);' \
        --replace-fail 'if (channels != NULL && !g_strv_contains ((const gchar *const *) channels, "xfce4-terminal"))' \
          'if (!g_file_test (user_config, G_FILE_TEST_EXISTS | G_FILE_TEST_IS_SYMLINK))' \
        --replace-fail '  g_strfreev (channels);' '  g_free (user_config);'

      substituteInPlace terminal/terminal-screen.c \
        --replace-fail '  screen->terminal = g_object_new (TERMINAL_TYPE_WIDGET, NULL);' '
        screen->terminal = g_object_new (TERMINAL_TYPE_WIDGET, NULL);
        GtkCssProvider *padding = gtk_css_provider_new ();
        gtk_css_provider_load_from_data (padding, "* { padding: 8px; }", -1, NULL);
        gtk_style_context_add_provider (gtk_widget_get_style_context (screen->terminal),
                                        GTK_STYLE_PROVIDER (padding),
                                        GTK_STYLE_PROVIDER_PRIORITY_APPLICATION);
        g_object_unref (padding);'
    '';
  });

  # O KXMLGUI procura estes arquivos antes dos recursos internos do Konsole.
  # Mantém a versão original do XML para dar precedência ao arquivo pessoal.
  konsoleToolbars = pkgs.runCommand "konsole-noir-toolbars" {
    inherit (pkgs.kdePackages.konsole) src;
  } ''
    target="$out/share/kxmlgui5/konsole"
    mkdir -p "$target"
    tar -xf "$src" -C "$target" --strip-components=2 --wildcards \
      '*/desktop/konsoleui.rc' '*/desktop/sessionui.rc'
    substituteInPlace "$target/konsoleui.rc" \
      --replace-fail '<ToolBar name="mainToolBar">' '<ToolBar name="mainToolBar" hidden="true">'
    substituteInPlace "$target/sessionui.rc" \
      --replace-fail '<ToolBar name="sessionToolbar">' '<ToolBar name="sessionToolbar" hidden="true">'
  '';
in
{
  config = lib.mkMerge [
    (lib.mkIf (config.personalConfig.desktop == "xfce") {
      # Mantém o mesmo executável, menu e helper TerminalEmulator do XFCE.
      environment.xfce.excludePackages = [ pkgs.xfce4-terminal ];
      environment.systemPackages = [ terminal ];
      fonts.packages = [ pkgs.dejavu_fonts ];

      environment.etc."xdg/xfce4/xfconf/xfce-perchannel-xml/xfce4-terminal.xml".text = ''
        <?xml version="1.0" encoding="UTF-8"?>
        <channel name="xfce4-terminal" version="1.0">
          <property name="background-mode" type="string" value="TERMINAL_BACKGROUND_TRANSPARENT"/>
          <property name="background-darkness" type="double" value="0.90"/>
          <property name="color-use-theme" type="bool" value="false"/>
          <property name="color-background" type="string" value="#202126"/>
          <property name="color-foreground" type="string" value="#e8e9ee"/>
          <property name="color-cursor-use-default" type="bool" value="false"/>
          <property name="color-cursor" type="string" value="#b6ceff"/>
          <property name="color-cursor-foreground" type="string" value="#202126"/>
          <property name="color-selection-use-default" type="bool" value="false"/>
          <property name="color-selection-background" type="string" value="#435a85"/>
          <property name="color-selection" type="string" value="#ffffff"/>
          <property name="color-palette" type="string" value="#282a32;#e58c91;#a9c98c;#e2c185;#8eb2ed;#c9a5e3;#8fcac6;#d7d9e1;#767b89;#f6abb0;#c3dfa6;#f4d7a1;#b1ccff;#e0bdf7;#afe5df;#f3f4f8"/>
          <property name="font-use-system" type="bool" value="false"/>
          <property name="font-name" type="string" value="DejaVu Sans Mono 11"/>
          <property name="cell-height-scale" type="double" value="1.12"/>
          <property name="misc-menubar-default" type="bool" value="false"/>
          <property name="misc-toolbar-default" type="bool" value="false"/>
          <property name="scrolling-bar" type="string" value="TERMINAL_SCROLLBAR_NONE"/>
          <property name="misc-always-show-tabs" type="bool" value="false"/>
          <property name="misc-borders-default" type="bool" value="true"/>
        </channel>
      '';
    })
    (lib.mkIf (config.personalConfig.desktop == "kde") {
      environment.systemPackages = [
        konsoleToolbars
        (pkgs.writeTextDir "share/konsole/Noir.profile" ''
          [General]
          Name=Noir
          Parent=FALLBACK/

          [Scrolling]
          ScrollBarPosition=2
        '')
      ];
      environment.etc."xdg/konsolerc".text = ''
        [Desktop Entry]
        DefaultProfile=Noir.profile

        [MainWindow]
        MenuBar=Disabled

        [KonsoleWindow]
        RemoveWindowTitleBarAndFrame=false

        [TabBar]
        TabBarVisibility=ShowTabBarWhenNeeded
      '';
    })
  ];
}
