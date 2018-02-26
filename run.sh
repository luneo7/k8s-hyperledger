#!/bin/bash +x

export CONFIG_PATH=$PWD
export FABRIC_CFG_PATH=$PWD

ORDERER=$CONFIG_PATH/crypto-config/ordererOrganizations
PEER=$CONFIG_PATH/crypto-config/peerOrganizations

function runOrderers () {
	echo "===> Running Orderers"
  for org in $(ls -l $1 | grep "^d" | awk -F" " '{print $9}') ; do
	  orgPath=$1"/"$org

		kubectl create -f "${orgPath}/${org}-namespace.yaml"

    for orderer in $(ls -l $orgPath"/orderers" | grep "^d" | awk -F" " '{print $9}') ; do
			ordererPath=$orgPath"/orderers/"$orderer
			kubectl create -f "${ordererPath}/${orderer}.yaml"
		done
  done
}

function runPeers () {
	echo "===> Running Peers"

	for org in $(ls -l $1 | grep "^d" | awk -F" " '{print $9}') ; do
    orgPath=$1"/"$org

		kubectl create -f "${orgPath}/${org}-namespace.yaml"

		kubectl create -f "${orgPath}/${org}-ca.yaml"

		for peer in $(ls -l $orgPath"/peers" | grep "^d" | awk -F" " '{print $9}') ; do
			peerPath=$orgPath"/peers/"$peer
			kubectl create -f "${peerPath}/${peer}.yaml"
		done

	done
}

function runCli () {
	kubectl create -f "${CONFIG_PATH}/crypto-config/cli.yaml"
}

function runK8sYaml () {
	echo "===> Running k8s"
	runOrderers $ORDERER
  runPeers $PEER
	runCli
}

runK8sYaml
