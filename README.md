# RemoteDirSynch
Wrapper Script for rsync on FreeNAS-9.10

This bash script provides a wrapper around rsync  version 3.1.2  protocol version 31 comparing the children of two directories (one local, the other remote) and synchronising changes locally, where the children of the local directory also exists on the remote server.
At present the primary use case is to backup changes from a server daily via a cron schedule using rsync.
