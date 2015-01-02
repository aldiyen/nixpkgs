{ stdenv, fetchurl
}:

stdenv.mkDerivation rec {
  name = "dspam-3.10.2";
  src = fetchurl {
    url = "mirror://sourceforge/dspam/${name}.tar.gz";
    sha256 = "ae76569604021f35b741fb95198a1e611a8c64c3838661973a6cf360bba593a9";
  };

#  buildInputs = [ nasm ];
}
