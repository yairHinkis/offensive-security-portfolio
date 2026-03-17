#!/bin/bash

domain=$1
RED="\033[1;31m"
RESET="\033[0m"

subdomain_path=$domain/subdomains
screenshot_path=$domain/screenshots
scan_path=$domain/scans

if [ ! -d "$domain" ];then
    mkdir $domain
fi
if [ ! -d "$subdomain_path" ];then
    mkdir $subdomain_path
fi
if [ ! -d "$screenshot_path" ];then
    mkdir $screenshot_path
fi
if [ ! -d "$scan_path" ];then
    mkdir $scan_path
fi

echo -e "${RED} [+] Launching subfinder ... ${RESET}"
subfinder -d $domain > $subdomain_path/found.txt

echo -e "${RED} [+] Launching assetfinder ... ${RESET}"
assetfinder $domain | grep $domain >> $subdomain_path/found.txt

echo -e "${RED} [+] Launching amass ... ${RESET}"
amass enum -d $domain >> $subdomain_path/found.txt

echo -e "${RED} [+] Finding alive subdomains ... ${RESET}"
cat $subdomain_path/found.txt | grep $domain | sort -u | httprobe -prefer-https | grep 'https' | sed 's/https\?:\/\///' | tee -a $subdomain_path/alive.txt 

echo -e "${RED} [+] Finding alive subdomains with more details ... ${RESET}"
cat $subdomain_path/found.txt | grep $domain | sort -u | httpx-toolkit -status-code -title | grep 'https' | tee -a $subdomain_path/detailed_alive.txt

echo -e "${RED} [+] Taking screenshots of alive subdomains ... ${RESET}"
gowitness scan file -f $subdomain_path/alive.txt --screenshot-path $screenshot_path/ --write-db

echo -e "${RED} [+] Running nmap on alive subdomains ... ${RESET}"
nmap -iL $subdomain_path/alive.txt -T4 -oN $scan_path/nmap.txt
