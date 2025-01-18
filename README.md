# postgresqlDBA
Postgresql Database Administration

## ENV Setup
2 envs setup :- 
  - linux XUbuntu :
    - easier & preferred
  - windows 11 wsl2 Ubuntu 24.04 LTS :
    - Far more better than installing directly on windows as pg_cron and pg_partman were having some issues post installation like no schema in db.
    - process same as Linux , only port matters


### Windows 11 WSL2 (Ubuntu 24.04)
Assuming WSL2 Ubuntu is running smoothly on the system , now update & upgrade it
```
ubuntu24_04@Preet:~$ sudo apt update
ubuntu24_04@Preet:~$ sudo apt upgrade -y
```
After this , add postgresql repo to source list
```
sudo apt update
sudo apt install -y postgresql-<version>
```
I did not add postgresql repo , and directly ran below without version so i got postgresql-16.
```
ubuntu24_04@Preet:~$ sudo apt install postgresql postgresql-contrib
```
Started and checked with the below commands
```
ubuntu24_04@Preet:~$ sudo service postgresql start
ubuntu24_04@Preet:~$ sudo service postgresql status
```
Now for updating the password 
```
ubuntu24_04@Preet:~$ sudo -i -u postgres
postgres@Preet:~$ \l
l: command not found
postgres@Preet:~$ psql
psql (16.6 (Ubuntu 16.6-0ubuntu0.24.04.1))
Type "help" for help.

postgres=# \password postgres
Enter new password for user "postgres":
Enter it again:
postgres=# \q
postgres@Preet:~$ exit
logout
```
Checked whether i have port 5435 free, as i have already a running instance of postgres on windows (port 5432 is already busy)

```
#net-tools might not be there
ubuntu24_04@Preet:~$ sudo apt install net-tools
ubuntu24_04@Preet:~$ sudo netstat -tuln | grep 5435
```
and on windows as well 
```
C:\Windows\System32>netstat -ano | findstr :5435
```

Updated postgresql.conf
```
ubuntu24_04@Preet:~$ sudo nano /etc/postgresql/16/main/postgresql.conf
```
with 
```
listen_addresses='*'
port = 5435
```

Updated pg_hba.conf
```
ubuntu24_04@Preet:~$ sudo nano /etc/postgresql/16/main/pg_hba.conf
```
with
```
host    all    all    0.0.0.0/0    md5
```

Now restarting the postgres service as the above changes requires a restart
```
ubuntu24_04@Preet:~$ sudo nano /etc/postgresql/16/main/postgresql.conf
ubuntu24_04@Preet:~$ sudo service postgresql restart
ubuntu24_04@Preet:~$ sudo cat /var/log/postgresql/postgresql-16-main.log
```
<details close>
  <summary>
the log file's cat output is as follows (Includes logs due to some typos)</summary>
  
