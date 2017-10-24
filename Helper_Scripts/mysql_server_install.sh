#!/bin/bash

echo -e "Do you want to install the standard installation from Source \n$TODO\nContinue? (y/n)"
if [ -z "${FORCE}" ] ; then
        read -d'' -s -n 1
        if [ "${REPLY}" != "y" ] ; then
	        echo "Supply the .deb package location"
                exit 1
        fi
else
	echo "  Starting operation."
	# Download and Install the Latest Updates for the OS
	apt update && apt upgrade -y
	# Install MySQL Server in a Non-Interactive mode. Default root password will be "root"
	echo "mysql-server-5.7 mysql-server/root_password password root" | sudo debconf-set-selections
	echo "mysql-server-5.7 mysql-server/root_password_again password root" | sudo debconf-set-selections
	apt-get -y install mysql-server-5.7


	# Run the MySQL Secure Installation wizard
	mysql_secure_installation

	sed -i 's/127\.0\.0\.1/0\.0\.0\.0/g' /etc/mysql/my.cnf
	mysql -uroot -p -e 'USE mysql; UPDATE `user` SET `Host`="%" WHERE `User`="root" AND `Host`="localhost"; DELETE FROM `user` WHERE `Host` != "%" AND `User`="root"; FLUSH PRIVILEGES;'
	
	service mysql restart
	#Install perf and mpstat
	apt install systat
	apt install linux-tools-common linux-tools-generic
fi

mkdir -p /opt/benchmarks/


