#!/bin/env python3

import string
import random
from os import sync

if __name__ == "__main__":
    out_dir = "mount"
    for _ in range(100):
        file_name = "".join(random.choice(string.ascii_lowercase) for i in range(16))
        file_path = out_dir + "/" + file_name
        file_text = "this is the text for file " + file_name + "\n"
        with open(file_path, "w") as f:
            f.write(file_text)
            print("created and wrote " + file_path)
    sync()
