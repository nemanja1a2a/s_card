#!/bin/bash
# Created by Nemanja

#-------------------------------------------------------------------------------------------------------
function check_version {
	program=$1
	version=`apt-cache policy $program | grep Installed |  cut -d ':' -f 2`
	if [ -z "$version" ]
	then
		version=" (none)"
	fi
	echo -e "$program version --> $version"
}

#-------------------------------------------------------------------------------------------------------
function opensc_v0_19 {
	dir=$1
	mode=$2

	if [ $mode != "I" ]
	then
		echo -e "\nRemoving opensc...\n"
		sleep 2
		sudo apt-get remove -y --purge opensc
		sudo apt-get autoremove -y

		if [ $mode == "D" ]
		then
		    return
		fi
	fi

	dpkg -s opensc &> /dev/null
	if [ $? -ne 0 ]
	then
		echo -e "\nDownloading opensc v0.19...\n"
		wget -O $dir/opensc.deb https://owncloud.iten.rs/index.php/s/jUvaLrFRSX4TLjs/download
		wget -O $dir/opensc-pkcs11.deb https://owncloud.iten.rs/index.php/s/PmZ6kODps9jhQBz/download

		echo -e "\nInstalling opensc...\n"
		sudo dpkg -i $dir/opensc*
	else
		echo "opensc is already installed"
	fi
}

#-------------------------------------------------------------------------------------------------------
function opensc_conf_file {
	if grep -c "max_send_size = 65535" /etc/opensc/opensc.conf &> /dev/null
	then 
		echo -e "\nConfig file contains proper data."
	else
		echo -e "Editing the config file..."
sudo chmod 666 /etc/opensc/opensc.conf
echo "# The following section shows definitions for PC/SC readers.
reader_driver pcsc {
# Limit command and response sizes. Some Readers don't propagate their
# transceive capabilities correctly. max_send_size and max_recv_size
# allow setting the limits manually, for example to enable extended
# length capabilities.
# Default: max_send_size = 255, max_recv_size = 256;
max_send_size = 65535;
max_recv_size = 65536;
}" >> /etc/opensc/opensc.conf
sudo chmod 444 /etc/opensc/opensc.conf
	fi
}

#-------------------------------------------------------------------------------------------------------
function manage {
	program=$1
	mode=$2

	if [ $mode != "I" ]
	then
		echo -e "\nRemoving $program...\n"
		sleep 2
		sudo apt-get remove -y --purge $program
		sudo apt-get autoremove -y
		sudo apt-get clean -y
		if [ $program == "icaclient" ] && [ -d "/opt/Citrix" ]
		then
		    echo -e "\nRemoving Citrix folder...\n"
			sudo rm -r /opt/Citrix
		elif [ $program == "opensc" ] && [ -d "/opt/opensc" ]
		then
		    echo -e "\nRemoving opensc folder...\n"
			sudo rm -r /etc/opensc
		fi
		if [ $mode == "D" ]
		then
		    return
		fi
	fi
	dpkg -s $program &> /dev/null
	if [ $? -ne 0 ]
	then
		if [ $mode == "R" ]
		then
			echo -e "\nInstalling $program...\n"
			sleep 2
		else
			echo "$program isn't installed. Installing..."  
		fi
		if [ $program == "icaclient" ]
		then
			install_citrix
		else
			sudo apt-get update
			sudo apt-get install -y $program
		fi
	else
		echo "$program is already installed"
	fi
}

