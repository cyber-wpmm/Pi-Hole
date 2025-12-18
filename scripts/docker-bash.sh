#!/bin/bash
# Automate the addition of blocklists in bulk using sqlite3

# Check if the Pi-hole Docker container is running
if ! sudo docker ps | grep -q pihole; then
  echo "Error: Pi-hole container is not running."
  exit 1
fi

# Define the blocklists to add
# Feel free to remove or add URLs as needed. 

BLOCKLISTS=(
  "https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts"
  "https://adaway.org/hosts.txt"
  "https://v.firebog.net/hosts/AdguardDNS.txt"
  "https://v.firebog.net/hosts/Admiral.txt"
  "https://raw.githubusercontent.com/anudeepND/blacklist/master/adservers.txt"
  "https://v.firebog.net/hosts/Easylist.txt"
  "https://pgl.yoyo.org/adservers/serverlist.php?hostformat=hosts&showintro=0&mimetype=plaintext"
  "https://raw.githubusercontent.com/FadeMind/hosts.extras/master/UncheckyAds/hosts"
  "https://raw.githubusercontent.com/bigdargon/hostsVN/master/hosts"
  "https://raw.githubusercontent.com/PolishFiltersTeam/KADhosts/master/KADhosts.txt"
  "https://raw.githubusercontent.com/FadeMind/hosts.extras/master/add.Spam/hosts"
  "https://v.firebog.net/hosts/static/w3kbl.txt"
  "https://raw.githubusercontent.com/matomo-org/referrer-spam-blacklist/master/spammers.txt"
  "https://someonewhocares.org/hosts/zero/hosts"
  "https://raw.githubusercontent.com/VeleSila/yhosts/master/hosts"
  "https://winhelp2002.mvps.org/hosts.txt"
  "https://v.firebog.net/hosts/neohostsbasic.txt"
  "https://raw.githubusercontent.com/RooneyMcNibNug/pihole-stuff/master/SNAFU.txt"
  "https://paulgb.github.io/BarbBlock/blacklists/hosts-file.txt"
  "https://v.firebog.net/hosts/Easyprivacy.txt"
  "https://raw.githubusercontent.com/FadeMind/hosts.extras/master/add.2o7Net/hosts"
)

# Access the Pi-hole gravity database and insert blocklists
sudo docker exec -it pihole sqlite3 /etc/pihole/gravity.db <<EOF
$(for url in "${BLOCKLISTS[@]}"; do
  echo "INSERT OR IGNORE INTO adlist (address) VALUES ('$url');"
done)
.exit
EOF

# Check if the sqlite3 command succeeded
if [ $? -ne 0 ]; then
  echo "Error: Failed to add blocklists to gravity.db."
  exit 1
fi

# Update gravity to apply the new blocklists
sudo docker exec -it pihole pihole -g