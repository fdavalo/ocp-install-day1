import gzip
import json
import base64
import sys
import urllib.parse

f = open(sys.argv[1])
ign = json.load(f)
f.close()

for fn in ign['storage']['files']:
    if 'contents' in fn:
        s = fn['contents']['source']
        arr = s.split(',')
        content = base64.b64decode(bytes(arr[1], 'utf-8'))
        #z = base64.b64encode(gzip.compress(content))
        #put everything in plain text for better global compression of the ignition file and encoding gzip+base64
        sn = 'data:text/plain;charset=utf-8,'+urllib.parse.quote(content.decode('utf-8'))
        fn['contents']['source'] = sn

print(json.dumps(ign))

