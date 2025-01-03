# 2025-01-03 03:49:03 by RouterOS 7.14.3
# software id = TH8Z-JV23
#
# model = RBD52G-5HacD2HnD
# serial number = C6140E5CB0E2
/interface bridge
add admin-mac=2C:C8:1B:8F:84:B4 auto-mac=no comment=defconf name=bridge \
    port-cost-mode=short
/interface wireless
set [ find default-name=wlan1 ] band=2ghz-b/g/n channel-width=20/40mhz-XX \
    comment="2 GHz" country=russia disabled=no distance=indoors frequency=\
    auto installation=indoor mode=ap-bridge ssid=cat-house-2g \
    wireless-protocol=802.11
set [ find default-name=wlan2 ] band=5ghz-a/n/ac channel-width=\
    20/40/80mhz-XXXX comment="5 GHz" country=russia disabled=no distance=\
    indoors frequency=auto installation=indoor mode=ap-bridge ssid=cat-house \
    wireless-protocol=802.11
/interface ethernet
set [ find default-name=ether1 ] disabled=yes name=ether1-wan2
/interface wireless manual-tx-power-table
set wlan1 comment="2 GHz"
set wlan2 comment="5 GHz"
/interface wireless nstreme
set wlan1 comment="2 GHz"
set wlan2 comment="5 GHz"
/interface list
add comment=defconf name=WAN
add comment=defconf name=LAN
/interface lte apn
set [ find default=yes ] ip-type=ipv4 use-network-apn=no
/interface wireless security-profiles
set [ find default=yes ] authentication-types=wpa2-psk mode=dynamic-keys \
    supplicant-identity=MikroTik
/ip pool
add name=dhcp ranges=192.168.88.200-192.168.88.254
add name=vpn ranges=10.0.0.10-10.0.0.20
/ip dhcp-server
add address-pool=dhcp interface=bridge lease-time=10m name=defconf
/ip smb users
set [ find default=yes ] disabled=yes
/ppp profile
set *0 local-address=192.168.88.1 remote-address=vpn
/interface pppoe-client
add add-default-route=yes allow=pap comment="MTC PPPoE" disabled=no \
    interface=ether2 keepalive-timeout=disabled name=ppoe-wan1 profile=\
    default-encryption user=ep795258434998_serv201
/routing bgp template
set default disabled=no output.network=bgp-networks
/routing ospf instance
add disabled=no name=default-v2
/routing ospf area
add disabled=yes instance=default-v2 name=backbone-v2
/snmp community
set [ find default=yes ] addresses=192.168.88.0/24
/interface bridge port
add bridge=bridge comment=defconf ingress-filtering=no interface=ether3 \
    internal-path-cost=10 path-cost=10
add bridge=bridge comment=defconf ingress-filtering=no interface=ether4 \
    internal-path-cost=10 path-cost=10
add bridge=bridge comment=defconf ingress-filtering=no interface=ether5 \
    internal-path-cost=10 path-cost=10
add bridge=bridge comment=defconf ingress-filtering=no interface=wlan1 \
    internal-path-cost=10 path-cost=10
add bridge=bridge comment=defconf ingress-filtering=no interface=wlan2 \
    internal-path-cost=10 path-cost=10
/ip firewall connection tracking
set udp-timeout=10s
/ip neighbor discovery-settings
set discover-interface-list=LAN
/ip settings
set max-neighbor-entries=8192
/ipv6 settings
set disable-ipv6=yes max-neighbor-entries=8192
/interface l2tp-server server
set default-profile=default enabled=yes use-ipsec=required
/interface list member
add comment=defconf interface=bridge list=LAN
add comment=defconf interface=ether1-wan2 list=WAN
add interface=ppoe-wan1 list=WAN
/interface ovpn-server server
set auth=sha1,md5
/interface pptp-server server
# PPTP connections are considered unsafe, it is suggested to use a more modern VPN protocol instead
set authentication=pap,chap,mschap1,mschap2
/ip address
add address=192.168.88.1/16 comment=defconf interface=bridge network=\
    192.168.0.0
add address=213.138.79.54/30 interface=ether1-wan2 network=213.138.79.52
add address=10.66.83.193 disabled=yes interface=*A network=10.66.83.0
/ip cloud
set update-time=no
/ip dhcp-client
add comment=defconf default-route-distance=2 interface=ether1-wan2 \
    use-peer-dns=no
/ip dhcp-server network
add address=192.168.0.0/16 comment=defconf dns-server=192.168.88.1 gateway=\
    192.168.88.1 netmask=16
/ip dns
set allow-remote-requests=yes servers=8.8.8.8,8.8.4.4
/ip dns static
add address=192.168.88.1 comment=defconf name=router.lan
add address=127.0.0.1 name=europaplus.ru
/ip firewall filter
add action=accept chain=input dst-port=1723 in-interface-list=WAN protocol=\
    tcp
add action=accept chain=input dst-port=1701,500,4500 in-interface-list=WAN \
    protocol=udp
add action=accept chain=input in-interface-list=WAN protocol=ipsec-esp
add action=accept chain=input comment="For WebFig oin WAN" dst-port=9090 \
    in-interface-list=WAN protocol=tcp
add action=drop chain=input comment="drop external dns" dst-port=53 \
    in-interface=ether1-wan2 protocol=udp
add action=drop chain=input comment="drop external dns" dst-port=53 \
    in-interface=ether1-wan2 protocol=tcp
add action=accept chain=input comment="accept established,related" \
    connection-state=established,related
add action=drop chain=input connection-state=invalid
add action=accept chain=input comment="allow ICMP" in-interface=ether1-wan2 \
    protocol=icmp
