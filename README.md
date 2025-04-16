# GreenFaaS ML Prototype

# Running OpenWhisk

    $ ./run_openwhisk.sh

# Setup
You need to install OpenStacks Swift SAIO on the local machine, or preferably on a distant machine with public access. You can follow the instructions given [here](https://docs.openstack.org/swift/latest/development_saio.html). This prototype uses the "test:tester" user in the "whiskcontainer" namespace, all the files that need to be uploaded to this namespace beforehand are in `swift_files/`.

For the rest of the setup, run `setup.sh`

# Grid5000 setup
`fgrenoble:` `$ git clone <this_repo>`

`fgrenoble:` `$ oarsub -I -t deploy -l host=1,walltime=3` -> returns the reserved machine `<node>`

`fgrenoble:` `$ kadeploy3 ubuntu2204-min -m <node> ; ssh root@<node>`

`node:` `$ /grid5000/code/bin/g5k-setup-docker ; apt install default-java nodejs npm`
