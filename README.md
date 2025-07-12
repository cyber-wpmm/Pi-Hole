# Pi-hole Setup and Configuration Guide

*Chicken Little - Win*  
*Date: 2025-07-09*

---

## Overview

This guide covers installing and configuring Pi-hole on a Raspberry Pi, including setting up a static IP, Docker installation, Pi-hole container setup, adding blocklists, password management, and DNS client configuration.

**Note:**
Assuming you have installed a Linux Operating System on your SD card with Raspberry Pi Imager, and have valid internet configuration (either Etherent or Wifi).
## Step 1: Check IP and Basic Commands

```bash
ip a
# or
ifconfig

# SSH into Raspberry Pi
ssh username@ip_address

# Update system
sudo apt update && sudo apt upgrade -y
```

## Step 2: Static IP configuration
### On Ubuntu server (Using Netplan)
Here I am using wlan0 instead of eth0 since my pi isn't physically connected to the router. To set up static IP address for the connection, you will need to edit the netplan yaml configuration file in /etc/netplan folder

I am using kitty terminal on my host so sometimes I am not able to nano in ssh session
**If you cannot nano during the SSH session:**
```bash
export TERM=xterm-256color
```

```bash
sudo nano /etc/netplan/50-cloud-init.yaml
#note the name may be different with different OS.
``` 
This is essentially what you may see if you have not connect to any network yet. 

```
network:
  version: 2
  ethernets:
    eth0:
      dhcp4: true
```
This is essentially what you might see in the default unconfigured 50-cloud-init.yaml file. However, with Raspberry Pi Imager, before flashing the SD card with and OS image, there is a setting where you can preconfigured the wifi connection, hostnames, and other usernames/password. 

We will have to manually insert the options we want. Since we are setting static IP addresses, we will need to turn off the DHCP and create default routes to your Router's IP address. 
```
network:
  version: 2
  renderer: networkd
  wifis:
    wlan0:
      dhcp4: no  #<-- Disabling DHCP for IPv4 Addresses
      addresses: [192.168.10.50/24] #<-- Static IP adderss of your choice (must be the same subnet)
      routes:
        - to: 0.0.0.0/0
          via: 102.168.10.1 #<-- Gateway/ Router IP address usually .1 at the end
      nameservers:
        addresses: [1.1.1.1, 8.8.8.8] #<-- Cloudflare and Google's DNS server
      access-points:
        "YourSSID": #<-- Wifi-Name
          password: "YourWiFiPassword"
```

```bash
#To Test if it is properly set up
ip a #check for ip address
ping google.com #See if there is any replies
```


### On PI OS (Using NetworkManager nmcli)
```bash
#Listing the known connections with the names
sudo nmcli connection show

#Change the name to your own 
nmcli connection modify "Wired connection 1" ipv4.addresses 192.168.1.100/24  #Change it to your choice

nmcli connection modify "Wired connection 1" ipv4.gateway 192.168.1.1  #must be in the same subnet as your ip

nmcli connection modify "Wired connection 1" ipv4.dns "8.8.8.8 1.1.1.1" 
nmcli connection modify "Wired connection 1" ipv4.method manual

#(Optional) Disabling IPv6
nmcli connection modify "Wired connection 1" ipv6.method ignore

nmcli connection down "Wired connection 1"
nmcli connection up "Wired connection 1"

#Checking if static IP address is implemented
ip a

#If this doesn't work rebooting the pi would be better
reboot

#If you ran into ssh error 
sudo nano /home/YOUR_USER/.ssh/known_hosts
#Edit out the existing host keys for the static IP address you have set and Retry SSH

```
## Step 3: Installing Docker 

