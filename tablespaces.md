# PostgreSQL Tablespaces

A **tablespace** is a location on disk where PostgreSQL stores data files containing database objects. It maps a logical name to a physical location on the disk.

## Default Tablespaces
- **pg_default**: Stores all user data.
- **pg_global**: Stores all global data (e.g., shared system catalogs).

## Advantages of Tablespaces
- Can create a new tablespace on a new filesystem (FS) and use it for data storage.
- Enables placing frequently accessed indexes or tables on high-performing devices.

---

## PostgreSQL Initialization

When initializing a PostgreSQL database in Linux, the following commands are used:

```bash
userName@HostName:~$ pg_ctl -D <data_dir_loc> initdb
userName@HostName:~$ pg_ctl -D <data_dir_loc> start
```

When the PostgreSQL server initializes, it creates necessary files in the `$PGDATA` directory. Two default tablespaces are automatically created:

- **pg_global**: Used for shared system catalogs.
- **pg_default**: Default tablespace for the `template1` and `template0` databases.

---

## Understanding Hostname and PostgreSQL Shell Interface

### Hostname
The hostname represents the system where the PostgreSQL server is running. It is helpful for connecting to PostgreSQL from local or remote clients. In commands, the `userName@HostName` indicates the username and hostname of the system executing the commands.

Example:
```bash
userName@HostName:~$ psql -U postgres
```
Here:
- `userName` is the Linux/OS user.
- `HostName` is the hostname of the server.

### PostgreSQL Shell Interface
The PostgreSQL shell (`psql`) is an interactive command-line interface to manage databases. It allows users to run SQL commands, manage tablespaces, and perform administrative tasks.

To access the shell:
```bash
userName@HostName:~$ psql -U postgres
```
Once inside the shell, the prompt changes to:
```sql
postgres-#
```

You can then use commands like:
- `\l` to list databases.
- `\db+` to list tablespaces.
- `\q` to quit the shell.

---

## Common Tablespace Commands

### Create a Tablespace
```sql
postgres-# CREATE TABLESPACE tbs1 LOCATION '/postgres/data/tbs1';
```

### List Tablespaces
```sql
postgres-# \db+
```

### Check Tablespace Directory
```bash
userName@HostName:~$ ls -l data/pg_tblspc
```

### Create a Database with a Specific Tablespace
```sql
postgres-# CREATE DATABASE db1 TABLESPACE tbs1;
```

### Create a Table
By default, tables use the `pg_default` tablespace unless otherwise specified. You can explicitly declare a tablespace:

```sql
postgres-# CREATE TABLE tbl1 (...);
```

---

## Managing PostgreSQL Service

### Check PostgreSQL Service Status
```bash
# Linux
userName@HostName:~$ sudo systemctl status postgresql*

# Windows
userName@HostName:~$ Get-Service -Name postgresql*
```

### Log in to PostgreSQL
```bash
userName@HostName:~$ psql -U postgres
```

### Create a New Instance and Initialize
```bash
userName@HostName:~$ mkdir -p /postgres/data/instanceName
userName@HostName:~$ pg_ctl -D /postgres/data/instanceName initdb
userName@HostName:~$ /usr/bin/pg_ctl -D /postgres/data/instanceName -l logfile start
```

### Check Running Processes
```sql
postgres-# SELECT pid, usename, application_name, client_addr, backend_start, wait_event 
postgres-# FROM pg_stat_activity;
```

---

## Moving Objects Between Tablespaces

### Move a Table to a New Tablespace
```sql
postgres-# ALTER TABLE tab1 SET TABLESPACE pg_default;
```

### Move All Tables
```sql
postgres-# ALTER TABLE ALL SET TABLESPACE pg_default;
```

> **Note:** Moving large tables can take significant time. During this operation:
> - Readers and writers still have access.
> - Low I/O performance might be observed.

### Move Indexes to a New Tablespace
Indexes associated with tables are not automatically moved. They need to be explicitly moved:
```sql
postgres-# ALTER INDEX index_name SET TABLESPACE ts2;
```

---

## Backup and Restore Tablespaces

### Backup a Tablespace
```bash
userName@HostName:~$ pg_basebackup --format=p --tablespace-mapping=/tmp/OldTSLocation=/tmp/NewTSLocation -D <dir_location>
```
### Standardized and Readable Command

```bash
pg_basebackup \
  --format=p \
  --tablespace-mapping=/tmp/OldTSLocation=/tmp/NewTSLocation \
  --pgdata=<dir_location>
```


1. **`pg_basebackup`**: Utility for creating a physical backup of the PostgreSQL cluster.
2. **`--format=p`**: Sets the output format to **plain** (file-system structure).
3. **`--tablespace-mapping=/tmp/OldTSLocation=/tmp/NewTSLocation`**: Redirects the tablespace from its original location to a new one during the backup.
4. **`--pgdata=<dir_location>`**: Specifies the directory where the main database cluster's backup will be stored.

---

## Additional Notes
- For large tables, consider creating a dump and restoring it rather than using `ALTER TABLE`.
- Tablespaces provide flexibility in managing storage and performance tuning by utilizing different physical devices.

---
