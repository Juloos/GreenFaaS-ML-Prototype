# GreenFaaS ML Prototype
Testing whether it is viable to estimate the energy consumption of a faas workload using machine learning model on the initial request.

Run OpenWhisk with

    $ ./run_openwhisk.sh

Run the demo to get energy consumption data with

    $ ./run_text2speech.sh

Wait that OpenWhisk finished building and deploying before running the demo for accurate data.

You can also decide to run the tests on multiple machines automatically on Grid5000 as described below.


# Prerequisites

An account on Grid5000 with access to Lyon site, and a machine with public access to run OpenStack Swift SAIO's front API.


# General setup
You need to install OpenStacks Swift SAIO on a distant machine with public access. You can follow the instructions given [here](https://docs.openstack.org/swift/latest/development_saio.html). This prototype uses the "test:tester" user and the "$HOSTNAME_whiskcontainer" namespaces for each host, all the files are automatically uploaded to the namespaces beforehand from `swift_files/`. Note that you will probably need to allocate more than the default 1Go to Swift's file system if you want to deploy the demo in multiple machines.


# Grid5000 setup
Please use Lyon as your frontend site for the machine reservation.

The following commands will help you setup an environment file to run the energy gathering data on multiple machines later on.

`flyon:` `$ oarsub -I -t deploy -l host=1,walltime=1`

`flyon:` `$ export NODE=$(oarprint host) && kadeploy3 ubuntu2204-min && ssh root@$NODE`

`node:` `$ f() { apt update -y && apt upgrade -y && apt install default-jre nodejs npm python3-swiftclient; }; DEBIAN_FRONTEND=noninteractive f`

`node:` `$ curl -fsSL https://get.docker.com -o get-docker.sh && chmod 700 get-docker.sh && ./get-docker.sh`

`node:` `$ git clone https://github.com/Juloos/GreenFaaS-ML-Prototype`

`node:` `$ ./GreenFaaS-ML-Prototype/run_openwhisk.sh`

Let the script run until it launches OpenWhisk, then stop it and exit the node.

`flyon:` `$ git clone https://github.com/Juloos/GreenFaaS-ML-Prototype && cd GreenFaaS-ML-Prototype`

`flyon:` `$ tgz-g5k -m $NODE -f openwhisk_image.tar.zst`


# Grid5000 deployment

`flyon:` `$ echo "Put the ip of your Swift distant machine here." >GreenFaaS-ML-Prototype/.ipv4`

`flyon:` `$ oarsub -t deploy -t monitor='wattmetre_power_watt' -l host=8,walltime=16 "./GreenFaaS-ML-Prototype/deploy.sh"`


# Credit
- text2speech & swift_files: Donald Onana
- openwhisk: Apache Software Foundation
- bin/wsk & bin/wskdeploy: Apache Software Foundation 
