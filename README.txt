Using the sysbench script to test mysql and benchmark mysql
1.	Prerequisites: Install ansible onto a machine. 
	This machine will be called an agent. 
	Now edit /etc/ansible/hosts. add the hostname of your target machine which you want to benchmark in the hosts file	
	eg: abc-server-sanjose
	Create a ssh key if it does not exist  ssh-keygen
	Copy this key to the remote server
	ssh-copy-id abc-server-sanjose
	This should enable passwordless interaction between the agent machine and target machine
2.	Pre installations:
	Add your username to the sudoers tab. Replace "YOUR USERNAME" with an actual username
	Now run the ansible playbook under the ansible folder.
	ansible-playbook ansible/ansible-new-machine.yml --extra-vars target=abc-server-sanjose


3.	Creation of folders /opt/benchmarks. Create /opt/benchmarks folder

4.	The setup
	The system will have 2 machines at minimum
	i.	Host machine. We need to fire the scripts from this machine
	ii.	Server: This will host the server
	iii.Client(optional-could be same as server): This will act as benchmark client
	iv.	Webserver(optional): The final files will be hosted to his machine.

5.	Adding keys between host client and server
Use ssh-copy-id to add ssh keys between host machine-server machine , host machine-client machine and clientmachine - server_machine, client machine-webserver. 
If server and client are same machines then ssh-copy-id 127.0.0.1 on the server machine needs to be issued.
Make sure the ids for all above scenarios are under known_hosts file

6. Options and their defaults:
Use ./runme.py -h with the script to check the usage scenarios and menu help.

7. In order to run the machine and install the packages use --with_install before the positional argument.

8. A sample for the command would be 

./runme.py -s abc-server-sanjose -C example_comment --with_install sysbench-mysql

This will install mysql-server latest from the git and also sysbench from the git. The user may choose to manually install the server. In that case the user will 
have to point to the correct paths for mysqld server and client.

in order to run a complete set 

./runme.py -s abc-server-sanjose -C example_comment --with_install sysbench-mysql --mysqlddir /opt/mysql-server/sql --mysqldir /opt/mysql-server/client -d /opt/benchmarks --threadlist 1,4,8,16,32,64,128,256,512 --tablerow 1000000 --tablecount 1,4,8,16 --mode oltp_read_only


