# PostgreSQL Data Directory and Database Directory

PostgreSQL organizes its storage using a **data directory** and **database directories**. Understanding their roles and structure is crucial for database management, including backups, migrations, and recovery.

---

## **1. PostgreSQL Data Directory**

### **Definition**
The **data directory** is the root directory where PostgreSQL stores all files necessary for its operation. It contains configuration files, logs, and subdirectories for managing data, including individual database directories.

---

### **Default Data Directory**
- On Linux-based systems:
  ```plaintext
  /var/lib/postgresql/<version>/data/
  ```
- On Windows systems, it is typically located under:
  ```plaintext
  C:\Program Files\PostgreSQL\<version>\data\
  ```

---

### **Contents of the Data Directory**
The data directory contains the following key files and subdirectories:
1. **`base/`**:  
   Contains the directories for all databases in the PostgreSQL cluster.
2. **`pg_wal/`**:  
   Stores Write-Ahead Log (WAL) files used for transaction logging and crash recovery.
3. **`pg_stat/`**:  
   Contains runtime statistics of the PostgreSQL cluster.
4. **`pg_tblspc/`**:  
   Contains symbolic links to tablespaces located outside the data directory.
5. **`global/`**:  
   Stores cluster-wide configuration and metadata files, including the `pg_control` file.
6. **Configuration Files**:
   - **`postgresql.conf`**: The main PostgreSQL configuration file.
   - **`pg_hba.conf`**: Configures client authentication.
   - **`pg_ident.conf`**: Maps database roles to operating system users.
7. **Log and Status Files**:
   - **`pg_log/`**: Stores PostgreSQL logs (if configured to log to files).
   - **`postmaster.pid`**: A lock file to prevent multiple instances of the same server.

---

### **How to Locate the Data Directory**
You can find the location of the current data directory by executing:
```bash
sudo -u postgres psql -c "SHOW data_directory;"
```

Example output:
```plaintext
       data_directory       
--------------------------
 /var/lib/postgresql/15/data/
(1 row)
```

---

### **Tasks and Operations on the Data Directory**

#### **1. Backing Up the Data Directory**
- Use the `pg_basebackup` tool for an efficient backup:
  ```bash
  sudo -u postgres pg_basebackup -D /path/to/backup -Fp -Xs -P
  ```
- Alternatively, create a physical copy:
  ```bash
  sudo rsync -av /var/lib/postgresql/<version>/data/ /path/to/backup/
  ```

#### **2. Moving the Data Directory**
Follow these steps to move the data directory:
1. Stop the PostgreSQL service:
   ```bash
   sudo systemctl stop postgresql
   ```
2. Copy the data directory to the new location:
   ```bash
   sudo rsync -av /var/lib/postgresql/15/data/ /new/data/path/
   ```
3. Update the `postgresql.conf` file with the new path:
   ```plaintext
   data_directory = '/new/data/path/'
   ```
4. Restart the PostgreSQL service:
   ```bash
   sudo systemctl start postgresql
   ```
5. Verify the new location:
   ```bash
   sudo -u postgres psql -c "SHOW data_directory;"
   ```

#### **3. Monitoring Disk Space**
Monitor disk usage in the data directory to prevent crashes:
```bash
df -h /var/lib/postgresql/15/data/
```

---

## **2. PostgreSQL Database Directory**

### **Definition**
A **database directory** is a subdirectory within the `base/` directory (or a custom tablespace) that stores all files related to a specific database in a PostgreSQL cluster.

---

### **Location**
- By default, database directories are stored under:
  ```plaintext
  <data_directory>/base/<database_oid>/
  ```
- For databases in custom tablespaces:
  ```plaintext
  <data_directory>/pg_tblspc/<tablespace_oid>/
  ```

---

### **Contents of the Database Directory**
1. **Files**:  
   Each file in a database directory represents a table, index, or other database object. These files are named based on the object's Object Identifier (OID).
2. **Special Subdirectories**:  
   - Subdirectories may exist if partitioning or certain extensions are used.
3. **Relation Files**:  
   - These include `.fsm` (free space maps), `.vm` (visibility maps), and main table files.

---

### **How to Identify a Database Directory**

#### **1. Find the OID of a Database**
To find the OID (Object Identifier) of a specific database:
```sql
SELECT oid, datname FROM pg_database;
```

Example output:
```plaintext
 oid  |  datname  
------+-----------
 16384 | postgres
 16385 | my_database
(2 rows)
```

#### **2. Locate the Corresponding Directory**
- For the `postgres` database (OID `16384`):
  ```plaintext
  <data_directory>/base/16384/
  ```

---

### **Tasks and Operations on the Database Directory**

#### **1. Backup and Recovery**
For database-level backup, use `pg_dump` or `pg_basebackup`. Avoid directly copying database directories unless PostgreSQL is shut down.

#### **2. Inspecting Database Files**
You can inspect database directories to check sizes or troubleshoot corruption:
```bash
sudo du -sh /var/lib/postgresql/15/data/base/<database_oid>/
```

#### **3. Handling Corrupt Database Files**
If corruption is suspected:
1. Stop the PostgreSQL service.
2. Use tools like `pg_resetwal` or `pg_dump` to attempt recovery.
3. Restore from a previous backup if necessary.

---

### **Tablespaces and Database Directories**
- **Default Tablespace**:  
  Database files reside in `base/` unless a custom tablespace is defined.
- **Custom Tablespace**:  
  Use the `pg_tblspc` directory for databases in custom tablespaces. For example:
  ```plaintext
  <data_directory>/pg_tblspc/<tablespace_oid>/
  ```

---

## **Key Differences Between Data Directory and Database Directory**

| Aspect               | Data Directory                          | Database Directory                   |
|----------------------|------------------------------------------|---------------------------------------|
| **Definition**       | Root directory for PostgreSQL instance. | Subdirectory for a specific database.|
| **Location**         | `/var/lib/postgresql/15/data/`          | `/var/lib/postgresql/15/data/base/<OID>/` |
| **Contents**         | Configuration, WAL, logs, etc.          | Files representing database objects. |
| **Purpose**          | Manages the entire PostgreSQL cluster.  | Stores data for one database.         |

---

## **Key Notes**

1. **Data Directory**
   - Use dedicated storage optimized for database workloads (e.g., SSDs with ext4 or xfs).
   - Regularly monitor disk space and performance.
   - Always back up the data directory before migrations or upgrades.

2. **Database Directory**
   - Avoid manual modifications; use SQL or PostgreSQL utilities.
   - Use tablespaces for databases requiring separate storage.
   - Ensure proper permissions (owned by the `postgres` user).

---
