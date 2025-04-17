# GreenFaaS ML Prototype
Testing whether it is viable to estimate the energy consumption of a faas workload using machine learning model on the initial request.

# Running OpenWhisk

    $ ./run_openwhisk.sh

# Setup
You need to install OpenStacks Swift SAIO on the local machine, or preferably on a distant machine with public access. You can follow the instructions given [here](https://docs.openstack.org/swift/latest/development_saio.html). This prototype uses the "test:tester" user in the "whiskcontainer" namespace, all the files that need to be uploaded to this namespace beforehand are in `swift_files/`.

For the rest of the setup, run `setup.sh`

# Grid5000 setup
`frontend:` `$ git clone https://github.com/Juloos/GreenFaaS-ML-Prototype --recursive`

`frontend:` `$ oarsub -I -t deploy -t monitor='wattmetre_power_watt' -l host=1,walltime=3` -> returns the reserved machine `<node>`

`frontend:` `$ export NODE=<node> ; kadeploy3 ubuntu2204-min -m $NODE && ssh root@$NODE`

`node:` `$ apt update && yes | apt upgrade && yes | apt install default-jre nodejs npm`

`node:` `$ curl -fsSL https://get.docker.com -o get-docker.sh && chmod 700 get-docker.sh && ./get-docker.sh`

# Credit
- text2speech & swift_files: Donald Onana
- openwhisk: Apache Software Foundation
- bin/wsk & bin/wskdeploy: Apache Software Foundation 
