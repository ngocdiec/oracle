--Kiểm tra lại log mode của DB:
SELECT name, log_mode FROM v$database;

--test
SELECT name, log_mode FROM v$database;
SHUTDOWN immediate;
STARTUP mount;
ALTER DATABASE ARCHIVELOG;
ALTER DATABASE OPEN;
