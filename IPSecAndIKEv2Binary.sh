#!/bin/sh
yum install -y strongswan 

# my_key_file=your key file path
# my_ca_file=your ca file path
# my_cert_file=your cert file path

cp -f $my_key_file /etc/strongswan/ipsec.d/private/serverKey.pem
cp -f $my_key_file /etc/strongswan/ipsec.d/private/clientKey.pem
cp -f $my_ca_file /etc/strongswan/ipsec.d/cacerts/caCert.pem
cp -f $my_cert_file /etc/strongswan/ipsec.d/certs/server.cert.pem
cp -f $my_cert_file /etc/strongswan/ipsec.d/certs/client.cert.pem

cat > /etc/strongswan/ipsec.conf<<EOF
# ipsec.conf - strongSwan IPsec configuration file
config setup
    uniqueids=never 

conn iOS_cert
    keyexchange=ikev1
    fragmentation=yes
    left=%defaultroute
    leftauth=pubkey
    leftsubnet=0.0.0.0/0
    leftcert=server.cert.pem
    right=%any
    rightauth=pubkey
    rightauth2=xauth
    rightsourceip=10.31.2.0/24
    rightcert=client.cert.pem
    auto=add

conn android_xauth_psk
    keyexchange=ikev1
    left=%defaultroute
    leftauth=psk
    leftsubnet=0.0.0.0/0
    right=%any
    rightauth=psk
    rightauth2=xauth
    rightsourceip=10.31.2.0/24
    auto=add

conn networkmanager-strongswan
    keyexchange=ikev2
    left=%defaultroute
    leftauth=pubkey
    leftsubnet=0.0.0.0/0
    leftcert=server.cert.pem
    right=%any
    rightauth=pubkey
    rightsourceip=10.31.2.0/24
    rightcert=client.cert.pem
    auto=add

conn ios_ikev2
    keyexchange=ikev2
    ike=aes256-sha256-modp2048,3des-sha1-modp2048,aes256-sha1-modp2048!
    esp=aes256-sha256,3des-sha1,aes256-sha1!
    rekey=no
    left=%defaultroute
    leftid=${vps_ip}
    leftsendcert=always
    leftsubnet=0.0.0.0/0
    leftcert=server.cert.pem
    right=%any
    rightauth=eap-mschapv2
    rightsourceip=10.31.2.0/24
    rightsendcert=never
    eap_identity=%any
    dpdaction=clear
    fragmentation=yes
    auto=add

conn windows7
    keyexchange=ikev2
    ike=aes256-sha1-modp1024!
    rekey=no
    left=%defaultroute
    leftauth=pubkey
    leftsubnet=0.0.0.0/0
    leftcert=server.cert.pem
    right=%any
    rightauth=eap-mschapv2
    rightsourceip=10.31.2.0/24
    rightsendcert=never
    eap_identity=%any
    auto=add
EOF

cat > /etc/strongswan/strongswan.conf<<EOF
charon {
    load_modular = yes
    duplicheck.enable = no
    compress = yes
    plugins {
            include strongswan.d/charon/*.conf
    }
    dns1 = 8.8.8.8
    dns2 = 8.8.4.4
    nbns1 = 8.8.8.8
    nbns2 = 8.8.4.4
}

include strongswan.d/*.conf
EOF

cat > /etc/strongswan/ipsec.secrets<<EOF
: RSA serverKey.pem
: PSK "myPskPass"
myUser  : EAP "myPass"
myUser %any : XAUTH "myPass"
EOF

if ! systemctl is-active firewalld > /dev/null; then
    systemctl start firewalld.service
fi

firewall-cmd --permanent --add-service="ipsec"
firewall-cmd --permanent --add-port=500/udp
firewall-cmd --permanent --add-port=4500/udp
firewall-cmd --permanent --add-masquerade
firewall-cmd --reload

systemctl enable strongswan.service
systemctl start strongswan.service
systemctl restart firewalld.service