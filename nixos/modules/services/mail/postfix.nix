{ config, lib, pkgs, ... }:

with lib;

let

  cfg = config.services.postfix;
  user = cfg.user;
  group = cfg.group;
  setgidGroup = cfg.setgidGroup;

  mainCf =
    ''
      queue_directory = /var/postfix/queue
      command_directory = ${pkgs.postfix}/sbin
      daemon_directory = ${pkgs.postfix}/libexec/postfix

      mail_owner = ${user}
      default_privs = nobody

    ''
    + optionalString config.networking.enableIPv6 ''
      inet_protocols = all
    ''
    + (if cfg.networks != null then
        ''
          mynetworks = ${concatStringsSep ", " cfg.networks}
        ''
      else if cfg.networksStyle != "" then
        ''
          mynetworks_style = ${cfg.networksStyle}
        ''
      else
        # Postfix default is subnet, but let's play safe
        ''
          mynetworks_style = host
        '')
    + optionalString (cfg.hostname != "") ''
      myhostname = ${cfg.hostname}
    ''
    + optionalString (cfg.domain != "") ''
      mydomain = ${cfg.domain}
    ''
    + optionalString (cfg.origin != "") ''
      myorigin = ${cfg.origin}
    ''
    + optionalString (cfg.destination != null) ''
      mydestination = ${concatStringsSep ", " cfg.destination}
    ''
    + optionalString (cfg.relayDomains != null) ''
      relay_domains = ${concatStringsSep ", " cfg.relayDomains}
    ''
    + optionalString (cfg.localRecipientMaps != null) ''
      local_recipient_maps = ${concatStringsSep " " cfg.localRecipientMaps}
    ''
    + optionalString (cfg.virtual != "") ''
      virtual_alias_maps = hash:/etc/postfix/virtual
    ''
    + ''
      relayhost = ${if cfg.lookupMX || cfg.relayHost == "" then
          cfg.relayHost
        else
          "[" + cfg.relayHost + "]"}

      alias_maps = hash:/var/postfix/conf/aliases

      mail_spool_directory = /var/spool/mail/

      setgid_group = ${setgidGroup}
    ''
    + optionalString (cfg.recipientDelimiter != null) ''
      recipient_delimiter = ${cfg.recipientDelimiter}
    ''
    + optionalString (cfg.smtpdRelayRestrictions != null) ''
      smtpd_relay_restrictions = ${concatStringsSep ", " cfg.smtpdRelayRestrictions}
    ''
    + optionalString cfg.enableSsl ''

      smtp_tls_CAfile = ${cfg.sslCACert}
      smtp_tls_cert_file = ${cfg.sslCert}
      smtp_tls_key_file = ${cfg.sslKey}

      smtp_use_tls = yes

      smtpd_tls_CAfile = ${cfg.sslCACert}
      smtpd_tls_cert_file = ${cfg.sslCert}
      smtpd_tls_key_file = ${cfg.sslKey}

      smtpd_use_tls = yes
    ''
    + optionalString(cfg.useDovecotSaslAuth) ''
      smtpd_sasl_type = dovecot
      smtpd_sasl_path = /var/postfix/private/auth
      smtpd_sasl_auth_enable = yes
    ''
    + cfg.extraConfig;

  masterCf = ''
    # ==========================================================================
    # service type  private unpriv  chroot  wakeup  maxproc command + args
    #               (yes)   (yes)   (yes)   (never) (100)
    # ==========================================================================
    smtp      inet  n       -       n       -       -       smtpd
  '' + optionalString(cfg.useDovecotSaslAuth) ''
    submission inet n       -       n       -       -       smtpd
      -o smtpd_sasl_auth_enable=yes
      -o smtpd_sasl_security_options=noanonymous
      -o smtpd_sasl_local_domain=$mydomain
      -o smtpd_sender_login_maps=$local_recipient_maps
      -o smtpd_client_restrictions=permit_sasl_authenticated,reject_non_fqdn_recipient,reject
      -o smtpd_sender_restrictions=reject_sender_login_mismatch
      ${optionalString cfg.enableSsl "-o smtpd_tls_security_level=encrypt"}
  ''
  + ''
    pickup    fifo  n       -       n       60      1       pickup
    cleanup   unix  n       -       n       -       0       cleanup
    qmgr      fifo  n       -       n       300     1       qmgr
    tlsmgr    unix  -       -       n       1000?   1       tlsmgr
    rewrite   unix  -       -       n       -       -       trivial-rewrite
    bounce    unix  -       -       n       -       0       bounce
    defer     unix  -       -       n       -       0       bounce
    trace     unix  -       -       n       -       0       bounce
    verify    unix  -       -       n       -       1       verify
    flush     unix  n       -       n       1000?   0       flush
    proxymap  unix  -       -       n       -       -       proxymap
    proxywrite unix -       -       n       -       1       proxymap
    smtp      unix  -       -       n       -       -       smtp
    relay     unix  -       -       n       -       -       smtp
            -o smtp_fallback_relay=
    #       -o smtp_helo_timeout=5 -o smtp_connect_timeout=5
    showq     unix  n       -       n       -       -       showq
    error     unix  -       -       n       -       -       error
    retry     unix  -       -       n       -       -       error
    discard   unix  -       -       n       -       -       discard
    local     unix  -       n       n       -       -       local
    virtual   unix  -       n       n       -       -       virtual
    lmtp      unix  -       -       n       -       -       lmtp
    anvil     unix  -       -       n       -       1       anvil
    scache    unix  -       -       n       -       1       scache
    ${cfg.extraMasterConf}
  '';

  aliases =
    optionalString (cfg.postmasterAlias != "") ''
      postmaster: ${cfg.postmasterAlias}
    ''
    + optionalString (cfg.rootAlias != "") ''
      root: ${cfg.rootAlias}
    ''
    + cfg.extraAliases
  ;

  aliasesFile = pkgs.writeText "postfix-aliases" aliases;
  virtualFile = pkgs.writeText "postfix-virtual" cfg.virtual;
  mainCfFile = pkgs.writeText "postfix-main.cf" mainCf;
  masterCfFile = pkgs.writeText "postfix-master.cf" masterCf;

