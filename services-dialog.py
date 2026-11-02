#!/usr/bin/env python3
"""The launcher's start window: the project folder, run.sh or Docker for the web stack, and a check box
per service, with Cancel, Stop all, Stop, Restart and Start.

    services-dialog.py ROOT FOLDER[,FOLDER...] ENTRY [ENTRY ...]

FOLDERS are folder names under ROOT; the first is selected. Each ENTRY is a group heading,
"#|title|description", or a service, "key|TRUE or FALSE|title|subtitle|ports". The run.sh / Docker
switch sits in the group of the first web service (primary, import, fe). Nothing starts on its own:
the window waits for Start, Restart, Stop, Stop all or Cancel.

Start prints two lines, the folder name and the ticked keys joined by "|", with "docker" added when the
web stack runs in Docker; Restart prints the same with "hard" added, Stop with "stop" added. Stop all
prints the folder name and "stop" alone, whatever is ticked: "stop" with no service key means every
service. All four exit 0. Cancel, Esc or
closing the window prints nothing and exits 1. Exit 3: the window could not be shown (no GTK 4 /
libadwaita bindings, no display, bad arguments), so the caller can fall back.
"""

import os
import sys
import traceback

WEB_KEYS = ("primary", "import", "fe")
# Both a workspace's start scripts need: run.sh, docker-run.sh and wr.sh refuse any other folder.
WORKSPACE_DIRS = ("backendApi", "dbMigrations")
# Wide enough for two columns side by side; a narrower window stacks them.
WIDTH = 1100
NARROW = "max-width: 720sp"
MODE_NOTES = {
    False: "Dev watchers with live reload",
    True: "Production build in containers. Asks for your sudo password in a window, and code edits need another start",
}
# The launcher's icon, beside the title. Its letters are black, so it sits on a white tile that reads on
# a dark header bar too.
LOGO = os.path.join(os.path.dirname(os.path.realpath(__file__)), "logo-small.svg")
LOGO_CSS = ".logo { background: white; border-radius: 6px; padding: 3px 5px; }"


def parse(argv):
    """ROOT FOLDERS ENTRY... as (root, folders, entries), or None when malformed."""
    if len(argv) < 3:
        return None
    folders = [f for f in argv[1].split(",") if f]
    entries = [e.split("|") for e in argv[2:]]
    for e in entries:
        if not (e[0] == "#" and len(e) == 3 or len(e) == 5 and e[1] in ("TRUE", "FALSE")):
            return None
    if not folders or not any(e[0] != "#" for e in entries):
        return None
    return argv[0], folders, entries


def join(names):
    return names[0] if len(names) == 1 else ", ".join(names[:-1]) + " and " + names[-1]


def summary(folder, ok, ticked, docker):
    """The sentence above the buttons: what Start will do, or why it cannot."""
    if not ok:
        return f"{folder} has no {' or '.join(WORKSPACE_DIRS)}. Pick another folder."
    web = [t for k, t in ticked if k in WEB_KEYS]
    tunnels = [t for k, t in ticked if k.startswith("ngrok")]
    python = [t for k, t in ticked if k not in WEB_KEYS and not k.startswith("ngrok")]
    parts = []
    if web:
        parts.append(f"{join(web)} with {'Docker' if docker else 'run.sh'}")
    if python:
        parts.append(f"{join(python)} with wr.sh")
    if tunnels:
        parts.append(join(tunnels))
    if not parts:
        return "Nothing is ticked. Tick a service to start it."
    return f"Starts {'; '.join(parts)} in {folder}."


