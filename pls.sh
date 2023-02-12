#!/bin/bash

cat $HOME/.ssh/authorized_keys >> authorized_keys
for i in `cat hosts`
do
 ssh -i key.pem kafkaadmin@$i "echo -e 'y\n' | ssh-keygen -t rsa -P '' -f $HOME/.ssh/id_rsa"
 ssh -i key.pem kafkaadmin@$i 'touch ~/.ssh/config; echo -e \ "host *\n StrictHostKeyChecking no\n UserKnownHostsFile=/dev/null" \ > ~/.ssh/config; chmod 644 ~/.ssh/config'
 ssh -i key.pem kafkaadmin@$i 'cat $HOME/.ssh/id_rsa.pub' >> authorized_keys
done

for i in `cat hosts`
do
 scp -i key.pem authorized_keys kafkaadmin@$i:$HOME/.ssh/authorized_keys
done
