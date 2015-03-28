{ stdenv, pkgs, fetchhg, dovecot, autoconf, automake, openssl }:

stdenv.mkDerivation rec {
  name = "dovecot-plugin-antispam";
   
  src = fetchhg {
    url = "http://hg.dovecot.org/dovecot-antispam-plugin";
    rev = "5ebc6aae4d7c";
    sha256 = "181i79c9sf3a80mgmycfq1f77z7fpn3j2s0qiddrj16h3yklf4gv";
  };

  buildInputs = [
    autoconf
    automake
    dovecot
    openssl
  ];

  # this needs to change the dovecot-config from the actual dovecot build, replacing dovecot_moduledir with ./ or similar
  preConfigure = ''
    ./autogen.sh
    sed ${pkgs.dovecot}/lib/dovecot/dovecot-config -e 's,dovecot_moduledir=${pkgs.dovecot}/lib/dovecot,dovecot_moduledir=$out,' > ./dovecot-config
  '';

  configureFlags = [
    "--with-dovecot=./"
  ];
}
