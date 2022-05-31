with (import <nixpkgs> {});
mkShell {
  name = "hotwired";

  buildInputs = [
      nodePackages.npm
      nodejs-16_x
  ];

  shellHook =
    ''
        export PATH=$PATH:./node_modules/.bin
    '';
}
