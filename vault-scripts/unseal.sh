#!/bin/sh
#######################################################################################
#                                                                                     #
# Complicated un-sealing process simplified by calling un-seal API after Vault launch #
# Second script in forked launch of container.  This script is called by launch.sh    #
# and runs in parallel to the vault process.                                          #
#                                                                                     #
# CAUTION: Consider passing un-seal key as a parameter to avoid embedding in the      #
#          URL below                                                                  #
#                                                                                     #
#######################################################################################
key=$VAULT_KEY
token=$VAULT_DEV_ROOT_TOKEN_ID
echo "Waiting for the Vault container to be ready to accept connections..."
sleep 10
echo "Calling un-seal API..."
wget --spider --header 'accept: application/json' --header 'Content-Type: application/json' --header "X-Vault-Token: $token" --post-data '{"key": "'$key'", "migrate": false, "reset": false}' 'http://127.0.0.1:8200/v1/sys/unseal'
sleep 1
echo "Vault un-sealed...done!"
