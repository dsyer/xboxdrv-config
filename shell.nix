with import <nixpkgs> { };

mkShell {

  name = "env";
  buildInputs = [
    xboxdrv evtest jstest-gtk
  ];

  shellHook = ''
    echo ":xboxdrv:"
  '';

}