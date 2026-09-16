# nix-config

Standalone [Home Manager](https://nix-community.github.io/home-manager/) configuration — my user environment (shell, prompt, git, terminal config, CLI tools) as code.

This is **layer 2** of a four-layer setup. It deliberately does *not* manage the operating system; that lives in [jonaskirkemyr/bluebuild](https://github.com/jonaskirkemyr/bluebuild) (BlueBuild → Fedora Kinoite image).

| Layer | What | Managed by |
|---|---|---|
| 1. System | kernel, KDE, RPMs, Flatpaks, `/etc` | the `bluebuild` repo's `recipes/recipe.yml` |
| **2. User config** | **`.zshrc`, prompt, git config, `kitty.conf`, CLI tools** | **this repo** |
| 3. Per-project tools | "Node 18 here, Node 24 there" | a `flake.nix` + `.envrc` per project |
| 4. Data | `/home`, databases | a real backup tool |

## Prerequisites

Nix, installed with the Determinate Systems installer (it handles ostree/bootc and SELinux, which the upstream installer does not):

```bash
curl -fsSL https://install.determinate.systems/nix | sh -s -- install
```

Log out and back in so the profile script is sourced. Flakes are on by default.

## Usage

On a machine running my BlueBuild image, all of this is wrapped:

```bash
ujust setup-nix              # then log out and back in
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
| Inconsolata Nerd Font | image (`fonts` module) | fontconfig should see it system-wide, including for non-Nix apps |
| `git` + config | here | git itself is small; the config is the point |
| IntelliJ IDEA | image (Flatpak) | large GUI app, wants its own sandbox and GL |
| VS Code | image (`dnf`, Microsoft repo) | RPM rather than Flatpak so it can see the Nix store and a project's direnv environment |
| `lazygit`, `vim-full` | here | not in Fedora's repos (Fedora has `vim-enhanced`, not `vim-full`) |
| `direnv` | here | it is the entry point to layer 3, and Home Manager wires `nix-direnv` caching in for free |
| KDE panel, widgets, clock format | here (`home/plasma.nix`, via plasma-manager) | it is all `~/.config/plasma*` — per-user config, same category as `kitty.conf` |
| wallpaper, virtual desktop count | here (`home/plasma.nix`) | per-user too; the image has no user session to apply them to |
| a third-party KDE widget (plasmoid) | here, in `home.packages` | plasma-manager *configures* widgets, it does not install them; `programs.plasma.extraWidgets` was removed in favour of `home.packages` |
| SDDM login screen, system `LC_TIME` | image | needs root, so out of scope for a Home Manager module by design |

### KDE Plasma

`home/plasma.nix` owns the panel, the virtual desktop count and the wallpaper. Three things to know before editing it:

- **It is authoritative over panels.** The generated login script starts with `panels().forEach((panel) => panel.remove())` and deletes `~/.config/plasma-org.kde.plasma.desktop-appletsrc` before rebuilding them. Any panel you dragged into place by hand and did not write down here is gone after the next login. Desktop containments *survive* that deletion even though the same file holds them: the script runs with plasmashell already up (`X-KDE-autostart-condition=ksmserver`), so plasmashell re-serialises the desktops from memory. Wallpaper and desktop widgets only change if something in `plasma.nix` names them.
- **The wallpaper applies to every screen.** `workspace.wallpaperPictureOfTheDay` loops over all desktops, so a multi-monitor setup gets the same wallpaper on each — there is no per-screen option.
- **Most of it applies at login, not on switch.** `panels`, `workspace` and `desktop` are written into a script that plasmashell runs at the next login. Raw ini keys under `configFile` land during `home-manager switch`, but the apps that read them (KWin, for the desktop count) only do so at startup. So: log out and back in.

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

Not in this repo, by design. In each project:

```bash
# .envrc, next to flake.nix
use flake
```

```bash
direnv allow   # once; after that it activates on cd
```

`direnv` and `nix-direnv` are configured here, and the direnv hook is in the zsh config, so this works out of the box.
