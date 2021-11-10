#!/bin/bash

# Use this script to create new backend in DS 7x servers and initialize
#
# Created on 28/Oct/2021
# Author = G.Nikolaidis
# Version 1.0.0

# Create backend on all DS server and create base dn only on the first server(base dn will be replicated)
# call the script with createBaseDn argument to create base-dn, call the script without arguments, this creates only backend.

# Start
#
clear


# Settings
# you can change the below settings to meet your installation requirments
#
OPENDJ=/opt/ds702Replication2/opendj
FQDN=localhost
ADMINPORT=6444
SSLPORT=3636
BIND="uid=admin"
BINDPASSWORD=Password1
BACKENDNAME=exampleCyBackend
TYPE=je
BASEDN=dc=example,dc=cy
DC=example
# add or remove indexes to be created, index-type:equality
# if other type of indexes needed better add a new loop
#
INDEXES=("cn" "mail" "ds-certificate-subject-dn" "ds-certificate-fingerprint" "uid")




# Create backend
#
printf "Creating backend " $BACKENDNAME
$OPENDJ/bin/./dsconfig create-backend \
--hostname $FQDN \
--port $ADMINPORT \
--bindDn $BIND \
--bindPassword $BINDPASSWORD \
--backend-name $BACKENDNAME \
--type $TYPE \
--set enabled:true \
--set base-dn:$BASEDN \
--usePkcs12TrustStore /$OPENDJ/config/keystore \
--trustStorePasswordFile /$OPENDJ/config/keystore.pin \
--no-prompt


# Create replication domain
#
printf "Creating replication domain " $BACKENDNAME
$OPENDJ/bin/./dsconfig \
create-replication-domain \
--hostname $FQDN \
--port $ADMINPORT \
--bindDN $BIND \
--bindPassword $BINDPASSWORD \
--provider-name "Multimaster Synchronization" \
--domain-name $BASEDN \
--type generic \
--set enabled:true \
--set base-dn:$BASEDN \
--usePkcs12TrustStore /$OPENDJ/config/keystore \
--trustStorePasswordFile /$OPENDJ/config/keystore.pin \
--no-prompt


# Create base dn
#
if [[ $1 == "createBaseDn" ]]; then
        printf "Creating base dn...."
        $OPENDJ/bin/./ldapmodify --hostname $FQDN --port $SSLPORT --useSsl --usePkcs12TrustStore $OPENDJ/config/keystore --trustStorePasswordFile $OPENDJ/config/keystore.pin --bindDn $BIND --bindPassword $BINDPASSWORD << EOF
dn: $BASEDN
objectClass: top
objectClass: domain
dc: $DC
EOF
else
        printf "do not create base dn"
fi

echo


# creating indexes
#
printf "start creating indexes..."
echo
echo
for i in ${INDEXES[@]}; do
  printf "creting $i index..."
  $OPENDJ/bin/./dsconfig create-backend-index \
  --backend-name $BACKENDNAME \
  --set index-type:equality \
  --type generic \
  --index-name $i \
  --hostname $FQDN \
  --port $ADMINPORT \
  --bindDn $BIND \
  --trustAll \
  --bindPassword $BINDPASSWORD \
  --no-prompt
  if [ $? -ne 0 ]; then
        printf "Creating index failed"
        exit -1
  fi
  echo
done

echo

# rebuild all the indexes
#
printf "start rebuilding indexes..."
echo
echo
for n in ${INDEXES[@]}; do
  echo
  printf "rebuilding $n index..."
  echo
  $OPENDJ/bin/./rebuild-index \
  --hostname $FQDN \
  --port $ADMINPORT \
  --bindDN $BIND \
  --bindPassword $BINDPASSWORD \
  --baseDN $BASEDN \
  --index $n \
  --usePkcs12TrustStore $OPENDJ/config/keystore \
  --trustStorePasswordFile $OPENDJ/config/keystore.pin
done
# --rebuildDegraded \
echo
echo
printf "Finished creating backend, base-dn, indexes and rebuilding ..."
echo

#END
