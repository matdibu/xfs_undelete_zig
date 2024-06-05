#!/bin/env python3

import random
import string
from os import sync

from pathlib import Path

if __name__ == "__main__":
    out_dir = "mount"
    for _ in range(100):
        file_name = "".join(random.choice(string.ascii_lowercase) for i in range(16))
        file_path = out_dir + "/" + file_name
        file_text = "this is the text for file " + file_name + "\n"
        with Path.open(file_path, "w") as f:
            f.write(file_text)
    sync()
