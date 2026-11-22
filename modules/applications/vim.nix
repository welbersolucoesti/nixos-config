{ pkgs, ... }:

{
  programs.vim = {
    enable = true;
    package = pkgs.vim.override {
      vimrc = pkgs.vimUtils.vimrcFile {
        beforePlugins = ''
          runtime! defaults.vim
        '';
        packages.noir.start = [ pkgs.vimPlugins.nerdtree ];
        customRC = ''
          set expandtab tabstop=4 shiftwidth=4 softtabstop=4
          set wildmenu number incsearch scrolloff=5 splitright splitbelow

          if has('persistent_undo')
            let s:state = empty($XDG_STATE_HOME) ? expand('~/.local/state') : $XDG_STATE_HOME
            let s:undo = s:state . '/vim/undo'
            if isdirectory(s:undo) || mkdir(s:undo, 'p', 0700)
              let &undodir = s:undo . '//'
              set undofile
            endif
          endif
        '';
      };
    };
  };
}
