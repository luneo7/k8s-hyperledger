#!/bin/bash +x

CHANNEL_NAME=$1
: ${CHANNEL_NAME:="businesschannel"}

export TOOLS=$PWD/bin
export CONFIG_PATH=$PWD
export FABRIC_CFG_PATH=$PWD
export VERSION=1.0.3
export ARCH=$(echo "$(uname -s|tr '[:upper:]' '[:lower:]'|sed 's/mingw64_nt.*/windows/')-$(uname -m | sed 's/x86_64/amd64/g')" | awk '{print tolower($0)}')

NFSSERVER="172.16.109.1"
ORDERER=$CONFIG_PATH/crypto-config/ordererOrganizations
PEER=$CONFIG_PATH/crypto-config/peerOrganizations
GENERATECLI=1
PORTSTARTFROM=30005
GAP=100
orgs=()

function downloadPlatformBinares() {
	if [ ! -f bin/cryptogen ];	then
		echo "===> Downloading platform binaries"
		curl https://nexus.hyperledger.org/content/repositories/releases/org/hyperledger/fabric/hyperledger-fabric/${ARCH}-${VERSION}/hyperledger-fabric-${ARCH}-${VERSION}.tar.gz | tar xz
	fi
}

function generateCerts (){
	echo "===> Generating Certificates"

	CRYPTOGEN=$TOOLS/cryptogen
	$CRYPTOGEN generate --config=./crypto-config.yaml
}

