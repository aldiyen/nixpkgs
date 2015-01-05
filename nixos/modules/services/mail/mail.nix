{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.mail;

in

{

  ###### interface

  options = {

    services.mail = {

      sendmailSetuidWrapper = mkOption {
        default = null;
        description = ''
          Configuration for the sendmail setuid wrwapper (like an element of
          security.setuidOwners)";
        '';
      };

      createVirtualMailboxOwner = mkOption {
        default = false;
        description = ''
          Creates the vmail user for use with virtual mailbox owner setups
          with certain Mail Delivery Agents
        '';
      };

    };

  };

  ###### implementation

  config = mkMerge [
    (mkIf (cfg.sendmailSetuidWrapper != null) {

      security.setuidOwners = [ cfg.sendmailSetuidWrapper ];

    })
    (mkIf (cfg.createVirtualMailboxOwner) {
      users.extraUsers.vmail = {
        description = "Virtual mailbox owner";
        uid = config.ids.uids.vmail;
        group = "vmail";
      };
      users.extraGroups.vmail = {
        gid = config.ids.gids.vmail;
      };
    })
  ];
}
