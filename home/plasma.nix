{ ... }:

# KDE Plasma desktop: panel geometry, widget order, the clock, virtual desktops,
# the wallpaper, the default terminal and the global shortcuts that go with it.
#
# This is the declarative version of what used to be dragged around by hand. It
# was transcribed from a working session — `~/.config/plasmashellrc` for the
# geometry and `AppletOrder` in `~/.config/plasma-org.kde.plasma.desktop-appletsrc`
# for the widget list — so applying it should be a no-op on the machine it came
# from.
#
# WARNING, read before the first switch on any *other* machine: declaring
# `panels` makes plasma-manager authoritative over *panels*. Its login script
# starts with `panels().forEach((panel) => panel.remove())` and deletes
# ~/.config/plasma-org.kde.plasma.desktop-appletsrc outright (to stop the file
# growing without bound — plasma-manager issue #76), then rebuilds the panels
# from what is below. Any panel you arranged by hand and did not write down here
# is gone. Run `nix run github:nix-community/plasma-manager` (rc2nix) on that
# machine first and reconcile, before switching.
#
# Desktop containments survive that deletion, despite the file holding them too:
# the script runs from a KDE autostart entry gated on
# `X-KDE-autostart-condition=ksmserver`, i.e. with plasmashell already up, so
# plasmashell re-serialises the desktops from memory. Wallpaper and desktop
# widgets are only changed by the settings below that name them.
#
# Two different apply times, which is worth knowing when a change seems not to
# take:
#   - `panels`, `workspace` (wallpaper), `desktop`  -> a script run at login
#   - `configFile` (raw ini keys), `shortcuts`      -> `home-manager switch`
# In practice: log out and back in after editing this file. The readers matter as
# much as the writers — kwin, kglobalaccel and plasmashell all load their config
# once, at session start.
#
# That login script has one system dependency, and it is easy to miss. Every
# desktop script plasma-manager generates is applied by a single line in its
# modules/startup.nix:
#
#   qdbus org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript ...
#
# unqualified, because on NixOS `qdbus` is on PATH. Fedora names it `qdbus-qt6`
# (so Qt5's can coexist) and ships nothing called plain `qdbus`, so there the
# script dies with "command not found" — and quietly: it wraps the call in
# `trap 'success=0' ERR` and only writes its
# ~/.local/share/plasma-manager/last_run_* marker on success, so it fails and
# retries at every login, forever. Meanwhile `configFile` and `shortcuts` keep
# landing, which makes it look like this file is being applied while the panel and
# the wallpaper are still whatever KDE's defaults are.
#
# The OS image links /usr/bin/qdbus -> qdbus-qt6 for this (its
# files/scripts/qdbus-compat.sh). On any other distro, check `command -v qdbus`
# before concluding that something below is wrong, and run
# ~/.local/share/plasma-manager/run_all.sh by hand to watch it happen.

