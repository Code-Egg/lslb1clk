#!/bin/bash
# /***************************************************************
# LiteSpeed WebADC Latest
# ****************************************************************/
### Author: Cold Egg
CMDFD='/opt'
LSDIR='/usr/local/lslb'
LSCONF="${LSDIR}/conf/lslbd_config.xml"
LSVCONF="${LSDIR}/DEFAULT/conf/vhconf.xml"
LICENSE='TRIAL'
LSLB_CONFIG='default'
SCRIPTPATH="$( cd "$(dirname "$0")" ; pwd -P )"
ADC_LOCAL_IP=''
WP_LOCAL_IP=''
VULTR_API=''
VULTR_REGION=''
USER=''
GROUP=''
LSUSER=''
LSPASS=''
LSGROUP=''
OSNAMEVER=''
OSNAME=''
OSVER=''
BANNERDST=''
LS_VER='3.1.7'
LAN_IP_FILTER='10.'
FIREWALLLIST="22 80 443 8090 7090 7099"
EMAIL='test@example.com'
EPACE='        '
FPACE='    '

silent() {
  if [[ $debug ]] ; then
    "$@"
  else
    "$@" >/dev/null 2>&1
  fi
}

check_input(){
    if [ -z "${1}" ];then
        help_message 2
        exit 1
    fi
}

echoY() {
    echo -e "\033[38;5;148m${1}\033[39m"
}
echoG() {
    echo -e "\033[38;5;71m${1}\033[39m"
}
echoR()
{
    echo -e "\033[38;5;203m${1}\033[39m"
}
echow(){
    FLAG=${1}
    shift
    echo -e "\033[1m${EPACE}${FLAG}\033[0m${@}"
}

help_message(){
    case ${1} in
    "1")
        echoY 'Installation finished, please reopen the ssh console to see the banner.'
        if [ "${LSLB_CONFIG}" = 'scaling_vultr' ]; then
            echo "Check https://docs.litespeedtech.com/lsadc/ for more scaling information."
        fi    
    ;;
    "2")
        echo 'This script is for shorten your setup time for the WebADC. Without any option, the script will install the WebADC with default value and trial license.'
        echo -e "\033[1mOPTIONS\033[0m"
        echow '-L, --license'
        echo "${EPACE}${EPACE}Example: lslb1clk.sh -L, to use specified LSADC serial number."
        echow '--scaling-vultr'
        echo "${EPACE}${EPACE}Example: lslb1clk.sh --scaling-vultr. It will install LSADC with Vultr scaling demo config setup."
        echow '--uninstall'
        echo "${EPACE}${EPACE}Example: lslb1clk.sh --uninstall. It will uninstall LSADC."      
        echow '-H, --help'
        echo "${EPACE}${EPACE}Display help and exit." 
        exit 0
    ;;    
    esac
}

check_os()
{
    OSTYPE=$(uname -m)
    MARIADBCPUARCH=
    if [ -f /etc/redhat-release ] ; then
        OSVER=$(cat /etc/redhat-release | tr -dc '0-9.'|cut -d \. -f1)
        if [ ${?} = 0 ] ; then
            OSNAMEVER=CENTOS${OSVER}
            OSNAME=centos
        fi
    elif [ -f /etc/lsb-release ] ; then
        OSNAME=ubuntu
    elif [ -f /etc/debian_version ] ; then
        OSNAME=debian
    fi
}

path_update(){
    if [ "${OSNAME}" = "centos" ] ; then
        BANNERDST='/etc/profile.d/99-one-click.sh'
    elif [ "${OSNAME}" = 'ubuntu' ] || [ "${OSNAME}" = 'debian' ]; then        
        BANNERDST='/etc/update-motd.d/99-one-click'
    fi
}    

backup_old(){
    if [ -f ${1} ] && [ ! -f ${1}_old ]; then
       mv ${1} ${1}_old
    fi
}

