#!/bin/bash

PWD=$(pwd)

unique_port()
{
  # Try to find an unused port number for each running instance of the program.

  START=8192
  RANGE=$[$(awk '{print $1}' /proc/sys/net/ipv4/ip_local_port_range)-$START]
  if [ $RANGE -lt 8 ]
  then
    START=$[$(awk '{print $2}' /proc/sys/net/ipv4/ip_local_port_range)]
    RANGE=$[65535-$START]
    if [ $RANGE -lt 8 ]
    then
      START=16384
      RANGE=32768
    fi
  fi
  echo $[($$%$RANGE)+$START]
}


rm -rf TARBALLS
mkdir TARBALLS
date=$(date '+%H_%d-%m-%Y')


if [ -d SOURCE ]; then
    echo "Updating source."
    cd SOURCE &&
    git pull &&
    cd .. || exit 0
else
    echo "Downloading source."
    mkdir SOURCE &&
    git clone git://github.com/imprudence/imprudence.git SOURCE || exit 0
fi

echo "Creating source tarball."
tar czf TARBALLS/impy-release-source_${date}.tar.gz --exclude-vcs SOURCE &&


echo "Building locally, assuming 64 bit, linux." &&
rm -fr BUILD &&
mkdir BUILD &&
tar xzf TARBALLS/impy-release-source_${date}.tar.gz -C BUILD &&
cd BUILD/SOURCE &&
cd linden/scripts/linux &&
./0-patch-SL-source &&
./1-get-libraries-from-SL &&
./2-trim-libraries-from-SL &&
./3-compile-SL-source &&
./4-package-viewer &&
cd ../../indra/viewer-linux-* &&
cp Imprudence-* ../../../../../TARBALLS
cd ../../../../..


FTP_PORT=$(unique_port)
echo "=== launching FTP daemon on port $FTP_PORT"
# Fire off an ftp daemon, making sure it's killed when this script exits.
# (We use the busybox version because no two ftp daemons have quite the same
# command line arguments, and this one's a known quantity.)

# Busybox needs -s 127.0.0.1 support here
./busybox nc -p $FTP_PORT -lle ./busybox ftpd -w TARBALLS &
trap "kill $(jobs -p)" EXIT
disown $(jobs -p)
# QEMU's alias for host loopback
FTP_SERVER=10.0.2.2


echo "Building in qemu, assuming 32 bit, linux." &&
# Relies on the guest having this in /etc/init/ttyS0.conf -
#start on stopped rc RUNLEVEL=[2345]
#stop on runlevel [!2345]
#respawn
#exec /sbin/getty -iLn -l /bin/bash 115200 ttyS0 vt102

qemu -M pc -cpu athlon -hda ~/bin/ubuntu32_diff.qcow2 -m 1G -serial stdio << zzzzEOFzzzz
          #
cd /home/builder &&
rm -fr BUILD &&
mkdir BUILD &&
mkdir -p TARBALLS &&
sleep 2 &&
busybox ftpget ${FTP_SERVER} -vP ${FTP_PORT} TARBALLS/impy-release-source_${date}.tar.gz impy-release-source_${date}.tar.gz &&
tar xzf TARBALLS/impy-release-source_${date}.tar.gz -C BUILD &&
cd BUILD/SOURCE &&
cd linden/scripts/linux &&
./0-patch-SL-source &&
./1-get-libraries-from-SL &&
./2-trim-libraries-from-SL &&
./3-compile-SL-source &&
./4-package-viewer &&
cd ../../indra/viewer-linux-* &&
cp Imprudence-* ../../../../../TARBALLS &&
cd /home/builder/TARBALLS &&
find . -name Imprudence-* -type f -exec busybox ftpput ${FTP_SERVER} -vP ${FTP_PORT} '{}' '{}' \;

shutdown -h now
zzzzEOFzzzz

sleep 10

echo "Building in qemu, Windows XP."
expect -c "set date ${date}" -c "set FTP_SERVER ${FTP_SERVER}" -c "set FTP_PORT ${FTP_PORT}"  - << "zzzzEOFzzzz"
set timeout -1
set send_slow {1 .1}
spawn qemu -M pc -cpu athlon -m 2G -hda /media/sdb2/IMAGES/xp_diff.qcow2 -cdrom /home/dvs1/Downloads/lose/winxphomex86.iso -serial stdio
match_max 100000
expect -exact "\$ "; sleep .1; send -s -- "cd /home/me\r"
expect -exact "\$ "; sleep .1; send -s -- "rm -fr BUILD\r"
expect -exact "\$ "; sleep .1; send -s -- "su - me -c 'mkdir BUILD'\r"
expect -exact "\$ "; sleep .1; send -s -- "su - me -c 'mkdir -p TARBALLS'\r"
expect -exact "\$ "; sleep 2;  send -s -- "lftp -c 'open -p $FTP_PORT $FTP_SERVER && lcd TARBALLS && get1 impy-release-source_$date.tar.gz'\r"
expect -exact "\$ "; sleep .1; send -s -- "su - me -c 'tar xzf TARBALLS/impy-release-source_$date.tar.gz -C BUILD'\r"
expect -exact "\$ "; sleep .1; send -s -- "su - me -c 'ls -la BUILD'\r"
expect -exact "\$ "; sleep .1; send -s -- "su - me -c 'ls -la TARBALLS'\r"

expect -exact "\$ "; sleep .1; send -s -- "shutdown -s now\r"
expect eof
zzzzEOFzzzz


