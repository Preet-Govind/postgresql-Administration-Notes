## PostgreSQL: Overview and Core Concepts

### What is PostgreSQL?

- PostgreSQL is a **free and open-source object-relational database management system (ORDBMS)**.  
- Originally developed as **POSTGRES** in 1986 by Michael Stonebraker and his team at UC Berkeley.  
- Offers **cross-platform support** on Linux, FreeBSD, macOS, Solaris, and Windows.  
- Provides **ACID compliance** (Atomicity, Consistency, Isolation, Durability) and employs **Multiversion Concurrency Control (MVCC)**.  

---

### PostgreSQL Object Naming Conventions

| Common Names    | PostgreSQL Terms  |
|-----------------|-------------------|
| Table for index | Relation          |
| Row             | Tuple             |
| Column          | Attribute         |
| Data block      | Page (on disk)    |
| Page            | Buffer (in memory)|

---

## PostgreSQL Data Storage: Pages

### Page in PostgreSQL

- A **page** is the smallest unit of data storage in PostgreSQL.  
- Tables and indexes are stored as **arrays of fixed-size pages** (default size: **8 KB**).  
- Pages consist of the following components:  
  - **Page Header Data (24 bytes)**: Metadata about the page, including free space pointers.  
  - **Item ID Data**: Pointers to items stored in the page.  
  - **Free Space**: Available for new pointers and data.  
  - **Special Space**: Index-specific or table-specific data.  

