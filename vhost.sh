#!/bin/bash
################################################
### Make sure only root can run the script
################################################
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root" 1>&2
   exit 1
fi
echo "This script creates a user and a vhost."
echo "This script may be re-run."

model_path=/etc/skel/
model_file=vhost_model.txt

################################################
### Check that the model files exists and 
### if not, exit with helpful message
################################################
if [ -f $model_path$model_file ]
	then
	echo "Vhost model file exists, starting .."
else
	echo "This script expects a file $model_file in $model_path but it does not exist, here's an example"
  cat <<EOF
	<VirtualHost *:80>
	DocumentRoot /home/username/domain_name/htdocs
	ServerName domain_name
	<Directory "/home/username/domain_name/htdocs">
	allow from all
	Options -Indexes
	</Directory>
	ServerAlias domain_name
	ErrorLog /home/username/domain_name/logs/error_log
	LogLevel warn
	CustomLog /home/username/domain_name/logs/access_log "combined"
	</VirtualHost>
EOF
	echo "Create a file in $model_path with the content above called $model_file."
	exit
fi
	################################################
	### Get the username
	################################################
read -p "Enter username>" username
if [ -n "$username" ]
	then
	echo $username
else 
	echo "Exit no username entered"
	exit
fi
	################################################
	### Add the user
	################################################
	adduser $username
	cd /home/$username
	################################################
	### Get the server/domain name
	################################################
	read -p "Enter vhost domain name>" domain_name
	if [ -n "$domain_name" ]
		then
		echo $domain_name
		if [ -d /home/$username/domain ]
			then
			echo "Mv domain"
			mv domain $domain_name
		else
			echo "MK files"
			mkdir $domain_name
			mkdir $domain_name/htdocs
			mkdir $domain_name/logs
			mkdir $domain_name/files
			mkdir $domain_name/files/deploy
		fi
		chown -R $username $domain_name/htdocs
		chown -R $username $domain_name/files
		chown -R $username $domain_name/files/deploy
	else
		echo "Exit no domain entered"
		exit
	fi
	cd $domain_name/files/deploy
	################################################
	### Grab the model vhost .conf file & edit it
	################################################
	ORIGINAL=username
	REPLACEMENT=$username
	if [ -f $model_path$model_file ]
	then
		echo "Customising model .conf file "
		cp $model_path$model_file ./$model_file
	################################################
	### First set username ...
	################################################
		for word in $(fgrep -l $ORIGINAL $model_file)
		do
  # -------------------------------------
  ex $word <<EOF
  :%s/$ORIGINAL/$REPLACEMENT/g
  :wq
EOF
	# :%s is the "ex" substitution command.
	# :wq is write-and-quit.
	# -------------------------------------
		done
	################################################
	### ... then set domain name
	################################################
	ORIGINAL_D=domain_name
	REPLACEMENT_D=$domain_name

	for word in $(fgrep -l $ORIGINAL_D $model_file)
	do
	# -------------------------------------
  ex $word <<EOF
  :%s/$ORIGINAL_D/$REPLACEMENT_D/g
  :wq
EOF
	# :%s is the "ex" substitution command.
	# :wq is write-and-quit.
	# -------------------------------------
	done
	################################################
	### Move the config file to site-available
	################################################
	echo "Moving config file to apache"
	mv ./$model_file /etc/apache2/sites-available/$domain_name.conf
	ln -s /etc/apache2/sites-available/$domain_name.conf /etc/apache2/sites-enabled/$domain_name.conf
	echo "Restart apache"
	service apache2 reload
	else
		echo "$model_path$model_file does not exist but is required."
		exit;
	fi
	################################################
	### Continue on to deploy a site?
	################################################

	read -p "Deploy from a remote site? (Assumes you've run package_for_deployment.sh
	at the remote end)Y/n>" deploy
	if [ $deploy = "Y" ]
			then
			echo "Deploy ..."
	else 
			echo "Done."
			exit
	fi
	################################################
	### Get the remote username
	################################################
	read -p "Enter remote username>" username
	if [ -n "$username" ]
			then
			echo $username
	else 
			echo "Exit no remote username entered"
			exit
	fi
	################################################
	### Get the remote hostname
	################################################
	read -p "Enter remote hostname>" hostname
	if [ -n "$hostname" ]
			then
			echo $hostname
	else 
			echo "Exit no remote hostname entered"
			exit
	fi
	################################################
	### Get the remote pathname
	################################################
	read -p "Enter remote pathname>" pathname
	if [ -n "$pathname" ]
			then
			echo $pathname
	else 
			echo "Exit no remote pathname entered"
			exit
	fi
	scp $username@$hostname:$pathname/deploy.sql.gz ./
	gunzip deploy.sql.gz
	echo "creating database, enter mysql root password:"
	mysql -uroot -e "create database $username" -p
	read -p "Enter local database password for $username>" db_pwd
	echo "creating database user, enter mysql root password:"
	mysql -uroot -e "grant all on $username.* to $username identified by '$db_pwd' " -p
	#echo "Loading db dump file, enter db password:"
	mysql -u $username -p $db_pwd $username < deploy.sql
	echo "Populated db, fetching htdocs ..."

	scp $username@$hostname:$pathname/htdocs.tar.gz ./
	exit

