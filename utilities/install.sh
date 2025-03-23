#! /bin/bash
#############################################################################################################
#                                                                                                           #
#  Device Management ToolKit installation and configuration script...................v0.1.0 21MAR25         #
#                                                                                                           #
#     This script will perform a standard installation of the Device Management ToolKit - Cloud Deployment  #
#     (formerly known as Open AMT Cloud ToolKit) and then execute several steps that will configure the     #
#     deployment with the necessary components to enable database and secret store persistence.             #
#                                                                                                           #
#     The first steps will install pre-requisite components automatically and then launch a PowerShell      #
#     script to finalize configuration settings.  PowerShell is used to enable compatibility across         #
#     OS platforms (future).                                                                                #
#                                                                                                           #
#############################################################################################################
tput clear
echo "Welcome to the Intel(R) AMT Device Management Toolkit - Cloud Deployment automated installer script."
echo -e "\nYou need to supply some minimal information but then we'll take it from there...Thank you and ENJOY!!!!\n\n"
read -p "Please enter the FQDN to be used for this deployment: " mpsCN
echo -e "\n\n\"$mpsCN\" will be used for this deployment.\n\n"
read -ers -p "Please enter the password for the WebUI \"admin\" user: " webUiPass
if [ -n "$webUiPass" ]; then
  echo -e "Password saved.\n"
else
  echo "You must supply a password for the admin account."
  read -ers -p "Please enter the password for the WebUI \"admin\" user: " webUiPass
  if [ -z "$webUiPass" ]; then
    echo -e "\n\n****Password requirement not satisfied...exiting!****"
    exit
  else
    echo -e "Password saved.\n"
  fi
fi
read -ers -p "Please enter the database connection password: " dbPass
if [ -n "$dbPass" ]; then
  echo -e "Password saved.\n"
else
  echo "You must supply a password for the database connection."
  read -ers -p "Please enter the database connection password: " dbPass
  if [ -z "$dbPass" ]; then
    echo -e "\n\n****Password requirement not satisfied...exiting!****"
    exit
  else
    echo -e "Password saved.\n"
  fi
fi
echo -e "\n\nUpdating APT and installing pre-reqs..."
apt update >> /dev/null
apt install docker-buildx docker-clean docker-compose-v2 docker-compose docker-doc docker-registry docker.io python3-docker python3-dockerpty -y
echo -e "\n\nChecking to see if we need PowerShell..."
checkPwsh=$(apt list | grep powershell)
if [[ "$check" == *"powershell"* ]] && [[ "$check" == *"installed"* ]]; then
  echo -e "\n\nAPT reports PowerShell is installed.  If you experience issues, package management may require cleanup."
else
  echo -e "\n\nInstalling PowerShell v7.5.0..."
  dpkg -i ./utilities/powershell_7.5.0-1.deb_amd64.deb
  echo -e "\n\nResolving any dependency orphans..."
  apt install -f -y >> /dev/null
  sleep 1
fi
echo -e "\n\nCloning submodules from Intel(R) AMT Device Management Toolkit repository..."
git clone https://github.com/device-management-toolkit/rps.git >> /dev/null
echo " -- RPS cloned..."
git clone https://github.com/device-management-toolkit/mps.git >> /dev/null
echo " -- MPS cloned..."
git clone https://github.com/device-management-toolkit/mps-router.git >> /dev/null
echo " -- MPS Router cloned..."
git clone https://github.com/device-management-toolkit/ui-toolkit.git >> /dev/null
git clone https://github.com/device-management-toolkit/sample-web-ui.git >> /dev/null
git clone https://github.com/device-management-toolkit/ui-toolkit-react.git >> /dev/null
git clone https://github.com/device-management-toolkit/ui-toolkit-angular.git >> /dev/null
echo " -- UI samples and integration kits cloned..."
git clone https://github.com/device-management-toolkit/rpc.git >> /dev/null
git clone https://github.com/device-management-toolkit/rpc-go.git >> /dev/null
echo " -- RPC components cloned..."
# Cleaning GIT orphans that can cause issues with services that expect empty data directories
rm -f ./postgres-data/.commit
rm -f ./vault-pd/.commit
echo -e "\n\nCalling PowerShell install,init and configuration script...enjoy!"
pwsh -ExecutionPolicy Bypass -Command "./utilities/install.ps1 -mpsCN \"$mpsCN\" -webUiPass \"$webUiPass\" -dbPass \"$dbPass\""
