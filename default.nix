# Questo file permette a chi non usa i Flakes (come il NUR) di accedere al pacchetto.
{ pkgs ? import <nixpkgs> { } }:

{
  # Esponiamo il pacchetto opencode usando callPackage sul file esistente.
  opencode = pkgs.callPackage ./package.nix { };
}
