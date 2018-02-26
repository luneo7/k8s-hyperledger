#!/bin/bash +x

export CONFIG_PATH=$PWD

ORDERER=$CONFIG_PATH/crypto-config/ordererOrganizations
PEER=$CONFIG_PATH/crypto-config/peerOrganizations

function clean () {
	sudo rm -rf /opt/share/*
	rm -rf channel-artifacts
	rm -rf crypto-config
}

function deleteOrderers () {
	echo "===> Deleting Orderers"
  for org in $(ls -l $1 | grep "^d" | awk -F" " '{print $9}') ; do
	  orgPath=$1"/"$org

    for orderer in $(ls -l $orgPath"/orderers" | grep "^d" | awk -F" " '{print $9}') ; do
			ordererPath=$orgPath"/orderers/"$orderer
			kubectl delete -f "${ordererPath}/${orderer}.yaml"
		done

	  kubectl delete -f "${orgPath}/${org}-namespace.yaml"
  done
}

function deletePeers () {

	kubectl delete -f templates/composer-playground.yaml

	kubectl delete -f templates/composer-playground-storage.yaml

	for org in $(ls -l $1 | grep "^d" | awk -F" " '{print $9}') ; do
    orgPath=$1"/"$org

		for peer in $(ls -l $orgPath"/peers" | grep "^d" | awk -F" " '{print $9}') ; do
			peerPath=$orgPath"/peers/"$peer
			kubectl delete -f "${peerPath}/${peer}.yaml"
		done

		kubectl delete -f "${orgPath}/${org}-ca.yaml"

		kubectl delete -f "${orgPath}/${org}-namespace.yaml"

	done

}

function deleteCli () {
	kubectl delete -f "${CONFIG_PATH}/crypto-config/cli.yaml"
}

function deleteK8s () {
	deleteOrderers $ORDERER
  deletePeers $PEER
	deleteCli
}

deleteK8s
