# nix-config

Standalone [Home Manager](https://nix-community.github.io/home-manager/) configuration — my user environment (shell, prompt, git, terminal config, CLI tools) as code.

This is **layer 2** of a four-layer setup. It deliberately does *not* manage the operating system; that lives in [jonaskirkemyr/bluebuild](https://github.com/jonaskirkemyr/bluebuild) (BlueBuild → Fedora Kinoite image).

| Layer | What | Managed by |
|---|---|---|
| 1. System | kernel, KDE, RPMs, Flatpaks, `/etc`, Nix itself | the `bluebuild` repo's `recipes/recipe.yml` |
| **2. User config** | **`.zshrc`, prompt, git config, `kitty.conf`, CLI tools** | **this repo** |
| 3. Per-project tools | "Node 18 here, Node 24 there" | a `flake.nix` + `.envrc` per project — started from [`templates/`](templates) here |
| 4. Data | `/home`, databases | a real backup tool |

## Prerequisites

Nix, with flakes enabled.

**On my BlueBuild image, nothing to do** — Nix is part of layer 1, installed from Fedora's `nix` and `nix-daemon` RPMs, with flakes already on in `/etc/nix/nix.conf`. `ujust check-nix` confirms it. On an atomic host `/nix` has to be a separate writable mount, which is a system concern, so the image owns it; see that repo's `docs/SETUP.md`.

**On plain Fedora**, the same packages work:

```bash
sudo dnf install nix nix-daemon
sudo systemctl enable --now nix-daemon
sudo usermod -aG nixbld "$USER"     # then log out and back in
```

**Anywhere else**, use whatever installer that platform prefers — the [Determinate Systems installer](https://install.determinate.systems) is the usual answer — and enable flakes:

```bash
mkdir -p ~/.config/nix
echo 'experimental-features = nix-command flakes' >> ~/.config/nix/nix.conf
```

## Usage

On a machine running my BlueBuild image, all of this is wrapped:

```bash
ujust setup-home-manager     # clones this repo to ~/nix-config and switches
ujust update-home-manager    # pull + re-apply, day to day
```

Anywhere else, do it by hand. First time on a machine — bootstrap without having `home-manager` installed yet:

```bash
nix run home-manager/release-25.11 -- switch --flake ".#$USER"
```

Every time after that, `home-manager` is on your `PATH`:

```bash
home-manager switch --flake ".#$USER"
```

Useful extras:

```bash
home-manager switch --flake ".#$USER" -b bak # back up files it would overwrite
home-manager generations                     # list previous generations
nix flake update                             # bump nixpkgs + home-manager
```

### A machine with a different username

The login name is listed in exactly one place, the `users` list in [`flake.nix`](flake.nix):

```nix
users = [ "jonask" "someone-else" ];
```

`genAttrs` turns that into one `homeConfigurations.<name>` per entry, all sharing `home/home.nix`, which receives the name as its `username` argument. Every command above and every `ujust` recipe switches `--flake ".#$USER"`, so adding a name is the only edit — nothing downstream is tied to a particular user.

It has to be listed at all because `home.username` is a string option with no default (from `stateVersion` 20.09 onwards) and flake evaluation is pure, so nothing inside the flake can read `$USER`. `ujust setup-home-manager` checks the list before switching and tells you which names it knows about, instead of failing with a Nix trace.

## Git identity (one step per machine)

Nothing in this repo identifies me — no name, no email, no signing key — so it's reusable as-is. All of that lives in an untracked, machine-local `~/.config/git/identity`.

On my BlueBuild image, one command writes it:

```bash
ujust set-git-identity <username>
```

It fetches `https://github.com/<username>.gpg`, which is the *public* half of every GPG key you've uploaded, and reads three things straight out of it: the fingerprint for `user.signingkey`, and the name and email from the key's UID. If you've published more than one key it lists them and asks which. Nothing is imported into your keyring — it parses with `gpg --show-keys`.

It also checks whether the matching **private** key is actually in your keyring, and only turns on `commit.gpgsign` if it is. GitHub can't give you a private key, so on a fresh machine you still restore that from your own backup (`gpg --import …`) and re-run the recipe to flip signing on.

By hand, anywhere else:

```bash
mkdir -p ~/.config/git
cat > ~/.config/git/identity <<'EOF'
[user]
	name = Your Name
	email = you@example.com
	signingkey = 0123456789ABCDEF0123456789ABCDEF01234567
[commit]
	gpgsign = true
EOF
```

Home Manager appends the `include` at the end of `~/.config/git/config`, so this file overrides anything the config sets. Git ignores the include when the file doesn't exist, so the only symptom of forgetting it is git's usual *"please tell me who you are"* on your first commit.

The same mechanism gives you a per-context identity if you want one — add a second entry with a `condition`:

```nix
includes = [
  { path = "~/.config/git/identity"; }
  { path = "~/.config/git/identity-work"; condition = "gitdir:~/work/"; }
];
```

If `switch` refuses because a file already exists in `$HOME` (typically `~/.zshrc` from a previous non-Nix setup), either delete it or use `-b bak`.

## What lives here vs. in the image

The rule: **Nix owns configuration and non-graphical CLI tools; the image owns binaries that touch hardware or that Fedora already packages well.**

| Thing | Where | Why |
|---|---|---|
| `zsh` binary | image (`dnf`) | Home Manager's zsh module writes the config but installs no package; the login shell in `/etc/passwd` must be a system path |
| `.zshrc`, aliases, oh-my-zsh | here | changes often, no rebuild needed |
| `starship` | here | pure config + a small static binary; no reason to carry a COPR for it |
| `kitty` binary | image (`dnf`) | needs the system GL drivers — this is what nixGL used to work around |
| `kitty.conf` (theme, keybinds) | here | `programs.kitty.package = null` writes config only |
| which terminal KDE opens (`Ctrl+Alt+T`, Dolphin's "Open Terminal") | here (`home/plasma.nix`) | two keys in `kdeglobals` and one global shortcut — all per-user |
| Inconsolata Nerd Font | image (`fonts` module) | fontconfig should see it system-wide, including for non-Nix apps |
| `git` + config | here | git itself is small; the config is the point |
| IntelliJ IDEA | image (Flatpak) | large GUI app, wants its own sandbox and GL |
| VS Code | image (`dnf`, Microsoft repo) | RPM rather than Flatpak so it can see the Nix store and a project's direnv environment |
| `lazygit`, `vim-full` | here | not in Fedora's repos (Fedora has `vim-enhanced`, not `vim-full`) |
| `direnv` | here | it is the entry point to layer 3, and Home Manager wires `nix-direnv` caching in for free |
| dev-shell templates per language | here (`templates/`) | they change far more often than the image does, and `nix flake init -t` reads them straight out of this flake |
| KDE panel, widgets, clock format | here (`home/plasma.nix`, via plasma-manager) | it is all `~/.config/plasma*` — per-user config, same category as `kitty.conf` |
| wallpaper, virtual desktop count | here (`home/plasma.nix`) | per-user too; the image has no user session to apply them to |
| a third-party KDE widget (plasmoid) | here, in `home.packages` | plasma-manager *configures* widgets, it does not install them; `programs.plasma.extraWidgets` was removed in favour of `home.packages` |
| SDDM login screen, system `LC_TIME` | image | needs root, so out of scope for a Home Manager module by design |

### KDE Plasma

`home/plasma.nix` owns the panel, the virtual desktop count, the wallpaper and the default terminal. Four things to know before editing it:

- **It is authoritative over panels.** The generated login script starts with `panels().forEach((panel) => panel.remove())` and deletes `~/.config/plasma-org.kde.plasma.desktop-appletsrc` before rebuilding them. Any panel you dragged into place by hand and did not write down here is gone after the next login. Desktop containments *survive* that deletion even though the same file holds them: the script runs with plasmashell already up (`X-KDE-autostart-condition=ksmserver`), so plasmashell re-serialises the desktops from memory. Wallpaper and desktop widgets only change if something in `plasma.nix` names them.
- **The wallpaper applies to every screen.** `workspace.wallpaperPictureOfTheDay` loops over all desktops, so a multi-monitor setup gets the same wallpaper on each — there is no per-screen option.
- **Most of it applies at login, not on switch.** `panels`, `workspace` and `desktop` are written into a script that plasmashell runs at the next login. Raw ini keys under `configFile` land during `home-manager switch`, but the apps that read them (KWin, for the desktop count) only do so at startup. So: log out and back in.
- **The application menu's pinned apps are a special case.** Kickoff keeps them as KActivities resource links in kactivitymanagerd's sqlite database, not in an ini file, and scopes them to the applet's instance id — so unpinning by hand does not survive the next login, because the rebuilt panel's new applet re-seeds them from the applet's own `favorites` default. `plasma.nix` sets that default to empty instead, which means the pinned page stays empty and anything you pin from the menu lasts only until you log out. Use `iconTasks.launchers` for a permanent launcher.

To capture settings you have already tuned by hand instead of transcribing them:

```bash
nix run github:nix-community/plasma-manager   # rc2nix, dumps current Plasma config as Nix
```

Its output uses raw config keys rather than the high-level modules, so treat it as a starting point rather than a drop-in.

### Notes on the migration from the old config

Changes from the previous standalone config, and why:

- **`targets.genericLinux.enable = true`** replaces the hand-written `XDG_DATA_DIRS` and `PATH` `sessionVariables`. It does the same job correctly on a non-NixOS distro, and additionally adds `/usr/share/zsh/site-functions` to `fpath` so RPM-provided zsh completions keep working.
- **nixGL and `nixGLIntel` are gone**, along with `mesa` and the wrapped `xdg.desktopEntries.kitty`. Nothing built by Nix draws to the screen any more, so there is nothing to wrap.
- **`nixpkgs.config.allowUnfree` moved to `flake.nix`.** Setting it inside a home module is silently ignored when `pkgs` is passed to `homeManagerConfiguration` explicitly — which it is.
- **`git-lfs` moved from `home.packages` to `programs.git.lfs.enable = true`**, so it also gets the `filter.lfs` git config it needs.
- **`home.stateVersion` stays at `"24.05"`.** It records which defaults this config was written against, not which release is in use. Changing it can silently alter module behaviour.

## Layer 3: per-project environments

The environments themselves live in each project, as a `flake.nix` + `.envrc` — not here. The *starting points* are here, in [`templates/`](templates):

| Template | What the shell has |
|---|---|
| `csharp` | `dotnet-sdk_10`, plus `DOTNET_ROOT` (the SDK's own setup hook doesn't set it) |
| `java` | `jdk21`, `maven`, `gradle` |
| `kotlin` | `jdk21`, `kotlin`, `gradle` |
| `nodejs` | `nodejs_22`, `pnpm` |

They're exposed as flake `templates`, so plain Nix is enough to use them:

```bash
cd ~/git/some-project
nix flake init -t ~/nix-config#kotlin
direnv allow
```

On my BlueBuild image that's wrapped, and the wrapper also does the parts that are easy to forget — staging both files (Nix ignores untracked files in a git repo, which otherwise fails with a confusing "does not exist"), adding `.direnv/` to `.gitignore`, and `direnv allow`:

```bash
ujust create-flake kotlin      # no argument lists the templates
```

Three deliberate choices inside the templates:

- **One input, no `flake-utils`.** It would be a second input to read in every `nix flake update` diff, to save the four lines of `genAttrs` that replace it.
- **The url is a branch, not a revision.** The project's own `flake.lock` is what pins the toolchain, so two projects created the same day drift independently from then on. `nix flake update` in the project moves it forward.
- **No `JAVA_HOME`.** openjdk ships a setup hook that exports it (`$out/lib/openjdk`) whenever the shell hasn't already, so setting it in the template would just be a second place to keep in sync. Contrast `DOTNET_ROOT`, which dotnet's hook genuinely doesn't set.

They live in this repo rather than in the image because a template is the sort of thing you tweak the week after writing it: a change here is a `git pull`, a change in the image is a CI build, an `ujust update` and a reboot.

`direnv` and `nix-direnv` are configured here, and the direnv hook is in the zsh config, so this works out of the box.
