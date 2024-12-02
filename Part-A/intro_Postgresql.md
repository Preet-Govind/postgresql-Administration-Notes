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
   - **Checkpoint**: Ensures data consistency by flushing changes to disk periodically.  
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

### **10. Additional Notes**

- Ensure the `archive_command` is **idempotent**, so reruns don’t cause duplication issues.  
- Use a reliable storage system for the archive destination (e.g., NFS, cloud).  
- Monitor the `pg_stat_archiver` view to catch archiving issues early.  
- Combine archiving with base backups for robust PITR solutions.

---