#-------------------------------------------------------------------------------------------------------
function install_citrix {
# https://ubuntuforums.org/showthread.php?t=1481300
# Get arch type of ubuntu
# i686 = 32 bit
# x86_64 = 64 bit

ARCH_TYPE=`uname -m`

# Check if curl is installed
dpkg -s curl &> /dev/null
if [ $? -ne 0 ]
then
  sudo apt-get update
  sudo apt-get install -y curl
fi

# Create download link from official Citrix site
if [ $ARCH_TYPE = "i686" ] 
then
  GDA=`curl -sS https://www.citrix.com/downloads/workspace-app/linux/workspace-app-for-linux-latest.html | awk '/icaclient_/ && /i386/ && /__gda__/' | cut -d? -f2 | cut -d\" -f1`
  STRING=`curl -sS https://www.citrix.com/downloads/workspace-app/linux/workspace-app-for-linux-latest.html | awk '/icaclient_/ && /i386/ && /filepathOrUrl/'`
  DOWNLOAD_LINK=`grep -Eo 'downloads[^"]+' <<< $STRING`
  DOWNLOAD_LINK=`echo $DOWNLOAD_LINK | xargs`
  DOWNLOAD_LINK="${DOWNLOAD_LINK}?${GDA}"
elif [ $ARCH_TYPE = "x86_64" ] 
then
  GDA=`curl -sS https://www.citrix.com/downloads/workspace-app/linux/workspace-app-for-linux-latest.html | awk '/icaclient_/ && /amd64/ && /__gda__/' | cut -d? -f2 | cut -d\" -f1`
  STRING=`curl -sS https://www.citrix.com/downloads/workspace-app/linux/workspace-app-for-linux-latest.html | awk '/icaclient_/ && /amd64/ && /filepathOrUrl/'`
  DOWNLOAD_LINK=`grep -Eo 'downloads[^"]+' <<< $STRING`
  DOWNLOAD_LINK=`echo $DOWNLOAD_LINK | xargs`
  DOWNLOAD_LINK="${DOWNLOAD_LINK}?${GDA}"
fi

filename=$(basename "$DOWNLOAD_LINK" | cut -d? -f1)

# Download Citrix from created link
cd /tmp
wget -O $filename $DOWNLOAD_LINK

# Install Citrix from downloaded file (get error on missing dependencies)
echo -e "\n\nIf CITRIX installation opens a new window, choose NO and press ENTER!!!"
read -n 1 -s -r -p "(Press any key to continue)"
echo -e "\n\n"

sudo dpkg -i $filename

# https://askubuntu.com/questions/40011/how-to-let-dpkg-i-install-dependencies-for-me
# install dependencies
if [ $? -ne 0 ]
then
  echo "[WARNING] Dependencies not satisfied, trying to obtain them and install again"
  sudo apt-get -f install
  sudo dpkg -i $filename
fi

# Remove leftovers
rm /tmp/$filename

# Link certificates
echo -e "\nLinking certificates to Citrix.\n"
sudo ln -s /usr/share/ca-certificates/mozilla/* /opt/Citrix/ICAClient/keystore/cacerts/
}

#----------------------------------------------------------------------------#
#                                MAIN PART                                   #
#----------------------------------------------------------------------------#

#------------------------#
# Check if on Linux Mint #
#------------------------#
if [ -d "/etc/linuxmint" ]
then
	echo -e "\nYou are on Linux Mint. Mint up!\n"
	mint=true
else
	echo -e "\nNo Mint for you!\n"
	mint=false
fi

#-------------------------#
# Assess input parameters #
#-------------------------#
mode="N"
if [[ $1 == *"/"* ]] && [ ! -z "$1" ]
then
	tmp_dir=$1
	if [ ! -z "$2" ]
	then
		mode=$2
	fi
elif [[ $2 == *"/"* ]] && [ ! -z "$2" ]
then
	mode=$1
	tmp_dir=$2
elif [ ! -z "$1" ]
then
	mode=$1
	tmp_dir=$(mktemp -d -t XXXXXXXXX)
else
	tmp_dir=$(mktemp -d -t XXXXXXXXX)
fi

#-----------#
# echo mode #
#-----------#
case $mode in
   I)
      echo -e "Installing card programs...\n"
      ;;
   R)
      echo -e "Reinstalling card programs...\n"
      ;;
   D)
      echo -e "Removing card programs...\n"
      ;;
   *)
      echo -e "Mode is not recognized!\n"
      ;;
esac

#----------------#
# set what to do #
#----------------#
R_opensc=false
R_pcscd=false
R_libnss=false
R_citrix=false
case $3 in
   opensc)
      R_opensc=true
      echo -e "opensc only\n"
      ;;
   pcscd)
      R_pcscd=true
      echo -e "pcscd only\n"
      ;;
   libnss)
      R_libnss=true
      echo -e "libnss3-tools only\n"
      ;;
   citrix)
      R_citrix=true
      echo -e "citrix only\n"
      ;;
   *)
      R_opensc=true
      R_pcscd=true
      R_libnss=true
      R_citrix=true
      ;;
esac

echo -e "^C to stop it, or wait.\n"
sleep 8

if [ ! -d "$tmp_dir" ]
then
   mkdir $tmp_dir
fi

if "$R_opensc"; then
#---------------#
# Manage opensc #
#---------------#
   result=`apt-cache policy opensc | grep Candidate |  cut -d ':' -f 2 | cut -d '-' -f 1 | tr -d '.'`
   ver=$(echo "$result + 0" | bc)

   ARCH_TYPE=`uname -m`
   if [ $ver -le 190 ] && [ $ARCH_TYPE = "x86_64" ]
   then
      opensc_v0_19 $tmp_dir $mode
   else
      manage opensc $mode
   fi
fi

if "$R_pcscd"; then
#--------------#
# Manage pcscd #
#--------------#
   manage pcscd $mode
fi

if "$R_libnss"; then
#----------------------#
# Manage libnss3-tools #
#----------------------#
   manage libnss3-tools $mode

   if ([ $mode == "R" ] || [ $mode == "D" ]) && [ -d "$HOME/.pki/nssdb" ]
   then
      echo -e "\nRemoving nssdb folder..."
      rm -r $HOME/.pki/nssdb
   fi

   if [ $mode != "D" ]
   then
      if [ ! -d "$HOME/.pki/nssdb" ] && echo -e "\nDirectory $HOME/.pki/nssdb DOES NOT exists. Updating..."
      then
         if pgrep chrome &> /dev/null
         then 
            echo -e "\nClose Chrome or it will be killed in 8 seconds."
            sleep 8
            if pgrep chrome &> /dev/null
            then
               pkill chrome
               sleep 2
            fi
         fi
         sleep 2
         if pgrep chrome &> /dev/null
         then
            echo -e "\nChrome is still running. Exiting..."
            exit 0
         else
            echo -e "\n\nWhen required continue by pressing ENTER!!! (even for passwords)"
            read -n 1 -s -r -p "(Press any key to continue)"
	    echo -e "\n"
            mkdir -p $HOME/.pki/nssdb
            certutil -d $HOME/.pki/nssdb -N
            modutil -dbdir sql:$HOME/.pki/nssdb -add opensc-pkcs11 -libfile opensc-pkcs11.so -mechanisms FRIENDLY
         fi
      else
         echo -e "\nDirectory $HOME/.pki/nssdb already exists.\n"
      fi
   fi
fi

if "$R_citrix"; then
#------------------#
# Manage icaclient #
#------------------#
   manage icaclient $mode
fi

command -v pcscd >/dev/null 2>&1
if [ $? -eq 0 ]
then
   echo -e "\npcscd restart"
   sudo service pcscd restart
fi

#--------------------#
# Installed programs #
#--------------------#
echo -e "\n\nListing all installed programs:\n"
check_version opensc
check_version pcscd
check_version libnss3-tools
check_version icaclient

#--------------------#
# Delete temp folder #
#--------------------#
rm -rf $tmp_dir

exit 0
