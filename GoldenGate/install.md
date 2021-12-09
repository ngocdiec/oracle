# Cài đặt GoldenGate Software
Đẩy bộ cài GoldenGate lên server của cả SourceDB và TargetDB
```bash
scp 191001_fbo_ggs_Linux_x64_shiphome.zip oracle@goldengate:/tmp
```

Login vào server bằng user oracle và thực hiện các lệnh sau
```bash
su - oracle
cd /tmp
unzip 191001_fbo_ggs_Linux_x64_shiphome.zip
mkdir -p /u01/app/oracle/product/ogg_1

# Add OGG_HOME
cd /home/oracle/
vi .bash_profile
export OGG_HOME=/u01/app/oracle/product/ogg_1

# Install Oracle GoldenGate
cd /tmp/fbo_ggs_Linux_x64_shiphome/Disk1/
./runInstaller
```

Đặt SourceDB chạy archivelog mode:
```sql
--Kiểm tra lại log mode của DB:
SELECT name, log_mode FROM v$database;

SHUTDOWN immediate;
STARTUP mount;
ALTER DATABASE ARCHIVELOG;
ALTER DATABASE OPEN;
```

# Cấu hình các tham số cho database
## Trên SourceDB
Alter database
```sql
SELECT supplemental_log_data_min, force_logging FROM v$database;
ALTER DATABASE ADD SUPPLEMENTAL LOG DATA;
ALTER DATABASE FORCE LOGGING;
ALTER SYSTEM SWITCH LOGFILE;
SELECT supplemental_log_data_min, force_logging FROM v$database;
ALTER SYSTEM SET enable_goldengate_replication=TRUE SCOPE=BOTH;
```
Tạo user và tablespace cho GoldenGate
```sql
CREATE TABLESPACE TS_OGG DATAFILE '/data/MMS/TS_OGG.dbf' SIZE 100M AUTOEXTEND ON NEXT 10M MAXSIZE UNLIMITED;
CREATE USER ggadmin IDENTIFIED BY "ggadmin" DEFAULT TABLESPACE TS_OGG TEMPORARY TABLESPACE TEMP PROFILE DEFAULT ACCOUNT UNLOCK;
GRANT CREATE SESSION, CONNECT, RESOURCE, ALTER SYSTEM TO ggadmin;
EXEC DBMS_GOLDENGATE_AUTH.GRANT_ADMIN_PRIVILEGE(grantee=>'ggadmin', privilege_type=>'CAPTURE', grant_optional_privileges=>'*');
```


## Trên TargetDB
Alter database
```sql
ALTER SYSTEM SET enable_goldengate_replication=TRUE SCOPE=BOTH;
```
Tạo user và tablespace cho GoldenGate
```sql
CREATE TABLESPACE TS_OGG DATAFILE '/data/GG4BD/TS_OGG.dbf' SIZE 100M AUTOEXTEND ON NEXT 10M MAXSIZE UNLIMITED;
CREATE USER ggadmin IDENTIFIED BY "ggadmin"   DEFAULT TABLESPACE TS_OGG TEMPORARY TABLESPACE TEMP PROFILE DEFAULT ACCOUNT UNLOCK;
GRANT CREATE SESSION, CONNECT, RESOURCE, ALTER SYSTEM TO ggadmin;
EXEC DBMS_GOLDENGATE_AUTH.GRANT_ADMIN_PRIVILEGE(grantee=>'ggadmin', privilege_type=>'APPLY', grant_optional_privileges=>'*');
```
# Cấu hình các tham số cho GoldenGate
## Khởi tạo GoldenGate
### Trên SourceDB
```bash
cd $OGG_HOME
sqlplus / as sysdba
```

```sql
@marker_setup.sql
@ddl_setup.sql
@role_setup.sql
GRANT GGS_GGSUSER_ROLE TO ggadmin;
@ddl_enable.sql
--@prvtlmpg.plb --below 12c
```

Tạo các thư mục cần thiết
```bash
cd $OGG_HOME
./ggsci
create subdirs
```
Tạo credentialstore
```bash
cd $OGG_HOME
./ggsci
# GGSCI
add credentialstore
alter credentialstore add user ggadmin@mms alias ggsource
info credentialstore

# test credentialstore
dblogin useridalias ggsource
```

### Trên TargetDB
```bash
cd $OGG_HOME
sqlplus / as sysdba
```

```sql
@marker_setup.sql
@ddl_setup.sql
@role_setup.sql
GRANT GGS_GGSUSER_ROLE TO ggadmin;
@ddl_enable.sql
--@prvtlmpg.plb --below 12c
```

Tạo các thư mục cần thiết
```bash
cd $OGG_HOME
./ggsci
create subdirs
```

Tạo credentialstore
```bash
cd $OGG_HOME
./ggsci
# GGSCI
add credentialstore
alter credentialstore add user ggadmin@mms alias ggtarget
info credentialstore

# test credentialstore
dblogin useridalias ggtarget
```
