# Tarayicida calisan Nix/NixOS demo kalibi (container2wasm ile WASM'a cevrilir).
{ pkgs ? import <nixpkgs> { } }:
let
  s = pkgs.pkgsStatic;
  busybox = s.busybox;
  bash = s.bashInteractive;
  nix = s.nix;
  hello = s.hello;
  figlet = s.figlet;

  demo = pkgs.writeTextDir "root/demo.nix" ''
    # Bu dosya cevrimdisi derlenebilir: nix-build demo.nix && cat result
    let
      sh = "${busybox}/bin/sh";
    in
    derivation {
      name = "merhaba-nix";
      system = "x86_64-linux";
      builder = sh;
      args = [ "-c" "echo 'Merhaba! Bu dosya Nix ile tarayicida derlendi.' > $out" ];
    }
  '';

  etc = pkgs.runCommand "etc" { } ''
    mkdir -p $out/etc/nix $out/root $out/tmp $out/bin $out/usr/bin
    cat > $out/etc/passwd <<P
    root:x:0:0:root:/root:${bash}/bin/bash
    nobody:x:65534:65534:nobody:/var/empty:/bin/sh
    P
    cat > $out/etc/group <<G
    root:x:0:
    nixbld:x:30000:
    nogroup:x:65534:
    G
    cat > $out/etc/nix/nix.conf <<N
    build-users-group =
    sandbox = false
    substituters =
    experimental-features = nix-command flakes
    N
    cat > $out/etc/os-release <<O
    NAME="Nix (tarayici demo)"
    ID=nix-browser-demo
    PRETTY_NAME="Nix ${nix.version} - tarayicida, container2wasm ile"
    O
    cat > $out/etc/motd <<M

    Bu, tarayicinizda calisan bir Linux. Icinde Nix paket yoneticisi var.
    Tam NixOS degil (systemd yok, internet yok) ama Nix'i deneyebilirsiniz:

      nix --version
      nix eval --expr '1 + 2'
      nix eval --expr 'builtins.map (x: x * x) [ 1 2 3 ]'
      nix-build demo.nix && cat result
      nix path-info --all
      hello
      figlet NixOS

    Not: Emulasyon yavas calisir, komutlarin cevap vermesi saniyeler surebilir.

    M
    cat > $out/root/.bashrc <<B
    export PATH=/bin:/usr/bin:${nix}/bin:${busybox}/bin
    export PS1='[\u@nix-tarayici:\w]\$ '
    export NIX_PATH=
    cat /etc/motd
    B
    cp $out/root/.bashrc $out/root/.bash_profile
    ln -s ${bash}/bin/bash $out/bin/bash
    ln -s ${busybox}/bin/sh $out/bin/sh
    ln -s ${busybox}/bin/env $out/usr/bin/env
  '';
in
pkgs.dockerTools.buildLayeredImage {
  name = "nix-browser";
  tag = "latest";
  contents = [ busybox bash nix hello figlet etc demo ];
  includeNixDB = true;
  extraCommands = "mkdir -p tmp var/empty && chmod 1777 tmp";
  config = {
    Cmd = [ "${bash}/bin/bash" "--login" ];
    WorkingDir = "/root";
    Env = [
      "HOME=/root"
      "USER=root"
      "TERM=xterm-256color"
      "PATH=/bin:/usr/bin:${nix}/bin:${busybox}/bin"
    ];
  };
}
