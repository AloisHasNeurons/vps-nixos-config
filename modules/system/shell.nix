{pkgs, ...}: {
  # Interactive shell for alois, mirroring the laptop's ~/.zshrc.
  # root and deploy keep bash: CI runs its commands over SSH as deploy.
  users.users.alois.shell = pkgs.zsh;

  programs.zsh = {
    enable = true;

    # NixOS-native versions of the zsh-autosuggestions and
    # zsh-syntax-highlighting oh-my-zsh plugins
    autosuggestions.enable = true;
    syntaxHighlighting.enable = true;

    ohMyZsh = {
      enable = true;
      theme = "gnzh";
      plugins = ["git" "sudo" "z" "you-should-use"];
      customPkgs = [pkgs.zsh-you-should-use];
      # Must be set before oh-my-zsh.sh is sourced
      preLoaded = ''
        HIST_STAMPS="dd.mm.yyyy"
      '';
    };

    shellAliases = {
      c = "clear";
      myip = "curl http://ipecho.net/plain; echo";
      img = "kitten icat";
    };

    # kitty shell integration (prompt marks, jump between commands, open new
    # windows in the current directory) over plain `ssh`. `kitten ssh` already
    # sets it up itself and exports KITTY_SHELL_INTEGRATION, so skip it then.
    interactiveShellInit = ''
      if [[ "$TERM" == xterm-kitty && -z "$KITTY_SHELL_INTEGRATION" ]]; then
        export KITTY_SHELL_INTEGRATION="enabled"
        autoload -Uz -- ${pkgs.kitty.shell_integration}/zsh/kitty-integration
        kitty-integration
        unfunction kitty-integration
      fi
    '';
  };

  # Replaces `source <(fzf --zsh)` (Ctrl-R history search, Ctrl-T file picker)
  programs.fzf = {
    keybindings = true;
    fuzzyCompletion = true;
  };

  # Everything lives in /etc/zshrc. An empty ~/.zshrc stops zsh from showing its
  # new-user wizard on first login ("f" only creates it if it doesn't exist).
  systemd.tmpfiles.rules = ["f /home/alois/.zshrc 0644 alois users -"];

  environment.systemPackages = [
    pkgs.micro
    # TERM=xterm-kitty: without its terminfo, clear/backspace/full-screen apps break
    pkgs.kitty.terminfo
    # `kitten` alone (no GUI): icat, clipboard, transfer over SSH
    pkgs.kitty.kitten
  ];
  environment.variables.EDITOR = "micro";
}