in

{

  ###### interface

  options = {

    services.postfix = {

      enable = mkOption {
        default = false;
        description = "Whether to run the Postfix mail server.";
      };

      setSendmail = mkOption {
        default = true;
        description = "Whether to set the system sendmail to postfix's.";
      };

      user = mkOption {
        default = "postfix";
        description = "What to call the Postfix user (must be used only for postfix).";
      };

      group = mkOption {
        default = "postfix";
        description = "What to call the Postfix group (must be used only for postfix).";
      };

      setgidGroup = mkOption {
        default = "postdrop";
        description = "
          How to call postfix setgid group (for postdrop). Should
          be uniquely used group.
        ";
      };

      networks = mkOption {
        default = null;
        example = ["192.168.0.1/24"];
        description = "
          Net masks for trusted - allowed to relay mail to third parties -
          hosts. Leave empty to use mynetworks_style configuration or use
          default (localhost-only).
        ";
      };

      networksStyle = mkOption {
        default = "";
        description = "
          Name of standard way of trusted network specification to use,
          leave blank if you specify it explicitly or if you want to use
          default (localhost-only).
        ";
      };

      hostname = mkOption {
        default = "";
        description ="
          Hostname to use. Leave blank to use just the hostname of machine.
          It should be FQDN.
        ";
      };

      domain = mkOption {
        default = "";
        description ="
          Domain to use. Leave blank to use hostname minus first component.
        ";
      };

      origin = mkOption {
        default = "";
        description ="
          Origin to use in outgoing e-mail. Leave blank to use hostname.
        ";
      };

      destination = mkOption {
        default = null;
        example = ["localhost"];
        description = "
          Full (!) list of domains we deliver locally. Leave blank for
          acceptable Postfix default.
        ";
      };

      relayDomains = mkOption {
        default = null;
        example = ["localdomain"];
        description = "
          List of domains we agree to relay to. Default is the same as
          destination.
        ";
      };

      localRecipientMaps = mkOption {
        default = null;
        description = "
          List of lookup table files containing local recipients.
          Sets Postifix's local_recipient_maps value
        ";
      };

      relayHost = mkOption {
        default = "";
        description = "
          Mail relay for outbound mail.
        ";
      };

      lookupMX = mkOption {
        default = false;
        description = "
          Whether relay specified is just domain whose MX must be used.
        ";
      };

      postmasterAlias = mkOption {
        default = "root";
        description = "Who should receive postmaster e-mail.";
      };

      rootAlias = mkOption {
        default = "";
        description = "
          Who should receive root e-mail. Blank for no redirection.
        ";
      };

      extraAliases = mkOption {
        default = "";
        description = "
          Additional entries to put verbatim into aliases file.
        ";
      };

      extraConfig = mkOption {
        default = "";
        description = "
          Extra lines to be added verbatim to the main.cf configuration file.
        ";
      };

      enableSsl = mkOption {
        default = false;
        description = "Whether to enable SSL. Make sure to define the SSL cert paths as well!";
      };

      sslCert = mkOption {
        default = "";
        description = "SSL certificate to use.";
      };

      sslCACert = mkOption {
        default = "";
        description = "SSL certificate of CA.";
      };

      sslKey = mkOption {
        default = "";
        description = "SSL key to use.";
      };

      recipientDelimiter = mkOption {
        default = null;
        example = "+";
        description = "
          Delimiter for address extension: so mail to user+test can be handled by ~user/.forward+test
        ";
      };

      virtual = mkOption {
        default = "";
        description = "
          Entries for the virtual alias map.
        ";
      };

      extraMasterConf = mkOption {
        default = "";
        example = "submission inet n - n - - smtpd";
        description = "Extra lines to append to the generated master.cf file.";
      };

      useDovecotSaslAuth = mkOption {
        default = false;
        description = ''
	  Whether to use Dovecot for SASL SMTP auth.
	  Note: This enables dovecot2 and makes Postfix listen on SMTP submission
	  port 587 for SASL-authenticated email submissions
	'';
      };

      smtpdRelayRestrictions = mkOption {
        default = null;
        description = "List of SMTP relay restrictions (Postfix's smtpd_relay_restrictions setting) settings";
      };
   };
};


  ###### implementation

  config = mkIf config.services.postfix.enable {

    environment = {
      etc = singleton
        { source = "/var/postfix/conf";
          target = "postfix";
        };

      # This makes comfortable for root to run 'postqueue' for example.
      systemPackages = [ pkgs.postfix ];
    };

    services.mail.sendmailSetuidWrapper = mkIf config.services.postfix.setSendmail {
      program = "sendmail";
      source = "${pkgs.postfix}/bin/sendmail";
      owner = "nobody";
      group = "postdrop";
      setuid = false;
      setgid = true;
    };

    users.extraUsers = singleton
      { name = user;
        description = "Postfix mail server user";
        uid = config.ids.uids.postfix;
        group = group;
      };

    users.extraGroups =
      [ { name = group;
          gid = config.ids.gids.postfix;
        }
        { name = setgidGroup;
          gid = config.ids.gids.postdrop;
        }
      ];

    services.dovecot2 = mkIf config.services.postfix.useDovecotSaslAuth {
      enable = true;
      appendAuth = ''
        unix_listener /var/postfix/private/auth {
          mode = 0660
          user = ${user}
          group = ${group}
        }
      '';
    };

    jobs.postfix =
      # I copy _lots_ of shipped configuration filed
      # that can be left as is. I am afraid the exact
      # will list slightly change in next Postfix
      # release, so listing them all one-by-one in an
      # accurate way is unlikely to be better.
      { description = "Postfix mail server";

        wantedBy = [ "multi-user.target" ];
        after = [ "network.target" ];

        daemonType = "fork";

        preStart =
          ''
            ${pkgs.coreutils}/bin/mkdir -p /var/spool/mail /var/postfix/conf /var/postfix/queue
          '' + optionalString config.services.postfix.useDovecotSaslAuth ''
            ${pkgs.coreutils}/bin/mkdir -p /var/postfix/private
          ''
          + ''

            ${pkgs.coreutils}/bin/chown -R ${user}:${group} /var/postfix
            ${pkgs.coreutils}/bin/chown -R ${user}:${setgidGroup} /var/postfix/queue
            ${pkgs.coreutils}/bin/chmod -R ug+rwX /var/postfix/queue
            ${pkgs.coreutils}/bin/chown root:root /var/spool/mail
            ${pkgs.coreutils}/bin/chmod a+rwxt /var/spool/mail

            ln -sf "${pkgs.postfix}/share/postfix/conf/"* /var/postfix/conf

            ln -sf ${aliasesFile} /var/postfix/conf/aliases
            ln -sf ${virtualFile} /var/postfix/conf/virtual
            ln -sf ${mainCfFile} /var/postfix/conf/main.cf
            ln -sf ${masterCfFile} /var/postfix/conf/master.cf

            ${pkgs.postfix}/sbin/postalias -c /var/postfix/conf /var/postfix/conf/aliases
            ${pkgs.postfix}/sbin/postmap -c /var/postfix/conf /var/postfix/conf/virtual

            ${pkgs.postfix}/sbin/postfix -c /var/postfix/conf start
          '';

        preStop = ''
            ${pkgs.postfix}/sbin/postfix -c /var/postfix/conf stop
        '';

      };

  };

}
