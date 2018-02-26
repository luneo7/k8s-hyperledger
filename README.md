# Hyperledger on Kubernetes

This project will build a basic blockchain with the following components:
* Fabric-CA (2, one for Org1 and another for Org2)
* Orderer (solo)
* Fabric-Peer (2, one for Org1 and another for Org2)
* Hyperleger Composer


Note: It is possible to run this project on minikube. This work is based on Haining Henry Zhang article on Hyperledger Fabric.

# Instructions

## Environment creation in Kubernetes

For execution you need to export the "/opt/share" path on a NFS server

It is necessary to change the "generate.sh" file and put the IP of the NFS server in the variable "NFSSERVER"

The machine that is executing the script must also have mounted the NFS share in the "/opt/share" path because the necessary files for Hyperledger will be placed there, for example, the "channel-artifacts", "crypto-config" and composer files.


Note: There is also a composer-rest-server dockerfile, located in the "composer-rest-server" folder, with maximum payload configured to 1Mb.

### 1. Generate k8s artifacts and files

```
./generate.sh
```

### 2. Run the k8s files

```
./run.sh
```

### 3. Create a channel and run k8s Composer Playground yaml

```
./generateChannel.sh
```

### 4. Deploy a Composer Rest Server

Only after creating a network in Composer Playground you can run a rest server for that specific network. For that you need to change "#NAMEOFTHENETWORK" in the "templates/composer-rest-server.yaml" file with the name of the network that you created, and then run the following command:

```
kubectl create -f templates/composer-rest-server.yaml
```

## Removal of the environment in kubernetes

### 1. Run the script for removal

```
./delete.sh
```
