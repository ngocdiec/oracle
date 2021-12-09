--Kiểm tra lại log mode của DB:
SELECT name, log_mode FROM v$database;

SHUTDOWN immediate;
STARTUP mount;
ALTER DATABASE NOARCHIVELOG;
ALTER DATABASE OPEN;
