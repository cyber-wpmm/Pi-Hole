# Pi-hole Setup Guide

This guide documents the steps to install and configure [Pi-hole](https://pi-hole.net/) on a Raspberry Pi for network-wide ad-blocking. This documentation will not include the instllation process of a Linux on the Pi.

I have Ubuntu 24.04.2 LTS server running on my [Raspberry Pi 4 model B](https://www.raspberrypi.com/products/raspberry-pi-4-model-b/specifications/).
I am planning to have Pi-Hole run on docker container. 

## Requirements
- Raspberry Pi (any model)
- Raspberry Pi OS (Debian-based, e.g. Ubuntu 22.04 or Raspberry Pi OS)
- Optional Docker
- Static IP address Configuration
- Internet connection
- Optional: SSH access

## Tools Used

- Pi-hole
- DNS / DHCP configuration
- SSH (optional)

## Step 1: Performing 
```bash
#Do this on your pi to know what the ip address is

ip a
#or
ifconfig

ssh username@ip_address
#enter your password

sudo apt update && upgrade -y 
```

## Step 2: Static IP configuration
### On Ubuntu server (Using Netplan)
Here I am using wlan0 instead of eth0 since my pi isn't physically connected to the router. To set up static IP address for the connection, you will need to edit the netplan yaml configuration file in /etc/netplan folder

```
sudo nano /etc/netplan/50-cloud-init.yaml
#note the name may be different with different OS.
```
```
network:
  version: 2
  ethernets:
    eth0:
      dhcp4: true
```
This is essentially what you might see in the default unconfigured 50-cloud-init.yaml file. We will have to manually insert the options we want. Since we are setting static IP addresses, we will need to turn off the DHCP and create default routes to your Router's IP address. 
```
network:
  version: 2
  renderer: networkd
  wifis:
    wlan0:
      dhcp4: no  #<-- Disabling DHCP for IPv4 Addresses
      addresses: [192.168.10.50/24] #<-- Static IP adderss of your 
      routes:
        - to: 0.0.0.0/0
          via: 102.168.10.1 #<-- Router IP address usually .1 at the end
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

```
#Installing docker's official install script:
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

sudo reboot

#Checking docker version
docker --version
docker compose --version

##Making directory for Pihole
mkdir pihole

cd pihole #I put my yml file in the pihole directory
nano docker-compose.yml
```

Paste the code from the [docker-pi-hole](https://github.com/pi-hole/docker-pi-hole)  
It will look something like this and you just need to change the important configurations:

```yaml
# More info at https://github.com/pi-hole/docker-pi-hole/ and https://docs.pi-hole.net/
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
    restart: unless-stopped

```

```
#Afterwards we create the container

sudo docker compose up -d

sudo docket ps #To check acttive containers

#go to the following url link in a browser:
#if you have your host ip address statically setup as 192.168.10.10
#then go to here:

192.168.10.10/admin
 
```

**You will be prompted with:**
"After installing Pi-hole for the first time, a password is generated and displayed to the user. The password cannot be retrieved later on, but it is possible to set a new password (or explicitly disable the password by setting an empty password) using the command"
```
#To access the bash shell of the pihole container:
sudo docker exec -it pihole /bin/bash

#Note: If you changed the container name to something else other than pihole changed it throughout the commands.

#pihole set new password
pihole setpassword YourPassword
```

**Here are some useful links for adding block (deny) lists or allow lists**
https://github.com/hagezi/dns-blocklists
https://github.com/r0xd4n3t/pihole-adblock-lists

**The following are the lists of blocklists I have used for my pihole**
- https://raw.githubusercontent.com/hagezi/dns-blocklists/main/adblock/pro.plus.txt
- https://raw.githubusercontent.com/hagezi/dns-blocklists/main/adblock/fake.txt
- https://raw.githubusercontent.com/hagezi/dns-blocklists/main/adblock/tif.txt
- https://raw.githubusercontent.com/hagezi/dns-blocklists/main/adblock/tif.medium.txt
- https://raw.githubusercontent.com/hagezi/dns-blocklists/main/adblock/doh-vpn-proxy-bypass.txt
- https://raw.githubusercontent.com/r0xd4n3t/pihole-adblock-lists/main/pihole_adlists.txt
- https://raw.githubusercontent.com/hagezi/dns-blocklists/main/adblock/urlshortener.txt
- https://raw.githubusercontent.com/hagezi/dns-blocklists/main/adblock/spam-tlds-adblock.txt
- https://raw.githubusercontent.com/hagezi/dns-blocklists/main/adblock/gambling.txt
- https://raw.githubusercontent.com/hagezi/dns-blocklists/main/adblock/gambling.medium.txt
- https://raw.githubusercontent.com/matomo-org/referrer-spam-blacklist/master/spammers.txt
- https://raw.githubusercontent.com/anudeepND/blacklist/master/adservers.txt
- 

### What's next?
After adding the deny lists, it is also important to add white lists or allow lists so that some of the important domains can be accessed and are not blocked. 

https://raw.githubusercontent.com/anudeepND/whitelist/master/domains/whitelist.txt

### Changing the DNS for Clients 
Since I do not have access to my router, as I am using CGNAT. I will have to manually configure each client's device to set their dns server to point to the IP address of the pihole docker, more specifically my Pi 5 since the docker uses Bridge mode as default. 

```
nmcli connection show

nmcli connection modify WIFI_NAME ipv4.dns PI_IPv4_Address

nmcli connection modify WIFI_NAME ipv4.ignore-auto-dns yes

nmcli connection up WIFI_NAME

#To verify if DNS has changed:
nmcli device show wlp4s0 | grep IP4.DNS

#wlp4s0 can be eth0 too depending on your device's network interface
```