![Page Layout](https://github.com/Preet-Govind/postgresqlDBA/blob/f67fb8aa86c7c39d768ccab794c7ece12f00dad8/img/page_Layout.png)

---

## PostgreSQL Architecture and Memory Model

### Overview

PostgreSQL uses a **client-server model** with a **process-per-user connection architecture**, ensuring high concurrency.  
Its core components include **client-side libraries**, **server-side processes**, and **physical storage**.

---

### PostgreSQL Architecture

![PostgreSQL Architecture](https://github.com/Preet-Govind/postgresqlDBA/blob/b04b2a6988858e05d4af9d5b071d907561cf81ee/img/procNMemArch1.png)

1. **Client-Side**  
   - **Client Application**:  
     Sends SQL queries and receives results via APIs like JDBC, ODBC, or `libpq`.  
   - **Client Interface Library**:  
     Manages communication with the PostgreSQL server.  

2. **Server-Side**  
   - **Postmaster Daemon Process**:  
     - Handles client connections, authentication, and forking a **backend process** for each client.  
   - **Backend Processes**:  
     - Each process handles one client, executes queries, and interacts with memory and storage.  

3. **Physical Files**  
   PostgreSQL persists data to various files:  
   - **Data Files**: Store tables and indexes.  
   - **WAL Files**: Track changes for recovery.  
   - **Archive Files**: Optional WAL backups for Point-In-Time Recovery (PITR).  
   - **Log Files**: Record server activity and errors.

---

### Memory Model in PostgreSQL

PostgreSQL memory is classified into **shared memory** and **per-backend memory**:

1. **Shared Memory** (used by all processes):  
   - **Shared Buffers**: Cache frequently accessed table and index data.  
   - **WAL Buffers**: Temporarily store changes before writing to WAL files.  
   - **Temporary Buffers**: Used for temporary tables and data within a transaction.  
   - **CLOG Buffers**: Store transaction statuses for concurrency control.  

2. **Per-Backend Memory** (specific to each backend process):  
   - **Work Memory (`work_mem`)**: Allocated for sorting and hash operations during query execution.  
   - **Maintenance Work Memory (`maintenance_work_mem`)**: For operations like `VACUUM` and `CREATE INDEX`.  
   - **Temporary Buffers**: Backend-local buffers for temporary data.  

![Memory Architecture](https://github.com/Preet-Govind/postgresqlDBA/blob/main/img/procNMemArch2.png)

---

### PostgreSQL Processes

PostgreSQL operates with various processes to ensure scalability and stability:

1. **Postmaster Process**  
   - Handles connection requests and spawns backend processes.

2. **Backend Processes**  
   - Dedicated to each client, handling SQL execution and memory interactions.

3. **Background Processes**:  
   - **BGWriter**: Writes dirty pages from shared buffers to disk.  
   - **WAL Writer**: Flushes WAL changes to disk.  
   - **Auto Vacuum**: Maintains database health and updates statistics.  
   - **Checkpoint**: Ensures data consistency by flushing changes(i.e syncs all buffers from shared buffer to data files) to disk periodically or when ```max_wal_size``` value is exceeded.  
   - **Stats Collector**: Gathers performance metrics and activity logs.  
   - **Archiver**: Archives WAL files for PITR.  
   - **Logical Replication Launcher**: Manages replication workers for logical replication.  

---
## **1. User Connects to PostgreSQL**

When a user connects to the PostgreSQL server:  

1. **Connection Request to Postmaster**  
   - The user sends a connection request (using tools like `psql`, `pgAdmin`, or applications through `libpq`).  
   - The request is handled by the **Postmaster daemon process**.  

2. **Authentication and Authorization**  
   - The Postmaster verifies the user credentials based on `pg_hba.conf` rules.  
     - This includes methods like password-based authentication (`md5`, `scram-sha-256`) or trust, etc.  

3. **Backend Process Forked**  
   - Once authenticated, the Postmaster **forks a backend process** (`postgres`) dedicated to handling this user's session.  
   - The backend process is attached to **shared memory** but manages its own **local memory**.  

4. **Direct Communication**  
   - After forking the backend process, the Postmaster is no longer involved.  
   - The user and the backend process now communicate directly.  

---

## **2. SELECT Query Execution Flow**

**Scenario**: The user issues a `SELECT` query like:  
```sql
SELECT * FROM employees WHERE department = 'Sales';
```

### Step-by-Step Process:

### **Step 1: Query Parsing**
- The query is received by the backend process and parsed into an **Abstract Syntax Tree (AST)**.  
- The **Parser** validates the SQL syntax and transforms the query into a **Query Tree**.  

### **Step 2: Query Planning and Optimization**
- The **Planner/Optimizer** analyzes the query and decides:  
  - The best **execution plan** (e.g., sequential scan or index scan).  
  - Which indexes or joins to use, based on statistics collected by the **Stats Collector**.  

### **Step 3: Query Execution**
- The **Executor** runs the plan generated by the planner:  
  - **Accessing Shared Buffers**:  
    - If the requested data (pages) is in **Shared Buffers**, it is served directly from memory.  
    - Otherwise, data is fetched from disk using the **Background Writer** or **File System Cache** and loaded into the Shared Buffers.  
  - **Data Filtering**:  
    - The backend process scans pages, filters rows based on the query condition (`department = 'Sales'`), and returns results.  

### **Step 4: Return Results to Client**
- The backend process sends the filtered rows back to the client using the **libpq protocol**.  

---

### **Processes/Utilities Involved in SELECT**
1. **Postmaster**: Manages the initial connection.  
2. **Stats Collector**: Provides table and index statistics to the Planner/Optimizer.  
3. **Background Writer**: Ensures dirty pages are written to disk, ensuring shared buffer availability.  
4. **Executor**: Processes and fetches the requested data.  

---

## **3. INSERT/UPDATE/DELETE Query Execution Flow**

**Scenario**: The user issues an `INSERT` query like:  
```sql
INSERT INTO employees (name, department) VALUES ('John Doe', 'Sales');
```

### Step-by-Step Process:

### **Step 1: Query Parsing**
- Similar to a `SELECT`, the query is parsed into a **Query Tree** and validated.

### **Step 2: Query Planning**
- The planner determines how the insertion will take place (e.g., appending to the table's pages or handling constraints like foreign keys).

### **Step 3: WAL Logging**
- Before making any changes, the backend process logs the changes into the **WAL (Write-Ahead Log)**.  
- **WAL Writer Process** writes these logs to disk periodically.  

### **Step 4: Shared Buffers Update**
- The backend process updates the **Shared Buffers** with the new data.  
- If the target table is heavily modified, the **BGWriter** ensures the data is flushed to disk eventually.  

### **Step 5: Lock Management**
- The backend process locks the target rows/pages for updates or deletes to ensure **MVCC** consistency.

### **Step 6: Commit Transaction**
- At the end of the transaction, the backend process ensures:  
  - The WAL changes are flushed to disk.  
  - Metadata in the **CLOG Buffers** is updated to mark the transaction as "committed".  

---

### **Processes/Utilities Involved in INSERT/UPDATE/DELETE**
1. **Postmaster**: Manages the connection and forks backend processes.  
2. **WAL Writer**: Handles writing WAL changes to disk for durability.  
3. **BGWriter**: Writes dirty buffers (modified pages) from shared memory to disk.  
4. **Checkpointer**: Ensures consistent data writes to disk during updatable periodic checkpoints.  
5. **Stats Collector**: Updates statistics related to table modifications.  

---

## **4. MVCC (Multiversion Concurrency Control)**

### How PostgreSQL Ensures Consistency:
- PostgreSQL ensures consistency using **MVCC**, which creates snapshots for each transaction.  
- For `SELECT` queries:  
  - The backend process reads a snapshot consistent with the transaction start time.  
  - It ignores uncommitted changes made by other transactions.  
- For `INSERT/UPDATE/DELETE` queries:  
  - The backend process marks old tuples as "dead" and creates new tuples, ensuring non-blocking reads.

---

## **Flow Summary Table**

| **Query Type** | **Postmaster** | **Backend Process** | **Shared Memory**      | **Utility Processes** |
|----------------|----------------|----------------------|-------------------------|------------------------|
| **SELECT**     | Forks backend  | Parses, Plans, Executes | Reads data into buffers | Stats Collector, BGWriter |
| **INSERT/UPDATE/DELETE** | Forks backend  | Logs to WAL, Locks rows/pages | Updates shared buffers | WAL Writer, Checkpointer |

---
## **PostgreSQL Archiver Process**

The **Archiver Process** in PostgreSQL is responsible for managing the archiving of completed **Write-Ahead Log (WAL)** segments when the database is running in **archive mode**. This ensures that WAL segments are safely stored in an external location, enabling point-in-time recovery (PITR) and providing disaster recovery capabilities.

---

### **1. What is the Archiver Process?**

The Archiver is an **optional utility process** that runs when the database is in **archive mode**.  
- Its job is to copy filled (completed) WAL segments from the **WAL directory** (`$PGDATA/pg_wal/`) to a configured archive destination.  
- The archive destination can be a local directory, a network share, or a cloud storage system.

---

### **2. When Does the Archiver Process Start?**

- The Archiver process starts **only** when the `archive_mode` parameter is set to `on` in `postgresql.conf`.  
- The location to which the WAL files are copied is determined by the `archive_command` parameter.

```conf
# postgresql.conf example
archive_mode = on
archive_command = 'cp %p /var/lib/pgsql/archivedir/%f'
```

---

### **3. Workflow of the Archiver Process**

When a WAL segment is filled, the following steps occur:

### **Step 1: WAL Segment Marked as "Ready"**
- The **WAL Writer Process** generates WAL data during transactions.  
- Once a WAL segment is filled, it is marked as `.ready` in the directory `$PGDATA/pg_wal/archive_status/`.

### **Step 2: Archiver Process Activates**
- The Archiver Process periodically scans `$PGDATA/pg_wal/archive_status/` for `.ready` files.  
- If `.ready` files are found, it triggers the **archive_command**.

### **Step 3: WAL Segment Copied to Archive Destination**
- The Archiver Process executes the command specified in `archive_command`.  
  - `%p`: The full path to the WAL segment file.  
  - `%f`: The filename of the WAL segment.  

Example:  
```bash
cp /var/lib/pgsql/data/pg_wal/00000001000000000000000A /backup/archivedir/
```

### **Step 4: Marking as "Done"**
- If the archiving is successful, the Archiver Process renames the `.ready` file to `.done`.  
  - This ensures the file isn’t archived again.  

If the archiving fails, the `.ready` file remains, and the Archiver retries the process.

---

### **4. Important Parameters for Archiver**

| **Parameter**       | **Description**                                                                                      |
|----------------------|------------------------------------------------------------------------------------------------------|
| `archive_mode`       | Enables archiving. Set to `on` or `always`.                                                         |
| `archive_command`    | Specifies the shell command to archive the WAL file.                                                |
| `archive_timeout`    | Forces a switch to a new WAL segment and triggers archiving if no activity has occurred in the given interval. Default is 0 (disabled). |
| `archive_status_directory` | Directory (`$PGDATA/pg_wal/archive_status/`) used to track WAL segments' readiness or completion. |

---

### **5. Processes/Utilities Involved**
- **WAL Writer**: Fills WAL segments and marks them `.ready`.  
- **Archiver Process**: Copies the `.ready` WAL files to the archive destination.  
- **Background Writer** (indirectly): Ensures WAL buffers and dirty pages are written to disk.  

---

### **6. Archiver Process in the Context of Point-in-Time Recovery (PITR)**

The Archiver Process plays a crucial role in supporting **PITR**:  

1. **WAL Archiving**  
   - WAL files are continuously archived, preserving all changes made to the database.  

2. **Base Backups**  
   - A base backup is taken using tools like `pg_basebackup`.  
   - The archived WAL files are then applied during recovery to recreate the database state at a specific point in time.  

---

### **7. Example Scenarios**

#### **Successful Archiving**
1. WAL Writer marks `00000001000000000000000A` as `.ready`.  
2. Archiver executes:  
   ```bash
   cp /var/lib/pgsql/data/pg_wal/00000001000000000000000A /backup/archivedir/
   ```
3. Archiver renames `.ready` to `.done`.  

#### **Failed Archiving**
1. If the destination is unavailable (e.g., disk full or network issues), the `.ready` file remains.  
2. The Archiver retries periodically until the file is successfully archived.  

---

### **8. Monitoring Archiver Activity**

To monitor the Archiver process, check the following:  

1. **Logs**  
   - Configure PostgreSQL to log archiving activity using the `log_min_messages` parameter.  

2. **pg_stat_archiver View**  
   Use the following query:  
   ```sql
   SELECT * FROM pg_stat_archiver;
   ```
   | Column                 | Description                                   |
   |------------------------|-----------------------------------------------|
   | `archived_count`       | Number of successfully archived WAL files.   |
   | `last_archived_wal`    | Name of the last archived WAL file.          |
   | `last_archived_time`   | Timestamp of the last successful archive.    |
   | `failed_count`         | Number of failed archive attempts.           |
   | `last_failed_wal`      | Name of the last failed WAL file.            |
   | `last_failed_time`     | Timestamp of the last failed archive attempt.|

---

### **9. Summary Table**

| **Action**             | **Directory/File**                  | **Process**            | **Description**                                         |
|-------------------------|-------------------------------------|------------------------|---------------------------------------------------------|
| WAL filled             | `$PGDATA/pg_wal/`                  | WAL Writer             | Fills the WAL segment and marks `.ready`.              |
| WAL ready for archive  | `$PGDATA/pg_wal/archive_status/`    | Archiver Process       | Checks for `.ready` files periodically.                |
| Archiving starts       | Configured Archive Destination      | Archiver Process       | Executes `archive_command` to copy WAL to the archive. |
| Success                | `$PGDATA/pg_wal/archive_status/`    | Archiver Process       | Renames `.ready` to `.done`.                           |

---

### **10. Key Notes**

- Ensure the `archive_command` is **idempotent**, so reruns don’t cause duplication issues.
    -  Idempotent refers to an operation that produces the same result no matter how many times it is performed. For example, in HTTP, GET and DELETE requests are idempotent because repeated calls do not change the outcome.
- Use a reliable storage system for the archive destination (e.g., NFS, cloud).  
- Monitor the `pg_stat_archiver` view to catch archiving issues early.  
- Combine archiving with base backups for robust PITR solutions.

---

## **Memory Segments in PostgreSQL**

In PostgreSQL, memory management is a critical component of database performance. It uses various memory segments to manage data efficiently, allowing for optimized reads, writes, and recovery operations. The key memory segments include **Shared Buffers**, **WAL Buffers**, and **CLOG & Other Buffers**. Below is a detailed breakdown:

---

### **1. Shared Buffer**
- **Purpose**: Shared Buffers act as a cache between the database and disk. It ensures that data read or modified is processed in memory, avoiding frequent disk I/O. 
- **Key Features**:
  - **Direct Access Restriction**: Users cannot directly access data files stored on disk. Instead, all reads/writes (via `SELECT/INSERT/UPDATE/DELETE`) go through the **Shared Buffer**.
  - **Dirty Buffers**: Data written or modified in Shared Buffers is referred to as a "dirty buffer".
  - **Data Persistence**: Dirty buffers are flushed to disk by the **Background Writer Process**.
- **Configuration**: 
  - The size of the Shared Buffer pool is controlled by the `shared_buffers` parameter in the `postgresql.conf` file.
- **Performance Impact**:
  - Increasing the `shared_buffers` value can reduce disk I/O and improve query performance but requires sufficient available system memory.

---

### **2. WAL Buffer**
- **Purpose**: Write-Ahead Log (WAL) Buffers, also known as "transaction log buffers," temporarily store WAL data before writing it to persistent storage.
- **Key Features**:
  - **WAL Data**: Contains metadata about changes made to the database (not the actual data). It is crucial for **database recovery** and helps reconstruct actual data during crash recovery.
  - **Persistence**: WAL data is written to physical files known as **WAL Segments** or **Checkpoint Segments**.
  - **Flushing**: The WAL Writer process is responsible for flushing WAL Buffers to the WAL segments on disk.
- **Configuration**: 
  - The size of the WAL Buffer is controlled by the `wal_buffers` parameter in the `postgresql.conf` file.
- **Key Notes**: 
  - Proper tuning of WAL Buffers is essential for balancing performance and recovery speed. Setting a value too low may cause frequent flushes, increasing I/O overhead.

---

### **3. CLOG and Other Buffers**
#### **CLOG (Commit Log) Buffers**
- **Purpose**: Tracks the commit status of all transactions in the database.  
  - For example: Whether a transaction was committed or rolled back.  
- **Key Feature**: Stored in memory to reduce latency for transaction status lookups during query execution.

#### **Work Memory**
- **Purpose**: Allocated for single sort operations or hash tables during query execution.
- **Configuration**:
  - Controlled by the `work_mem` parameter.
- **Key Notes**:
  - For complex queries with multiple sorts or hash operations, sufficient `work_mem` allocation prevents excessive disk usage.

#### **Maintenance Work Memory**
- **Purpose**: Reserved for **maintenance operations** such as:
  - `VACUUM`
  - `CREATE INDEX`
  - `ALTER TABLE ADD FOREIGN KEY`
- **Configuration**:
  - Controlled by the `maintenance_work_mem` parameter.
- **Key Notes**: 
  - Since these operations are not frequent, the value for `maintenance_work_mem` can be larger than `work_mem`.

#### **Temporary Buffers**
- **Purpose**: Used during user sessions for operations involving **temporary tables**, **large sorts**, or **hash tables**.
- **Configuration**:
  - Controlled by the `temp_buffers` parameter.
- **Key Notes**:
  - This setting can only be modified within a session **before** the first use of temporary tables.

---

### **Key Notes**
- **Shared Buffers**:
  - Set to 25-40% of available system memory for most workloads.
  - Monitor and adjust using tools like `pg_stat_activity` to avoid over-allocation.
- **WAL Buffers**:
  - Ensure sufficient allocation for write-heavy workloads to avoid frequent flushes.
- **Work Memory**:
  - Be cautious when tuning. Higher values may improve query performance but increase overall memory usage across concurrent queries.
- **Maintenance Memory**:
  - Allocate generously for `VACUUM` or index creation but monitor memory consumption for large operations.

Proper tuning of PostgreSQL memory settings significantly impacts database performance, reducing latency and improving throughput while maintaining crash recovery and durability guarantees.

---

## **Physical Files in PostgreSQL**

PostgreSQL stores and manages its data in various physical files. These files are critical for database operations, crash recovery, and performance monitoring. Below is an overview:

---

### **1. Data Files**
- **Purpose**:  
  Data files store the actual database content, including tables, indexes, and other objects.  
  These files contain raw data, not executable instructions or code.
- **Storage Details**:  
  - Organized into 8 KB pages (default).  
  - Data is read or written in these fixed-size pages.  
- **Location**:  
  Stored in the `$PGDATA/base` directory, with subdirectories for each database.

---

### **2. WAL (Write-Ahead Log) Files**
- **Purpose**:  
  Write-Ahead Log (WAL) files ensure durability and consistency by logging all changes before they are written to data files.  
  WAL allows PostgreSQL to recover from crashes by replaying transactions.  
- **Characteristics**:  
  - WAL files store metadata sufficient to reconstruct actual data during recovery.  
  - Changes are flushed from WAL buffers to disk by the WAL writer process.  
- **Configuration Parameters**:  
  - `wal_segment_size`: Size of each WAL segment (default: 16 MB).  
  - `wal_buffers`: Memory allocated for WAL before writing to disk.  
  - `archive_mode`: Enables WAL archiving for recovery purposes.
- **Location**:  
  Located in `$PGDATA/pg_wal` (or `$PGDATA/pg_xlog` in older versions).

---

### **3. Log Files**
- **Purpose**:  
  Log files record all server activity, including errors, warnings, queries, and performance statistics.  
  Useful for debugging and monitoring database performance.  
- **Log Contents**:  
  - Server messages (e.g., stderr, csvlog, syslog).  
  - Detailed query performance metrics (if `log_min_duration_statement` is set).  
- **Configuration Parameters**:  
  - `log_directory`: Specifies the directory for log files.  
  - `log_filename`: Defines the log file naming convention.  
  - `logging_collector`: Enables collection of logs into files.  
- **Location**:  
  By default, logs are stored in `$PGDATA/pg_log`.

---

### **4. Archive Log Files**
- **Purpose**:  
  Archive log files store copies of WAL segments for **Point-In-Time Recovery (PITR)** and disaster recovery.  
  They are written when WAL files are filled, ensuring no WAL data is lost.  
- **How it Works**:  
  - WAL segments marked as `.ready` are archived.  
  - Archiver process copies `.ready` files to the archive location and renames them as `.done`.  
- **Configuration Parameters**:  
  - `archive_mode`: Enables WAL archiving.  
  - `archive_command`: Command to copy WAL segments to archive storage.  
- **Use Case**:  
  - Restoring a database to a previous state.  
  - Required for replication and backup strategies.  
- **Location**:  
  Specified by the `archive_command` parameter, usually in a user-defined directory.  

---

### **Key Notes**
- **Durability & Recovery**:  
  WAL and archive logs are crucial for maintaining ACID compliance and recovering from crashes or failures.  
- **Performance Monitoring**:  
  Logs provide valuable insights into server health and query performance.  
- **Best Practices**:  
  - Keep log files and archive logs regularly monitored and rotated.  
  - Ensure sufficient storage for WAL and archive logs to prevent database interruptions.  
