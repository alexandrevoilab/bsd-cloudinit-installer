#!/bin/sh

##############################################
#  variables
##############################################

# env
PATH=/sbin:/bin:/usr/sbin:/usr/bin:/usr/local/sbin:/usr/local/bin

# files and dirs
SSH_DIR='/etc/ssh'
RC_SCRIPT_FILE='/etc/rc.local'
RC_BACKUP_FILE='/etc/rc.local.bak'
RC_CONF='/etc/rc.conf'
LOADER_CONF='/boot/loader.conf'
WORKING_DIR='/root'
BSDINIT_DIR="$WORKING_DIR/bsd-cloudinit-master"
VENV_DIR="$BSDINIT_DIR/.venv"

# bsd cloudinit
BSDINIT_URL='https://github.com/pellaeon/bsd-cloudinit/archive/master.tar.gz'

# commands
VERIFY_PEER='--ca-cert=/usr/local/share/certs/ca-root-nss.crt'
FETCH="fetch ${VERIFY_PEER}"

INSTALL_PKGS='
	lang/python27
	devel/py-virtualenv
	devel/py-babel
	devel/py-greenlet
	net/py-netifaces
	security/sudo
	security/ca_root_nss
	'


##############################################
#  utils
##############################################
	
echo_debug() {
	echo '[debug] '$1
}
echo_bsdinit_stamp() {
	echo '# Generated by bsd-cloudinit-installer '`date +'%Y/%m/%d %T'`
}


##############################################
#  main block
##############################################

# Get freebsd version
if uname -K > /dev/null 2>&1
then
	BSD_VERSION=`uname -K`
else
	_BSD_VERSION=`uname -r | cut -d'-' -f 1`
	BSD_VERSION=$(printf "%d%02d%03d" `echo ${_BSD_VERSION} | cut -d'.' -f 1` `echo ${_BSD_VERSION} | cut -d'.' -f 2` 0)
fi

if [ $BSDINIT_DEBUG ]
then
	echo_debug "BSD_VERSION = $BSD_VERSION"
	BSDINIT_SCRIPT_DEBUG_FLAG='--debug'
fi

# Raise unsupport error
[ "$BSD_VERSION" -lt 903000 ] && {
	echo 'Oops! Your freebsd version is too old and not supported!'
	exit 1
}

# Install our prerequisites
export ASSUME_ALWAYS_YES=yes
pkg install $INSTALL_PKGS

[ ! `which python2.7` ] && {
	echo 'python2.7 Not Found !'
	exit 1
}

$FETCH -o - $BSDINIT_URL | tar -xzvf - -C $WORKING_DIR

virtualenv $VENV_DIR --system-site-packages
. "$VENV_DIR/bin/activate"
PYTHON="$VENV_DIR/bin/python"
pip install --upgrade pip
pip install -r "$BSDINIT_DIR/requirements.txt"

rm -vf $SSH_DIR/ssh_host*

touch $RC_SCRIPT_FILE
cp -pf $RC_SCRIPT_FILE $RC_BACKUP_FILE
echo_bsdinit_stamp >> $RC_SCRIPT_FILE
echo "(
	$PYTHON $BSDINIT_DIR/run.py --log-file /tmp/cloudinit.log $BSDINIT_SCRIPT_DEBUG_FLAG
	cp -pf $RC_BACKUP_FILE $RC_SCRIPT_FILE
	rm -r $BSDINIT_DIR
	rm $RC_BACKUP_FILE
)" >> $RC_SCRIPT_FILE

# Output to OpenStack console log
echo_bsdinit_stamp >> $LOADER_CONF
echo 'console="comconsole,vidconsole"' >> $LOADER_CONF
# Bootloader menu delay
echo 'autoboot_delay="1"' >> $LOADER_CONF

if [ $BSDINIT_DEBUG ]
then
	sed -I '' '/^console/d' $LOADER_CONF
fi

echo_bsdinit_stamp >> $RC_CONF
# Get the active NIC and set it to use dhcp
for i in `ifconfig -u -l`
do
	case $i in
		'lo0')
			;;
		'plip0')
			;;
		'pflog0')
			;;
		*)
			echo 'ifconfig_'${i}'="DHCP"' >> $RC_CONF
			break;
			;;
	esac
done
# Enabel sshd in rc.conf
if ! /usr/bin/egrep '^sshd_enable' $RC_CONF > /dev/null
then
	echo 'sshd_enable="YES"' >> $RC_CONF
fi

# Allow %wheel to become root with no password
sed -i '' 's/# %wheel ALL=(ALL) NOPASSWD: ALL/%wheel ALL=(ALL) NOPASSWD: ALL/' /usr/local/etc/sudoers

# Readme - clean history
echo '==================================================='
echo 'If you want to clean the tcsh history, please issue'
echo '    # set history = 0'
echo '==================================================='
