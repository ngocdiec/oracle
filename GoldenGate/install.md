Push file to server
```console
$ scp 191001_fbo_ggs_Linux_x64_shiphome.zip oracle@goldengate:/tmp
```

Login vào server bằng user oracle và thực hiện các lệnh sau
```console
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

Đặt SourceDB chạy archivelog mode
https://github.com/ngocdiec/oracle/blob/772b901560c7a12860dafbbeaa24bf4afdf1fc85/src/enable-archivelog-mode.sql#L1-L7