validate_ipv4(){
    if [[ "${1}" =~ ^(([1-9]?[0-9]|1[0-9][0-9]|2([0-4][0-9]|5[0-5]))\.){3}([1-9]?[0-9]|1[0-9][0-9]|2([0-4][0-9]|5[0-5]))$ ]]; then
        echoG 'IP check pass'
    else
        echoR "IP ${1} does not match IPv4 format, exit!"; exit 1
    fi
}

verify_input_exit_loop(){
    if [ -z "${1}" ] ; then
        echo -e "\nPlease input non-empty value! \n"
    else
        echo -e "The value you input is: \e[31m${1}\e[39m"
        printf "%s"  "Please verify if it is correct. [n/Y] "
        read TMP_YN
        if [[ "${TMP_YN}" !=~ ^(n|N) ]]; then
            break
        fi    
    fi
}

get_lan_ipv4(){
    ### Filter IP start from 10.*
    if [ -z ${ADC_LOCAL_IP} ]; then 
        ADC_LOCAL_IP=$(ip -4 addr | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | grep -e "^${LAN_IP_FILTER}")
        FILTER_MATCH_NUM="$(ip -4 addr | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | grep -e "^${LAN_IP_FILTER}" | wc -l)"
        if [ "${FILTER_MATCH_NUM}" = '0' ]; then
            echoR "No IP mathc with ^${LAN_IP_FILTER} filter, please check manually! exit! "
            ip addr; exit 1
        elif [ "${FILTER_MATCH_NUM}" = '1' ]; then
            validate_ipv4 "${ADC_LOCAL_IP}"
            echoG "Found VPC IP: ${ADC_LOCAL_IP}" 
        else
            echoY "Found multiple IP match with ^${LAN_IP_FILTER} filter, please input it manually!"
            ip addr;
            while true; do
                printf "%s" "Please input Vultr ADC VPC IP: "
                read ADC_LOCAL_IP
                validate_ipv4 "${ADC_LOCAL_IP}"
                verify_input_exit_loop "${ADC_LOCAL_IP}"
            done 
        fi
    fi
    FILTER_NETMASK=$(ip -4 addr | grep "${ADC_LOCAL_IP}" | awk -F '/' '{ print $2 }' | cut -f 1 -d " ")
}

get_vultr_api(){
    if [ -z ${VULTR_API} ]; then 
        while true; do
            printf "%s" "Please input Vultr API string: "
            read VULTR_API
            verify_input_exit_loop "${VULTR_API}"
        done
    fi
}

get_node_IP(){
    if [ -z ${WP_LOCAL_IP} ]; then 
        while true; do
            printf "%s" "Please input Vultr backend node VPC IP: "
            read WP_LOCAL_IP
            validate_ipv4 "${WP_LOCAL_IP}"
            verify_input_exit_loop "${WP_LOCAL_IP}"
        done 
    fi
}

get_node_json(){
    ### Get node information via API and filter based on the node's VPC IP. 
    echoG 'curl vultr API v2'
    VULTR_OUTPUT_JSON=$(curl "https://api.vultr.com/v2/instances" -X GET -H "Authorization: Bearer ${VULTR_API}" \
      | jq '.instances' | jq -r --arg  WP_LOCAL_IP "$WP_LOCAL_IP" 'map(select(.internal_ip == "$WP_LOCAL_IP"))')
}

get_node_name(){
    ULTR_NODE_NAME=$(echo "${VULTR_OUTPUT_JSON}" | jq '.[].label')
    if [ -z ${ULTR_NODE_NAME} ]; then 
        while true; do
            printf "%s" "Please input Vultr backend node name: "
            read VULTR_NODE_NAME
            verify_input_exit_loop VULTR_NODE_NAME
        done
    fi
}

get_node_region(){
    VULTR_REGION=$(echo "${VULTR_OUTPUT_JSON}" | jq '.[].region')
    if [ -z ${VULTR_REGION} ]; then 
        while true; do
            printf "%s" "Please input 3 character airline code of your Vultr node region (Ex, for New York/New Jersey, it is ewr): "
            read VULTR_REGION
            verify_input_exit_loop VULTR_REGION
        done
    fi
}


