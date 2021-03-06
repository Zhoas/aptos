#!/bin/bash
sudo apt update && apt install jq -y
sudo apt install curl
if exists docker; then
	echo ''
else
  curl -fsSL https://get.docker.com -o get-docker.sh && sh get-docker.sh
fi
curl -s https://raw.githubusercontent.com/cryptongithub/init/main/logo.sh | bash && sleep 2

echo "=+=+=+=+=+=++=+=++=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+="

echo -e "\e[1m\e[32m1. Installing required dependencies... \e[0m" && sleep 1
sudo apt-get update & sudo apt-get install git -y
# Installing yq to modify yaml files
sudo wget -qO /usr/local/bin/yq https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64
sudo chmod a+x /usr/local/bin/yq
cd $HOME
rm -rf aptos-core
rm /usr/local/bin/aptos*
sudo mkdir -p /opt/aptos/data aptos aptos/identity


echo -e "\e[1m\e[32m2. Cloning github repo... \e[0m" && sleep 1
git clone https://github.com/aptos-labs/aptos-core.git
cd aptos-core
git checkout origin/devnet &> /dev/null
cp $HOME/aptos-core/config/src/config/test_data/public_full_node.yaml $HOME/aptos
wget -P $HOME/aptos https://devnet.aptoslabs.com/genesis.blob
wget -P $HOME/aptos https://devnet.aptoslabs.com/waypoint.txt
wget -P $HOME/aptos https://api.zvalid.com/aptos/seeds.yaml
/usr/local/bin/yq e -i '.base.waypoint.from_config="'$(cat $HOME/aptos/waypoint.txt)'"' $HOME/aptos/public_full_node.yaml
/usr/local/bin/yq e -i '.execution.genesis_file_location = "'$HOME/aptos/genesis.blob'"' $HOME/aptos/public_full_node.yaml

echo "=+=+=+=+=+=++=+=++=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+="

echo -e "\e[1m\e[32m3. Installing required Aptos dependencies... \e[0m" && sleep 1
echo y | ./scripts/dev_setup.sh
source ~/.cargo/env

echo -e "\e[1m\e[32m4. Compiling aptos-node ... \e[0m" && sleep 1
cargo build -p aptos-node --release


echo -e "\e[1m\e[32m5. Compiling aptos-operational-tool ... \e[0m" && sleep 1
cargo build -p aptos-operational-tool --release

echo "=+=+=+=+=+=++=+=++=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+="

echo -e "\e[1m\e[32m6. Moving aptos-node to /usr/local/bin/aptos-node ... \e[0m" && sleep 1
mv $HOME/aptos-core/target/release/aptos-node /usr/local/bin


echo -e "\e[1m\e[32m7. Moving aptos-operational-tool to /usr/local/bin/aptos-operational-tool ... \e[0m" && sleep 1
mv $HOME/aptos-core/target/release/aptos-operational-tool /usr/local/bin

echo "=+=+=+=+=+=++=+=++=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+="

echo -e "\e[1m\e[32m8. Generating a unique node identity ... \e[0m" && sleep 1

/usr/local/bin/aptos-operational-tool generate-key --encoding hex --key-type x25519 --key-file $HOME/aptos/identity/private-key.txt &> /dev/null
/usr/local/bin/aptos-operational-tool extract-peer-from-file --encoding hex --key-file $HOME/aptos/identity/private-key.txt --output-file $HOME/aptos/identity/peer-info.yaml > $HOME/aptos/identity/id.json
PEER_ID=$(sed -n 2p $HOME/aptos/identity/peer-info.yaml | sed 's/.$//')
PRIVATE_KEY=$(cat $HOME/aptos/identity/private-key.txt)

# Setting node identity
/usr/local/bin/yq e -i '.full_node_networks[] +=  { "identity": {"type": "from_config", "key": "'$PRIVATE_KEY'", "peer_id": "'$PEER_ID'"} }' $HOME/aptos/public_full_node.yaml

# Setting peer list
/usr/local/bin/yq ea -i 'select(fileIndex==0).full_node_networks[0].seeds = select(fileIndex==1).seeds | select(fileIndex==0)' $HOME/aptos/public_full_node.yaml $HOME/aptos/seeds.yaml
rm $HOME/aptos/seeds.yaml
              
echo "=+=+=+=+=+=++=+=++=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+="

echo -e "\e[1m\e[32m9. Creating systemctl service ... \e[0m" && sleep 1

echo "[Unit]
Description=Subspace Farmer

[Service]
User=$USER
Type=simple
ExecStart=/usr/local/bin/aptos-node --config $HOME/aptos/public_full_node.yaml
Restart=always
RestartSec=10
LimitNOFILE=10000

[Install]
WantedBy=multi-user.target
" > $HOME/aptos-fullnode.service
mv $HOME/aptos-fullnode.service /etc/systemd/system

echo "=+=+=+=+=+=++=+=++=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+="

echo -e "\e[1m\e[32m10. Starting the node ... \e[0m" && sleep 1

sudo systemctl restart systemd-journald
sudo systemctl daemon-reload
sudo systemctl enable aptos-fullnode
sudo systemctl restart aptos-fullnode

echo "=+=+=+=+=+=++=+=++=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+="

echo -e "\e[1m\e[32m11. Aptos FullNode Started \e[0m"

echo "=+=+=+=+=+=++=+=++=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+="

