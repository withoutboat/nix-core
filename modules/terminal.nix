{ pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
    zellij
    zsh
    starship
    
    fzf            
    bat            
    ripgrep        
    shell-gpt
  ];

  programs.zsh = {
    enable = true;
    autosuggestions.enable = true;
    syntaxHighlighting.enable = true;
  };

  home-manager.sharedModules = [
    {
      programs.ghostty = {
        enable = true;
        enableZshIntegration = true;
      };
    }
  ];
}
