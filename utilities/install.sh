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
echo -e "\e[35mWelcome to the Intel(R) AMT Device Management Toolkit - Cloud Deployment automated installer script.\e[0m"
echo -e "\n\e[36mThe Intel(R) AMT Device Management Toolkit (formerly known as Open AMT Cloud Toolkit) default configuration is designed to provide an ephemeral evaluation environment.  All data such as secrets and configurations are removed with reboots, service and/or container restarts with this design. With additional configuration, this can be altered to facilitate persistence. \n\n\e[35mThis script is designed to enable persistence at the time of deployment as well as automate and simplify the deployment process. \e[0m"
echo -e "\n\n\e[33mNOTE:\nSome sensitive credential/secret information is stored on the file system as a result of enabling automation and persistence.  Access to the directory that hosts the containers and their configurations should be strictly controlled.\n\n****Any and all risk, liability and/or responsibility for the outcome(s), intended or unintended. is assumed by the user when executing this script.**** \e[0m"
echo -e "\n\e[35mYou will need to supply some minimal information but then we will take it from there...Thank you and ENJOY!!!! \e[0m"
# Prompt for the FQDN to be used with this deployment
read -p "Please enter the FQDN to be used for this deployment: " mpsCN
echo -e "\n\e[36m$mpsCN\e[32m will be used for this deployment.\n"

# Check to see if there is a certificate PFX in our directory
pfxCheck=$(ls | grep $mpsCN | grep pfx)
if [[ "$pfxCheck" == "$mpsCN.pfx" ]]; then
  echo -e "\e[36mIt appears that there is a certificate for \e[32m$mpsCN \e[36min this directory."
  read -ers -p "Please enter the PFX password: " pfxPass
  echo -e "PFX password saved. \e[32m"
fi

# Capture required passwords and exit if not provided
echo -e "\e[33m "
read -ers -p "Please enter the password for the WebUI \"admin\" user: " webUiPass
if [ -n "$webUiPass" ]; then
  echo -e "\e[32mPassword saved. \n"
else
  echo -e "\e[33mYou must supply a password for the admin account."
  read -ers -p "Please enter the password for the WebUI \"admin\" user: " webUiPass
  if [ -z "$webUiPass" ]; then
    echo -e "\n\n\e[31m****Password requirement not satisfied...exiting!**** \e[0m"
    exit
  else
    echo -e "\e[32mPassword saved. \n"
  fi
fi
echo -e "\e[33m "
read -ers -p "Please enter the database connection password: " dbPass
if [ -n "$dbPass" ]; then
  echo -e "\e[32mPassword saved. \n"
else
  echo "\e[33mYou must supply a password for the database connection."
  read -ers -p "Please enter the database connection password: " dbPass
  if [ -z "$dbPass" ]; then
    echo -e "\n\n\e[31m****Password requirement not satisfied...exiting!**** \e[0m"
    exit
  else
    echo -e "\e[32mPassword saved. \n"
  fi
fi

# Start performing actions
echo -e "\n\e[32mUpdating APT and installing pre-reqs..."
apt update &> /dev/null
apt install docker-buildx docker-clean docker-compose-v2 docker-compose docker-doc docker-registry docker.io python3-docker python3-dockerpty -y &> /dev/null

# Check for PowerShell via APT (need to adjust this to look for the binary due to multiple sources)
echo -e "Checking to see if we need PowerShell..."
checkPwsh=$(apt list | grep powershell)
if [[ "$checkPwsh" == *"powershell"* ]] && [[ "$checkPwsh" == *"installed"* ]]; then
  echo -e "\nAPT reports PowerShell is installed.  If you experience issues, package management may require cleanup."
else
  echo -e "\n\e[33mInstalling PowerShell v7.5.0..."
  dpkg -i ./utilities/powershell_7.5.0-1.deb_amd64.deb
  echo -e "Resolving any dependency orphans... \e[0m"
  apt install -f -y &> /dev/null
  sleep 1
fi

# Pull latest versions directory from toolkit GIT repo
echo -e "\n\e[32mCloning submodules from Intel(R) AMT Device Management Toolkit repository..."
git clone --quiet https://github.com/device-management-toolkit/rps.git >> /dev/null
echo " -- RPS cloned..."
git clone --quiet https://github.com/device-management-toolkit/mps.git >> /dev/null
echo " -- MPS cloned..."
git clone --quiet https://github.com/device-management-toolkit/mps-router.git >> /dev/null
echo " -- MPS Router cloned..."
git clone --quiet https://github.com/device-management-toolkit/ui-toolkit.git >> /dev/null
git clone --quiet https://github.com/device-management-toolkit/sample-web-ui.git >> /dev/null
git clone --quiet https://github.com/device-management-toolkit/ui-toolkit-react.git >> /dev/null
git clone --quiet https://github.com/device-management-toolkit/ui-toolkit-angular.git >> /dev/null
echo " -- UI samples and integration kits cloned..."
git clone --quiet https://github.com/device-management-toolkit/rpc.git >> /dev/null
git clone --quiet https://github.com/device-management-toolkit/rpc-go.git >> /dev/null
echo " -- RPC components cloned..."

# Cleaning GIT orphans that can cause issues with services that expect empty data directories
echo -e "\n\e[32mCleaning up GIT directory placeholder orphans..."
rm -f ./postgres-data/.commit
rm -f ./vault-pd/.commit

# Switch to PowerShell for platform compatibility
echo -e "\n\e[36mCalling PowerShell install, init and configuration script...enjoy! \e[0m"
pwsh -ExecutionPolicy Bypass -Command "./utilities/install.ps1 -mpsCN \"$mpsCN\" -webUiPass \"$webUiPass\" -dbPass \"$dbPass\" -pfxPass \"$pfxPass\""
