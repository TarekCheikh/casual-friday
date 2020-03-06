#!/bin/bash
# Just a gitlab fresh install

# Close STDOUT file descriptor
exec 1<&-
# Close STDERR FD
exec 2<&-
# Open STDOUT as $LOG_FILE file for read and write.
exec 1<>/root/gitlab-init.log
# Redirect STDERR to STDOUT
exec 2>&1

# Installing dependecies
install_dependencies()
{
	# Update
	sudo apt update
	# Gitlab dependencies
	sudo apt-get install -y curl openssh-server ca-certificates
}

# Installing gitlab
install_gitlab()
{
	# Gitlab repo
	curl -sS https://packages.gitlab.com/install/repositories/gitlab/gitlab-ce/script.deb.sh | sudo bash
	# Install
	sudo apt install gitlab-ce -y
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
	sudo mkcert gitlab.local '*.gitlab.local' localhost 127.0.0.1 ::1
	sudo mkdir -p /etc/gitlab/ssl
	sudo mv gitlab*-key.pem /etc/gitlab/ssl/gitlab.local.key
	sudo mv gitlab*.pem /etc/gitlab/ssl/gitlab.local.crt
}

# Perform necessary configurations and start
configure_and_start_gitlab()
{
	echo "letsencrypt['enable'] = false" > /etc/gitlab/gitlab.rb
	echo "external_url 'https://gitlab.local'" >> /etc/gitlab/gitlab.rb
	echo "nginx['enable'] = true" >> /etc/gitlab/gitlab.rb
	echo "nginx['listen_https'] = true" >> /etc/gitlab/gitlab.rb
	echo "nginx['listen_addresses'] = ['*', '[::]']" >> /etc/gitlab/gitlab.rb
	echo "nginx['ssl_certificate'] = '/etc/gitlab/ssl/gitlab.local.crt'" >> /etc/gitlab/gitlab.rb
	echo "nginx['ssl_certificate_key'] = '/etc/gitlab/ssl/gitlab.local.key'" >> /etc/gitlab/gitlab.rb
	echo "nginx['ssl_protocols'] = 'TLSv1.2'" >> /etc/gitlab/gitlab.rb
	gitlab-ctl reconfigure
	gitlab-ctl start
}

# Script entry point
install_dependencies
install_gitlab
generate_local_ssl_certificate
configure_and_start_gitlab
