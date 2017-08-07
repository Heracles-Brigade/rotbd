#files to be ignored
binary_files = ["lgt","map","mat","bmp","wav","ogg","tga","png","hg2","hgt","geo","sdf","vdf","mesh","skeleton","py"]

textchars = bytearray({7,8,9,10,12,13,27} | set(range(0x20, 0x100)) - {0x7f})
is_binary_string = lambda bytes : bool(bytes.translate(None, textchars))

def is_binary_file(file):
  bfile = False
  for ext in binary_files:
    if(file.lower().endswith(ext)):
      return True
  return is_binary_string(open(file, 'rb').read(1024))

