#!/bin/sh
#######################################################################################
#                                                                                     #
# Vault entrypoint changed to use this script so that un-sealing with a single Vault  #
# instance can be handled automatically.                                              #
#                                                                                     #
#######################################################################################
/bin/sh -c "/vault/data/bin/unseal.sh"&
/bin/sh -c "exec vault server -config=/vault/config/vault.json"