Here is the [Official Guide](https://docs.docker.com/compose/install/linux/#install-using-the-repository)

```bash
#Installing docker's official install script:
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

#This allows user to run docker with root privelege without requiring to type sudo again and again (OPTIONAL)
sudo usermod -aG docker $USER

sudo reboot

#Checking docker version
docker --version
docker compose version

##Making directory for Pihole
mkdir pihole

cd pihole #I put my yml file in the pihole directory
nano docker-compose.yml
```

Paste the code from the [docker-pi-hole](https://github.com/pi-hole/docker-pi-hole)  
It will look something like this and you just need to change the important configurations:

```yml
# More info at https://github.com/pi-hole/docker-pi-hole/ and https://docs.pi-hole.net/
#By Default this configuration will make Pi-Hole use bridge network. 
services:
  pihole:
    container_name: pihole
    image: pihole/pihole:latest
    ports:
      # DNS Ports
      - "53:53/tcp"
      - "53:53/udp"
      # Default HTTP Port
      - "80:80/tcp"
      # Default HTTPs Port. FTL will generate a self-signed certificate
      - "443:443/tcp"
      # Uncomment the line below if you are using Pi-hole as your DHCP server
      #- "67:67/udp"
      # Uncomment the line below if you are using Pi-hole as your NTP server
      #- "123:123/udp"
    environment:
      # Set the appropriate timezone for your location (https://en.wikipedia.org/wiki/List_of_tz_database_time_zones), e.g:
      TZ: 'Europe/London'
      # Set a password to access the web interface. Not setting one will result in a random password being assigned
      FTLCONF_webserver_api_password: 'correct horse battery staple'
      # If using Docker's default `bridge` network setting the dns listening mode should be set to 'all'
      FTLCONF_dns_listeningMode: 'all'
    # Volumes store your data between container upgrades
    volumes:
      # For persisting Pi-hole's databases and common configuration file
      - './etc-pihole:/etc/pihole'
      # Uncomment the below if you have custom dnsmasq config files that you want to persist. Not needed for most starting fresh with Pi-hole v6. If you're upgrading from v5 you and have used this directory before, you should keep it enabled for the first v6 container start to allow for a complete migration. It can be removed afterwards. Needs environment variable FTLCONF_misc_etc_dnsmasq_d: 'true'
      #- './etc-dnsmasq.d:/etc/dnsmasq.d'
    cap_add:
      # See https://github.com/pi-hole/docker-pi-hole#note-on-capabilities
      # Required if you are using Pi-hole as your DHCP server, else not needed
      - NET_ADMIN
      # Required if you are using Pi-hole as your NTP client to be able to set the host's system time
      - SYS_TIME
      # Optional, if Pi-hole should get some more processing time
      - SYS_NICE
    restart: unless-stopped
```

It is important to modify this based on what you will be using for (DHCP, NTP server). Since I am not able to have access to the router itself (Using CGNAT), i will just be changing the DNS server of each clients to the IP addess of my raspberry pi. For me in came down to this:

```yml
services:
  pihole:
    container_name: pihole
    image: pihole/pihole:latest
    ports:
      # DNS Ports
      - "53:53/tcp"
      - "53:53/udp"
      - "80:80/tcp"
      - "443:443/tcp"
    environment:
      TZ: 'Pacific/Auckland'
      FTLCONF_webserver_api_password: 'YourPassword'
      FTLCONF_dns_listeningMode: 'all' #This is important if you are using default bridge network settings
    volumes:
      - './etc-pihole:/etc/pihole'
      - './etc-dnsmasq.d:/etc/dnsmasq.d'
    restart: unless-stopped
```
Before you create the container, it is important to check if the ports are used.
Usually port 53 can be used by service resolv for DNS. 

```bash
sudo ss -tulpn

#Here you can check which ports are being used by which services.
#systemd-resolve is using port 53 so we will stop the service and disable it to not have conflict with the pihole.

sudo systemctl disable systemd-resolved
sudo systemctl stop systemd-resolved



#Temporarily we will still need to point to a valid DNS server in our resolv.conf
sudo nano /etc/resolv.conf

#add or change nameserver to google's DNS server
nameserver 8.8.8.8

#Ctrl+O and Ctrl + X || Save and Exit
```


```bash
#Afterwards we create the container

docker compose up -d
#OR
sudo docker compose up -d

docket ps #To check acttive containers


#go to the following url link in a browser:
#if you have your host ip address statically setup as 192.168.10.10
#then go to here:

192.168.10.10/admin #your Pi's Ip address will/might be different
 
```

**If you run into error where password is not working or see the following issue:**
```
"After installing Pi-hole for the first time, a password is generated and displayed to the user.
The password cannot be retrieved later on, but it is possible to set a new password (or explicitly disable the password by setting an empty password) using the command"
```
```bash
#To access the bash shell of the pihole container:
sudo docker exec -it pihole /bin/bash

#Note: If you changed the container name to something else other than pihole changed it throughout the commands.

#pihole set new password
pihole setpassword YourPassword
```

To add the blocklists quickly, we would need to access the gravity.db file. 

```bash
#Install sqlite3
sudo apt install sqlite3
```

```bash
sudo sqlite3 /etc-pihole/gravity.db

INSERT OR IGNORE INTO adlist (address) VALUES
('https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts'),
('https://adaway.org/hosts.txt'),
('https://v.firebog.net/hosts/AdguardDNS.txt'),
('https://v.firebog.net/hosts/Admiral.txt'),
('https://raw.githubusercontent.com/anudeepND/blacklist/master/adservers.txt'),
('https://v.firebog.net/hosts/Easylist.txt'),
('https://pgl.yoyo.org/adservers/serverlist.php?hostformat=hosts&showintro=0&mimetype=plaintext'),
('https://raw.githubusercontent.com/FadeMind/hosts.extras/master/UncheckyAds/hosts'),
('https://raw.githubusercontent.com/bigdargon/hostsVN/master/hosts'),
('https://raw.githubusercontent.com/PolishFiltersTeam/KADhosts/master/KADhosts.txt'),
('https://raw.githubusercontent.com/FadeMind/hosts.extras/master/add.Spam/hosts'),
('https://v.firebog.net/hosts/static/w3kbl.txt'),
('https://raw.githubusercontent.com/matomo-org/referrer-spam-blacklist/master/spammers.txt'),
('https://someonewhocares.org/hosts/zero/hosts'),
('https://raw.githubusercontent.com/VeleSila/yhosts/master/hosts'),
('https://winhelp2002.mvps.org/hosts.txt'),
('https://v.firebog.net/hosts/neohostsbasic.txt'),
('https://raw.githubusercontent.com/RooneyMcNibNug/pihole-stuff/master/SNAFU.txt'),
('https://paulgb.github.io/BarbBlock/blacklists/hosts-file.txt'),
('https://v.firebog.net/hosts/Easyprivacy.txt'),
('https://raw.githubusercontent.com/FadeMind/hosts.extras/master/add.2o7Net/hosts'),
('https://raw.githubusercontent.com/crazy-max/WindowsSpyBlocker/master/data/hosts/spy.txt'),
('https://hostfiles.frogeye.fr/firstparty-trackers-hosts.txt'),
('https://raw.githubusercontent.com/Perflyst/PiHoleBlocklist/master/android-tracking.txt'),
('https://raw.githubusercontent.com/Perflyst/PiHoleBlocklist/master/SmartTV.txt'),
('https://raw.githubusercontent.com/Perflyst/PiHoleBlocklist/master/AmazonFireTV.txt'),
('https://gitlab.com/quidsup/notrack-blocklists/raw/master/notrack-blocklist.txt'),
('https://raw.githubusercontent.com/DandelionSprout/adfilt/master/Alternate%20versions%20Anti-Malware%20List/AntiMalwareHosts.txt'),
('https://v.firebog.net/hosts/Prigent-Crypto.txt'),
('https://raw.githubusercontent.com/FadeMind/hosts.extras/master/add.Risk/hosts'),
('https://bitbucket.org/ethanr/dns-blacklists/raw/8575c9f96e5b4a1308f2f12394abd86d0927a4a0/bad_lists/Mandiant_APT1_Report_Appendix_D.txt'),
('https://phishing.army/download/phishing_army_blocklist_extended.txt'),
('https://gitlab.com/quidsup/notrack-blocklists/raw/master/notrack-malware.txt'),
('https://v.firebog.net/hosts/RPiList-Malware.txt'),
('https://raw.githubusercontent.com/Spam404/lists/master/main-blacklist.txt'),
('https://raw.githubusercontent.com/AssoEchap/stalkerware-indicators/master/generated/hosts'),
('https://urlhaus.abuse.ch/downloads/hostfile/'),
('https://lists.cyberhost.uk/malware.txt'),
('https://malware-filter.gitlab.io/malware-filter/phishing-filter-hosts.txt'),
('https://v.firebog.net/hosts/Prigent-Malware.txt'),
('https://raw.githubusercontent.com/jarelllama/Scam-Blocklist/main/lists/wildcard_domains/scams.txt'),
('https://v.firebog.net/hosts/RPiList-Phishing.txt'),
('https://v.firebog.net/hosts/Prigent-Ads.txt'),
('https://cdn.jsdelivr.net/gh/hagezi/dns-blocklists@latest/domains/native.amazon.txt'),
('https://cdn.jsdelivr.net/gh/hagezi/dns-blocklists@latest/domains/native.apple.txt'),
('https://cdn.jsdelivr.net/gh/hagezi/dns-blocklists@latest/domains/native.winoffice.txt'),
('https://cdn.jsdelivr.net/gh/hagezi/dns-blocklists@latest/domains/native.tiktok.extended.txt'),
('https://small.oisd.nl/rpz'),
('https://urlhaus.abuse.ch/downloads/hostfile'),
('https://cdn.jsdelivr.net/gh/hagezi/dns-blocklists@latest/rpz/tif.mini.txt');

.exit

docker exec -it pihole pihole -g
```
**Here are some useful links for adding block (deny) lists or allow lists**
- https://github.com/hagezi/dns-blocklists
- https://github.com/r0xd4n3t/pihole-adblock-lists
- 

### Changing the DNS for Clients 
Since I do not have access to my router, as I am using CGNAT. 
I will have to manually configure each client's device to set their dns server to point to the IP address of the pihole docker, more specifically my Pi 5 since the docker uses Bridge mode as default. 

```
nmcli connection show

nmcli connection modify WIFI_NAME ipv4.dns PI_IPv4_Address

nmcli connection modify WIFI_NAME ipv4.ignore-auto-dns yes

nmcli connection up WIFI_NAME

#To verify if DNS has changed:
nmcli device show wlp4s0 | grep IP4.DNS

#wlp4s0 can be eth0 too depending on your device's network interface
```

### Changing DNS for Router
If you have access to the router, then change the DNS setting to point to the Pi's Private IP address in the DHCP settings.  
Makes sure that the private IP for Pi is also reserved, and add secondary DNS (Optional) in case your PI is not accessible anymore. 

### What's next?
After adding the deny lists, it is also important to add white lists or allow lists so that some of the important domains can be accessed and are not blocked. 

https://raw.githubusercontent.com/anudeepND/whitelist/master/domains/whitelist.txt
