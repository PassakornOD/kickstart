#!/bin/bash

source ./prepare_media.sh
##########function in install_package.sh#############
# Prepare_repo
# InstallDhcp
# InstallTftpServer
# InstallFtp
# InstallSyslinux
# CreateDirectory
# PXEboot
# PXEbootEFI
# ContentMedia
# PrepareKickstart
# StartService
# AllowFirewall
#####################################################

#source ./configure.sh
############function in configure.sh#################
# ConfigDHCP
# ConfigPxelinux
# ConfigEFI


################## Call function ######################
echo -e "======Welcome to Kickstart==========\n\n"
read -p "Please chose mountpoint for repository : " mountpoint
read -p "Please enter host ip : " ip_host
read -p "Please please select protocol [ftp or http] : " protocol

oct_1=`echo ${ip_host} |cut -d "." -f 1` 
oct_2=`echo ${ip_host} |cut -d "." -f 2` 
oct_3=`echo ${ip_host} |cut -d "." -f 3` 
oct_4=`echo ${ip_host} |cut -d "." -f 4` 

ip_subnet="${oct_1}.${oct_2}.${oct_3}.0"
ip_start="${oct_1}.${oct_2}.${oct_3}.200"
ip_end="${oct_1}.${oct_2}.${oct_3}.220"
ip_gw="${oct_1}.${oct_2}.${oct_3}.1"
repo=""
ks=""
path_proto=""
pg=""

echo -e "Copy ISO to localhost...."
Mount_iso $mountpoint

echo -e "Configure repository...."
configure_repo $mountpoint

echo -e "install package..."
echo -e "- install dhcpd...."
InstallPackage dhcp
echo -e "- install tftp server...."
InstallPackage tftp-server

InstallPackage syslinux


if [ $protocol != "http" ]
then
    repo=${protocol}://${ip_host}/pub${mountpoint}/
    ks=${protocol}://${ip_host}/pub${mountpoint}${mountpoint}_gui.cfg
    path_proto=/var/ftp/pub${mountpoint}
    pg=vsftpd
else
    repo=${protocol}://${ip_host}${mountpoint}/
    ks=${protocol}://${ip_host}${mountpoint}${mountpoint}_gui.cfg 
    path_proto=/var/www/html${mountpoint}
    pg=httpd
fi
echo -e "- install ${protocol}...."
InstallPackage $pg
echo -e "Confgiure PXE Boot"
PXEboot $mountpoint $path_proto
ConfigPxelinux $mountpoint $repo $ks
ConfigEFI $mountpoint $repo $ks
echo -e "Confgiure dhcp server"
ConfigDHCP $ip_host $ip_subnet $ip_gw $ip_start $ip_end

Copy_iso $mountpoint $path_proto

echo -e "start and enable service"
StartService dhcpd.service
StartService tftp.service
StartService $pg
echo -e "allow firewall"
AllowFirewall