{
  programs.plasma = {
    enable = true;

    # deliberately NOT setting overrideConfig = true. That would reset every KDE
    # setting not named in this file to its default on each login, which means
    # anything tweaked in System Settings and not yet transcribed here silently
    # disappears. Opt in later, once this file covers enough.

    panels = [{
      location = "bottom";
      height = 48;

      # what "don't fill the whole screen" actually is: a custom length mode with
      # explicit bounds, centred, and detached from the screen edge. The two
      # lengths differ by 18px because they came from dragging the panel handles;
      # set them equal for a panel that never resizes itself.
      lengthMode = "custom";
      minLength = 1747;
      maxLength = 1765;
      alignment = "center";
      floating = true;
      hiding = "none";

      # order is significant — it is AppletOrder in the generated file
      widgets = [
        {
          kickoff = {
            icon = "start-here"; # the Fedora logo, not the default K

            # Nothing pinned in the application menu.
            #
            # Kickoff does not keep its favourites in an ini file — they are
            # KActivities resource links in kactivitymanagerd's sqlite db under
            # ~/.local/share, scoped to a client id that embeds the applet's
            # instance number ("org.kde.plasma.kickoff.favorites.instance-<id>",
            # from main.qml's Component.onCompleted). Which is why unpinning them
            # by hand does not stick *here*: this file rebuilds the panel at every
            # login, the fresh kickoff applet gets a new instance id and so an
            # empty favourites model, and the applet then seeds it from its own
            # config:
            #
            #   if (!configuration.favoritesPortedToKAstats) {
            #       if (favoritesModel.count < 1) {
            #           favoritesModel.portOldFavorites(configuration.favorites);
            #       }
            #       configuration.favoritesPortedToKAstats = true;
            #   }
            #
            # `favorites` defaults to preferred://browser, kontact, systemsettings,
            # dolphin and discover — exactly the list that keeps coming back. So
            # seed from an empty list, and set the ported flag so the seeding is
            # skipped outright. (There is no plasma-manager option for this;
            # `settings` is the module's raw-key escape hatch, and these land in
            # the applet's own Configuration/General group.)
            #
            # Trade-off: pinning from the menu still works, but only until the next
            # login. For something permanent use `iconTasks.launchers` below.
            settings.General = {
              favorites = "";
              favoritesPortedToKAstats = true;
            };
          };
        }
        {
          iconTasks.launchers = [ ]; # nothing pinned; task manager only
        }
        "org.kde.plasma.marginsseparator"
        {
          # note the `general` nesting — unlike kickoff and iconTasks, the pager
          # module puts its settings there. `desktopNumber` is what serialises to
          # the `displayedText=Number` currently in the applets file.
          pager.general = {
            displayedText = "desktopNumber";
            showOnlyCurrentScreen = true;
            showWindowOutlines = false;
          };
        }
        "org.kde.plasma.systemtray"
        {
          digitalClock.time.format = "24h";
          # pinned rather than left to the locale on purpose. The clock would
          # already read 24h from LC_TIME (set per-user in plasma-localerc below,
          # and system-wide by the OS image), but that couples the panel to the
          # locale — pick up a machine with a bare en_US and it silently reverts
          # to am/pm. This key makes the panel independent of that.
        }
        "org.kde.plasma.showdesktop"
      ];
    }];

    workspace = {
      # Bing's picture of the day. Note this applies to *every* screen: the
      # generated script loops `for (const desktop of desktops())` and sets the
      # plugin on each. A second monitor left on a static image (org.kde.image)
      # will start following Bing too — that is the only behavioural change here
      # on the machine this was transcribed from.
      #
      # Other providers accepted: apod, flickr, natgeo, noaa, wcpotd, epod,
      # simonstalenhag. Only one wallpaper option may be set at a time — the
      # module asserts that `wallpaper`, `wallpaperSlideShow`,
      # `wallpaperPictureOfTheDay`, `wallpaperPlainColor` and
      # `wallpaperCustomPlugin` are mutually exclusive.
      wallpaperPictureOfTheDay.provider = "bing";

      # scale and crop to fill the screen rather than letterbox it — this is the
      # FillMode=2 the desktop already had. Written into the potd config group,
      # so it survives the plugin switch.
      wallpaperFillMode = "preserveAspectCrop";
    };

    # Ctrl+Alt+T, moved to kitty. This is *not* covered by the TerminalApplication
    # key below: that shortcut is registered against konsole's desktop file itself
    # (`X-KDE-Shortcuts=Ctrl+Alt+T` in org.kde.konsole.desktop, mirrored into
    # /usr/share/kglobalaccel/), so kglobalaccel keeps launching konsole no matter
    # what the component chooser says. The binding has to be moved, not redirected:
    # the empty list writes `_launch=none`, which is how KDE records "unbound".
    #
    # The `/` in the group names becomes kglobalshortcutsrc's nested-group syntax,
    # i.e. [services][kitty.desktop] — plasma-manager writes these through
    # configFile."kglobalshortcutsrc", so don't also set that file by hand.
    shortcuts = {
      "services/org.kde.konsole.desktop"._launch = [ ];
      "services/kitty.desktop"._launch = "Ctrl+Alt+T";
    };

    configFile = {
      # Default terminal: kitty, which the OS image installs as an RPM so it sees
      # the system GL drivers. plasma-manager has no module for this, so these are
      # raw keys; they are declared in plasma-workspace's
      # kcms/componentchooser/terminal_settings.kcfg, in kdeglobals/[General], with
      # defaults `konsole` and `org.kde.konsole.desktop`.
      #
      # Both are needed, because callers read different ones:
      #   TerminalApplication — plasmashell and ktelnetservice6, as a command name
      #   TerminalService     — a .desktop storage id. KTerminalLauncherJob (so
      #                         Dolphin's "Open Terminal") prefers this one and
      #                         only synthesises a service from the command when
      #                         it is empty.
      #
      # KIO only knows how to pass a working directory to konsole (`--workdir`) and
      # xterm, but it also sets the launched process's own cwd, so kitty still
      # opens in the right folder with no flag of its own.
      "kdeglobals".General = {
        TerminalApplication = "kitty";
        TerminalService = "kitty.desktop";
      };

      # Region & Language -> Formats. Norwegian time and number conventions on an
      # otherwise English system: 24-hour clock, 16. sep. 2026, comma as the
      # decimal separator. The OS image sets the same LC_TIME in /etc/locale.conf
      # so the SDDM login screen agrees, but that only lands on a fresh install —
      # this covers every machine this config is applied to.
      "plasma-localerc".Formats = {
        LANG = "en_US.UTF-8";
        LC_TIME = "nb_NO.UTF-8";
        LC_NUMERIC = "nb_NO.UTF-8";
      };

      # Two virtual desktops in one row — what the Pager widget in the panel
      # above displays.
      #
      # Written as raw kwinrc keys instead of the obvious
      # `kwin.virtualDesktops = { number = 2; rows = 1; }`, because that module
      # also rewrites the desktops' identifiers to the literal strings
      # `Id_1=Desktop_1` / `Id_2=Desktop_2`. The custom KWin tile layouts in
      # ~/.config/kwinrc are keyed by the desktops' current UUIDs
      # (`[Tiling][24816e05-…]`), so renaming the ids would orphan them and the
      # 25/50/25 split would have to be drawn again by hand.
      #
      # Setting only these two keys is safe: without `overrideConfig` the writer
      # keeps every key it did not touch (`should_keep_key = is_persistent or not
      # self.reset` in plasma-manager's write_config.py), so the Id_ lines and the
      # whole [Tiling] section stay as they are.
      #
      # KWin only reads this at startup, so a count change needs a re-login too.
      "kwinrc".Desktops = {
        Number = 2;
        Rows = 1;
      };
    };
  };
}
