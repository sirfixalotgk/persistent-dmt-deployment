#!/bin/sh
#
#
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

echo "Updating APT and installing pre-reqs..."
apt update
apt install docker-buildx docker-clean docker-compose-v2 docker-compose docker-doc docker-registry docker.io python3-docker python3-dockerpty -y
sleep 5
echo "Installing PowerShell v7.5.0..."
dpkg -i ./utilities/powershell_7.5.0-1.deb_amd64.deb
echo "Resolving any dependency orphans..."
apt install -f -y
sleep 5
echo "Cloning submodules from Intel(R) AMT Device Management Toolkit repository..."
git clone https://github.com/device-management-toolkit/rps.git
git clone https://github.com/device-management-toolkit/mps.git
git clone https://github.com/device-management-toolkit/mps-router.git
git clone https://github.com/device-management-toolkit/ui-toolkit.git
git clone https://github.com/device-management-toolkit/sample-web-ui.git
git clone https://github.com/device-management-toolkit/ui-toolkit-react.git
git clone https://github.com/device-management-toolkit/ui-toolkit-angular.git
git clone https://github.com/device-management-toolkit/rpc.git
git clone https://github.com/device-management-toolkit/rpc-go.git
# Cleaning GIT orphans that can cause issues with services that expect empty data directories
rm -f ./postgres-data/.commit
rm -f ./vault-pd/.commit
echo "Calling PowerShell install,init and configuration script...enjoy!
pwsh -ExecutionPolicy Bypass -Command "./utilities/install.ps1"
