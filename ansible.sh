#!/bin/bash

WORKDIR=/opt/ansible_wordpress
SSH_KEY=$WORKDIR/mykey
PLAYBOOK=$WORKDIR/wordpress.yml
INVENTORY=$WORKDIR/inventory
USER=allcome_0
VAULT_FILE=$WORKDIR/mysql.yml
VAULT_PASSWD=$WORKDIR/vault_passwd

chmod 0400 $SSH_KEY

ansible-playbook \
-i $INVENTORY \
-l 'google_wp google_wp_db' \
-b \
-u $USER \
--private-key $SSH_KEY \
--vault-id $VAULT_FILE \
--vault-password-file=$VAULT_PASSWD \
$PLAYBOOK
