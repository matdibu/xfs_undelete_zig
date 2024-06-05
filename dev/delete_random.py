#!/usr/bin/env python3

from pathlib import Path
from random import shuffle
from sys import argv

if __name__ == "__main__":
    target_dir = "mount"
    delete_ratio = int(argv[1])
    files = list(Path(target_dir).iterdir())
    shuffle(files)
    for file in files[::delete_ratio]:
        file.unlink()
