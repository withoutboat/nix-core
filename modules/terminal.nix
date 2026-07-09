{ pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
    ghostty
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
}
