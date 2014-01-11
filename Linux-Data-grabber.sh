#!/bin/bash
#**********************************************
#   Linux data collection script.
#   Author Reed
#   Version 0.2f
#   Date 10 Jan 2014
#
#   This script is used to collect system information
#   from Linux systems during evaluations. The
#   collected data is not all-inclusive and should
#   be changed based on the needs of the assesment.
#**********************************************

#**********************************************
#   TODO:
#           Parse /etc/passwd entries for hash harvesting
#           add command line arguments and interaction
#           check system service directory permissions
#           make setuid check array to eliminate extra for loops
#           parse hostlist to remove duplicate hosts for list paring
#           fix script execution with arguments for each function \
#           and an interactive dialog for the less CLI saavy users
#**********************************************

#**********************************************
#   Declare various variables for collection
#   and output formats 
#**********************************************
date=`date +%Y.%m.%d-%H%M.%Z`
host=`hostname`
ip=`ifconfig -a | awk /"inet addr"/'{if ( $2 !~ "127.0.0.1") print $2}' |sed -e "s/addr://" | head -1`
PREFIX="$date_$host_$ip"
TEMP="/tmp/VZP"
LOGS="/var/log"
ETCDIR="/etc"
ARCHIVE="$PREFIX.tar"

#**********************************************
#   Display script usage
#**********************************************
usage()
{
    cat << EOF
usage: $0 options

This is the VZP Linux Data collection script.
Place this script on a Linux machine and run as root
or an administrative user.

OPTIONS:
    -a  Run everything
    -i  Run in interactive mode (for Erman)
    -b  Set TEMP dir to this (defaults to -b /tmp/VZP)
    -c  Collect Configs
    -d  Collect Cron information
    -f  FTP archive to HOST (-f 10.0.0.1)
    -g  FTP username (defaults to -g COTF)
    -h  FTP password (defaults to -h cotf)
    -l  Collect logs
    -m  Collect login history
    -n  Collect network information
    -p  Collect installed package information
    -s  Collect system state information
    -t  Locate SUID programs
    -u  Collect user information
    -z  Set name of archive to save data to (defaults to -z DATE_TIME_HOST.tar)
    -?  Show this help
EOF
}

#**********************************************
#   Create directories for data collection
#**********************************************
makeDirs() {
echo "Creating $TEMP tree"
mkdir $TEMP
mkdir $TEMP/etc
mkdir $TEMP/state
}
#**********************************************
#   Collect log files and put them in $TEMP/logs
#**********************************************
getLogs() {
echo "Collecting $LOGS in $TEMP/logs"
cp -R $LOGS $TEMP
dmesg >> $TEMP/state/dmesg.txt
}

#**********************************************
#   Collect config files and put them in $TEMP/etc
#**********************************************
getConfigs() {
echo "Collecting $ETCDIR in $TEMP/etc"
cp -R $ETCDIR $TEMP
}

#**********************************************
#   Collect kernel version and other system info
#   including currently mounted drives
#**********************************************
getState() {
echo "Collecting system state info into $TEMP/state"
uname -a >> $TEMP/state/uname.txt
lsb_release -a >> $TEMP/state/lsb_release.txt
lsmod >> $TEMP/state/loaded_modules.txt
mount >> $TEMP/state/mounted_devices.txt
df >> $TEMP/state/free_space.txt
ls -l /home >> $TEMP/state/home_dirs.txt
whoami >> $TEMP/state/whoami.txt
echo "PCI Devices" >> $TEMP/state/installed_devices.txt
lspci >> $TEMP/state/installed_devices.txt
echo "USB Devices" >> $TEMP/state/installed_devices.txt
lsusb >> $TEMP/state/installed_devices.txt
date >> $TEMP/state/current_date_localtime.txt
date -u >> $TEMP/state/current_date_UTC.txt
}

#**********************************************
#   User information from the system
#**********************************************
getUsers() {
echo "Collecting user info into $TEMP/state"
USERS=`awk '{ if ($3 > 499) print $1}' FS=":" /etc/passwd`
for user in $USERS; do
        echo $user >> $TEMP/state/user_information.txt && chage -l $user >> $TEMP/state/user_information.txt
done
who >> $TEMP/state/who_is_logged_in.txt
cp /etc/passwd $TEMP/state
cp /etc/shadow $TEMP/state
}

#**********************************************
#   Collect network and route info for all devices
#**********************************************
getNet() {
echo "Collecting network information into $TEMP/state"
netstat -rn >> $TEMP/state/routes.txt
netstat -na | grep LISTEN\   >> $TEMP/state/network_pids.txt
netstat -na | grep CONNECTED\   >> $TEMP/state/connected_sessions.txt
netstat -lptu >> $TEMP/state/listening_sockets.txt
if [ -x /sbin/ip ]; then
        ip route list table all >> $TEMP/state/ip_route_list_table_all.txt
          ip rule list >> $TEMP/state/ip_rule_list.txt
        ip link show >> $TEMP/state/ip_link.txt
fi
lsof -i >> $TEMP/state/lsof-i-network.txt
for table in filter nat mangle raw; do
        iptables -nvL -t $table >> $TEMP/state/ip_filter_list_$table.txt
done
arp -a >> $TEMP/state/arp_table.txt
ifconfig -a >> $TEMP/state/interface_configs.txt
}

