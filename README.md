# gschechtli
Enhanced Bash history with context using SQLite

The built-in history of Bash `~/.bash_history` does not provide context about when and where a command was executed.
This project provides a single Bash script which records commands (with context) into an SQLite 3 database file.

Here are the instructions for installing it on *Debian GNU/Linux 12 (bookworm)*:

Download [the `gschechtli.sh` file](./gschechtli.sh) and move it to the `~/.local/share/` directory.

Then, install the packages [`sqlite3`](https://packages.debian.org/bookworm/sqlite3) and [`fzf`](https://packages.debian.org/bookworm/fzf).

Finally, place the following line at the very end of the `~/.bashrc` file to source the script each time a Bash session is started:
```bash
. ~/.local/share/gschechtli.sh
```

The history of future Bash sessions will then be written to the file `~/.local/share/gschechtli.sqlite3`.
Using the up arrow key, one can search this history using `fzf`.
All commands which were executed in the current directory will be shown in chronological order.
