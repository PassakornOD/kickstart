#!/bin/bash

#Copy CentOS/RHEL ISO
Mount_iso(){
    mountpoint=$1
    mkdir $mountpoint
    mount /dev/sr0 $mountpoint
}

#Configure repository
configure_repo(){
    mountpoint=$1
    #Clear repo configure
    echo -e "clear exist repo config"
    mv /etc/yum.repos.d/*.repo /tmp
    echo -e "clear complete\n\n"

    echo -e "disable gpgcheck in /etc/yum.conf"
    if [ `grep gpgcheck /etc/yum.conf |awk -F= '{print $2}'` != '0' ]
    then

        GPG=`grep gpgcheck /etc/yum.conf`
        sed -i "s/${GPG}/gpgcheck=0/g" /etc/yum.conf
        GPG1=`grep gpgcheck /etc/yum.conf`
        echo "Change parameter from ${GPG} to ${GPG1}"
    echo -e "************************************************\n"
    fi

    echo -e "configure repo"
    yum-config-manager --add-repo=file://${mountpoint}
    yum clear all
}

#install package
InstallPackage(){
    rpm=$1
    yum install -y $rpm
}

PXEboot(){
    mountpoint=$1
    path_proto=$2
    # create directory for boot label
    mkdir /var/lib/tftpboot/pxelinux.cfg
    # create directory networkboot
    mkdir -p /var/lib/tftpboot/networkboot${mountpoint}
    # create link source media
    mkdir -p $path_proto


    #Copy file pxe to tftpboot
    cp -v /usr/share/syslinux/pxelinux.0 /var/lib/tftpboot/
    cp -v /usr/share/syslinux/menu.c32 /var/lib/tftpboot/
    cp -v /usr/share/syslinux/mboot.c32 /var/lib/tftpboot/
    cp -v /usr/share/syslinux/chain.c32 /var/lib/tftpboot/

    # Copy boot image file
    cp ${mountpoint}/images/pxeboot/{initrd.img,vmlinuz} /var/lib/tftpboot/networkboot${mountpoint}

    #bootloader of UEFI
    cp ${mountpoint}/EFI/BOOT/grubx64.efi /var/lib/tftpboot

}

#Copy ISO to server
Copy_iso(){
    mount=$1
    path_proto=$2

    echo "Start copy content media"
    # Copy contents of ISO file
    cp -rpf ${mount}/* $path_proto
    echo "Done...."
}

# start and enable service
StartService(){
    services=$1
    systemctl start $services
    systemctl enable $services
}

AllowFirewall() {
  # Allow dhcp and proxy dhcp service
  firewall-cmd --permanent --add-service={dhcp,proxy-dhcp}

  # Allow tftp server service
  firewall-cmd --permanent --add-service=tftp

  # Allow FTP service
  firewall-cmd --permanent --add-service=ftp


  # reload rule firewall
  firewall-cmd --reload
}

#############################################################################################

#############################################################################################
ConfigDHCP() {
  ip_host=$1
  ip_subnet=$2
  ip_gw=$3
  ip_start=$4
  ip_end=$5

  # Configure dhcp file
  cat >> /etc/dhcp/dhcpd.conf << EOF
  option space pxelinux;
  option pxelinux.magic code 208 = string;
  option pxelinux.configfile code 209 = text;
  option pxelinux.pathprefix code 210 = text;
  option pxelinux.reboottime code 211 = unsigned integer 32;
  option architecture-type code 93 = unsigned integer 16;

  subnet ${ip_subnet} netmask 255.255.255.0 {
  	option routers ${ip_gw};
  	range ${ip_start} ${ip_end};

  	class "pxeclients" {
  	  match if substring (option vendor-class-identifier, 0, 9) = "PXEClient";
  	  next-server ${ip_host};

  	  if option architecture-type = 00:07 {
  	    filename "grubx64.efi";
  	    } else {
  	    filename "pxelinux.0";
  	  }
  	}
  }
EOF
}

ConfigPxelinux() {
  mountpoint=$1
  repo=$2
  ks=$3

  ##############################Configure pxelinux file########################
  cat >> /var/lib/tftpboot/pxelinux.cfg/default << EOF
    default menu.c32
    prompt 0
    timeout 60
    menu title PXE boot Menu
    label 1^) Install OS Manual
    kernel /networkboot${mountpoint}/vmlinuz
    append initrd=/networkboot${mountpoint}/initrd.img inst.repo=${repo}

    label 2^) Install OS Kickstart
    kernel /networkboot${mountpoint}/vmlinuz
    append initrd=/networkboot${mountpoint}/initrd.img inst.repo=${repo} ks=${ks}
EOF
}

ConfigEFI() {
  mountpoint=$1
  repo=$2
  ks=$3
  ##############################Configure EFI file########################
  cat >> /var/lib/tftpboot/grub.cfg << EOF
    set timeout=20

    menuentry 'Install OS Manual' {
        linuxefi /networkboot${mountpoint}/vmlinuz inst.repo=${repo}
        initrdefi /networkboot${mountpoint}/initrd.img
    }

    menuentry 'Install OS Kickstart' {
        linuxefi /networkboot${mountpoint}/vmlinuz inst.repo=${repo} inst.ks=${ks}
        initrdefi /networkboot${mountpoint}/initrd.img
    }
EOF
}