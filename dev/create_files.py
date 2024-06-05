#!/usr/bin/env python3

from random import choice
from string import ascii_lowercase
from os import sync
from sys import argv

from pathlib import Path

if __name__ == "__main__":
    no_of_files = int(argv[1])
    out_dir = "mount"
    for index in range(no_of_files):
        file_name = "".join(choice(ascii_lowercase) for i in range(16))
        file_path = out_dir + "/" + file_name
        file_text = f"this is the text for file #{index}, named {file_name}, repeated {index} times"
        with Path.open(file_path, "w") as f:
            for _ in range(0, index):
                f.write(file_text)
    sync()
