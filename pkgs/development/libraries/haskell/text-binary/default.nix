# This file was auto-generated by cabal2nix. Please do NOT edit manually!

{ cabal, binary, text }:

cabal.mkDerivation (self: {
  pname = "text-binary";
  version = "0.1.0";
  sha256 = "0wc501j8hqspnhf4d1hyb18f1wgc4kl2qx1b5s4bkxv0dfbwrk6z";
  buildDepends = [ binary text ];
  meta = {
    homepage = "https://github.com/kawu/text-binary";
    description = "Binary instances for text types";
    license = self.stdenv.lib.licenses.bsd3;
    platforms = self.ghc.meta.platforms;
  };
})