```
2025-01-15 15:24:45.341 UTC [268] LOG:  starting PostgreSQL 16.2 (Ubuntu 16.2-1ubuntu4) on x86_64-pc-linux-gnu, compiled by gcc (Ubuntu 13.2.0-23ubuntu3) 13.2.0, 64-bit
2025-01-15 15:24:45.341 UTC [268] LOG:  listening on IPv4 address "127.0.0.1", port 5432
2025-01-15 15:24:45.344 UTC [268] LOG:  listening on Unix socket "/var/run/postgresql/.s.PGSQL.5432"
2025-01-15 15:24:45.355 UTC [304] LOG:  database system was interrupted; last known up at 2024-12-17 14:10:00 UTC
2025-01-15 15:24:45.701 UTC [304] LOG:  database system was not properly shut down; automatic recovery in progress
2025-01-15 15:24:45.705 UTC [304] LOG:  redo starts at 0/1531050
2025-01-15 15:24:45.705 UTC [304] LOG:  invalid record length at 0/1531088: expected at least 24, got 0
2025-01-15 15:24:45.705 UTC [304] LOG:  redo done at 0/1531050 system usage: CPU: user: 0.00 s, system: 0.00 s, elapsed: 0.00 s
2025-01-15 15:24:45.713 UTC [302] LOG:  checkpoint starting: end-of-recovery immediate wait
2025-01-15 15:24:45.730 UTC [302] LOG:  checkpoint complete: wrote 3 buffers (0.0%); 0 WAL file(s) added, 0 removed, 0 recycled; write=0.006 s, sync=0.002 s, total=0.020 s; sync files=2, longest=0.001 s, average=0.001 s; distance=0 kB, estimate=0 kB; lsn=0/1531088, redo lsn=0/1531088
2025-01-15 15:24:45.733 UTC [268] LOG:  database system is ready to accept connections
2025-01-15 15:25:51.616 UTC [268] LOG:  received fast shutdown request
2025-01-15 15:25:51.618 UTC [268] LOG:  aborting any active transactions
2025-01-15 15:25:51.620 UTC [268] LOG:  background worker "logical replication launcher" (PID 324) exited with exit code 1
2025-01-15 15:25:51.620 UTC [302] LOG:  shutting down
2025-01-15 15:25:51.622 UTC [302] LOG:  checkpoint starting: shutdown immediate
2025-01-15 15:25:51.630 UTC [302] LOG:  checkpoint complete: wrote 0 buffers (0.0%); 0 WAL file(s) added, 0 removed, 0 recycled; write=0.001 s, sync=0.001 s, total=0.010 s; sync files=0, longest=0.000 s, average=0.000 s; distance=0 kB, estimate=0 kB; lsn=0/1531138, redo lsn=0/1531138
2025-01-15 15:25:51.632 UTC [268] LOG:  database system is shut down
2025-01-15 15:25:53.106 UTC [3595] LOG:  starting PostgreSQL 16.6 (Ubuntu 16.6-0ubuntu0.24.04.1) on x86_64-pc-linux-gnu, compiled by gcc (Ubuntu 13.2.0-23ubuntu4) 13.2.0, 64-bit
2025-01-15 15:25:53.106 UTC [3595] LOG:  listening on IPv4 address "127.0.0.1", port 5432
2025-01-15 15:25:53.109 UTC [3595] LOG:  listening on Unix socket "/var/run/postgresql/.s.PGSQL.5432"
2025-01-15 15:25:53.113 UTC [3598] LOG:  database system was shut down at 2025-01-15 15:25:51 UTC
2025-01-15 15:25:53.117 UTC [3595] LOG:  database system is ready to accept connections
2025-01-15 15:30:53.372 UTC [3596] LOG:  checkpoint starting: time
2025-01-15 15:30:53.395 UTC [3596] LOG:  checkpoint complete: wrote 3 buffers (0.0%); 0 WAL file(s) added, 0 removed, 0 recycled; write=0.005 s, sync=0.002 s, total=0.023 s; sync files=2, longest=0.001 s, average=0.001 s; distance=0 kB, estimate=0 kB; lsn=0/1531220, redo lsn=0/15311E8
2025-01-15 16:37:41.758 UTC [11777] postgres@postgres LOG:  provided user name (postgres) and authenticated user name (ubuntu24_04) do not match
2025-01-15 16:37:41.760 UTC [11777] postgres@postgres FATAL:  Peer authentication failed for user "postgres"
2025-01-15 16:37:41.760 UTC [11777] postgres@postgres DETAIL:  Connection matched file "/etc/postgresql/16/main/pg_hba.conf" line 118: "local   all             postgres                                peer"
2025-01-15 16:38:48.624 UTC [11816] postgres@postgres LOG:  provided user name (postgres) and authenticated user name (ubuntu24_04) do not match
2025-01-15 16:38:48.624 UTC [11816] postgres@postgres FATAL:  Peer authentication failed for user "postgres"
2025-01-15 16:38:48.624 UTC [11816] postgres@postgres DETAIL:  Connection matched file "/etc/postgresql/16/main/pg_hba.conf" line 118: "local   all             postgres                                peer"
2025-01-15 16:40:17.348 UTC [11861] postgres@postgres LOG:  provided user name (postgres) and authenticated user name (ubuntu24_04) do not match
2025-01-15 16:40:17.348 UTC [11861] postgres@postgres FATAL:  Peer authentication failed for user "postgres"
2025-01-15 16:40:17.348 UTC [11861] postgres@postgres DETAIL:  Connection matched file "/etc/postgresql/16/main/pg_hba.conf" line 118: "local   all             postgres                                peer"
2025-01-15 16:40:35.587 UTC [11888] postgres@postgres ERROR:  unrecognized configuration parameter "listen_address"
2025-01-15 16:40:35.587 UTC [11888] postgres@postgres STATEMENT:  show listen_address;
2025-01-15 16:40:53.448 UTC [3596] LOG:  checkpoint starting: time
2025-01-15 16:40:53.716 UTC [11888] postgres@postgres ERROR:  parameter "listen_addresses" cannot be changed without restarting the server
2025-01-15 16:40:53.716 UTC [11888] postgres@postgres STATEMENT:  set listen_addresses='*';
2025-01-15 16:40:53.719 UTC [3596] LOG:  checkpoint complete: wrote 3 buffers (0.0%); 0 WAL file(s) added, 0 removed, 0 recycled; write=0.218 s, sync=0.008 s, total=0.272 s; sync files=3, longest=0.005 s, average=0.003 s; distance=2 kB, estimate=2 kB; lsn=0/1531BC8, redo lsn=0/1531B90
2025-01-15 16:43:06.210 UTC [3595] LOG:  received fast shutdown request
2025-01-15 16:43:06.212 UTC [3595] LOG:  aborting any active transactions
2025-01-15 16:43:06.215 UTC [3595] LOG:  background worker "logical replication launcher" (PID 3601) exited with exit code 1
2025-01-15 16:43:06.215 UTC [3596] LOG:  shutting down
2025-01-15 16:43:06.217 UTC [3596] LOG:  checkpoint starting: shutdown immediate
2025-01-15 16:43:06.226 UTC [3596] LOG:  checkpoint complete: wrote 0 buffers (0.0%); 0 WAL file(s) added, 0 removed, 0 recycled; write=0.001 s, sync=0.001 s, total=0.011 s; sync files=0, longest=0.000 s, average=0.000 s; distance=0 kB, estimate=2 kB; lsn=0/1531C78, redo lsn=0/1531C78
2025-01-15 16:43:06.230 UTC [3595] LOG:  database system is shut down
2025-01-15 16:43:06.407 UTC [11952] LOG:  starting PostgreSQL 16.6 (Ubuntu 16.6-0ubuntu0.24.04.1) on x86_64-pc-linux-gnu, compiled by gcc (Ubuntu 13.2.0-23ubuntu4) 13.2.0, 64-bit
2025-01-15 16:43:06.407 UTC [11952] LOG:  listening on IPv4 address "0.0.0.0", port 5432
2025-01-15 16:43:06.407 UTC [11952] LOG:  listening on IPv6 address "::", port 5432
2025-01-15 16:43:06.410 UTC [11952] LOG:  listening on Unix socket "/var/run/postgresql/.s.PGSQL.5432"
2025-01-15 16:43:06.412 UTC [11952] LOG:  invalid authentication method "0.0.0.0?0"
2025-01-15 16:43:06.412 UTC [11952] CONTEXT:  line 119 of configuration file "/etc/postgresql/16/main/pg_hba.conf"
2025-01-15 16:43:06.412 UTC [11952] FATAL:  could not load /etc/postgresql/16/main/pg_hba.conf
2025-01-15 16:43:06.413 UTC [11952] LOG:  database system is shut down
pg_ctl: could not start server
Examine the log output.
2025-01-15 16:49:53.956 UTC [11979] LOG:  starting PostgreSQL 16.6 (Ubuntu 16.6-0ubuntu0.24.04.1) on x86_64-pc-linux-gnu, compiled by gcc (Ubuntu 13.2.0-23ubuntu4) 13.2.0, 64-bit
2025-01-15 16:49:53.956 UTC [11979] LOG:  listening on IPv4 address "0.0.0.0", port 5435
2025-01-15 16:49:53.957 UTC [11979] LOG:  listening on IPv6 address "::", port 5435
2025-01-15 16:49:53.959 UTC [11979] LOG:  listening on Unix socket "/var/run/postgresql/.s.PGSQL.5435"
2025-01-15 16:49:53.960 UTC [11979] LOG:  invalid authentication method "0.0.0.0?0"
2025-01-15 16:49:53.960 UTC [11979] CONTEXT:  line 119 of configuration file "/etc/postgresql/16/main/pg_hba.conf"
2025-01-15 16:49:53.960 UTC [11979] FATAL:  could not load /etc/postgresql/16/main/pg_hba.conf
2025-01-15 16:49:53.961 UTC [11979] LOG:  database system is shut down
pg_ctl: could not start server
Examine the log output.
2025-01-15 16:53:05.981 UTC [12112] LOG:  starting PostgreSQL 16.6 (Ubuntu 16.6-0ubuntu0.24.04.1) on x86_64-pc-linux-gnu, compiled by gcc (Ubuntu 13.2.0-23ubuntu4) 13.2.0, 64-bit
2025-01-15 16:53:05.982 UTC [12112] LOG:  listening on IPv4 address "0.0.0.0", port 5435
2025-01-15 16:53:05.982 UTC [12112] LOG:  listening on IPv6 address "::", port 5435
2025-01-15 16:53:05.985 UTC [12112] LOG:  listening on Unix socket "/var/run/postgresql/.s.PGSQL.5435"
2025-01-15 16:53:05.988 UTC [12112] LOG:  invalid authentication method "0.0.0.0?0"
2025-01-15 16:53:05.988 UTC [12112] CONTEXT:  line 119 of configuration file "/etc/postgresql/16/main/pg_hba.conf"
2025-01-15 16:53:05.988 UTC [12112] FATAL:  could not load /etc/postgresql/16/main/pg_hba.conf
2025-01-15 16:53:05.989 UTC [12112] LOG:  database system is shut down
pg_ctl: could not start server
Examine the log output.
2025-01-15 16:55:21.998 UTC [12155] LOG:  starting PostgreSQL 16.6 (Ubuntu 16.6-0ubuntu0.24.04.1) on x86_64-pc-linux-gnu, compiled by gcc (Ubuntu 13.2.0-23ubuntu4) 13.2.0, 64-bit
2025-01-15 16:55:21.998 UTC [12155] LOG:  listening on IPv4 address "0.0.0.0", port 5435
2025-01-15 16:55:21.998 UTC [12155] LOG:  listening on IPv6 address "::", port 5435
2025-01-15 16:55:22.001 UTC [12155] LOG:  listening on Unix socket "/var/run/postgresql/.s.PGSQL.5435"
2025-01-15 16:55:22.003 UTC [12155] LOG:  invalid authentication method "0.0.0.0?0"
2025-01-15 16:55:22.003 UTC [12155] CONTEXT:  line 119 of configuration file "/etc/postgresql/16/main/pg_hba.conf"
2025-01-15 16:55:22.003 UTC [12155] FATAL:  could not load /etc/postgresql/16/main/pg_hba.conf
2025-01-15 16:55:22.004 UTC [12155] LOG:  database system is shut down
pg_ctl: could not start server
Examine the log output.
2025-01-15 16:59:02.542 UTC [12207] LOG:  starting PostgreSQL 16.6 (Ubuntu 16.6-0ubuntu0.24.04.1) on x86_64-pc-linux-gnu, compiled by gcc (Ubuntu 13.2.0-23ubuntu4) 13.2.0, 64-bit
2025-01-15 16:59:02.543 UTC [12207] LOG:  listening on IPv4 address "0.0.0.0", port 5435
2025-01-15 16:59:02.543 UTC [12207] LOG:  listening on IPv6 address "::", port 5435
2025-01-15 16:59:02.545 UTC [12207] LOG:  listening on Unix socket "/var/run/postgresql/.s.PGSQL.5435"
2025-01-15 16:59:02.547 UTC [12207] LOG:  invalid authentication method "0.0.0.0/0"
2025-01-15 16:59:02.547 UTC [12207] CONTEXT:  line 119 of configuration file "/etc/postgresql/16/main/pg_hba.conf"
2025-01-15 16:59:02.547 UTC [12207] FATAL:  could not load /etc/postgresql/16/main/pg_hba.conf
2025-01-15 16:59:02.548 UTC [12207] LOG:  database system is shut down
pg_ctl: could not start server
Examine the log output.
2025-01-15 17:01:04.343 UTC [12232] LOG:  starting PostgreSQL 16.6 (Ubuntu 16.6-0ubuntu0.24.04.1) on x86_64-pc-linux-gnu, compiled by gcc (Ubuntu 13.2.0-23ubuntu4) 13.2.0, 64-bit
2025-01-15 17:01:04.343 UTC [12232] LOG:  listening on IPv4 address "0.0.0.0", port 5435
2025-01-15 17:01:04.343 UTC [12232] LOG:  listening on IPv6 address "::", port 5435
2025-01-15 17:01:04.345 UTC [12232] LOG:  listening on Unix socket "/var/run/postgresql/.s.PGSQL.5435"
2025-01-15 17:01:04.350 UTC [12235] LOG:  database system was shut down at 2025-01-15 16:43:06 UTC
2025-01-15 17:01:04.357 UTC [12232] LOG:  database system is ready to accept connections
2025-01-15 17:04:31.087 UTC [12262] postgres@postgres ERROR:  syntax error at or near "shared_preload_libraries" at character 1
2025-01-15 17:04:31.087 UTC [12262] postgres@postgres STATEMENT:  shared_preload_libraries = 'pg_cron'
        show shared_preload_libraries;
2025-01-15 17:05:28.640 UTC [12262] postgres@postgres ERROR:  syntax error at or near "shared_preload_libraries" at character 1
2025-01-15 17:05:28.640 UTC [12262] postgres@postgres STATEMENT:  shared_preload_libraries = 'pg_cron'
        ;
2025-01-15 17:05:35.400 UTC [12262] postgres@postgres ERROR:  parameter "shared_preload_libraries" cannot be changed without restarting the server
2025-01-15 17:05:35.400 UTC [12262] postgres@postgres STATEMENT:  set shared_preload_libraries = 'pg_cron';
2025-01-15 17:06:04.428 UTC [12233] LOG:  checkpoint starting: time
2025-01-15 17:06:04.443 UTC [12233] LOG:  checkpoint complete: wrote 3 buffers (0.0%); 0 WAL file(s) added, 0 removed, 0 recycled; write=0.004 s, sync=0.002 s, total=0.018 s; sync files=2, longest=0.001 s, average=0.001 s; distance=0 kB, estimate=0 kB; lsn=0/1531D60, redo lsn=0/1531D28
2025-01-15 17:08:15.373 UTC [12232] LOG:  received fast shutdown request
2025-01-15 17:08:15.375 UTC [12232] LOG:  aborting any active transactions
2025-01-15 17:08:15.376 UTC [12262] postgres@postgres FATAL:  terminating connection due to administrator command
2025-01-15 17:08:15.378 UTC [12232] LOG:  background worker "logical replication launcher" (PID 12238) exited with exit code 1
2025-01-15 17:08:15.378 UTC [12233] LOG:  shutting down
2025-01-15 17:08:15.380 UTC [12233] LOG:  checkpoint starting: shutdown immediate
2025-01-15 17:08:15.390 UTC [12233] LOG:  checkpoint complete: wrote 0 buffers (0.0%); 0 WAL file(s) added, 0 removed, 0 recycled; write=0.001 s, sync=0.001 s, total=0.012 s; sync files=0, longest=0.000 s, average=0.000 s; distance=0 kB, estimate=0 kB; lsn=0/1531E10, redo lsn=0/1531E10
2025-01-15 17:08:15.392 UTC [12232] LOG:  database system is shut down
2025-01-15 17:08:15.540 UTC [12525] LOG:  starting PostgreSQL 16.6 (Ubuntu 16.6-0ubuntu0.24.04.1) on x86_64-pc-linux-gnu, compiled by gcc (Ubuntu 13.2.0-23ubuntu4) 13.2.0, 64-bit
2025-01-15 17:08:15.541 UTC [12525] LOG:  listening on IPv4 address "0.0.0.0", port 5435
2025-01-15 17:08:15.541 UTC [12525] LOG:  listening on IPv6 address "::", port 5435
2025-01-15 17:08:15.543 UTC [12525] LOG:  listening on Unix socket "/var/run/postgresql/.s.PGSQL.5435"
2025-01-15 17:08:15.547 UTC [12528] LOG:  database system was shut down at 2025-01-15 17:08:15 UTC
2025-01-15 17:08:15.552 UTC [12525] LOG:  database system is ready to accept connections
2025-01-15 17:08:15.556 UTC [12531] LOG:  pg_cron scheduler started
2025-01-16 04:12:59.455 UTC [12526] LOG:  checkpoint starting: time
2025-01-16 04:12:59.503 UTC [12526] LOG:  checkpoint complete: wrote 3 buffers (0.0%); 0 WAL file(s) added, 0 removed, 0 recycled; write=0.009 s, sync=0.003 s, total=0.049 s; sync files=2, longest=0.002 s, average=0.002 s; distance=0 kB, estimate=0 kB; lsn=0/1531EF8, redo lsn=0/1531EC0
```
</details>


