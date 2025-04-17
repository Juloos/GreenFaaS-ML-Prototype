# GreenFaaS ML Prototype
Testing whether it is viable to estimate the energy consumption of a faas workload using machine model on the initial request.

# Running OpenWhisk

    $ ./run_openwhisk.sh

# Setup
You need to install OpenStacks Swift SAIO on the local machine, or preferably on a distant machine with public access. You can follow the instructions given [here](https://docs.openstack.org/swift/latest/development_saio.html). This prototype uses the "test:tester" user in the "whiskcontainer" namespace, all the files that need to be uploaded to this namespace beforehand are in `swift_files/`.

For the rest of the setup, run `setup.sh`

# Grid5000 setup
`fgrenoble:` `$ git clone <this_repo>`

`fgrenoble:` `$ oarsub -I -t deploy -l host=1,walltime=3,monitor='wattmetre_power_watt'` -> returns the reserved machine `<node>`

`fgrenoble:` `$ kadeploy3 ubuntu2204-min -m <node> ; ssh root@<node>`

`node:` `$ apt update ; yes | apt upgrade ; yes | apt install default-jre nodejs npm ; /grid5000/code/bin/g5k-setup-docker`

# Credit
- text2speech & swift_files: Donald 
- openwhisk: Apache Software Foundation