#**********************************************
#   Collect installed packages and process lists
#**********************************************
getPackages() {
echo "Collecting package information into $TEMP/state"
rpm -qa --last >> $TEMP/state/installed_packages.txt                
chkconfig --list | grep ":on" >> $TEMP/state/configured_services.txt 
ps axuw --forest >> $TEMP/state/process_list.txt
lsof >> $TEMP/state/open_files.txt
}

#**********************************************
#   Collect crontab information
#**********************************************
getCron() {
echo "Collecting cron information into $TEMP/state"
CRONS=`ls /var/spool/cron/* 2>> /dev/null`
if [ "$CRONS" != "" ]; then
   for file in $CRONS ; do
        echo $file >> $TEMP/state/crontabs.txt
        cat $file >> $TEMP/state/crontabs.txt
   done
else
   echo "No user crontabs in /var/spool/cron" >> $TEMP/state/crontabs.txt
fi
}

#**********************************************
#   Locate SUID files 
#**********************************************
findSuid() {
    DIRS1="/usr/bin"
    DIRS2="/usr/sbin"
    DIRS3="/bin"
    DIRS4="/sbin"
    PERMISSIONS="+4000"

echo "Locating SetUID files in $DIRS1 $DIRS2 $DIRS3 $DIRS4 with permissions $PERMISSIONS"

    echo $DIRS1 >> $TEMP/state/setuid_files.txt

    for file in $( find "$DIRS1" -perm "$PERMISSIONS" )
    do
        ls -ltF --author "$file" >> $TEMP/state/setuid_files.txt
    done

    echo $dirs2 >> $TEMP/state/setuid_files.txt

    for file in $( find "$DIRS2" -perm "$PERMISSIONS" )
    do
        ls -ltF --author "$file" >> $TEMP/state/setuid_files.txt
    done

    echo $dirs3 >> $TEMP/state/setuid_files.txt

    for file in $( find "$DIRS3" -perm "$PERMISSIONS" )
    do
        ls -ltF --author "$file" >> $TEMP/state/setuid_files.txt
    done

    echo $dirs4 >> $TEMP/state/setuid_files.txt

    for file in $( find "$DIRS4" -perm "$PERMISSIONS" )
    do
        ls -ltF --author "$file" >> $TEMP/state/setuid_files.txt
    done
}

#**********************************************
#   Collect login and reboot history to check 
#   for failed login attempts. Could indicate
#   an attack has occured
#**********************************************
checkLogins() {
echo "Checking login information and saving to $TEMP/state"
    last -w >> $TEMP/state/login_history.txt
    lastb -w >> $TEMP/state/failed_login_history.txt
    last reboot >> $TEMP/state/reboot_history.txt
    lastlog >> $TEMP/state/lastlog.txt
}

#**********************************************
#   Package up $TEMP
#**********************************************
packIt() {
echo "Packaging the $TEMP folder to $ARCHIVE"
cd $TEMP
tar -cf $ARCHIVE state etc log
}

#**********************************************
#   FTP the package to the attack host
#**********************************************
sendPackage() {

ftp -n -v $FTPHOST << EOT
user $FTPUSER $FTPPASS
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
runAll() {
makeDirs
getLogs
getConfigs
getState
getUsers
getNet
getPackages
getCron
findSuid
checkLogins
packIt
}

#echo "Results are in $TEMP"

#**********************************************
#   Automated or Interactive?
#   defaults to 100% automated until Erman sees it,
#   then it becomes 100% interactive
#**********************************************
#parseArgs() {
while getopts "ab:cdilmnpstuz:?" OPTIONS
    do
        case "$OPTIONS" in
                a)
                    makeDirs
                    runAll
                    ;;
                b)
                    $TEMP=$OPTARG
                    ;;
                c)
                    getConfigs
                    ;;
                d)
                    getCron
                    ;;
                f)
                    $FTPHOST=$OPTARG
                    ;;
                g)
                    $FTPUSER=$OPTARG
                    ;;
                h)
                    $FTPPASS=$OPTARG
                    ;;
                i)
                    runInteractive
                    ;;
                l)
                    getLogs
                    ;;
                m)
                    checkLogins
                    ;;
                n)
                    getNet
                    ;;
                p)
                    getPackages
                    ;;
                s)
                    getState
                    ;;
                t)
                    makeDirs
                    findSuid
                    ;;
                u)
                    getUsers
                    ;;
                z)
                    packIt $ARCHIVE=$OPTARG
                    ;;
                ?)
                    usage
                    exit
                    ;;
    esac
done

#}