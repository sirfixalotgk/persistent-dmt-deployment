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

apt update
apt install docker-buildx docker-clean docker-compose-v2 docker-compose docker-doc docker-registry docker.io python3-docker python3-dockerpty -y
sleep 5
dpkg -i ./utilities/powershell_7.5.0-1.deb_amd64.deb
apt install -f -y
sleep 5
pwsh -ExecutionPolicy Bypass -Command "./utilities/install.ps1"
