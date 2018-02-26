#!/bin/bash

echo
echo " ============================================== "
echo " ==========initialize businesschannel========== "
echo " ============================================== "
echo


echo_r () {
    [ $# -ne 1 ] && return 0
    echo -e "\033[31m$1\033[0m"
}
echo_g () {
    [ $# -ne 1 ] && return 0
    echo -e "\033[32m$1\033[0m"
}
echo_y () {
    [ $# -ne 1 ] && return 0
    echo -e "\033[33m$1\033[0m"
}
echo_b () {
    [ $# -ne 1 ] && return 0
    echo -e "\033[34m$1\033[0m"
}

CHANNEL_NAME="$1"
: ${CHANNEL_NAME:="businesschannel"}
: ${TIMEOUT:="60"}
COUNTER=1
MAX_RETRY=5
ORDERER_CA=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/ordererOrganizations/orderer/orderers/orderer.orderer/msp/tlscacerts/tlsca.orderer-cert.pem

echo_b "Channel name : "$CHANNEL_NAME

verifyResult () {
	if [ $1 -ne 0 ] ; then
		echo_b "!!!!!!!!!!!!!!! "$2" !!!!!!!!!!!!!!!!"
                echo_r "================== ERROR !!! FAILED to execute End-2-End Scenario =================="
		echo
   		exit 1
	fi
}

setGlobals () {

	if [ $1 -eq 0 -o $1 -eq 1 ] ; then
		CORE_PEER_LOCALMSPID="Org1MSP"
		CORE_PEER_TLS_ROOTCERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/org1/peers/peer0.org1/tls/ca.crt
		CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/org1/users/Admin@org1/msp
		if [ $1 -eq 0 ]; then
			CORE_PEER_ADDRESS=peer0.org1:7051
		else
			CORE_PEER_ADDRESS=peer1.org1:7051
			CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/org1/users/Admin@org1/msp
		fi
	else
		CORE_PEER_LOCALMSPID="Org2MSP"
		CORE_PEER_TLS_ROOTCERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/org2/peers/peer0.org2/tls/ca.crt
		CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/org2/users/Admin@org2/msp
		if [ $1 -eq 2 ]; then
			CORE_PEER_ADDRESS=peer0.org2:7051
		else
			CORE_PEER_ADDRESS=peer1.org2:7051
		fi
	fi

	env |grep CORE
}

createChannel() {
	setGlobals 0

        if [ -z "$CORE_PEER_TLS_ENABLED" -o "$CORE_PEER_TLS_ENABLED" = "false" ]; then
		peer channel create -o orderer.orderer:7050 -c $CHANNEL_NAME -f /opt/gopath/src/github.com/hyperledger/fabric/peer/channel-artifacts/channel.tx >&log.txt
	else
		peer channel create -o orderer.orderer:7050 -c $CHANNEL_NAME -f /opt/gopath/src/github.com/hyperledger/fabric/peer/channel-artifacts/channel.tx --tls $CORE_PEER_TLS_ENABLED --cafile $ORDERER_CA >&log.txt
	fi
	res=$?
	cat log.txt
	verifyResult $res "Channel creation failed"
	echo_g "===================== Channel \"$CHANNEL_NAME\" is created successfully ===================== "
	echo
}

updateAnchorPeers() {
        PEER=$1
        setGlobals $PEER

        if [ -z "$CORE_PEER_TLS_ENABLED" -o "$CORE_PEER_TLS_ENABLED" = "false" ]; then
		peer channel update -o orderer.orderer:7050 -c $CHANNEL_NAME -f /opt/gopath/src/github.com/hyperledger/fabric/peer/channel-artifacts/${CORE_PEER_LOCALMSPID}anchors.tx >&log.txt
	else
		peer channel update -o orderer.orderer:7050 -c $CHANNEL_NAME -f /opt/gopath/src/github.com/hyperledger/fabric/peer/channel-artifacts/${CORE_PEER_LOCALMSPID}anchors.tx --tls $CORE_PEER_TLS_ENABLED --cafile $ORDERER_CA >&log.txt
	fi
	res=$?
	cat log.txt
	verifyResult $res "Anchor peer update failed"
	echo_g "===================== Anchor peers for org \"$CORE_PEER_LOCALMSPID\" on \"$CHANNEL_NAME\" is updated successfully ===================== "
	echo
}

## Sometimes Join takes time hence RETRY atleast for 5 times
joinWithRetry () {
	peer channel join -b $CHANNEL_NAME.block  >&log.txt
	res=$?
	cat log.txt
	if [ $res -ne 0 -a $COUNTER -lt $MAX_RETRY ]; then
		COUNTER=` expr $COUNTER + 1`
		echo_b "PEER$1 failed to join the channel, Retry after 2 seconds"
		sleep 2
		joinWithRetry $1
	else
		COUNTER=1
	fi
        verifyResult $res "After $MAX_RETRY attempts, PEER$ch has failed to Join the Channel"
}

joinChannel () {
	for ch in 0 1 2 3; do
		setGlobals $ch
		joinWithRetry $ch
		echo_g "===================== PEER$ch joined on the channel \"$CHANNEL_NAME\" ===================== "
		sleep 2
		echo
	done
}


## Create channel
echo_b "Creating channel..."
createChannel

## Join all the peers to the channel
echo_b "Having all peers join the channel..."
joinChannel

## Set the anchor peers for each org in the channel
echo_b "Updating anchor peers for org1..."
updateAnchorPeers 0
echo_b "Updating anchor peers for org2..."
updateAnchorPeers 2


echo
echo_g "===================== All GOOD, initialization completed ===================== "
echo

echo
echo " _____   _   _   ____  "
echo "| ____| | \ | | |  _ \ "
echo "|  _|   |  \| | | | | |"
echo "| |___  | |\  | | |_| |"
echo "|_____| |_| \_| |____/ "
echo

exit 0
