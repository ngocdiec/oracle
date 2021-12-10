---
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
---
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
---
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
Cấu hình tham số GLOBALS và MANAGER
```bash
cd $OGG_HOME
./ggsci
# GGSCI

edit params ./GLOBALS
GGSCHEMA GGADMIN
CHECKPOINTTABLE     GGADMIN.checkpoint

edit params mgr
PORT 7809
DYNAMICPORTLIST 7810-7820
AUTOSTART ER *
AUTORESTART ER *, RETRIES 16, WAITMINUTES 4
PURGEOLDEXTRACTS ./dirdat/*, USECHECKPOINTS, MINKEEPHOURS 2

stop mgr
start mgr
info all
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

Cấu hình tham số GLOBALS và MANAGER
```bash
cd $OGG_HOME
./ggsci
# GGSCI

edit params ./GLOBALS
GGSCHEMA GGADMIN
CHECKPOINTTABLE     GGADMIN.checkpoint

edit params mgr
PORT 7809
DYNAMICPORTLIST 7810-7820
AUTOSTART ER *
AUTORESTART ER *, RETRIES 16, WAITMINUTES 4
PURGEOLDEXTRACTS ./dirdat/*, USECHECKPOINTS, MINKEEPHOURS 2

# Restart mgr
stop mgr
start mgr
info all
```
---
# Tạo các tiến trình đồng bộ cho GoldenGate
## Trên SourceDB
### Đăng ký dữ liệu cần đồng bộ
Có thể đăng ký tất các các table trong schema, hoặc chỉ định riêng từng table. Lựa chọn một trong hai cách sau:
```bash
cd $OGG_HOME
./ggsci
dblogin useridalias ggsource
```

```diff
- text in red
+ text in green
! text in orange
# text in gray
@@ text in purple (and bold)@@
```
Đăng ký theo schema (:warning: lưu ý thay SCHEMA_NAME bằng schema name thực tế)
```bash
add schematrandata SCHEMA_NAME
```

Đăng ký theo table (:warning: lưu ý thay SCHEMA_NAME bằng schema name thực tế)
```bash
# add tất cả các columns của table
add trandata TABLE_NAME
# add và chỉ định một số column
add trandata TABLE_NAME COLS(colums)
# add và loại trừ một số column
add trandata TABLE_NAME COLSEXCEPT(colums)
# add và chỉ định table không có PK
add trandata TABLE_NAME NOKEY
```
Có một số yêu cầu mà bảng được đồng bộ phải đáp ứng:
1. Bảng nên có Primary Key (PK), nếu không có PK thì có thể sử dụng column có độ distinct cao, tuy nhiên có thể phát sinh lỗi đồng bộ
2. Không được update column là PK.

### Tạo tiến trình integrated extract
```bash
cd $OGG_HOME
./ggsci
dblogin useridalias ggsource

edit params capture1
EXTRACT capture1
useridalias ggsource
EXTTRAIL ./dirdat/tr

# Đăng ký tất cả bảng
TABLE VNPAYGW.*;
# Đăng ký cụ thể từng bảng
TABLE VNPAYGW.TNX_DETAIL;
# Đăng ký bảng theo điều kiện
TABLE VNPAYGW.TERMINALS,COLSEXCEPT(PUBLIC_KEY, PRIVATE_KEY);
TABLE VNPAYGW.TNX,COLSEXCEPT(CARD_NUMBER);

GETAPPLOPS
LOGALLSUPCOLS
UPDATERECORDFORMAT COMPACT
DDL INCLUDE MAPPED
DDLOPTIONS REPORT
DDLOptions AddTranData

register extract capture1 database
add extract capture1, integrated tranlog, begin now
add exttrail ./dirdat/tr, extract capture1
```
### Tạo tiến trình pump
```bash
cd $OGG_HOME
./ggsci
dblogin useridalias ggsource

edit params pump1
EXTRACT pump1
Passthru
useridalias ggsource
RMTHOST 192.168.1.102 , MGRPORT 7809
RMTTRAIL ./dirdat/tr
TABLE VNPAYGW.TERMINALS;
TABLE VNPAYGW.TNX;
TABLE VNPAYGW.TNX_DETAIL;
LOGALLSUPCOLS
DDL INCLUDE MAPPED
DDLOPTIONS REPORT
DDLOptions AddTranData

add extract pump1, exttrailsource ./dirdat/tr, begin now
add rmttrail ./dirdat/tr, extract pump1
```

## Trên TargetDB
### Tạo tiến trình replicat
```bash
cd $OGG_HOME
./ggsci
dblogin useridalias ggsource

edit params apply1
REPLICAT apply1
#DBOPTIONS INTEGRATEDPARAMS(parallelism 8)
DBOPTIONS NOSUPPRESSTRIGGERS
#DDLOPTIONS USELOGINSCHEMA
DDLERROR 1435 IGNORE INCLUDE OPTYPE ALTER OBJTYPE SESSION
DDLERROR 2149 ignore
USERIDALIAS ggtarget
DISCARDFILE ./dirrpt/apply1.dsc,append,MEGABYTES 400
ASSUMETARGETDEFS
#SOURCEDEFS ./dirdef/source.def
#TARGETDEFS ./dirdef/target.def
HANDLECOLLISIONS

# Đăng ký tất cả bảng
MAP VNPAYGW.*, TARGET VNPAYGW.*;

# Đăng ký cụ thể từng bảng
MAP VNPAYGW.TERMINALS ,TARGET VNPAYGW.TERMINALS;
MAP VNPAYGW.TNX ,TARGET VNPAYGW.TNX;
MAP VNPAYGW.TNX_DETAIL ,TARGET VNPAYGW.TNX_DETAIL;

add replicat apply1, integrated  exttrail ./dirdat/tr
```
---
# Khởi tạo đồng bộ GoldenGate - No downtime
## Đồng bộ metadata từ SourceDB sang TargetDB
```bash
# Trên SourceDB
expdp directory=DUMPDIR dumpfile=meta.dmp logfile=meta.log schemas=VNPAYGW content=metadata_only

# Trên TargetDB
impdp directory=DUMPDIR dumpfile=meta.dmp logfile=meta.log
```
## Start tiến trình capture1 và pump1 trên SourceDB
```bash
cd $OGG_HOME
./ggsci

start extract capture1
start extract pump1
info all
```

## Kiểm tra số SCN hiện tại trên SourceDB
```sql
SELECT TO_CHAR (current_scn) FROM v$database;
```
## Tiến hành export data only sau khi có thông tin current SCN trên SourceDB
```bash
expdp directory=DUMPDIR dumpfile=dataonly.dmp logfile=dataonly.log schemas=VNPAYGW content=DATA_ONLY flashback_scn=CURRENT_SCN
```
## import data vừa được export vào TargetDB
```bash
impdp directory=DUMPDIR dumpfile=dataonly.dmp logfile=dataonly.log
```
## Start tiến trình apply1 trên TargetDB aftercsn CURRENT_SCN
```bash
cd $OGG_HOME
./ggsci

start replicat apply1, aftercsn CURRENT_SCN
info all
```

:warning:Ngoại trừ primary key, ta nên disable tất cả constraint trên TargetDB. Có thể bỏ qua khi chỉ đồng bộ 1 chiều Uni-Directional Replication.


# Các tình huống vận hành GoldenGate
1. Thay đổi cấu trúc trên SourceDB nhưng không tự apply
Chạy các lệnh SQL để apply cấu trúc đã thay đổi lên TargetDB. Việc này không ảnh hưởng đến tiến trình đồng bộ.
2. Bổ sung index trên TargetDB
Việc thêm index trên TargetDB không ảnh hưởng đến SourceDB và tiến trình đồng bộ.
3. Tiến trình Extract/Pump/Replicat bị treo (các lệnh stop tiến trình trả lỗi)
Sử dụng lệnh kill để tắt tiến trình, sau đó start lại tiến trình và kiểm tra việc đồng bộ
```bash
cd $OGG_HOME
./ggsci

kill replicat apply1
```
