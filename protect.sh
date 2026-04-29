echo "HI!!!!. This project aims to automate the initial process of configuring the security of Linux servers."

echo "Warning: For this script to work, you must need to run it as sudo "

echo "First tell me, what operating system are you using??"
echo ""
echo "Select 1 for  --> (Debian)"
echo "Select 2 for  --> (Redhat)"
read distro

if [ "$distro" = "1" ]; then
	echo "updating system"
	apt update -y && apt upgrade -y
	clear
	echo "The update was success"
	
	echo "Let's configurate the firewalls rules, but first... "
	echo -e " Enter 1 --> for ufw\n (The advantage of this is that it's easy to implement, so if you want to make a change, it will be easy for you to do so)\n Enter 2 --> for iptables\n (With this, you have full control over your system)  "

	read fire

	if [ "$fire" = "1" ]; then
		if command -v ufw >/dev/null 2>&1; then
			echo "'UFW'is installed starting with the setup"
			ufw default deny incoming
			ufw default allow outgoing
			ufw allow 22
			ufw limit 22/tcp
			ufw limit ssh/tcp
			ufw enable
			ufw verbose
			
			clear
			echo "----------------------------"
			echo "Setup complete"
			
		else
			echo -e "'UFW'is not installed\n installing"
			apt install ufw -y
			
			echo -e "--- 'UFW' installed ---\n starting with the setup"
			ufw default deny incoming
            ufw default allow outgoing
            ufw allow 22
            ufw limit 22/tcp
            ufw limit ssh/tcp
            ufw enable
            ufw verbose
			
			clear
			echo "----------------------------"
			echo "Setup complete" 
		fi
#la otra pocion del firewall
	elif [ "$fire" = "2" ]; then
		
		echo "Setting up rules"
		
		iptables -A INPUT -i lo -j ACCEPT
		iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
		iptables -A INPUT -p tcp --dport 22 -j ACCEPT
		iptables -P INPUT DROP

		clear
		echo "----------------------------"
		echo "Setup complete"

	else
		echo "This option is invalid :("
		exit 1
	fi

	echo "----------------------------"

	ssh="/etc/ssh/sshd_config"

	echo "Making a backup for /etc/ssh/sshd_config"

	cp "$ssh" "$ssh.bak"

	sed -i "s/^#*PermitRootLogin.*/PermitRootLogin no/" $ssh

	systemctl restart ssh
	echo "ssh secure"
	clear
	
#la parte de la configuracion de fail2ban 

	echo "----------------------------"
	echo "Installing Fail2ban"

	apt install fail2ban -y

	cp "/etc/fail2ban/jail.conf" "/etc/fail2ban/jail.local"

	clear

	echo -e "Enter how long you want the ban to last\n type 's' for seconds (example: 10s).\n type 'm' for minutes (example: 10m).\n type 'h' for hours (example: 10h)."
	read ban
	echo "Enter the numbers of attempts available"
	read can
	echo -e "Enter the time limit per attempt before the ban count resets\n type 's' for seconds (example: 10s).\n type 'm' for minutes (example: 10m).\n type 'h' for hours (example: 10h)."
	read tiepo


	sed -i 's/^bantime\s*=.*/bantime  = $ban/' "/etc/fail2ban/jail.local"
	sed -i 's/^findtime\s*=.*/findtime  = $tiepo/' "/etc/fail2ban/jail.local"
	sed -i 's/^maxretry\s*=.*/maxretry = $can/' "/etc/fail2ban/jail.local"

	echo "Restarting the service"

	systemctl restart fail2ban

	echo -e "--- EVERYTHING COMPLETE ---\n Now you can use your server securely"
	exit 0
# Esta es la parte de RedHat
elif [ "$distro" = "2" ]; then
	echo "updating system"
	dnf update -y && dnf upgrade -y
	clear
	echo "The update was success"

	echo " Let's configurate the firewalls rules, but first... "
	echo -e " Enter 1 --> for firewalld\n (The advantage of this is that it's easy to implement, so if you want to make a change, it will be easy for you to do so)\n Enter 2 --> for nftables\n (With this, you have full control over your system)  "


	read fire

	if [ "$fire" = "1" ]; then
		echo "Setting up rules"
		
		firewall-cmd --permanent --zone=public --set-target=DROP
		firewall-cmd --permanent --zone=trusted --add-interface=lo
		firewall-cmd --permanent --zone=public --add-service=ssh
		firewall-cmd --reload
		clear
		
		echo "Setup complete"
		echo "Firewalls secure"

	elif [ "$fire" = "2" ]; then
		echo "Disabling firewalld"
		systemctl stop firewalld
		systemctl disable firewalld
		echo "___________________________"
		echo "Let's mask firewalld\n so that no other process\n can activate it and cause everything to fail"
		echo "___________________________"
		systemctl mask firewalld

		echo "COMPLETE"
		
		echo "Setting up nftables"
		sytemctl enable --now nftables
		#nos falta crear las tablas y reglas de todo
		echo "Creating tables...\n What is the name of your new tables?"
		read "tabla"
		nft add table inet "$tabla"
		nft add chain inet "$tabla" entrada { type filter hook input priority 0 \; polity drop \; }
		nft add rules inet "$tabla" entrada iif lo accept
		nft add rules inet "$tabla" entrada ct state astablished,related accept
		nft add rules inet "$tabla" entrada tcp dport 22 accept
		nft list ruleset > /etc/sysconfig/nftables.conf

		echo "Setting up rules"
		sudo systemctl reload nftables

		clear
		
	else
		echo "This option is invalid :("
		exit 1
	fi
	echo "----------------------------"

	echo "Securing ROOT access via SSH"
	
	ssh="/etc/ssh/sshd_config"

	echo "Making a backup for $ssh"

	cp "$ssh" "$ssh.bak"

	sed -i "s/^#*PermitRootLogin.*/PermitRootLogin no/" $ssh

	systemctl restart ssh
	echo "ssh secure"

	clear

	echo "----------------------------"
	echo "Installing Fail2ban"

	dnf install epel-release
	dnf install fail2ban fail2ban-firewalld -y
	systemctl enable --now fail2ban

	cp "/etc/fail2ban/jail.conf" "/etc/fail2ban/jail.local"

	clear
	echo -e "Enter how long you want the ban to last\n type 's' for seconds (example: 10s).\n type 'm' for minutes (example: 10m).\n type 'h' for hours (example: 10h)."
        read ban
        echo "Enter the numbers of attempts available"
        read can
        echo -e "Enter the time limit per attempt before the ban count resets\n type 's' for seconds (example: 10s).\n type 'm' for minutes (example: 10m).\n type 'h' for hours (example: 10h)."
        read tiepo


	#esas \s*=.* sirve para asegurarse al full de los espacios 

	sed -i 's/^bantime\s*=.*/bantime  = $ban/' "/etc/fail2ban/jail.local"
	sed -i 's/^findtime\s*=.**/findtime  = $tiepo/' "/etc/fail2ban/jail.local"
	sed -i 's/^maxretry\s*=.*/maxretry = $can/' "/etc/fail2ban/jail.local"
	sed -i 's/^banaction\s*=.*/banaction = firewallcmd-ipset' "/etc/fail2ban/jail.local"
	sed -i 's/^backend\s*=.*/backend = systemd' "/etc/fail2ban/jail.local"
	
	echo "Restarting service"

	systemctl restart fail2ban

	echo -e "--- EVERYTHING COMPLETE ---\n Now you can use your server securely"
	exit 0
else
	echo "This option is invalid >:0"
	exit 1
fi
done
