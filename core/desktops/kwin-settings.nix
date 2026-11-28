wallpaper:

{
  input = ''
    [Keyboard]
    NumLock[$i]=0

    [Mouse]
    cursorTheme[$i]=breeze_cursors
    cursorSize[$i]=24

    [Libinput][Defaults][Touchpad]
    NaturalScroll[$i]=true
  '';

  desktops = ''
    [Desktops]
    Number[$i]=2
    Rows[$i]=1
    Name_1[$i]=Work 1
    Name_2[$i]=Work 2
  '';

  plugins = ''
    [Plugins]
    glideEnabled[$i]=true
    magiclampEnabled[$i]=true
    scaleEnabled[$i]=false
    squashEnabled[$i]=false
  '';

  windows = ''
    [Windows]
    RollOverDesktops[$i]=false
  '';

  locker = ''
    [Greeter]
    WallpaperPlugin[$i]=org.kde.image

    [Greeter][Wallpaper][org.kde.image][General]
    Image[$i]=file://${wallpaper}
  '';
}
