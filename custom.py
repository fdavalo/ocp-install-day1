import gzip
import json
import base64
import sys
import os
import yaml

cluster = sys.argv[1]

f = open("custom-machine-config.yaml")
mc = yaml.load(f)
config = mc["spec"]["config"]
f.close()

custom = {
        "contents": "[Unit]\nDescription=Customizations\nWants=kubelet.service\nAfter=kubelet.service\n\n[Service]\nExecStart=/usr/local/bin/custom.sh /var/lib/kubelet/kubeconfig\n\nRestart=on-failure\nRestartSec=5s\n\n[Install]\nWantedBy=multi-user.target\n",
        "enabled": True,
        "name": "custom.service"
}

script = {
        "overwrite": True,
        "path": "/usr/local/bin/custom.sh",
        "user": {
          "name": "root"
        },
        "contents": {
          "source": "data:text/plain;charset=utf-8;base64,"
        },
        "mode": 365
}

src = {
        "overwrite": True,
        "path": "/usr/local/src/custom.yaml",
        "user": {
          "name": "root"
        },
        "contents": {
          "source": "data:text/plain;charset=utf-8;base64,"
        },
        "mode": 365
}

if "systemd" not in config: config["systemd"] = {}
if "units" not in config["systemd"]: config["systemd"]["units"] = []
config["systemd"]["units"].append(custom)

if "storage" not in config: config["storage"] = {}
if "files" not in config["storage"]: config["storage"]["files"] = []
f = open("custom.sh")
content = f.read()
f.close()
script['contents']['source'] = script['contents']['source'] + base64.b64encode(content.encode('utf-8')).decode('utf-8')
config["storage"]["files"].append(script)

operators = "" 
configmaps = []
roles = ""
for filename in os.listdir('custom-operators'):
    f = os.path.join('custom-operators', filename)
    if os.path.isfile(f):
        f = open(f)
        cm = yaml.load(f)
        configmaps.append(cm["metadata"]["name"])
        if operators == "": operators = cm["metadata"]["name"]
        else: operators = operators + "," + cm["metadata"]["name"]
        if roles == "": roles = "      - " + cm["metadata"]["name"] +"\n"
        else: roles = roles + "      - " + cm["metadata"]["name"] +"\n"
        f.close()


content = ""
for d in ["custom", "custom-operators", "custom-manifests"]:
    for filename in os.listdir(d):
        f = os.path.join(d, filename)
        if os.path.isfile(f):
            f = open(f)
            content = content + f.read().replace("@operators@", operators) + "\n---\n"
            f.close()

src['contents']['source'] = src['contents']['source'] + base64.b64encode(content.encode('utf-8')).decode('utf-8')
config["storage"]["files"].append(src)

f = open(cluster+"/openshift/99_master-custom.yaml", "w")
f.write(yaml.dump(mc,default_flow_style = False, allow_unicode = True, encoding = None))
f.close()

for filename in os.listdir('custom-roles'):
    f = os.path.join('custom-roles', filename)
    if os.path.isfile(f):
        f = open(f)
        fc = f.read()
        f.close()
        f = open(cluster+"/openshift/"+filename, "w")
        f.write(fc.replace("@operators@", roles))
        f.close()

for filename in os.listdir('custom-rolebindings'):
    f = os.path.join('custom-rolebindings', filename)
    if os.path.isfile(f):
        f = open(f)
        fc = f.read()
        f.close()
        f = open(cluster+"/openshift/"+filename, "w")
        f.write(fc.replace("@cluster@", cluster))
        f.close()


