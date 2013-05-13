ImpyReleaseBuilder
==================

A script to build Imprudence for various OSes using qemu and virtual
serial ports.

Lot's of people wonder why I don't use ssh, the reason is that ssh
requires both the host and the guest computer to spend effort on
encrypting the data stream that is only private between them anyway. 
The poor things are working hard enough compiling the horendously huge
viewer, the less overhead the better.  So the only thing using ssh gets
you is to slow things down.


Installing 64 bit Linux build image.
====================================

Get an Ubuntu 10.04.1 AMD64 desktop install CD image.

Create a qemu disk image -
qemu-img create -f qcow2 ubuntu64_base.qcow2 20G

Start up qemu, booting from the CD image the first time -
qemu-system-x86_64 -M pc -cpu qemu64 -m 1G -hda ubuntu64_base.qcow2 -cdrom ubuntu-10.04.1-desktop-amd64.iso -boot once=d

Install Ubuntu.  Mostly select the defaults, except -
Log in automatically.

Update the system -
apt-get update
apt-get dist-upgrade

Make sure this is in /etc/init/ttyS0.conf -
start on stopped rc RUNLEVEL=[2345]
stop on runlevel [!2345]
respawn
exec /sbin/getty -iLn -l /bin/bash 115200 ttyS0 vt102

Install developmont stuff, and build time dependencies.
apt-get install cmake binutils-gold bison build-essential flex git-core texinfo
apt-get install freeglut3-dev libcrypto++-dev libgcrypt11-dev libgpg-error-dev libgsf-1-dev libmagic-dev libssl-dev libxinerama-dev libxrender-dev

Shutdown qemu, then setup the snapshot -
qemu-img create -f qcow2 -o backing_file=ubuntu64_base.qcow2 ubuntu64_diff.qcow2



Installing 32 bit Linux build image.
====================================

Same as the 64 bit version above, but use Ubuntu 10.04.1 i386 desktop install CD, and use qemu-system-i386.


Installing Windows XP build image.
==================================

Been a long time since I did this, forgot how.  These are the general tasks -

create the disk image
install under qemu
reboot
labourously install all the development stuff and build time dependencies
(refer to http://wiki.kokuaviewer.org/wiki/Imprudence:Compiling/1.4/Windows for details)
reboot
setup cygwin shell on serial port as a service
or sshd, seems to work better
reboot
Then reboot more, coz it's Windows.


Installing Mac build system.
============================

It's actually against Apples license for Mac OSX to install it on a VM
that is not running on Apple branded hardware, so this time it has to be
real Apple hardware.  When I actually get one, I'l make notes and get it
to work.  This one likely needs to use ssh, don't think Mac's have
serial ports.

