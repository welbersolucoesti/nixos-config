choicesFile:
{ lib, ... }:

let
  names = [ "codex" "cron" "virtualization" ];
  choices = builtins.fromJSON (builtins.readFile choicesFile);
in
{
  config.personalConfig = if builtins.pathExists choicesFile then
    assert lib.assertMsg
      (builtins.isAttrs choices && builtins.attrNames choices == names
        && lib.all builtins.isBool (builtins.attrValues choices))
      "O arquivo optionals.json deve conter somente as três escolhas booleanas do Noir.";
    lib.genAttrs names (name: {
      # Após a primeira alteração pelo Noir, prevalece sobre definições legadas comuns.
      enable = lib.mkOverride 90 choices.${name};
    })
  else {
    codex.enable = lib.mkOverride 90 false;
  };
}
