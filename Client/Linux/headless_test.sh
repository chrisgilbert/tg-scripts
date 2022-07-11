#!/bin/bash

#configured and ran against Linux Client version 1.0.37 against Debian Bullseye
red=$'\e[1;31m'
grn=$'\e[1;32m'
yel=$'\e[1;33m'
end=$'\e[0m'

##Required services
declare -a req_services=("systemd-resolved")
##Informational services
declare -a services=("chronyd" "ntpd")


iss="$(openssl s_client -connect twingate.com:443 2>/dev/null | openssl x509 -noout -issuer)"
resp="$(curl --fail -sL -w '%{http_code}' 'https://www.twingate.com/' -o /dev/null)"
 

# check services by systemctl
if [[ $(twingate status) = online ]]; then
    printf "%s\n" "${grn}Twingate Client is online.${end}"
else 
    printf "%s\n" "${red}Twingate Client is not online.${end}"
    printf "%s\n" "Running diagnostic checks..."
   
    for req_service in "${req_services[@]}"; do
        if [[ $(systemctl show -p SubState --value $req_service) = running ]]; then
            printf "%s\n" "${grn}Required service $req_service is running.${end}"
        else
            printf "%s\n" "${red}Error: Required service $req_service is not running.${end}"
        fi
    done
    for service in "${services[@]}"; do
        if [[ $(systemctl show -p SubState --value $service) = running ]]; then
            printf "%s\n" "${grn}Service $service is running.${end}"
        else
            printf "%s\n" "${yel}Info: Service $service is not running or installed.${end}"
        fi
    done
    if [[ $iss= "issuer=C = US, O = Let's Encrypt, CN = R3" ]]; then
        printf "%s\n" "${grn}SSL certificate issuer matches${end}"
    else
        printf "%s\n" "${red}Error: SSL certificate issuer is not expected. Expected 'issuer=C = US, O = Let's Encrypt, CN = R3' but returned $iss ${end}"
    fi
    if [[ $resp = 200 ]]; then
        printf "%s\n" "${grn}HTTP response to twingate.com OK: $resp. ${end}"
    else
        printf "%s\n" "${red}HTTP response to twingate.com not OK: $resp. ${end}"
    fi
    printf "%s\n" "### TWINGATE CLIENT LOGS ## START ###"
    sudo journalctl -u twingate --since "10 minutes ago" --no-pager
    printf "%s\n" "### TWINGATE CLIENT LOGS ## END ###"
fi
