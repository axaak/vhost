# vhost
shell script to setup new vhost under Apache
This script creates a new (Linux) user which is used for the document root, logs and associated files
of a new vhosted website. It creates a new vhost under Apache and reloads Apache to pick up the new website.
To use:
1) Copy vhost_model.txt to /etc/skel
2) Run vhost.sh
3) Enter user info when prompted
4) Enter website domain info when prompted


