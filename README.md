# oracle
Indexs



```console:src/enable-archivelog-mode.sql
SHUTDOWN immediate;
STARTUP mount;
ALTER DATABASE ARCHIVELOG;
ALTER DATABASE OPEN;

```