Install pg_partman and pg_cron
```
ubuntu24_04@Preet:~$ sudo apt update
ubuntu24_04@Preet:~$ sudo apt install postgresql-16-partman
ubuntu24_04@Preet:~$ sudo apt install postgresql-16-cron
ubuntu24_04@Preet:~$ sudo nano /etc/postgresql/16/main/postgresql.conf
```
add shared_preload_libraries = 'pg_cron' in the above file and restart using
below command
```
ubuntu24_04@Preet:~$ sudo service postgresql restart
```


Now to login from windows (11) open command prompt
```
C:\Windows\System32>psql -h localhost -p 5435 -U postgres
```
---

<details close><summary>Images</summary>
  
WSL2 Ubuntu 24.04
![image](https://github.com/Preet-Govind/postgresql-Administration-Notes/blob/main/wsl_terminal_psql.png)

---

Windows 11 cmd
![image](https://github.com/Preet-Govind/postgresql-Administration-Notes/blob/main/cmd_psql.png)

</details>


### Now readying a replica apart from archive
Update postgresql.conf on the Primary
```
ALTER SYSTEM SET listen_addresses = '*';
ALTER SYSTEM SET wal_level = 'replica';
ALTER SYSTEM SET max_wal_senders = 5;
ALTER SYSTEM SET max_replication_slots = 5;
```
Verify , moostly used 123456 for ease of practice
```
SELECT pg_reload_conf();
CREATE ROLE replica_user WITH REPLICATION LOGIN PASSWORD '123456';
```
Update pg_hba.conf
```
host    replication    all    127.0.0.1/32    md5
```

create the Cluster with pg_createcluster , 16 is the postgres version replica_cluster is the name given
```
sudo pg_createcluster --port 5436 16 replica_cluster
```

Remove data and take base backup
```
sudo rm -rv /var/lib/postgresql/16/replica_cluster/
sudo pg_basebackup -h 127.0.0.1 -p 5435 -U replica_user -X stream -C -S replica_1 -v -R -W -D /var/lib/postgresql/16/replica_cluster/
```

Give permission to postgres user
```
sudo chown postgres -R /var/lib/postgresql/16/main/
sudo systemctl restart postgresql
```
Restart with the changes,if needed
```
sudo systemctl restart postgresql@16-replica_cluster
pg_lsclusters
```

Verify primary con info
```
ubuntu24_04@Preet:~$ sudo cat /var/lib/postgresql/16/replica_cluster/postgresql.auto.conf
[sudo] password for ubuntu24_04:

primary_conninfo = 'user=replica_user password=123456 channel_binding=prefer host=127.0.0.1 port=5435 sslmode=prefer ss>primary_slot_name = 'replica_1'
```

Verify with the replica's data or check with some main's table in replica
```
ubuntu24_04@Preet:~$ psql -U postgres -p 5436
SELECT client_addr, state
FROM pg_stat_replication;
```

verify from db
```
SELECT pg_is_in_recovery(); -- Should return 'true'
postgres=# SELECT now() - pg_last_xact_replay_timestamp() AS replication_delay;
```

You can't change the password for postgres as its in read-only

---

<details close>
  <summary>Images</summary>
  
WSL2 Ubuntu 24.04
![image](https://github.com/Preet-Govind/postgresql-Administration-Notes/blob/main/term2.png)

---
<!--
Windows 11 cmd
![image](https://github.com/Preet-Govind/postgresql-Administration-Notes/blob/main/cmd2.png)
-->
</details>
