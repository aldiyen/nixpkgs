{ config, lib, pkgs, ... }:

with lib;

let

  cfg = config.services.dovecot2;

  dovecotConf =
    ''
      base_dir = /var/run/dovecot2/

      protocols = ${optionalString cfg.enableImap "imap"} ${optionalString cfg.enablePop3 "pop3"} ${optionalString cfg.enableLmtp "lmtp"}
    ''
    + (if cfg.enableSsl then
    ''

      ssl_cert = <${cfg.sslServerCert}
      ssl_key = <${cfg.sslServerKey}
      ssl_ca = <${cfg.sslCACert}
      disable_plaintext_auth = yes
      ssl = required
    '' else ''

      ssl = no
      disable_plaintext_auth = no
    '')
    + (if cfg.useVirtualMailboxOwner then ''

      mail_uid = ${toString config.ids.uids.vmail}
      mail_gid = ${toString config.ids.gids.vmail}
      userdb {
        driver = static
      }
    '' else ''
      userdb {
        driver = passwd
      }
    '')
    + ''

      default_internal_user = ${cfg.user}

      mail_location = ${cfg.mailLocation}

      maildir_copy_with_hardlinks = yes

      auth_mechanisms = plain login
      service auth {
        user = root
        ${cfg.appendAuth}
      }
      passdb {
        driver = pam
        args = ${optionalString cfg.showPAMFailure "failure_show_msg=yes"} dovecot2
      }
    ''
    + optionalString cfg.enableLmtp ''

      service lmtp {
        user = root
        ${cfg.appendLmtp}
      }
    ''
    + ''

      pop3_uidl_format = %08Xv%08Xu
    '' + cfg.extraConfig;

  confFile = pkgs.writeText "dovecot.conf" dovecotConf;

#  confLink = pkgs.runCommand "ln -sf ${dovecotConf} ${pkgs.dovecot2}/etc/dovecot/dovecot.conf";

in

{

  ###### interface

  options = {

    services.dovecot2 = {

      enable = mkOption {
        default = false;
        description = "Whether to enable the Dovecot 2.x POP3/IMAP server.";
      };

      enablePop3 = mkOption {
        default = true;
        description = "Start the POP3 listener (when Dovecot is enabled).";
      };

      enableImap = mkOption {
        default = true;
        description = "Start the IMAP listener (when Dovecot is enabled).";
      };

      user = mkOption {
        default = "dovecot2";
        description = "Dovecot user name.";
      };

      group = mkOption {
        default = "dovecot2";
        description = "Dovecot group name.";
      };

      extraConfig = mkOption {
        default = "";
        example = "mail_debug = yes";
        description = "Additional entries to put verbatim into Dovecot's config file.";
      };

      mailLocation = mkOption {
        default = "maildir:/var/spool/mail/%u"; /* Same as inbox, as postfix */
        example = "maildir:~/mail:INBOX=/var/spool/mail/%u";
        description = ''
          Location that dovecot will use for mail folders. Dovecot mail_location option.
        '';
      };

      enableSsl = mkOption {
        default = false;
        description = "Whether to enable SSL. Make sure to define the SSL cert paths as well!";
      };

      sslServerCert = mkOption {
        default = "";
        description = "Server certificate";
      };

      sslCACert = mkOption {
        default = "";
        description = "CA certificate used by the server certificate.";
      };

      sslServerKey = mkOption {
        default = "";
        description = "Server key.";
      };

      showPAMFailure = mkOption {
        default = false;
        description = "Show the PAM failure message on authentication error (useful for OTPW).";
      };

      useVirtualMailboxOwner = mkOption {
        default = false;
        description = "If enabled, mailboxes will all be owned by a single virtual user";
      };

      appendAuth = mkOption {
        type = types.lines;
        default = "";
        description = ''
            Configuration lines to be appended inside of the service auth {} block
        '';
      };

      enableLmtp = mkOption {
        default = false;
        description = "Enables Dovecot's LMTP service";
      };

      appendLmtp = mkOption {
        type = types.lines;
        default = "";
        description = ''
            Configuration lines to be appended inside of the service lmtp {} block
        '';
      };
    };

  };


  ###### implementation

  config = mkIf config.services.dovecot2.enable {

    security.pam.services.dovecot2 = {};

    services.mail.createVirtualMailboxOwner = mkIf cfg.useVirtualMailboxOwner true;

    users.extraUsers = [
      { name = cfg.user;
        uid = config.ids.uids.dovecot2;
        description = "Dovecot user";
        group = cfg.group;
      }
      { name = "dovenull";
        uid = config.ids.uids.dovenull2;
        description = "Dovecot user for untrusted logins";
        group = cfg.group;
      }
    ];

    users.extraGroups = [
      { name = cfg.group;
        gid = config.ids.gids.dovecot2;
      }
    ];

    jobs.dovecot2 =
      { description = "Dovecot IMAP/POP3 server";

        startOn = "started networking";

        preStart =
          ''
            for directory in ${pkgs.dovecot}/lib/dovecot ${pkgs.dovecot-antispam} ${pkgs.dovecot_pigeonhole}/lib/dovecot; do
              find $directory -mindepth 1 -maxdepth 1 -type f | while read file; do
                ln -sf $file /var/lib/dovecot/modules/$(basename $file)
              done;
              find $directory -mindepth 2 -maxdepth 2 -type f | while read file; do
                dn=$(dirname $file)
                bn=$(basename $file)
                mkdir -p /var/lib/dovecot/modules/$dn
                ln -sf $file /var/lib/dovecot/modules/$dn/$bn
              done;
            done;
	    touch /var/lib/dovecot/modules/blah.txt
            ${pkgs.coreutils}/bin/mkdir -p /var/run/dovecot2 /var/run/dovecot2/login
            ${pkgs.coreutils}/bin/chown -R ${cfg.user}:${cfg.group} /var/run/dovecot2
          '';

        exec = "${pkgs.dovecot}/sbin/dovecot -F -c ${confFile}";
      };

    environment.systemPackages = [ pkgs.dovecot ];

    assertions = [{ assertion = cfg.enablePop3 || cfg.enableImap;
                    message = "dovecot needs at least one of the IMAP or POP3 listeners enabled";}];

  };

}