add action=accept chain=input comment="allow Winbox" in-interface-list=LAN \
    port=8291 protocol=tcp
add action=accept chain=input comment="allow SSH" dst-port=46496 protocol=tcp
add action=drop chain=input comment="block everything else" in-interface=\
    ether1-wan2
add action=fasttrack-connection chain=forward comment=\
    "fast-track for established,related" connection-state=established,related \
    hw-offload=yes
add action=accept chain=forward comment="accept established,related" \
    connection-state=established,related
add action=drop chain=forward connection-state=invalid
add action=drop chain=forward comment=\
    "drop access to clients behind NAT form WAN" connection-nat-state=!dstnat \
    connection-state=new in-interface=ether1-wan2
/ip firewall mangle
add action=mark-routing chain=prerouting disabled=yes new-routing-mark=*400 \
    passthrough=no src-address-list=blacktemple-vpn
/ip firewall nat
add action=masquerade chain=srcnat comment="defconf: masquerade" \
    ipsec-policy=out,none out-interface-list=WAN
add action=dst-nat chain=dstnat comment="rasp-4-m-b-3 150" dst-address=\
    80.80.99.170 dst-port=50150 protocol=tcp to-addresses=192.168.88.150 \
    to-ports=22
add action=dst-nat chain=dstnat comment="orange-5-1 512GB 155 - SSH" \
    dst-address=80.80.99.170 dst-port=50155 protocol=tcp to-addresses=\
    192.168.88.155 to-ports=22
add action=dst-nat chain=dstnat comment="orange-5-2 256GB 151 - SSH" \
    dst-address=80.80.99.170 dst-port=50151 protocol=tcp to-addresses=\
    192.168.88.151 to-ports=22
add action=dst-nat chain=dstnat comment="orange-5-2 256GB 151 - Docker" \
    dst-address=80.80.99.170 dst-port=41945 protocol=tcp to-addresses=\
    192.168.88.151 to-ports=2375
add action=dst-nat chain=dstnat comment="orange-5-2 256GB 151 - PostgreSQL" \
    dst-address=80.80.99.170 dst-port=41950 protocol=tcp to-addresses=\
    192.168.88.151 to-ports=25432
add action=dst-nat chain=dstnat comment="orange-5-1 512GB 155 - KUBECTL" \
    dst-address=80.80.99.170 dst-port=6443 protocol=tcp to-addresses=\
    192.168.88.155 to-ports=6443
add action=dst-nat chain=dstnat comment="orange-5-2 256GB 151 - HTTP/HTTPS" \
    dst-address=80.80.99.170 dst-port=80,443 protocol=tcp to-addresses=\
    192.168.88.151
add action=redirect chain=dstnat comment="Static DNS" dst-port=53 protocol=\
    tcp to-ports=53
add action=redirect chain=dstnat comment="Static DNS" dst-port=53 protocol=\
    udp to-ports=53
add action=masquerade chain=srcnat comment="Hairpin NAT" dst-address=\
    192.168.88.0/24 protocol=tcp src-address=192.168.88.0/24
/ip service
set telnet disabled=yes
set ftp disabled=yes
set www port=9090
set ssh port=46496
set api address=192.168.88.0/24 disabled=yes
set api-ssl address=192.168.88.0/24 disabled=yes
/ip smb shares
set [ find default=yes ] directory=/flash/pub
/ip ssh
set strong-crypto=yes
/ppp secret
add name=zen
/routing bfd configuration
add disabled=no
/snmp
set contact=zabbix enabled=yes location=zabbix trap-generators="" \
    trap-version=2
/system clock
set time-zone-name=Europe/Moscow
/system logging
add topics=firewall
add topics=natpmp
/system note
set show-at-login=no
/system ntp client
set enabled=yes
/system ntp client servers
add address=0.ru.pool.ntp.org
add address=1.ru.pool.ntp.org
add address=2.ru.pool.ntp.org
add address=3.ru.pool.ntp.org
/system scheduler
add interval=18h name=Check-WiFi-Loop on-event=CheckWiFiStatus policy=\
    ftp,reboot,read,write,policy,test,password,sniff,sensitive,romon \
    start-date=2023-05-10 start-time=17:00:00
add interval=1d name=CheckWiFi2 on-event=CheckWiFiStatus policy=\
    ftp,reboot,read,write,policy,test,password,sniff,sensitive,romon \
    start-date=2023-05-10 start-time=09:25:00
/system script
add dont-require-permissions=no name=CheckWiFiStatus owner=zen policy=\
    ftp,reboot,read,write,policy,test,password,sniff,sensitive,romon source=":\
    local currenttime [/system clock get time]\r\
    \n:local wifiinterface \"wlan2\"\r\
    \n\r\
    \n:log info \"Check wi-fi status \$currenttime\"\r\
    \n\r\
    \n:local status [/interface wireless get \$wifiinterface disabled]\r\
    \n:if (\$status = true) do={\r\
    \n    /interface wireless set \$wifiinterface disabled=no\r\
    \n    :log info \"WiFi \$wifiinterface enabled\"\r\
    \n}"
/tool bandwidth-server
set enabled=no
/tool mac-server
set allowed-interface-list=LAN
/tool mac-server mac-winbox
set allowed-interface-list=LAN
/tool sniffer
set file-name=tv-sniff.pcap filter-interface=wlan2 filter-ip-protocol=tcp \
    filter-mac-address=10:38:1F:76:AD:96/FF:FF:FF:FF:FF:FF only-headers=yes \
    streaming-enabled=yes
