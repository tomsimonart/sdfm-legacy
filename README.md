## SDFM

### Description

The Super DotFile Manager is a minimalistic tool with a single purpose:
Allow you to track and share configuration files on multiple machines.

### How it works

SDFM will hard link files (only within your home directory) into a storage directory.
This storage is designed to work with git so you can version your configuration
files and share them between machines.

### Installation

Run `make` for instructions.

For development you can link sdfm to a file in your PATH: `ln ./sdfm.sh ~/.local/usr/bin/sdfm`.

### Example: using git to version and share your storage
You can track your storage with anything you want, but here is an example on how to do it with git:

1. Initialize git on machine 1:
    ```bash
    # Open the storage directory
    sdfm shell
    git init
    git remote add origin git@github.com:<username>/<repo>
    ```
2. Track a configuration file on machine 1:
    ```bash
    # Let's say you want share your .bashrc file with machine 2
    sdfm add ~/.bashrc
    git add .bashrc
    git commit -m 'Add .bashrc to the storage'
    git push
    ```
2. On machine 2:
    ```bash
    sdfm shell
    git clone git@github.com:<username>/<repo> .
    sdfm install
    ```
    Now if you already had a `.bashrc` file in your home directory then SDFM will create a backup automatically (using `ln --backup=numbered`).
    Your old `.bashrc` will now be named `~/.bashrc.~1~` (or `~/.bashrc.~2~` if you already had a backup).


### Features

[License](LICENSE)