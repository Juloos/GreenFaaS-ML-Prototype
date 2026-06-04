# Setup
Clone this repository to your homedir on Grid5000 (be careful that each site has a different homedir). Beware of the 'simple-OW-deploy' branch.

First you need to cook images for the nodes to quickly deploy environments that have OpenWhisk. Run `./g5k_prepare.sh` from a site frontend of Grid5000 and wait ~30m.

You can now deploy that newly created environment by running `./g5k_interactive.sh [<nb of nodes> = 1] [<walltime> = 1]` to reserve nodes and then `./g5k_deploy/partial_start.sh` to deploy OpenWhisk on those nodes.


# Credit
- openwhisk: Apache Software Foundation
- bin/wsk & bin/wskdeploy: Apache Software Foundation
- Grid'5000: https://www.grid5000.fr/
