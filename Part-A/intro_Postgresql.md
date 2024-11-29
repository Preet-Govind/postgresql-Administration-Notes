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
