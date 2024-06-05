#!/bin/env python3

from os import listdir
from random import shuffle

from pathlib import Path

if __name__ == "__main__":
    target_dir = "mount"
    files = listdir(target_dir)
    shuffle(files)
    for file in files[::2]:
        path = target_dir + "/" + file
        Path.unlink(path)
