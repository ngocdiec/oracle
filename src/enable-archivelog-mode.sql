--Kiểm tra lại log mode của DB:
SELECT name, log_mode FROM v$database;

--test
SHUTDOWN immediate;
STARTUP mount;
ALTER DATABASE ARCHIVELOG;
ALTER DATABASE OPEN;
