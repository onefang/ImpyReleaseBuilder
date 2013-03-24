#!/bin/bash

# These control which ones get built.
do_local=0
do_linux64=1
do_linux32=1
do_windowsXP=0
do_mac=0

# Where to find suitable disk images for the various OS's.
img_linux64=~/bin/ubuntu64_diff.qcow2
img_linux32=~/bin/ubuntu32_diff.qcow2
img_windowsXP=/media/sdb2/IMAGES/xp_diff.qcow2


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
tar czf TARBALLS/impy-release-source_${date}.tar.gz SOURCE &&


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


if [ $do_local -eq 1 ]
then
    echo "Building local." &&
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
fi


if [ $do_linux64 -eq 1 ]
then
    echo "Building in qemu, 64 bit linux." &&
    qemu-system-x86_64 -M pc -cpu phenom -m 1G -hda $img_linux64 -serial stdio <<- zzzzEOFzzzz
	#
    mkdir -p /home/builder &&
    cd /home/builder &&
    rm -fr BUILD &&
    rm -fr TARBALLS &&
    mkdir -p BUILD &&
    mkdir -p TARBALLS &&
    sleep 2 &&
    busybox ftpget ${FTP_SERVER} -vP ${FTP_PORT} TARBALLS/impy-release-source_${date}.tar.gz impy-release-source_${date}.tar.gz &&
    tar xzf TARBALLS/impy-release-source_${date}.tar.gz -C BUILD &&
    cd BUILD/SOURCE &&
    cd linden/scripts/linux &&
    ./0-patch-SL-source &&
    ./1-get-libraries-from-SL &&
    ./2-trim-libraries-from-SL &&
    cp -ar ../../libraries/x86_64-linux/include/ares ../../libraries/include  # Hack around an odd problem.
    ./3-compile-SL-source &&
    ./4-package-viewer &&
    cd ../../indra/viewer-linux-* &&
    cp Imprudence-* ../../../../../TARBALLS &&
    cd /home/builder/TARBALLS &&
    find . -name Imprudence-* -type f -exec busybox ftpput ${FTP_SERVER} -vP ${FTP_PORT} '{}' '{}' \;

    shutdown -h now
zzzzEOFzzzz
    sleep 10
fi


if [ $do_linux32 -eq 1 ]
then
    echo "Building in qemu, 32 bit linux." &&
    qemu-system-i386 -M pc -cpu athlon -m 1G -hda $img_linux32 -serial stdio <<- zzzzEOFzzzz
	#
    mkdir -p /home/builder &&
    cd /home/builder &&
    rm -fr BUILD &&
    rm -fr TARBALLS &&
    mkdir -p BUILD &&
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
fi


if [ $do_windowsXP -eq 1 ]
then
    echo "Building in qemu, Windows XP."
    # A here document would be preferable, but "interact" won't work then.
    expect -c "
	set timeout -1
	set send_slow {1 .1}
	spawn qemu-system-i386 -M pc -cpu athlon -m 2G -hda ${img_windowsXP} -serial stdio
	match_max 100000
	strace 1
	expect -exact \"\$ \"; sleep .1; send -s -- \"cd /home/me\r\"
	expect -exact \"\$ \"; sleep .1; send -s -- \"rm -fr BUILD\r\"
	expect -exact \"\$ \"; sleep .1; send -s -- \"rm -fr TARBALLS\r\"
	expect -exact \"\$ \"; sleep .1; send -s -- \"su - me -c 'mkdir -p BUILD'\r\"
	expect -exact \"\$ \"; sleep .1; send -s -- \"su - me -c 'mkdir -p TARBALLS'\r\"
	expect -exact \"\$ \"; sleep 2;  send -s -- \"lftp -c 'open -p ${FTP_PORT} ${FTP_SERVER} && lcd TARBALLS && get1 impy-release-source_${date}.tar.gz'\r\"
	expect -exact \"\$ \"; sleep .1; send -s -- \"su - me -c 'tar xzf TARBALLS/impy-release-source_${date}.tar.gz -C BUILD'\r\"
	expect -exact \"\$ \"; sleep .1; send -s -- \"su - me -c 'ls -la BUILD'\r\"
	expect -exact \"\$ \"; sleep .1; send -s -- \"su - me -c 'ls -la TARBALLS'\r\"
	expect -exact \"\$ \"; sleep .1; send -s -- \"cd /home/me/BUILD/SOURCE\r\"

	interact quit return; sleep .1;  send -s -- \"\r\"
	expect -exact \"\$ \"; sleep .1; send -s -- \"shutdown -s now\r\"
	expect eof"
    echo ''
    sleep 10
fi


if [ $do_mac -eq 1 ]
then
    echo "No Mac support yet, coz I need a real Mac for that."
fi