function generateChannelArtifacts() {
	echo "===> Generating Channel Artifacts"

	if [ ! -d channel-artifacts ]; then
		mkdir channel-artifacts
	fi

	CONFIGTXGEN=$TOOLS/configtxgen

 	$CONFIGTXGEN -profile TwoOrgsOrdererGenesis -outputBlock ./channel-artifacts/genesis.block

	$CONFIGTXGEN -profile TwoOrgsChannel -outputCreateChannelTx ./channel-artifacts/channel.tx -channelID $CHANNEL_NAME

	$CONFIGTXGEN -profile TwoOrgsChannel -outputAnchorPeersUpdate ./channel-artifacts/Org1MSPanchors.tx -channelID $CHANNEL_NAME -asOrg Org1MSP

	$CONFIGTXGEN -profile TwoOrgsChannel -outputAnchorPeersUpdate ./channel-artifacts/Org2MSPanchors.tx -channelID $CHANNEL_NAME -asOrg Org2MSP

  mkdir -p /opt/share/composer

  chmod -R 777 /opt/share/composer

	chmod +x ./scripts/*.sh

	chmod -R 777 ./channel-artifacts && chmod -R 777 ./crypto-config && chmod -R 777 ./chaincode

	cp ./channel-artifacts/genesis.block ./crypto-config/ordererOrganizations/*

	cp -r ./crypto-config /opt/share/ && cp -r ./channel-artifacts /opt/share/ && cp -r ./chaincode /opt/share

	cp ./scripts/*.sh /opt/share/channel-artifacts/
}

function clean () {
	sudo rm -rf /opt/share/*
	rm ./templates/composer-playground-storage.yaml
	rm -rf channel-artifacts
	rm -rf crypto-config
}

function generateNamespacePod () {
  for d in $(ls -l $1 | grep "^d" | awk -F" " '{print $9}') ; do
    configORGS $d $1/$d
    orgs+=($1/$d)
  done
}

function generateDeploymentPod () {
	for org in "${orgs[@]}"; do

		suffix=""
		if [[ "$org" == *"peer"* ]]; then
			suffix="/peers"
		else
			suffix="/orderers"
		fi

    for d in $(ls -l $org$suffix | grep "^d" | awk -F" " '{print $9}') ; do
			  path=$org$suffix"/"$d
				if [[ "$suffix" == *"peer"* ]]; then
          configPEERS $d $path
				else
          configORDERERS $d $path
				fi
		done

	done
}

function configPEERS () {
  local name=$1
	local path=$2

	mspPathTemplate='peers/'$name'/msp'
	tlsPathTemplate='peers/'$name'/tls'

	peerName=$(echo $name | cut -d'.' -f1)
	orgName=$(echo $name | cut -d'.' -f2)

	addressSegment=$(echo $orgName | cut -d'-' -f1 | grep -oE '[^org]+$')
	addressSegment=$((($addressSegment - 1) * $GAP))

	exposedPort=$(($PORTSTARTFROM + $addressSegment))

	peerOffset=$(echo $peerName | grep -oE '[^peer]+$')
	peerOffset=$(($peerOffset * 3))

	exposedPort1=$(($PORTSTARTFROM + $addressSegment + $peerOffset + 1))
	exposedPort2=$(($PORTSTARTFROM + $addressSegment + $peerOffset + 2))
	exposedPort3=$(($PORTSTARTFROM + $addressSegment + $peerOffset + 3))

	gossipBoostrapN=""
	gossipBoostrapV=""

	if [[ "$peerName" != *"0"* ]]; then
		gossipBoostrapN="- name: CORE_PEER_GOSSIP_BOOTSTRAP"
		gossipBoostrapV="  value: peer0.""$(echo "$orgName" | sed 's/\./\-/g')"":7051"
	fi

	msp=$(echo $orgName | tr "-" "\n")
	msp=${msp[0]}
	msp="$(tr '[:lower:]' '[:upper:]' <<<${msp:0:1})${msp:1}""MSP"

	sed "s?\$namespace?""$(echo "$orgName" | sed 's/\./\-/g')""?g; \
			 s?\$podName?""$peerName""-""$orgName""?g; \
			 s?\$peerID?""$peerName""?g; \
			 s?\$org?""$orgName""?g; \
			 s?\$corePeerID?""$name""?g; \
			 s?\$peerAddress?""$name":7051"?g; \
			 s?\$peerGossip?""$name":7051"?g; \
			 s?\$localMSPID?""$msp""?g; \
			 s?\$gossipBoostrapName?""$gossipBoostrapN""?g; \
			 s?\$gossipBoostrapValue?""$gossipBoostrapV""?g; \
			 s?\$mspPath?""$mspPathTemplate""?g; \
			 s?\$tlsPath?""$tlsPathTemplate""?g; \
			 s?\$nodePort1?""$(echo $exposedPort1)""?g; \
			 s?\$nodePort2?""$(echo $exposedPort2)""?g; \
			 s?\$nodePort3?""$(echo $exposedPort3)""?g; \
			 s?\$pvName?""$(echo "$orgName" | sed 's/\./\-/g')""-pvc?g" \
			 templates/fabric_1_0_pod_peer.base.yaml > $path/$name".yaml"

}

function configORDERERS () {
	local name=$1
	local path=$2

	mspPathTemplate='orderers/'$name'/msp'
	tlsPathTemplate='orderers/'$name'/tls'

	ordererName=$(echo $name | cut -d'.' -f1)
	orgName=$(echo $name | cut -d'.' -f2-)

  ordererOffset=$(echo $ordererName | grep -oE '[^orderer]+$')

	if [[ ! $ordererOffset =~ ^-?[0-9]+$ ]]; then
    ordererOffset=0
	fi

	exposedPort=$((32000 + $ordererOffset))

	msp="$(tr '[:lower:]' '[:upper:]' <<<${ordererName:0:1})${ordererName:1}""MSP"

	sed "s?\$namespace?""$(echo "$orgName" | sed 's/\./\-/g')""?g; \
			 s?\$podName?""$ordererName""-""$orgName""?g; \
			 s?\$ordererID?""$ordererName""?g; \
			 s?\$localMSPID?""$msp""?g; \
			 s?\$mspPath?""$mspPathTemplate""?g; \
			 s?\$tlsPath?""$tlsPathTemplate""?g; \
			 s?\$nodePort?""$(echo $exposedPort)""?g; \
			 s?\$pvName?""$(echo "$orgName" | sed 's/\./\-/g')""-pvc?g" \
			 templates/fabric_1_0_pod_orderer.base.yaml > $path/$name".yaml"

}


function configCLI () {
	local name=$1
  local path=$2

	msp=$(echo $name | tr "." "\n")
	msp=${msp[0]}
	msp="$(tr '[:lower:]' '[:upper:]' <<<${msp:0:1})${msp:1}""MSP"

	sed "s?\$mspPath?users/Admin@"$name"/msp?g; \
			 s?\$name?cli?g; \
			 s?\$nfsServer?""$NFSSERVER""?g; \
			 s?\$artifactsNamepvc?cli-artifacts-pvc?g; \
			 s?\$artifactsNamepv?cli-artifacts-pv?g; \
			 s?\$artifactsName?cli-artifacts?g; \
			 s?\$peerAddress?peer0-""$(echo "$name" | sed 's/\./\-/g')"":7051?g; \
			 s?\$mspid?""$msp""?g" \
			 templates/fabric_1_0_pod_cli.base.yaml > $path"/cli.yaml"


	sed "s?\$nfsServer?""$NFSSERVER""?g" \
		 	 templates/composer-playground-storage.base.yaml > templates/composer-playground-storage.yaml

}

function configORGS () {
  local name=$1
  local path=$2

  sed "s?\$org?""$(echo "$name" | sed 's/\./\-/g')""?g; \
       s?\$pvName?""$(echo "$name" | sed 's/\./\-/g')""-pv?g; \
       s?\$pvcName?""$(echo "$name" | sed 's/\./\-/g')""-pvc?g; \
			 s?\$nfsServer?""$NFSSERVER""?g; \
       s?\$path?""$(echo "$path" | sed 's?'$CONFIG_PATH'?/opt/share?g')""?g" \
       templates/fabric_1_0_pod_namespace.base.yaml > $path/$name"-namespace.yaml"

  if [[ $path == *"peer"* ]];  then

    if [[ $GENERATECLI == 1 ]]; then
      configCLI $name "${CONFIG_PATH}/crypto-config"
      GENERATECLI=0
		fi

		addressSegment=$(echo $name | cut -d'.' -f1 | grep -oE '[^org]+$')
		addressSegment=$((($addressSegment - 1) * $GAP))

		exposedPort=$(($PORTSTARTFROM + $addressSegment))

		skFile=''

		for f in $(ls -l $path"/ca" | awk -F" " '{print $9}')  ; do
			if [[ "$f" == *sk ]]; then
				skFile=$f
			fi
    done

		tlsCertTemplate='/etc/hyperledger/fabric-ca-server-config/ca.'$name'-cert.pem'
		tlsKeyTemplate='/etc/hyperledger/fabric-ca-server-config/'$skFile
		caPathTemplate='ca/'
		cmdTemplate=' fabric-ca-server start --ca.certfile /etc/hyperledger/fabric-ca-server-config/ca.'$name'-cert.pem --ca.keyfile /etc/hyperledger/fabric-ca-server-config/'$skFile' -b admin:adminpw -d '

		sed "s?\$namespace?""$(echo "$name" | sed 's/\./\-/g')""?g; \
         s?\$caname?ca-""$(echo $name | cut -d'.' -f1)""?g; \
         s?\$command?""$cmdTemplate""?g; \
         s?\$caPath?""$caPathTemplate""?g; \
         s?\$tlsKey?""$tlsKeyTemplate""?g; \
         s?\$tlsCert?""$tlsCertTemplate""?g; \
				 s?\$nodePort?""$(echo $exposedPort)""?g; \
         s?\$pvName?""$(echo "$name" | sed 's/\./\-/g')""-pvc?g" \
         templates/fabric_1_0_pod_ca.base.yaml > $path/$name"-ca.yaml"

	fi
}

function generateK8sYaml () {
	echo "===> Generating k8s yaml"
  generateNamespacePod $PEER
	generateDeploymentPod
	orgs=()
  generateNamespacePod $ORDERER
	generateDeploymentPod
}

downloadPlatformBinares
clean
generateCerts
generateChannelArtifacts
generateK8sYaml
