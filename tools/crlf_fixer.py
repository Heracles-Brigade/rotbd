# Fixes CRLF issues for battlezone
# Operates on all files in folder

import mimetypes
import argparse
import re
import glob
import os


#files that are always binary
binary_files = ["lgt","map","mat","bmp","wav","ogg","tga","png","hg2","hgt","geo","sdf","vdf","mesh","skeleton","py"]

textchars = bytearray({7,8,9,10,12,13,27} | set(range(0x20, 0x100)) - {0x7f})
is_binary_string = lambda bytes : bool(bytes.translate(None, textchars))

def is_binary_file(file):
  bfile = False
  for ext in binary_files:
    if(file.lower().endswith(ext)):
      return True
  return is_binary_string(open(file, 'rb').read(1024))

parser = argparse.ArgumentParser(description='CRLF -> LF')
parser.add_argument('path',help='file or directory to operate on')

args = parser.parse_args()
if(os.path.isfile(args.path)):
  files = [args.path]
else:
  files = [n for n in glob.glob("{}/*".format(args.path)) if not is_binary_file(n)]

for file in files:
  try:
    with open(file,'r') as f:
      content = f.read()
    with open(file,'w',newline='\r\n') as f:
      f.write(content)
  except:
    print("Could not read or convert file {}".format(file))
