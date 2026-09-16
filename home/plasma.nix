{ ... }:

# KDE Plasma desktop: panel geometry, widget order, the clock, virtual desktops
# and the wallpaper.
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
#   - `configFile` (raw ini keys)                   -> `home-manager switch`
# In practice: log out and back in after editing this file.

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
          kickoff.icon = "start-here"; # the Fedora logo, not the default K
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

    configFile = {
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