def run(root, folders, entries):
    import gi

    gi.require_version("Gtk", "4.0")
    gi.require_version("Gdk", "4.0")
    gi.require_version("Adw", "1")
    from gi.repository import Gdk, GLib, Gtk

    # Checked before libadwaita loads: without a display it crashes instead of failing. (Importing
    # Gtk already ran Gtk.init_check(), and calling it again returns True even when that failed.)
    display = Gdk.Display.get_default()
    if display is None:
        return 3
    from gi.repository import Adw

    Adw.init()
    loop = GLib.MainLoop()
    status = [1]

    project = Adw.PreferencesGroup()
    folder_row = Adw.ComboRow(title="Folder", model=Gtk.StringList.new(folders))
    project.add(folder_row)

    # Radio buttons rather than a linked toggle pair: which one is picked reads at a glance.
    run_sh = Gtk.CheckButton(label="run.sh", active=True)
    docker = Gtk.CheckButton(label="Docker")
    docker.set_group(run_sh)
    switch = Gtk.Box(spacing=12, valign=Gtk.Align.CENTER)
    switch.append(run_sh)
    switch.append(docker)
    mode_row = Adw.ActionRow(title="Runs with")
    mode_row.add_suffix(switch)

    # Two columns: the folder and the first group (the web stack) on the left, every other group on
    # the right, so the whole form shows without scrolling.
    left = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=24)
    right = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=24)
    left.append(project)

    def new_group(title=None, description=None):
        added = Adw.PreferencesGroup(title=title, description=description)
        (left if left.get_last_child() is project else right).append(added)
        return added

    group = None
    checks = []
    for entry in entries:
        if entry[0] == "#":
            group = new_group(entry[1], entry[2] or None)
            continue
        key, on, title, subtitle, ports = entry
        if group is None:
            group = new_group()
        if key in WEB_KEYS and mode_row.get_parent() is None:
            group.add(mode_row)
        check = Gtk.CheckButton(active=on == "TRUE", valign=Gtk.Align.CENTER)
        row = Adw.ActionRow(title=title, subtitle=subtitle, use_markup=False, activatable_widget=check)
        row.add_prefix(check)
        if ports:
            row.add_suffix(Gtk.Label(label=ports, css_classes=["dim-label", "numeric"]))
        group.add(row)
        checks.append((key, title, check))

    message = Gtk.Label(xalign=0, wrap=True, hexpand=True, css_classes=["heading"])

    def icon_button(label, icon, **props):
        return Gtk.Button(child=Adw.ButtonContent(icon_name=icon, label=label), **props)

    cancel = icon_button("Cancel", "window-close-symbolic")
    # Plain: Start is the one action the window suggests, and a restart loses nothing.
    restart = icon_button(
        "Restart",
        "view-refresh-symbolic",
        tooltip_text="Stops the ticked services if they are running, then starts them fresh. Tunnels are not restarted",
    )
    # Plain like Restart: it acts on the ticked services, as Restart and Start do.
    stop = icon_button(
        "Stop",
        "media-playback-stop-symbolic",
        tooltip_text="Stops the ticked services and tunnels, from any folder, whether run.sh, Docker or wr.sh "
        "started them. Starts nothing",
    )
    # Red, and apart from the three that act on the ticks: it ends everything, whatever is ticked.
    stop_all = icon_button(
        "Stop all",
        "media-playback-stop-symbolic",
        css_classes=["destructive-action"],
        tooltip_text="Stops every service in this window that is running, from any folder, whether run.sh, "
        "Docker or wr.sh started it, and the ngrok tunnels. Starts nothing",
    )
    start = icon_button("Start", "media-playback-start-symbolic", css_classes=["suggested-action"])
    buttons = Gtk.Box(spacing=8, valign=Gtk.Align.CENTER)
    for button in (cancel, stop_all, stop, restart, start):
        buttons.append(button)
    bar = Gtk.Box(spacing=18, margin_top=12, margin_bottom=12, margin_start=18, margin_end=18)
    bar.append(message)
    bar.append(buttons)

    columns = Gtk.Box(spacing=24, homogeneous=True, margin_top=24, margin_bottom=24, margin_start=24, margin_end=24)
    columns.append(left)
    columns.append(right)
    # As tall as the form, so nothing hides behind the bottom bar; it scrolls only on a screen too short.
    scroller = Gtk.ScrolledWindow(
        child=columns, hscrollbar_policy=Gtk.PolicyType.NEVER, propagate_natural_height=True
    )

    view = Adw.ToolbarView(content=scroller, bottom_bar_style=Adw.ToolbarStyle.RAISED)
    css = Gtk.CssProvider()
    css.load_from_string(LOGO_CSS)
    Gtk.StyleContext.add_provider_for_display(display, css, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION)
    logo = Gtk.Box(valign=Gtk.Align.CENTER, css_classes=["logo"])
    picture = Gtk.Picture.new_for_filename(LOGO)
    picture.set_can_shrink(False)
    logo.append(picture)
    heading = Gtk.Box(spacing=10)
    heading.append(logo)
    heading.append(Adw.WindowTitle(title="CapExpert", subtitle="Start services"))
    view.add_top_bar(Adw.HeaderBar(title_widget=heading))
    view.add_bottom_bar(bar)

    # Fits the smallest screen attached, whichever one the window opens on: 90 % of its width, and
    # its height less room for the header bar, the bottom bar and the desktop's own top bar.
    monitors = display.get_monitors()
    screens = [monitors.get_item(i).get_geometry() for i in range(monitors.get_n_items())]
    width = min([WIDTH] + [int(s.width * 0.9) for s in screens])
    scroller.set_max_content_height(min([900] + [int(s.height * 0.9) - 200 for s in screens]))
    window = Adw.Window(title="CapExpert", content=view, default_width=width)
    window.set_size_request(360, 320)
    window.set_default_widget(start)

    narrow = Adw.Breakpoint.new(Adw.BreakpointCondition.parse(NARROW))
    narrow.connect("apply", lambda *_: (columns.set_orientation(Gtk.Orientation.VERTICAL), columns.set_homogeneous(False)))
    narrow.connect("unapply", lambda *_: (columns.set_orientation(Gtk.Orientation.HORIZONTAL), columns.set_homogeneous(True)))
    window.add_breakpoint(narrow)

    def update(*_):
        name = folders[folder_row.get_selected()]
        path = os.path.join(root, name)
        ok = all(os.path.isdir(os.path.join(path, d)) for d in WORKSPACE_DIRS)
        folder_row.set_subtitle(path)
        mode_row.set_subtitle(MODE_NOTES[docker.get_active()])
        ticked = [(key, title) for key, title, check in checks if check.get_active()]
        # The switch only decides how the web services run; with none ticked it has nothing to decide.
        mode_row.set_sensitive(any(key in WEB_KEYS for key, _ in ticked))
        message.set_label(summary(name, ok, ticked, docker.get_active()))
        startable = ok and bool(ticked)
        for button in (start, restart, stop):
            button.set_sensitive(startable)
        # The ticks do not matter to it, but the stop scripts still run from a workspace.
        stop_all.set_sensitive(ok)

    def respond(action=None):
        keys = [key for key, _, check in checks if check.get_active()]
        if docker.get_active():
            keys.append("docker")
        if action:
            keys.append(action)
        finish(keys)

    def finish(keys):
        print(folders[folder_row.get_selected()])
        print("|".join(keys))
        status[0] = 0
        loop.quit()

    folder_row.connect("notify::selected", update)
    docker.connect("toggled", update)
    for _, _, check in checks:
        check.connect("toggled", update)
    cancel.connect("clicked", lambda *_: loop.quit())
    stop_all.connect("clicked", lambda *_: finish(["stop"]))
    stop.connect("clicked", lambda *_: respond("stop"))
    restart.connect("clicked", lambda *_: respond("hard"))
    start.connect("clicked", lambda *_: respond())
    window.connect("close-request", lambda *_: loop.quit() or False)
    escape = Gtk.ShortcutController()
    escape.add_shortcut(
        Gtk.Shortcut(
            trigger=Gtk.ShortcutTrigger.parse_string("Escape"),
            action=Gtk.CallbackAction.new(lambda *_: loop.quit() or True),
        )
    )
    window.add_controller(escape)

    update()
    window.present()
    start.grab_focus()
    loop.run()
    return status[0]


def main():
    args = parse(sys.argv[1:])
    if args is None:
        return 3
    try:
        return run(*args)
    except Exception:
        traceback.print_exc()
        return 3


if __name__ == "__main__":
    sys.exit(main())
