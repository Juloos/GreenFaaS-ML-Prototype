import swiftclient as sc
import os
import socket
import glob
import sys

os.chdir(os.path.dirname(os.path.abspath(__file__)))


if len(sys.argv) != 2:
  print("Usage: %s <ipv4_address>" % sys.argv[0])
  sys.exit(1)

conn = sc.Connection(
  authurl="http://%s:8080/auth/v1.0" % sys.argv[1],
  user="test:tester",
  key="testing",
  auth_version='1'
)

for filename in glob.glob("*Ko.txt"):
  with open(filename, 'rb') as f:
    conn.put_object('%s_whiskcontainer' % socket.gethostname(), filename, contents=f.read())
