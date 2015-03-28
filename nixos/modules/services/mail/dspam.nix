{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.dspam;

  configFile = ''
    StorageDriver ${pkgs.dspam}/lib/dspam/lib${cfg.storageDriver}_drv.so

    Home /var/spool/dspam
  ''
  + (if cfg.useDovecotLmtp then ''
    DeliveryHost        ${cfg.deliveryHost}
    # config assumes server and client(s) are always local at present
    # DeliveryPort      ...
    DeliveryIdent       ${cfg.deliveryIdent}
    DeliveryProto       LMTP
  '' else ''
    TrustedDeliveryAgent "${cfg.trustedDeliveryAgent}"
  '')
  + ''
#    EnablePlusedDetail  on
#    PlusedCharacter +
#    PlusedUserLowercase on
    OnFail error
    Trust root
    Trust dspam
    TrainingMode teft
    TestConditionalTraining on
    Feature noise
    Feature whitelist
    Algorithm graham burton
    Tokenizer osb
    PValue bcr
    WebStats off
    Preference "trainingMode=TEFT"      # { TOE | TUM | TEFT | NOTRAIN } -> default:teft
    Preference "spamAction=deliver"     # { quarantine | tag | deliver } -> default:quarantine
    Preference "spamSubject=[SPAM]"     # { string } -> default:[SPAM]
    Preference "statisticalSedation=5"  # { 0 - 10 } -> default:0
    Preference "enableBNR=on"       # { on | off } -> default:off
    Preference "enableWhitelist=on"     # { on | off } -> default:on
    Preference "signatureLocation=headers"  # { message | headers } -> default:message
    Preference "tagSpam=off"        # { on | off }
    Preference "tagNonspam=off"     # { on | off }
    Preference "showFactors=off"        # { on | off } -> default:off
    Preference "optIn=off"          # { on | off }
    Preference "optOut=off"         # { on | off }
    Preference "whitelistThreshold=10"  # { Integer } -> default:10
    Preference "makeCorpus=off"     # { on | off } -> default:off
    Preference "storeFragments=off"     # { on | off } -> default:off
    Preference "localStore="        # { on | off } -> default:username
    Preference "processorBias=on"       # { on | off } -> default:on
    Preference "fallbackDomain=off"     # { on | off } -> default:off
    Preference "trainPristine=off"      # { on | off } -> default:off
    Preference "optOutClamAV=off"       # { on | off } -> default:off
    Preference "ignoreRBLLookups=off"   # { on | off } -> default:off
    Preference "RBLInoculate=off"       # { on | off } -> default:off
    Preference "notifications=off"      # { on | off } -> default:off
    AllowOverride enableBNR
    AllowOverride enableWhitelist
    AllowOverride fallbackDomain
    AllowOverride ignoreGroups
    AllowOverride ignoreRBLLookups
    AllowOverride localStore
    AllowOverride makeCorpus
    AllowOverride optIn
    AllowOverride optOut
    AllowOverride optOutClamAV
    AllowOverride processorBias
    AllowOverride RBLInoculate
    AllowOverride showFactors
    AllowOverride signatureLocation
    AllowOverride spamAction
    AllowOverride spamSubject
    AllowOverride statisticalSedation
    AllowOverride storeFragments
    AllowOverride tagNonspam
    AllowOverride tagSpam
    AllowOverride trainPristine
    AllowOverride trainingMode
    AllowOverride whitelistThreshold
    AllowOverride dailyQuarantineSummary
    AllowOverride notifications
    IgnoreHeader Accept-Language
    IgnoreHeader Authentication-Results
    IgnoreHeader Content-Type
    IgnoreHeader DKIM-Signature
    IgnoreHeader Date
    IgnoreHeader DomainKey-Signature
    IgnoreHeader Importance
    IgnoreHeader In-Reply-To
    IgnoreHeader List-Archive
    IgnoreHeader List-Help
    IgnoreHeader List-Id
    IgnoreHeader List-Post
    IgnoreHeader List-Subscribe
    IgnoreHeader List-Unsubscribe
    IgnoreHeader Message-ID
    IgnoreHeader Message-Id
    IgnoreHeader Organization
    IgnoreHeader Received
    IgnoreHeader References
    IgnoreHeader Reply-To
    IgnoreHeader Resent-Date
    IgnoreHeader Resent-From
    IgnoreHeader Thread-Index
    IgnoreHeader Thread-Topic
    IgnoreHeader User-Agent
    IgnoreHeader X-policyd-weight
    IgnoreHeader thread-index
    Notifications   off
    PurgeSignatures 14  # Stale signatures
    PurgeNeutral    90  # Tokens with neutralish probabilities
    PurgeUnused     90  # Unused tokens
    PurgeHapaxes    30  # Tokens with less than 5 hits (hapaxes)
    PurgeHits1S     15  # Tokens with only 1 spam hit
    PurgeHits1I     15  # Tokens with only 1 innocent hit
    LocalMX 127.0.0.1
    SystemLog   on
    UserLog     on
    Opt out
    TrackSources spam
    ParseToHeader on
    ChangeModeOnParse on
    ChangeUserOnParse on
    Broken case
    MaxMessageSize 5000000 # 5 MB
#    ClamAVPort      3310
#    ClamAVHost      127.0.0.1
#    ClamAVResponse      accept
  ''
  + optionalString cfg.enableDaemon ''
    ServerPID       /var/run/dspam/dspam.pid
    ServerQueueSize 32
    ServerMode      auto
    # config assumes server and client(s) are always local at present
    # ServerHost ...
    # ServerPort ...
    ServerPass.Relay1 "${cfg.relayPass}"
    ServerParameters "${cfg.serverParameters}"
    ServerIdent     "${cfg.serverIdent}"
    ServerDomainSocketPath "${cfg.serverSocketPath}"
    ClientHost      ${cfg.serverSocketPath}
    ClientIdent     "${cfg.relayPass}@Relay1"
  ''
  + ''
    ProcessorURLContext on
    ProcessorBias on
    StripRcptDomain off

    ${cfg.appendConfig}
    ${cfg.extraConfig}
  '';
in

{
  options = {
    services.dspam = {
      enable = mkOption {
        default = false;
        description = "
          Enable the DSPAM spam filter
        ";
      };

      enableDaemon = mkOption {
        default = true;
        description = "
          Run the DSPAM daemon
        ";
      };

      user = mkOption {
        default = "dspam";
        description = "User account under which DSPAM runs.";
      };

      group = mkOption {
        default = "dspam";
        description = "Group account under which DSPAM runs.";
      };

      storageDriver = mkOption {
        default = "hash";
        description = ''
	  DSPAM storage driver to use. Options are: hash, mysql, pgsql, sqlite3
	  While the default is "hash", the SQL options will use less disk space
	'';
      };

      useDovecotLmtp = mkOption {
        default = false;
	description = ''
	  Whether to deliver messages to Dovecot via LMTP
	'';
      };

      deliveryHost = mkOption {
        default = "/var/dspam/private/lmtp";
	description = "Path to the delivery host (or unix socket) to be used by DSPAM delivery via LMTP";
      };

      deliveryIdent = mkOption {
        default = "localhost";
	description = "Ident to be sent when connecting to the LMTP host";
      };

      trustedDeliveryAgent = mkOption {
        default = "";
	description = "Delivery agent DSPAM will use when delivering mail (if not using LMTP)";
      };

      relayPass = mkOption {
        default = "relayPassword";
	description = "Ident value used by DSPAM client to allow DSPAM server to identify it";
      };

      serverParameters = mkOption {
        default = "--user dspam --deliver=innocent,spam -d %u";
	description = "DSPAM ServerParameters setting, for use with daemon mode";
      };

      serverIdent = mkOption {
        default = "localhost";
	description = "Ident value for incoming LMTP connections";
      };

      serverSocketPath = mkOption {
        default = "/var/dspam/dspam.sock";
	description = "Unix file socket path that DSPAM daemon will listen on";
      };

      appendConfig = mkOption {
        type = types.lines;
        default = "";
        description = ''
          Configuration lines appended to the generated DSPAM config file
        '';
      };

      extraConfig = mkOption {
        default = "";
        description = "Extra config to append at the end of dspam.conf";
      };
    };
  };

  config = mkIf cfg.enable {
  
    services.dovecot2 = mkIf cfg.useDovecotLmtp {
      enable     = true;
      enableLmtp = true;
      appendLmtp = ''
        unix_listener ${cfg.deliveryHost} {
          mode = 0660
          user = dspam
          group = dspam
        }
      '';
    };

    users.extraUsers = singleton
      { name = "dspam";
        group = "dspam";
        uid = config.ids.uids.dspam;
      };

    users.extraGroups = singleton
      { name = "dspam";
        gid = config.ids.gids.dspam;
      };

    environment.etc = singleton {
      source = pkgs.writeText "dspam.conf" configFile;
      target = "dspam.conf";
    };

# FIXME this isn't working and I don't know why!
#    systemd.services.dspam = { 
#      description = "DSPAM email spam filter";
#      after = [ "network.target" ];
#      wantedBy = [ "multi-user.target" ];
#
#      # FIXME somehow I need to make the dovecot LMTP socket directory before dovecot starts
#
#      preStart = ''
#        ${pkgs.coreutils}/bin/mkdir -p /var/run/dspam/ /var/dspam/
#        chown -R dspam:dspam /var/run/dspam/ /var/dspam/
#      '';
#
#      serviceConfig = {
#        ExecStart = "${pkgs.dspam}/bin/dspam --daemon --nofork";
#      };
#    };

    jobs.dspam = {
      description = "DSPAM email spam filter";
      after = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];

      daemonType = "fork";

      # FIXME somehow I need to make the dovecot LMTP socket directory before dovecot starts

      preStart = ''
        ${pkgs.coreutils}/bin/mkdir -p /var/run/dspam/ /var/dspam/
	chown -R dspam:dspam /var/run/dspam/ /var/dspam/
      '';

      exec = "${pkgs.dspam}/bin/dspam --daemon";
    };
  };
}