ubuntu_pkg_system(){
    if [ -e /usr/sbin/dmidecode ]; then
        echoG 'dmidecode is already installed'
    else
        echoG 'Install dmidecode'
        silent apt-get install dmidecode -y
        [[ -e /usr/sbin/dmidecode ]] && echoG 'Install dmidecode Success' || echoR 'Install dmidecode Failed'
    fi
    if [ -e /usr/bin/netstat ]; then
        echoG 'netstat is already installed'
    else
        echoG 'Install net-tools'
        silent apt-get install net-tools -y
    fi
    if [ "${LSLB_CONFIG}" = 'scaling_vultr' ]; then
        if [ -e /usr/bin/jq ]; then
            echoG 'jq is already installed'
        else    
            echoG 'Install dmidecode'
            silent apt-get install jq -y
            [[ -e /usr/bin/jq ]] && echoG 'Install jq Success' || echoR 'Install jq Failed'
        fi
    fi
}

centos_pkg_system(){
    if [ -e /usr/sbin/dmidecode ]; then
        echoG 'dmidecode is already installed'
    else
        echoG 'Install dmidecode'
        silent yum install dmidecode -y
        [[ -e /usr/sbin/dmidecode ]] && echoG 'Install dmidecode Success' || echoR 'Install dmidecode Failed'
    fi
    if [ -e /usr/bin/netstat ]; then
        echoG 'netstat is already installed'
    else
        echoG 'Install net-tools'
        silent yum install net-tools -y
    fi       
    if [ "${LSLB_CONFIG}" = 'scaling_vultr' ]; then
        if [ -e /usr/bin/jq ]; then
            echoG 'jq is already installed'
        else    
            echoG 'Install dmidecode'
            silent yum install jq -y
            [[ -e /usr/bin/jq ]] && echoG 'Install jq Success' || echoR 'Install jq Failed'
        fi
    fi    
}

uninstall_msg(){
    printf '\033[31mUninstall LSLB, do you still want to continue? [y/N]\033[0m '
    read answer
    echo

    if [ "$answer" != "Y" ] && [ "$answer" != "y" ] ; then
        echoG "OK, exit script!"
        exit 0
    else
        echoG "Ok, will start uninstall process .."
        sleep 5
    fi
}

get_ip(){
    MYIP=$(curl -s http://checkip.amazonaws.com || printf "0.0.0.0")
}

provider_ck()
{
    if [ -e /sys/devices/virtual/dmi/id/product_uuid ] && [ "$(sudo cat /sys/devices/virtual/dmi/id/product_uuid | cut -c 1-3)" = 'EC2' ]; then
        PROVIDER='aws'
    elif [ "$(dmidecode -s bios-vendor)" = 'Google' ];then
        PROVIDER='google'
    elif [ "$(dmidecode -s bios-vendor)" = 'DigitalOcean' ];then
        PROVIDER='do'
    elif [ "$(dmidecode -s bios-vendor)" = 'Vultr' ];then
        PROVIDER='vultr'          
    elif [ "$(dmidecode -s system-product-name | cut -c 1-7)" = 'Alibaba' ];then
        PROVIDER='aliyun'
    elif [ "$(dmidecode -s system-manufacturer)" = 'Microsoft Corporation' ];then
        PROVIDER='azure'
    else
        PROVIDER='undefined'
    fi
}

os_hm_path()
{
    if [ ${PROVIDER} = 'aws' ] && [ -d /home/ubuntu ]; then
        HMPATH='/home/ubuntu'
    elif [ ${PROVIDER} = 'google' ] && [ -d /home/ubuntu ]; then
        HMPATH='/home/ubuntu'
    elif [ ${PROVIDER} = 'aliyun' ] && [ -d /home/ubuntu ]; then
        HMPATH='/home/ubuntu'
    else
        HMPATH='/root'
    fi
    ADMIN_PASS_PATH="${HMPATH}/.litespeed_password"
    DB_PASS_PATH="${HMPATH}/.db_password"
}

KILL_PROCESS(){
    PROC_NUM=$(pidof ${1})
    if [ ${?} = 0 ]; then
        kill -9 ${PROC_NUM}
    fi
}

ubuntu_sysupdate(){
    echoG 'System update'
    silent apt-get update
    silent DEBIAN_FRONTEND=noninteractive apt-get -y \
    -o Dpkg::Options::='--force-confdef' \
    -o Dpkg::Options::='--force-confold' upgrade
    silent DEBIAN_FRONTEND=noninteractive apt-get -y \
    -o Dpkg::Options::='--force-confdef' \
    -o Dpkg::Options::='--force-confold' dist-upgrade
}

centos_sysupdate(){
    echoG 'System update'
    silent yum update -y
    setenforce 0
}

check_vultr_platform(){
    if [ "${PROVIDER}" != 'vultr' ]; then
        echoY "Detect ${PROVIDER} platform is not Vultr!"
        printf "%s"  "Do you still want to continue? [y/N] "
        read TMP_YN
        if [[ "${TMP_YN}" !=~ ^(y|Y) ]]; then
            exit 1
        fi    
    fi
}

remove_file(){
    if [ -e ${1} ]; then
        rm -rf ${1}
    fi
}

gen_password(){
    if [ ! -f ${ADMIN_PASS_PATH} ]; then
        ADMIN_PASS=$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 16 ; echo '')
    else
        ADMIN_PASS=$(grep admin_pass ${ADMIN_PASS_PATH} | awk -F'"' '{print $2}')
    fi
}

