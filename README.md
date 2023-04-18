# ocp-install-day1

Need to add values (vcenter) in install.env.sh and install-config.yaml-vcenter

Need to add values (certs, pull secret) in install-config.yaml-vcenter

Need to add values (vips, mac addresses, ip, dns, gateway) in install.env.$cluster.sh (ex install.env.vc2.sh)

Start install with : sh install.sh $cluster (ex: sh install.sh vc2)

custom-manifests directory : day 1 config like oauth (needs to adapt custom-roles, custom-rolesbindings if necessary)

custom-operators directory : config map for each operator with specific keys : namespace, operatorgroup, subscription, crds, yaml, plugin



