#!/bin/bash
###
 # @Author: Vincent Young
 # @Date: 2022-07-01 15:29:23
 # @LastEditors: Vincent Young
 # @LastEditTime: 2022-07-30 19:26:45
 # @FilePath: /MTProxy/mtproxy.sh
 # @Telegram: https://t.me/missuo
 # 
 # Copyright © 2022 by Vincent, All Rights Reserved. 
### 

PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH

# Define Color
red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'

# Make sure run with root
[[ $EUID -ne 0 ]] && echo -e "[${red}Error${plain}]Please run this script with ROOT!" && exit 1

download_file(){
	echo "正在检查系统..."

	bit=`uname -m`
	if [[ ${bit} = "x86_64" ]]; then
		bit="amd64"
    elif [[ ${bit} = "aarch64" ]]; then
        bit="arm64"
    else
	    bit="386"
    fi

    last_version=$(curl -Ls "https://api.github.com/repos/9seconds/mtg/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
    if [[ ! -n "$last_version" ]]; then
        echo -e "${red}Failure to detect mtg version may be due to exceeding Github API limitations, please try again later."
        exit 1
    fi
    echo -e "Latest version of mtg detected: ${last_version}, start installing..."
    version=$(echo ${last_version} | sed 's/v//g')
    wget -N --no-check-certificate -O mtg-${version}-linux-${bit}.tar.gz https://github.com/9seconds/mtg/releases/download/${last_version}/mtg-${version}-linux-${bit}.tar.gz
    if [[ ! -f "mtg-${version}-linux-${bit}.tar.gz" ]]; then
        echo -e "${red}Download mtg-${version}-linux-${bit}.tar.gz failed, please try again."
        exit 1
    fi
    tar -xzf mtg-${version}-linux-${bit}.tar.gz
    mv mtg-${version}-linux-${bit}/mtg /usr/bin/mtg
    rm -f mtg-${version}-linux-${bit}.tar.gz
    rm -rf mtg-${version}-linux-${bit}
    chmod +x /usr/bin/mtg
    echo -e "mtg-${version}-linux-${bit}.tar.gz installed successfully, start to configure..."
}

configure_mtg(){
    echo -e "开始配置 mtg..."
    wget -N --no-check-certificate -O /etc/mtg.toml https://raw.githubusercontent.com/missuo/MTProxy/main/mtg.toml
    
    echo ""
    read -p "输入伪装域名 (例如 qifei.shabibaidu.com): " domain
	[ -z "${domain}" ] && domain="qifei.shabibaidu.com"

	echo ""
    read -p "输入监听端口 (默认 8443):" port
	[ -z "${port}" ] && port="8443"

    secret=$(mtg generate-secret --hex $domain)
    
    echo "正在配置中..."

    sed -i "s/secret.*/secret = \"${secret}\"/g" /etc/mtg.toml
    sed -i "s/bind-to.*/bind-to = \"0.0.0.0:${port}\"/g" /etc/mtg.toml

    echo "mtg配置成功,开始配置systemctl..."
}

configure_systemctl(){
    echo -e "正在配置 systemctl..."
    wget -N --no-check-certificate -O /etc/systemd/system/mtg.service https://raw.githubusercontent.com/missuo/MTProxy/main/mtg.service
    systemctl enable mtg
    systemctl start mtg
    echo "mtg 配置成功,开始配置防火墙..."
    systemctl disable firewalld
    systemctl stop firewalld
    ufw disable
    echo "mtg 启动成功,enjoy it!"
    echo ""
    # echo "mtg configuration:"
    # mtg_config=$(mtg access /etc/mtg.toml)
    public_ip=$(curl -s ipv4.ip.sb)
    subscription_config="tg://proxy?server=${public_ip}&port=${port}&secret=${secret}"
    subscription_link="https://t.me/proxy?server=${public_ip}&port=${port}&secret=${secret}"
    echo -e "${subscription_config}"
    echo -e "${subscription_link}"
}

change_port(){
    read -p "输入你要修改的端口(默认 8443):" port
	[ -z "${port}" ] && port="8443"
    sed -i "s/bind-to.*/bind-to = \"0.0.0.0:${port}\"/g" /etc/mtg.toml
    echo "正在重启MTProxy..."
    systemctl restart mtg
    echo "MTProxy 重启完毕...!"
}

change_secret(){
    echo -e "请注意,不正确的修改Secret可能会导致MTProxy无法正常工作。."
    read -p "输入你要修改的Secret密钥:" secret
	[ -z "${secret}" ] && secret="$(mtg generate-secret --hex itunes.apple.com)"
    sed -i "s/secret.*/secret = \"${secret}\"/g" /etc/mtg.toml
    echo "Secret密钥更改完成!"
    echo "正在重启MTProxy..."
    systemctl restart mtg
    echo "MTProxy 重启完毕...!"
}

update_mtg(){
    echo -e "正在升级 mtg..."
    download_file
    echo "mtg 升级成功,开始重新启动MTProxy..."
    systemctl restart mtg
    echo "MTProxy已成功启动...!"
}

start_menu() {
    clear
    echo -e "  MTProxy v2 一键安装脚本
---- by Vincent | github.com/missuo/MTProxy ----
 ${green} 1.${plain} 安装MTproxy
 ${green} 2.${plain} 卸载MTproxy
————————————
 ${green} 3.${plain} 启动 MTProxy
 ${green} 4.${plain} 停止 MTProxy
 ${green} 5.${plain} 重启 MTProxy
 ${green} 6.${plain} 更改端口
 ${green} 7.${plain} 更改密钥
 ${green} 8.${plain} 升级脚本
————————————
 ${green} 0.${plain} Exit
————————————" && echo

	read -e -p " 请输入对应数字选择 [0-8]: " num
	case "$num" in
    1)
		download_file
        configure_mtg
        configure_systemctl
		;;
    2)
        echo "Uninstall MTProxy..."
        systemctl stop mtg
        systemctl disable mtg
        rm -rf /usr/bin/mtg
        rm -rf /etc/mtg.toml
        rm -rf /etc/systemd/system/mtg.service
        echo "MTProxy已成功卸载!"
        ;;
    3) 
        echo "正在启动MTProxy..."
        systemctl start mtg
        systemctl enable mtg
        echo "MTProxy 启动成功!"
        ;;
    4) 
        echo "正在停止MTProxy..."
        systemctl stop mtg
        systemctl disable mtg
        echo "MTProxy 停止成功!"
        ;;
    5)  
        echo "正在重启MTProxy..."
        systemctl restart mtg
        echo "MTProxy 重启成功!"
        ;;
    6) 
        change_port
        ;;
    7)
        change_secret
        ;;
    8)
        update_mtg
        ;;
    0) exit 0
        ;;
    *) echo -e "${Error} Please enter a number [0-5]: "
        ;;
    esac
}
start_menu
