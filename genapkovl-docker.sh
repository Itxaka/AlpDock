#!/bin/sh -e

version="v3.19"

HOSTNAME="$1"
if [ -z "$HOSTNAME" ]; then
	echo "usage: $0 hostname"
	exit 1
fi

cleanup() {
	rm -rf "$tmp"
}

makefile() {
	OWNER="$1"
	PERMS="$2"
	FILENAME="$3"
	cat > "$FILENAME"
	chown "$OWNER" "$FILENAME"
	chmod "$PERMS" "$FILENAME"
}

rc_add() {
	mkdir -p "$tmp"/etc/runlevels/"$2"
	ln -sf /etc/init.d/"$1" "$tmp"/etc/runlevels/"$2"/"$1"
}

tmp="$(mktemp -d)"
trap cleanup EXIT

mkdir -p "$tmp"/etc
makefile root:root 0644 "$tmp"/etc/hostname <<EOF
$HOSTNAME
EOF

mkdir -p "$tmp"/etc/network
makefile root:root 0644 "$tmp"/etc/network/interfaces <<EOF
auto lo
iface lo inet loopback

auto eth0
iface eth0 inet dhcp
EOF

mkdir -p "$tmp"/etc/apk
makefile root:root 0644 "$tmp"/etc/apk/world <<EOF
alpine-base
bash-completion
coreutils
docker
docker-bash-completion
docker-cli-compose
findutils
openssh
procps
readline
sed
sudo
util-linux
EOF

makefile root:root 0644 "$tmp"/etc/apk/repositories <<EOF
https://dl-cdn.alpinelinux.org/alpine/${version}/main
https://dl-cdn.alpinelinux.org/alpine/${version}/community
EOF

mkdir -p "$tmp"/etc/local.d
makefile root:root 0744 "$tmp"/etc/local.d/set_bash.start <<EOF
#!/bin/ash
sed -i 's|root:/bin/ash|root:/bin/bash|' /etc/passwd
EOF

makefile root:root 0744 "$tmp"/etc/local.d/add_user.start <<EOF
#!/bin/ash
user="kairos"
echo -e "\$user\n\$user" | adduser \$user -s /bin/bash
mkdir /etc/sudoers.d
echo "\$user ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/\$user && chmod 0440 /etc/sudoers.d/\$user
EOF

rc_add devfs sysinit
rc_add dmesg sysinit
rc_add mdev sysinit
rc_add hwdrivers sysinit
rc_add modloop sysinit

rc_add hwclock boot
rc_add modules boot
rc_add sysctl boot
rc_add hostname boot
rc_add bootmisc boot
rc_add syslog boot
rc_add networking boot
rc_add local boot

rc_add docker default
rc_add sshd default

rc_add mount-ro shutdown
rc_add killprocs shutdown
rc_add savecache shutdown

tar -c -C "$tmp" etc usr| gzip -9n > $HOSTNAME.apkovl.tar.gz
