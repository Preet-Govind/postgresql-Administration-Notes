# PostgreSQL Data Directory

The **data directory** is where PostgreSQL stores all the data files, configuration files, and logs required for database operations. As the database grows over time, there may be a need to extend storage or allocate a dedicated file system for the data directory (`data_directory`) to a new location.

---

## Steps to Move the PostgreSQL Data Directory

### Step 1: Display the Current Data Directory Location
To find the location of the current data directory:
```bash
userName@HostName:~$ sudo -u postgres psql
postgres-# SHOW data_directory;

| data_directory           |
|--------------------------|
| /var/lib/postgresql/15/data/ |
(1 row)
```

---

### Step 2: Shut Down PostgreSQL and Verify Status
To move the data directory, the PostgreSQL server must be stopped.

```bash
# Check PostgreSQL service status
userName@HostName:~$ sudo status postgresql-15

# Stop PostgreSQL service
userName@HostName:~$ sudo stop postgresql-15

# Verify PostgreSQL service is stopped
userName@HostName:~$ sudo status postgresql-15
```

---

### Step 3: Prepare the New Data Directory
1. Create the new data directory and set the correct ownership and permissions:
```bash
userName@HostName:~$ sudo mkdir -p /postgres/data
userName@HostName:~$ sudo chown postgres:postgres /postgres/data
userName@HostName:~$ sudo chmod -R 750 /postgres/data
```

2. Copy the contents of the old data directory to the new location:
```bash
userName@HostName:~$ sudo rsync -av /var/lib/postgresql/15/data/ /postgres/data/
```

3. Verify the copied data:
```bash
userName@HostName:~$ cd /postgres/data
userName@HostName:~$ ls -lrt
```

---

### Step 4: Update Configuration to Use the New Data Directory
1. **Backup the PostgreSQL configuration file:**
```bash
userName@HostName:~$ sudo cp /var/lib/postgresql/15/data/postgresql.conf /var/lib/postgresql/15/data/postgresql.conf_original
```

2. **Edit the `postgresql.conf` file:**
```bash
userName@HostName:~$ sudo nano /var/lib/postgresql/15/data/postgresql.conf
```

3. **Update the `data_directory` parameter:**
```plaintext
data_directory = '/postgres/data/'
```

---

### Step 5: Restart PostgreSQL and Verify Functionality
1. Start the PostgreSQL service:
```bash
userName@HostName:~$ sudo systemctl start postgresql-15
```

2. Check the status of PostgreSQL:
```bash
userName@HostName:~$ sudo systemctl status postgresql-15
```

3. Check for any errors in the logs:
```bash
userName@HostName:~$ sudo tail -10f /var/log/messages
```

---

### Step 6: Verify the New Data Directory
1. Access PostgreSQL and verify the data directory:
```bash
userName@HostName:~$ sudo -u postgres psql
postgres-# SHOW data_directory;

| data_directory           |
|--------------------------|
| /postgres/data/          |
(1 row)
```

2. Confirm that PostgreSQL is operating correctly with the new data directory.

---

## Additional Notes

- **Backup Best Practices:**  
  Before moving the data directory, create a full backup of the database using tools like `pg_dump` or `pg_basebackup` to safeguard against potential data loss.

- **File System Considerations:**  
  - Use a filesystem optimized for database workloads (e.g., ext4, xfs).  
  - If using SSDs, ensure write performance is sufficient for transaction-heavy databases.  

- **SELinux and AppArmor Adjustments:**  
  If SELinux or AppArmor is enabled, update their configurations to allow PostgreSQL to access the new directory.

- **Disk Space Monitoring:**  
  Regularly monitor disk usage in the new data directory to prevent out-of-space issues, which can cause database crashes.

- **Testing Before Production Use:**  
  Test the new configuration in a staging environment before applying changes to production systems.

- **Using Symbolic Links:**  
  Alternatively, create a symbolic link from the old location to the new one for easier migration without modifying the configuration:
  ```bash
  userName@HostName:~$ sudo ln -s /postgres/data /var/lib/postgresql/15/data
  ```

- **Handling Large Databases:**  
  For large databases, use tools like `rsync` with options to preserve permissions and timestamps, ensuring a smooth copy operation.

- **Checking Post-Migration Performance:**  
  Monitor PostgreSQL performance using the `pg_stat_activity` view to ensure the migration has no adverse effects on database operations.
