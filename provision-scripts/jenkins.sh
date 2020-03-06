#!/bin/bash
# Just a jenkins fresh install

# Close STDOUT file descriptor
exec 1<&-
# Close STDERR FD
exec 2<&-
# Open STDOUT as $LOG_FILE file for read and write.
exec 1<>/root/jenkins-init.log
# Redirect STDERR to STDOUT
exec 2>&1

# Installing dependecies
install_dependencies()
{
	# Update
	sudo apt update
	# Jenkins dependencies (Java 10 and 11 not yet supported i think!)
	sudo apt-get install -y curl unzip openjdk-8-jdk
	# Docker for building
	sudo apt install -y apt-transport-https ca-certificates curl software-properties-common
	curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
	sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu bionic stable"
	sudo apt update
	sudo apt install -y docker-ce
	sudo usermod -aG docker ${USER}
	# ngnix as a reverse proxy
	sudo apt install -y nginx
	sudo cp /tmp/nginx_jenkins.default /etc/nginx/sites-available/default
}

generate_local_ssl_certificate()
{
	# Install mkcert
	wget https://github.com/FiloSottile/mkcert/releases/download/v1.4.1/mkcert-v1.4.1-linux-amd64
	mv mkcert-v1.4.1-linux-amd64 /usr/local/bin/mkcert
	chmod +x /usr/local/bin/mkcert
	# Init mkcert
	mkcert -install
	# Generate local trusted certificates
	sudo mkcert jenkins.local '*.jenkins.local' localhost 127.0.0.1 ::1
	sudo mkdir -p /etc/jenkins/ssl
	sudo mv jenkins*-key.pem /etc/jenkins/ssl/jenkins.local.key
	sudo mv jenkins*.pem /etc/jenkins/ssl/jenkins.local.crt
}

# Installing jenkins
install_jenkins()
{
	# GPG key
	wget -q -O - https://pkg.jenkins.io/debian/jenkins.io.key | sudo apt-key add -
	# Add jenkins repo
	sudo sh -c 'echo deb http://pkg.jenkins.io/debian-stable binary/ > /etc/apt/sources.list.d/jenkins.list'
	# Install
	sudo apt update
	sudo apt install -y jenkins
	# Install plugins
	wget https://gist.githubusercontent.com/micw/e80d739c6099078ce0f3/raw/33a21226b9938382c1a6aa68bc71105a774b374b/install_jenkins_plugin.sh -O /tmp/install_jenkins_plugins.sh
	sed -i 's/JAVA_ARGS="/JAVA_ARGS="-Djenkins.install.runSetupWizard=false /g' /etc/default/jenkins
	chmod +x /tmp/install_jenkins_plugins.sh
	sudo /tmp/install_jenkins_plugins.sh cloudbees-folder antisamy-markup-formatter build-timeout credentials-binding timestamper ws-cleanup ant gradle workflow-aggregator github-organization-folder pipeline-stage-view git subversion ssh-slaves matrix-auth pam-auth ldap email-ext mailer slack
	sudo /tmp/install_jenkins_plugins.sh blueocean sonar docker-plugin artifactory gitlab-plugin locale
	sudo usermod -aG docker jenkins
	sudo /etc/init.d/jenkins restart
	sudo cat /var/lib/jenkins/secrets/initialAdminPassword > /root/jenkins-admin-pass.txt && sudo chmod 400 /root/jenkins-admin-pass.txt
	sudo /etc/init.d/nginx restart
}

# Script entry point
install_dependencies
generate_local_ssl_certificate
install_jenkins