gen_pass_file(){
    if [ -f "${ADMIN_PASS_PATH}" ]; then
        rm -f ${ADMIN_PASS_PATH}
    fi
    echoG 'Generate .litespeed_password file'
    touch ${ADMIN_PASS_PATH}
}

update_pass_file(){
    cat >> ${ADMIN_PASS_PATH} <<EOM
admin_pass="${ADMIN_PASS}"
EOM
}    

restart_lslb(){
    echoG 'Restart LiteSpeed WebADC'
    systemctl restart lslb
}

test_page(){
    local URL=$1
    local KEYWORD=$2
    local PAGENAME=$3

    rm -rf tmp.tmp
    wget --no-check-certificate -O tmp.tmp  $URL >/dev/null 2>&1
    grep "$KEYWORD" tmp.tmp  >/dev/null 2>&1

    if [ $? != 0 ] ; then
        echoR "Error: $PAGENAME failed."
        TESTGETERROR=yes
    else
        echoG "OK: $PAGENAME passed."
    fi
    rm tmp.tmp
}

test_lslb_admin(){
    test_page https://localhost:7090/ "LiteSpeed WebAdmin" "test webAdmin page"
}

install_lslb(){
    cd ${CMDFD}/
    if [ -e ${CMDFD}/lslb* ] || [ -d ${LSDIR} ]; then
        echoY 'Remove existing LSADC'
        silent systemctl stop lslb
        KILL_PROCESS lslbd
        rm -rf ${CMDFD}/lslb*
        rm -rf ${LSDIR}
    fi
    echoG 'Download LiteSpeed WebADC'
    wget -q --no-check-certificate https://litespeedtech.com/packages/lslb/lslb-${LS_VER}-x86_64-linux.tar.gz -P ${CMDFD}/
    silent tar -zxvf lslb-*-x86_64-linux.tar.gz
    rm -f lslb-*.tar.gz
    cd lslb-*
    if [ "${LICENSE}" == 'TRIAL' ]; then 
        wget -q --no-check-certificate http://license.litespeedtech.com/reseller/trial.key
    else 
        echo "${LICENSE}" > serial.no
    fi    
    sed -i '/^license$/d' install.sh
    sed -i 's/read TMPS/TMPS=0/g' install.sh
    sed -i 's/read TMP_YN/TMP_YN=N/g' install.sh
    sed -i 's/read TMP_URC/TMP_URC=N/g' install.sh
    sed -i '/read [A-Z]/d' functions.sh
    sed -i "/DEFAULT_PORT=/i\    local TMP_PORT" functions.sh
    sed -i 's/HTTP_PORT=$TMP_PORT/HTTP_PORT=8090/g' functions.sh
    sed -i 's/ADMIN_PORT=$TMP_PORT/ADMIN_PORT=7090/g' functions.sh
    sed -i "/^license()/i\
    PASS_ONE=${ADMIN_PASS}\
    PASS_TWO=${ADMIN_PASS}\
    TMP_USER=''\
    TMP_GROUP=''\
    TMP_PORT=''\
    TMP_DEST=''\
    ADMIN_USER=''
    " functions.sh

    echoG 'Install LiteSpeed WebADC Server'
    silent /bin/bash install.sh
    echoG 'Upgrade to Latest stable release'
    silent ${LSDIR}/admin/misc/lsup.sh -f
    silent ${LSDIR}/bin/lslbctrl start
    SERVERV=$(cat ${LSDIR}/VERSION)
    echoG "Version: LSLB ${SERVERV}"
    rm -rf ${CMDFD}/lslb-*
    cd /
}

