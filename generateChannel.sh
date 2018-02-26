#!/bin/bash +x

CHANNEL_NAME=$1
: ${CHANNEL_NAME:="businesschannel"}

export TOOLS=$PWD/bin
export CONFIG_PATH=$PWD
export FABRIC_CFG_PATH=$PWD

function initialize() {
  echo "===> Initializing Channel"
	CLI_POD_NAME=$(kubectl get pod --namespace=default | grep cli | cut -d' ' -f1)

	kubectl --namespace=default exec $CLI_POD_NAME -- bash -c "./channel-artifacts/initialize.sh ${CHANNEL_NAME}"

}

function installChaincode() {
	echo "===> Installing Chaincode"
	CLI_POD_NAME=$(kubectl get pod --namespace=default | grep cli | cut -d' ' -f1)

  kubectl --namespace=default exec $CLI_POD_NAME -- bash -c "./channel-artifacts/installchaincode.sh"

}

function createComposerStorage() {
	echo "===> Creating Composer Storage"
	kubectl create -f templates/composer-playground-storage.yaml
}

function createIdentityImport() {
	echo "===> Creating Composer Identity Import"
	kubectl create -f templates/composer-identity-import.yaml

	while [ "$(kubectl get pod -a --namespace=org1 composer-identity-import | grep composer-identity-import | awk '{print $3}')" != "Completed" ]; do
    echo "Waiting for identity import to be Completed"
    sleep 1;
  done

	echo "===> Deleting Composer Identity Import"
	kubectl delete -f templates/composer-identity-import.yaml

	while [ "$(kubectl get svc --namespace=org1 | grep composer-identity-import | wc -l | awk '{print $1}')" != "0" ]; do
		echo "Waiting for identity import to be deleted"
		sleep 1;
  done

}

function createPlayground() {
	echo "===> Creating Composer Playground"
	kubectl create -f templates/composer-playground.yaml
}

initialize
createComposerStorage
createIdentityImport
createPlayground
