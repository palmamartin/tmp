with (import <nixpkgs> {});
mkShell {
  name = "hotwired";

  buildInputs = [
      nodePackages.npm
      nodejs-16_x
  ];

  shellHook =
    ''
        export $PATH:./node_modules/.bin
    '';
}
