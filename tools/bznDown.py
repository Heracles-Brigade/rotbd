import re
import argparse

parser = argparse.ArgumentParser(description='2XXX -> 1045')
parser.add_argument('file',help='The file to convert')
parser.add_argument('out',help='Output file')


args = parser.parse_args()

DOWNGRADE_TO = "version [1] =\n1045"

V_NUM = "version \[1\] =\n\d*"

ARR_PFIX = "{}\s*\[\d+\]\s*=\n.*\n"
V_PFIX = "{}\s*=\s*.*\n"

PURGE_MAP = [
    "cloak\w*",
    "isCritical"
]


with open(args.file,"r") as f:
    content = f.read()
    content = re.sub(V_NUM,DOWNGRADE_TO,content)
    for i, v in enumerate(PURGE_MAP):
        content = re.sub(ARR_PFIX.format(v),"",content)
        content = re.sub(V_PFIX.format(v),"",content)

with open(args.out or args.file,"w") as f:
    f.write(content)
