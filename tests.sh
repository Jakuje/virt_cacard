#!/bin/bash

set -ex -o xtrace

echo "#######################################################################################################################"
echo "#######################################################################################################################"
echo "#######################################################################################################################"
echo "#######################################################################################################################"

# do not recurse
> /usr/share/p11-kit/modules/opensc.module

# disable opensc file caching
cat > /etc/opensc.conf <<OPENSC_CONF
app default {
	framework pkcs15 {
		use_file_caching = false;
	}
}
OPENSC_CONF


# Start the pcscd in container environment. Without polkit
/usr/sbin/pcscd --disable-polkit -f 2>&1 | sed -e 's/^/pcscd: /' &
#/usr/sbin/pcscd --disable-polkit -f -d &> /tmp/pcscd.log &

# Try to wait up to 30 seconds for pcscd to come up and create PID file
for ((i=1;i<=30;i++)); do
        echo "Waiting for pcscd to start: $i s"
        if [ -f "/var/run/pcscd/pcscd.pid" ]; then
                echo "PCSC PID: `cat /var/run/pcscd/pcscd.pid`"
                break
        fi
        sleep 1
done

SRC=$PWD
TMPDIR=$(mktemp -d)
cd $TMPDIR

#export G_MESSAGES_DEBUG=virt_cacard
for T in 0 1; do
	SLOT=$(($T * 4))
	mkdir "t$T"
	pushd "t$T"
	cp $SRC/{setup-softhsm2.sh,cert.cfg} ./
	. setup-softhsm2.sh
	pkcs11-tool --read-object --id 01 --type cert --output-file "$TMPDIR/cert${T}-softhsm.der" --module=$P11LIB
	openssl x509 -inform DER -in "$TMPDIR/cert${T}-softhsm.der" -text > "$TMPDIR/cert${T}-softhsm.txt"
	virt_cacard -s "$T" 2>&1 | sed -e "s/^/virt_cacard${T}: /;" &
	popd

	sleep 1

	pkcs11-tool -L 2>&1 | tee $TMPDIR/slots
	grep "Virtual PCD 00 0${T}" $TMPDIR/slots
	grep "Common Access Card" $TMPDIR/slots

	# list certs in slot
	pkcs11-tool --slot "$SLOT" -O --type cert

	# read cert from the slot
	pkcs11-tool --slot "$SLOT" --read-object --id 0001 --type cert --output-file "$TMPDIR/cert${T}.der"
	openssl x509 -inform DER -in "$TMPDIR/cert${T}.der" -text > "$TMPDIR/cert${T}.txt"

	diff "$TMPDIR/cert${T}.txt" "$TMPDIR/cert${T}-softhsm.txt"
done

# Make sure the certs are not the same
diff $TMPDIR/cert0.txt $TMPDIR/cert1.txt && exit 1

# check there are no empty slots
pkcs11-tool -L 2>&1 | tee $TMPDIR/slots
grep "(empty)" $TMPDIR/slots && exit 1
grep "Virtual PCD 00 00" $TMPDIR/slots
grep "Virtual PCD 00 01" $TMPDIR/slots
grep "Common Access Card" $TMPDIR/slots

# remove all the cards
virt_cacard -r
sleep 1

# check the slots are now empty
pkcs11-tool -L 2>&1 | tee $TMPDIR/slots
grep "(empty)" $TMPDIR/slots

# insert them back
virt_cacard -i
sleep 1

# check there are no empty slots
pkcs11-tool -L 2>&1 | tee $TMPDIR/slots
grep "(empty)" $TMPDIR/slots && exit 1
grep "Virtual PCD 00 00" $TMPDIR/slots
grep "Virtual PCD 00 01" $TMPDIR/slots
grep "Common Access Card" $TMPDIR/slots

pkill virt_cacard
pkill pcscd
rm -rf $TMPDIR