ubuntu_install_lslb(){
    install_lslb
}

centos_install_lslb(){
    install_lslb
}

uninstall_lslb(){
    echoG 'Uninstall LiteSpeed WebADC'
    if [ -d ${LSDIR} ]; then
        silent systemctl stop lslb
        KILL_PROCESS lslbd
        rm -rf ${LSDIR}
    fi    
}

ubuntu_uninstall_lslb(){
    uninstall_lslb
}

centos_uninstall_lslb(){
    uninstall_lslb
}

gen_selfsigned_cert(){
    echoG 'Generate Cert'
    KEYNAME="${LSDIR}/conf/example.key"
    CERTNAME="${LSDIR}/conf/example.crt"
    ### ECDSA 256bit
    openssl ecparam  -genkey -name prime256v1 -out ${KEYNAME}
    silent openssl req -x509 -nodes -days 365 -new -key ${KEYNAME} -out ${CERTNAME} <<csrconf
US
NJ
Virtual
LiteSpeedCommunity
Testing
webadmin
.
.
.
csrconf
}


setup_scaling_vultr_lslb(){
    echoG 'Setting LSADC Config'
    cd ${SCRIPTPATH}
    backup_old ${LSCONF}
    backup_old ${LSVCONF}
    cp conf/scaling_vultr/lslbd_config.xml ${LSDIR}/conf/
    cp conf/scaling_vultr/wp-scale-cluster.xml ${LSDIR}/DEFAULT/conf/
    sed -i "s/VULTER_API/${VULTR_API}/g" ${LSCONF}
    sed -i "s/ADC_LOCAL_IP/${ADC_LOCAL_IP}/g" ${LSCONF}
    sed -i "s/WP_LOCAL_IP/${WP_LOCAL_IP}/g" ${LSCONF}
    sed -i "s/VULTR_REGION/${VULTR_REGION}/g" ${LSCONF}
    sed -i "s/VULTR_REGION/${VULTR__NODE_REGION}/g" ${LSCONF}
    gen_selfsigned_cert
}

setup_default_lslb(){
    echoG 'Setting LSADC Config'
    #gen_selfsigned_cert
}

main_setup_lslb(){
    if [ "${LSLB_CONFIG}" = 'default' ]; then
        setup_default_lslb
    elif [ "${LSLB_CONFIG}" = 'scaling_vultr' ]; then
        setup_scaling_vultr_lslb
    fi
}

landing_pg(){
    echoG 'Setting Landing Page'
    curl -s https://raw.githubusercontent.com/litespeedtech/ls-cloud-image/master/Static/wp-landing.html \
    -o ${DOCLAND}/index.html
    if [ -e ${DOCLAND}/index.html ]; then
        echoG 'Landing Page finished'
    else
        echoR "Please check Landing Page here ${DOCLAND}/index.html"
    fi
}

ubuntu_firewall_add(){
    echoG 'Setting Firewall'
    ufw status verbose | grep inactive > /dev/null 2>&1
    if [ $? = 0 ]; then
        for PORT in ${FIREWALLLIST}; do
            ufw allow ${PORT} > /dev/null 2>&1
        done
        echo "y" | ufw enable > /dev/null 2>&1
        ufw status | grep '80.*ALLOW' > /dev/null 2>&1
        if [ $? = 0 ]; then
            echoG 'firewalld rules setup success'
        else
            echoR 'Please check ufw rules'
        fi
    else
        echoG "ufw already enabled"
    fi
}

