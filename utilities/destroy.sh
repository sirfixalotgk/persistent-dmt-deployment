#! /bin/bash
############################################################################
#    WARNING: This script will completely DESTROY this deploymnet.         #
#    NO DATA IS PRESERVED!!!                                               #
############################################################################
tput clear
echo -e "\n\n\e[31mDESTROY this deployment of the Intel(R) AMT Device Management Toolkit?\n\e[33m"
read -er -p "Type 'destroy' to obliterate this deployment: " destroyConfirm
if [[ "$destroyConfirm" == "destroy" ]]; then
  echo -e "\n\e[35mTaking containers offline..."
  docker-compose down -v
  echo -e "\nPruning everything (cache, images, containers...everything)..."
  docker system prune -a -f
  sleep 1
  echo -e "\n\nRemoving all files including dot-hidden files..."
  rm -fR *
  rm -fR .*
  echo -e "\n\n\e[0mOkay, it's all gone!"
else
  echo -e "\n\e[0mWhew!  That was close!  But, if you did mean to discard everything, 'destroy' (lowercase) must be entered to confirm."
fi
