{ config, pkgs, lib, username, ... }:

{
  home.username = username;
  home.homeDirectory = "/home/${username}";
  # Do not bump this casually — it selects migration behaviour, not a version.
  home.stateVersion = "24.05";

  # Makes Home Manager behave properly on a non-NixOS distro. Replaces the
  # hand-written XDG_DATA_DIRS: it puts the Nix profile's share/ ahead of
  # /usr/share so Nix-installed .desktop files show up in the KDE launcher,
  # sources nix.sh, fixes XCURSOR_PATH, and adds /usr/share/zsh/site-functions
  # to fpath so the image's zsh completions still work.
  targets.genericLinux.enable = true;

  home.sessionVariables = {
    DIRENV_LOG_FORMAT = ""; # Empty string disables logs
  };

  programs.git = {
    enable = true;

    lfs.enable = true; # replaces git-lfs in home.packages

    # Nothing identifying is in this repo, so it's reusable as-is by anyone.
    # Name, email, signing key and whether to sign all live in an untracked
    # per-machine file. On my BlueBuild image, `ujust set-git-identity` writes
    # it from a GitHub username; otherwise see the README.
    #
    # Home Manager emits `includes` with mkAfter, so this lands at the end of
    # ~/.config/git/config and wins over anything set above. Git silently
    # ignores the include when the file is missing, so a machine without it just
    # gets git's usual "please tell me who you are" on the first commit.
    includes = [ { path = "~/.config/git/identity"; } ];

    # `settings` replaces `extraConfig` and `aliases`, both deprecated in 25.11
    # (they still work, but warn on every switch).
    settings = {
      init.defaultBranch = "main";
      pull.rebase = true;

      alias = {
        co = "checkout";
        cob = "checkout -b";
        undo = "reset HEAD~1 --mixed";
        br = "branch --format='%(HEAD) %(color:yellow)%(refname:short)%(color:reset) - %(contents:subject) %(color:green)(%(committerdate:relative))' --sort=-committerdate";
        lg = "!git log --pretty=format:\"%C(magenta)%h%Creset -%C(red)%d%Creset %s %C(dim green)(%cr) [%an]\" --abbrev-commit -30";
        adog = "!git log --all --decorate --oneline --graph";
      };
    };
  };

  home.file.".gnupg/gpg-agent.conf".text = "pinentry-program ${pkgs.pinentry-tty}/bin/pinentry";

  programs.kitty = {
    enable = true;
    # The kitty binary comes from the OS image (Fedora RPM) so it can use the
    # system GL drivers directly. Home Manager writes kitty.conf only.
    package = null;

    font.name = "Inconsolata Nerd Font Propo";
    font.size = 11;

    settings = {
      scrollback_lines = 10000;
      enable_audio_bell = false;

      background_opacity = 0.85;
      # background_blur=1;

      copy_on_select = "yes";

      #dracula https://github.com/dracula/kitty/blob/master/dracula.conf
      background = "#282a36";
      foreground = "#f8f8f2";
      cursor = "#f8f8f2";
      cursor_text_color = "background";
      selection_background = "#44475a";
      selection_foreground = "#ffffff";
      url_color = "#8be9fd";

      # black
      color0 = "#21222c";
      color8 = "#6272a4";
      # red
      color1 = "#ff5555";
      color9 = "#ff6e6e";
      # green
      color2 = "#50fa7b";
      color10 = "#69ff94";
      # yellow
      color3 = "#f1fa8c";
      color11 = "#ffffa5";
      # blue
      color4 = "#bd93f9";
      color12 = "#d6acff";
      # magenta
      color5 = "#ff79c6";
      color13 = "#ff92df";
      # cyan
      color6 = "#8be9fd";
      color14 = "#a4ffff";
      # white
      color7 = "#f8f8f2";
      color15 = "#ffffff";

      tab_bar_style = "powerline";
      tab_title_template = "{title.split('/')[-1]}";

      # Tab bar colors
      active_tab_foreground = "#282a36";
      active_tab_background = "#f8f8f2";
      inactive_tab_foreground = "#282a36";
      inactive_tab_background = "#6272a4";

      # Marks
      mark1_foreground = "#282a36";
      mark1_background = "#ff5555";

      # Splits/Windows
      active_border_color = "#f8f8f2";
      inactive_border_color = "#6272a4";
    };

    keybindings = {
      "ctrl+v" = "paste_from_clipboard";
      "ctrl+t" = "new_tab";
      "ctrl+w" = "close_tab";
      "ctrl+shift+left" = "previous_tab";
      "ctrl+shift+right" = "next_tab";

      "ctrl+1" = "goto_tab 1";
      "ctrl+2" = "goto_tab 2";
      "ctrl+3" = "goto_tab 3";
      "ctrl+4" = "goto_tab 4";

      "ctrl+alt+1" = "first_window";
      "ctrl+alt+2" = "second_window";
      "ctrl+alt+3" = "third_window";
      "ctrl+alt+4" = "fourth_window";

      "ctrl+alt+e" = "next_window";
      "ctrl+alt+q" = "previous_window";
      "ctrl+alt+w" = "close_window";
      "ctrl+alt+r" = "start_resizing_window";
      "ctrl+alt+enter" = "launch --cwd=current";
      "ctrl+alt+l" = "next_layout";
    };
  };

  programs.home-manager.enable = true;

  # Only things the OS image does NOT provide. Anything graphical, and anything
  # Fedora packages well, belongs in the image instead — see the README.
  home.packages = with pkgs; [
    vim-full
    gnupg
    pinentry-tty
    lazygit # not in Fedora's repos
  ];

  programs.direnv = {
    enable = true;
    nix-direnv.enable = true; # caches dev shells; makes `use flake` fast
    config = {
      log_format = "";
    };
  };

  xdg.enable = true;
  # The nixGL-wrapped kitty desktop entry is gone: the RPM ships its own.

  programs.zsh = {
    enable = true;
    # Note: Home Manager's zsh module writes the config but does NOT install
    # zsh. The binary comes from the image, which is also what /etc/passwd
    # points at (`sudo usermod -s /usr/bin/zsh $USER`).

    # Enable starship prompt
    autosuggestion.enable = true;
    enableCompletion = true;
    syntaxHighlighting.enable = true;

    oh-my-zsh = {
      enable = true;
      plugins = [ "npm" "nvm" "z" ];
      theme = "robbyrussell";
    };

    shellAliases = {
      ll = "ls -lah";
    };

    # No direnv hook here: programs.direnv.enableZshIntegration (on by default)
    # already emits `eval "$(direnv hook zsh)"`. Doing it twice hooks twice.
    initContent = ''
      # Set environment variables
      export EDITOR=vi
      export PATH="$HOME/.local/bin:$PATH"
      export GPG_TTY=$(tty)
    '';
  };

  # Starship prompt
  programs.starship = {
    enable = true;
    enableZshIntegration = true;

    settings = {
      add_newline = true;
      format = "$username$hostname$directory$git_branch$git_state$git_status$nodejs$cmd_duration$line_break$character";

      directory = {
        style = "bold blue";
        truncation_length = 3;
      };

      character = {
        success_symbol = "[❯](purple)";
        error_symbol = "[❯](red)";
        vimcmd_symbol = "[❮](green)";
      };

      nodejs = {
        symbol = "";
        format = "[ $symbol ($version) ]($style)";
      };
    };
  };
}
