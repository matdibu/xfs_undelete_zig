#!/bin/env python3

from os import listdir
from random import shuffle

from Path import unlink

if __name__ == "__main__":
    target_dir = "mount"
    files = listdir(target_dir)
    shuffle(files)
    for file in files[::2]:
        path = target_dir + "/" + file
        unlink(path)
