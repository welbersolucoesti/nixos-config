// Executado pelo Plasma ao inicializar seu layout padrão.
if (panels().length === 0) {
    const top = new Panel();
    top.location = "top";
    top.height = 38;
    top.lengthMode = "fill";
    top.alignment = "center";
    top.hiding = "none";
    top.floating = true;
    top.opacity = "adaptive";

    const kickoff = top.addWidget("org.kde.plasma.kickoff");
    kickoff.currentConfigGroup = ["General"];
    kickoff.writeConfig("icon", "nix-snowflake");
    top.addWidget("org.kde.plasma.marginsseparator");
    top.addWidget("org.kde.plasma.windowlist");
    top.addWidget("org.kde.plasma.panelspacer");

    const clock = top.addWidget("org.kde.plasma.digitalclock");
    clock.currentConfigGroup = ["Appearance"];
    clock.writeConfig("showDate", false);
    clock.writeConfig("fontWeight", 400);

    top.addWidget("org.kde.plasma.panelspacer");
    top.addWidget("org.kde.plasma.systemtray");
    top.addWidget("org.kde.plasma.pager");
    top.addWidget("org.kde.plasma.showdesktop");

    const bottom = new Panel();
    bottom.location = "bottom";
    bottom.height = 42;
    bottom.lengthMode = "fit";
    bottom.alignment = "center";
    bottom.hiding = "dodgewindows";
    bottom.floating = true;
    bottom.opacity = "translucent";

    const tasks = bottom.addWidget("org.kde.plasma.icontasks");
    tasks.currentConfigGroup = ["General"];
    tasks.writeConfig("launchers", [
        "preferred://browser",
        "applications:idea.desktop",
        "applications:code.desktop",
        "applications:dbeaver.desktop",
        "applications:org.kde.dolphin.desktop",
    ]);
}
