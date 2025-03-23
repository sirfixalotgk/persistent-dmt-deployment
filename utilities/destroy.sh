#! /bin/bash
############################################################################
#    WARNING: This script will completely DESTROY this deploymnet.         #
#    NO DATA IS PRESERVED!!!                                               #
############################################################################
tput clear
echo -e "\n\nDESTROY this deployment of the Intel(R) AMT Device Management Toolkit?\n"
read -er -p "Type 'destroy' to obliterate this deployment: " destroyConfirm
if [[ "$destroyConfirm" == "destroy" ]]; then
  echo -e "\nTaking containers offline..."
  docker-compose down -v
  echo -e "\nPruning everything..."
  docker image prune -a -f
  docker volume prune -a -f
  docker container prune -f
  sleep 1
  echo -e "\n\nRemoving all files including dot-hidden files..."
  rm -fR *
  rm -fR .*
else
  echo -e "\nWhew!  That was close!  But, if you did mean to discard everything, 'destroy' (lowercase) must be entered to confirm."
fi
