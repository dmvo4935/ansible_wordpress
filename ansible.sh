#!/bin/bash

SSH_KEY=mykey
PLAYBOOK=wordpress.yml
INVENTORY=inventory
USER=allcome_0
VAULT_FILE=mysql.yml
VAULT_PASSWD=vault_passwd

ansible-playbook \
-i $INVENTORY \
-l 'google_wp google_wp_db' \
-b \
-u $USER \
--private-key $SSH_KEY \
--vault-id $VAULT_FILE \
--vault-password-file=$VAULT_PASSWD \
$PLAYBOOK
