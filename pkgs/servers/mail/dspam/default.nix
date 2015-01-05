{ stdenv, fetchurl, postgresql ? null, mysql ? null, sqlite ? null, zlib ? null }:

stdenv.mkDerivation rec {
  name = "dspam-3.10.2";
  src = fetchurl {
    url = "mirror://sourceforge/dspam/${name}.tar.gz";
    sha256 = "ae76569604021f35b741fb95198a1e611a8c64c3838661973a6cf360bba593a9";
  };

  # zlib is required to compile against mysql
  mysqlAvailable = mysql != null && zlib != null;

  # Listing hash_drv twice so it always builds the driver as a dynamic library instead
  # of statically compiling against it, to make configuration more consitent.
  storageDrivers = "hash_drv,hash_drv"
    + stdenv.lib.optionalString (postgresql != null) ",pgsql_drv"
    + stdenv.lib.optionalString (mysqlAvailable)     ",mysql_drv"
    + stdenv.lib.optionalString (sqlite != null)     ",sqlite3_drv";
    
  buildInputs = [ postgresql mysql sqlite zlib ];

  configureFlags = [
    "--enable-daemon"
    "--sysconfdir=/etc/"
    "--with-storage-driver=${storageDrivers}"
  ] ++ stdenv.lib.optional (postgresql != null) [
    "--with-pgsql-includes=${postgresql}/include/"
    "--with-pgsql-libraries=${postgresql}/lib/"
  ] ++ stdenv.lib.optional (mysqlAvailable) [
    "--with-mysql-includes=${mysql}/include/mysql/"
    "--with-mysql-libraries=${mysql}/lib/mysql/"
  ] ++ stdenv.lib.optional (sqlite != null) [
    "--with-sqlite-includes=${sqlite}/include/"
    "--with-sqlite-libraries=${sqlite}/lib/"
  ] ++ stdenv.lib.optional (postgresql != null || mysqlAvailable) [
    "--enable-virtual-users"
    "--enable-preferences-extension"
  ];
}