centos_firewall_add(){
    echoG 'Setting Firewall'
    if [ ! -e /usr/sbin/firewalld ]; then
        yum -y install firewalld > /dev/null 2>&1
    fi
    service firewalld start  > /dev/null 2>&1
    systemctl enable firewalld > /dev/null 2>&1
    for PORT in ${FIREWALLLIST}; do
        firewall-cmd --permanent --add-port=${PORT}/tcp > /dev/null 2>&1
    done
    firewall-cmd --reload > /dev/null 2>&1
    firewall-cmd --list-all | grep 80 > /dev/null 2>&1
    if [ $? = 0 ]; then
        echoG 'firewalld rules setup success'
    else
        echoR 'Please check firewalld rules'
    fi
}

add_profile(){
    echo "${1}" >> /etc/profile
}

rm_dummy(){
    remove_file /etc/update-motd.d/00-header
    remove_file /etc/update-motd.d/10-help-text
    remove_file /etc/update-motd.d/50-landscape-sysinfo
    remove_file /etc/update-motd.d/50-motd-news
    remove_file /etc/update-motd.d/51-cloudguest
    backup_old /etc/legal
}

set_banner(){
    echoG 'Set Banner'
    rm_dummy
    if [ ! -e ${BANNERDST} ]; then
        curl -s https://raw.githubusercontent.com/Code-Egg/lslb1clk/main/Banner/litespeedadc \
        -o ${BANNERDST}
        chmod +x ${BANNERDST}
    fi
    help_message 1
}

start_message(){
    START_TIME="$(date -u +%s)"
}

end_message(){
    END_TIME="$(date -u +%s)"
    ELAPSED="$((${END_TIME}-${START_TIME}))"
    echoY "***Total of ${ELAPSED} seconds to finish process***"
}

scaling_require_input(){
    check_vultr_platform
    get_lan_ipv4
    get_vultr_api
    get_node_json
    get_node_IP
    get_node_region
}

init_check(){
    check_os
    provider_ck
    path_update
    os_hm_path
}

init_setup(){
    gen_password
    gen_pass_file
    update_pass_file
}

ubuntu_main_install(){
    ubuntu_sysupdate
    ubuntu_pkg_system
    ubuntu_install_lslb
    ubuntu_firewall_add
}


ubuntu_main_config(){
    main_setup_lslb
    restart_lslb    
}

ubuntu_main_uninstall(){
    ubuntu_uninstall_lslb
    exit 0  
}

centos_main_install(){
    centos_sysupdate
    centos_pkg_system
    centos_install_lslb
    centos_firewall_add
}

centos_main_config(){
    main_setup_lslb
    restart_lslb
}

centos_main_uninstall(){
    centos_uninstall_lslb
    exit 0
}


verify_installation(){
    echoG 'Start validate settings'
    test_lslb_admin
    echoG 'End validate settings'
}


main(){
    init_check
    start_message
    init_setup
    if [ ${OSNAME} = 'centos' ]; then
        centos_main_install
        centos_main_config
    else
        ubuntu_main_install
        ubuntu_main_config
    fi
    verify_installation
    set_banner
    end_message
}

main_uninstall(){
    init_check
    start_message
    uninstall_msg
    if [ ${OSNAME} = 'centos' ]; then
        centos_main_uninstall
    else
        ubuntu_main_uninstall
    fi
    end_message
}

while [ ! -z "${1}" ]; do
    case ${1} in
        -[hH] | -help | --help)
            help_message 2
            ;;
        -[lL] | --license)
            shift
            check_input "${1}"
            LICENSE="${1}"
            ;;            
        --uninstall)
            main_uninstall
            ;;
        --scaling-vultr)
            LSLB_CONFIG='scaling_vultr'
            scaling_require_input
            ;;
        *) 
            help_message 2
            ;;              
    esac
    shift
done
main