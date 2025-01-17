/*
For practice purposes only.
The script overview :- 
1- a set of databases like main , archive and analytics purposes. 
2- multiple main tables and their history(log) tables 
3- procedure / function for manipulating data for the main tables . 
4 - data generation function / procedure , which can be run as cron job 
5- partitioning big tables - weekly basis , partman - automatically and/or when function called
6- trigger and fdw
7- The db size when generated should be in GBs in weeks.
8- Good number of tables. 
*/

/*
env setup in ReadMe.md
*/

-- Install required extensions
CREATE EXTENSION IF NOT EXISTS pg_partman schema partman;
CREATE EXTENSION IF NOT EXISTS pg_cron schema pg_cron;
CREATE EXTENSION IF NOT EXISTS postgres_fdw;

CREATE DATABASE archive;
CREATE DATABASE analytics;

\c postgres;
-- Main schemas
CREATE SCHEMA IF NOT EXISTS main;
CREATE SCHEMA IF NOT EXISTS history;
create schema if not exists partman;

CREATE EXTENSION IF NOT EXISTS pg_partman schema partman;
CREATE EXTENSION IF NOT EXISTS pg_cron;
CREATE EXTENSION IF NOT EXISTS postgres_fdw;

-- Create tables in the 'main' schema
CREATE TABLE main.users (
    user_id SERIAL PRIMARY KEY,
    username VARCHAR(100) NOT NULL,
    email VARCHAR(255) UNIQUE NOT NULL,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

-- Create the main.orders table as a partitioned table
CREATE TABLE main.orders (
    order_id SERIAL,
    user_id INT NOT NULL,
    order_date TIMESTAMP NOT NULL,
    total_amount NUMERIC(10, 2),
    status VARCHAR(50),
    updated_at TIMESTAMP DEFAULT NOW(),
    primary key (order_id,order_date)
) PARTITION BY RANGE (order_date);

CREATE TABLE main.products (
    product_id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    category VARCHAR(100),
    price NUMERIC(10, 2),
    stock_quantity INT DEFAULT 0,
    updated_at TIMESTAMP DEFAULT NOW()
);

-- Create corresponding history tables in the 'history' schema
CREATE TABLE history.users_history (
    log_id SERIAL PRIMARY KEY,
    user_id INT NOT NULL,
    username VARCHAR(100),
    email VARCHAR(255),
    operation_type VARCHAR(50), -- e.g., 'INSERT', 'UPDATE', 'DELETE'
    operation_timestamp TIMESTAMP DEFAULT NOW()
);

CREATE TABLE history.orders_history (
    log_id SERIAL PRIMARY KEY,
    order_id INT NOT NULL,
    user_id INT,
    order_date TIMESTAMP,
    total_amount NUMERIC(10, 2),
    status VARCHAR(50),
    operation_type VARCHAR(50),
    operation_timestamp TIMESTAMP DEFAULT NOW()
);

CREATE TABLE history.products_history (
    log_id SERIAL PRIMARY KEY,
    product_id INT NOT NULL,
    name VARCHAR(100),
    category VARCHAR(100),
    price NUMERIC(10, 2),
    stock_quantity INT,
    operation_type VARCHAR(50),
    operation_timestamp TIMESTAMP DEFAULT NOW()
);

-- Confirm table creation
\dt main.*;
\dt history.*;


-- Procedure for inserting or updating records in 'main.users'
CREATE OR REPLACE PROCEDURE main.manage_users(
    p_user_id INT,
    p_username VARCHAR,
    p_email VARCHAR
)
LANGUAGE plpgsql
AS $$
BEGIN
    -- If the user exists, update; otherwise, insert
    IF EXISTS (SELECT 1 FROM main.users WHERE user_id = p_user_id) THEN
        UPDATE main.users
        SET username = p_username,
            email = p_email,
            updated_at = NOW()
        WHERE user_id = p_user_id;

        -- Log the update
        INSERT INTO history.users_history(user_id, username, email, operation_type)
        VALUES (p_user_id, p_username, p_email, 'UPDATE');
    ELSE
        INSERT INTO main.users(username, email)
        VALUES (p_username, p_email)
        RETURNING user_id INTO p_user_id;

        -- Log the insert
        INSERT INTO history.users_history(user_id, username, email, operation_type)
        VALUES (p_user_id, p_username, p_email, 'INSERT');
    END IF;
END;
$$;


-- Function to generate random users
CREATE OR REPLACE FUNCTION main.generate_users(p_count INT)
RETURNS VOID
LANGUAGE plpgsql
AS $$
DECLARE
    i INT;
BEGIN
    FOR i IN 1..p_count LOOP
        INSERT INTO main.users(username, email)
        VALUES (
            'User' || i,
            'user' || i || '@example.com'
        );

        -- Log the insert
        INSERT INTO history.users_history(user_id, username, email, operation_type)
        VALUES (currval('main.users_user_id_seq'), 'User' || i, 'user' || i || '@example.com', 'INSERT');
    END LOOP;
END;
$$;

-- Create a partition set for the 'main.orders' table
SELECT partman.create_parent(
    p_parent_table := 'main.orders',
    p_control := 'order_date',
    p_interval := '1 week', -- Interval for range partitioning
    p_premake := 4,         -- Number of future partitions to create
    p_start_partition := '2025-01-01', -- Start of the first partition
    p_jobmon := true        -- Enable job monitoring
);

-- Schedule a cron job for maintaining partitions
SELECT cron.schedule(
    'partition_maintenance_orders',
    '0 0 * * *', -- Every day at midnight
    $$SELECT partman.run_maintenance('main.orders');$$
);


-- Trigger function for logging changes to the 'main.orders' table
CREATE OR REPLACE FUNCTION main.log_order_changes()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    -- On update or delete, insert into history table
    IF TG_OP = 'UPDATE' THEN
        INSERT INTO history.orders_history(order_id, user_id, order_date, total_amount, status, operation_type)
        VALUES (
            OLD.order_id,
            OLD.user_id,
            OLD.order_date,
            OLD.total_amount,
            OLD.status,
            'UPDATE'
        );
    ELSIF TG_OP = 'DELETE' THEN
        INSERT INTO history.orders_history(order_id, user_id, order_date, total_amount, status, operation_type)
        VALUES (
            OLD.order_id,
            OLD.user_id,
            OLD.order_date,
            OLD.total_amount,
            OLD.status,
            'DELETE'
        );
    END IF;
    RETURN NEW;
END;
$$;

-- Attach the trigger to the 'main.orders' table
CREATE TRIGGER orders_history_trigger
AFTER UPDATE OR DELETE
ON main.orders
FOR EACH ROW
EXECUTE FUNCTION main.log_order_changes();

-- Create a foreign server to access the 'archive' database
CREATE SERVER archive_server
FOREIGN DATA WRAPPER postgres_fdw
OPTIONS (host 'localhost', dbname 'archive', port '5435');

-- Map the current user to the foreign server
CREATE USER MAPPING FOR CURRENT_USER
SERVER archive_server
OPTIONS (user 'postgres', password '123456');

-- Import tables from the 'archive_main' schema
IMPORT FOREIGN SCHEMA archive_main
FROM SERVER archive_server
INTO main; -- Place them into the current 'main' schema



-- Generate random orders
CREATE OR REPLACE FUNCTION main.generate_orders(p_count INT)
RETURNS VOID
LANGUAGE plpgsql
AS $$
DECLARE
    i INT;
    random_user INT;
    random_amount NUMERIC(10, 2);
    random_status VARCHAR(50);
    statuses TEXT[] := ARRAY['Pending', 'Completed', 'Cancelled', 'Refunded'];
BEGIN
    FOR i IN 1..p_count LOOP
        -- Pick a random user
        SELECT user_id INTO random_user
        FROM main.users
        OFFSET floor(random() * (SELECT COUNT(*) FROM main.users))
        LIMIT 1;

        -- Generate random order details
        random_amount := round((random() * 1000 + 10)::numeric, 2);
        random_status := statuses[floor(random() * 4 + 1)::INT];

        -- Insert the order
        INSERT INTO main.orders(user_id, order_date, total_amount, status)
        VALUES (random_user, NOW() - (random() * interval '90 days'), random_amount, random_status);

        -- Log the insert
        INSERT INTO history.orders_history(order_id, user_id, order_date, total_amount, status, operation_type)
        VALUES (currval('main.orders_order_id_seq'), random_user, NOW(), random_amount, random_status, 'INSERT');
    END LOOP;
END;
$$;


-- Schedule a daily cron job to generate 10,000 orders
SELECT cron.schedule(
    'daily_order_generation',
    '0 1 * * *', -- Run daily at 1:00 AM
    $$SELECT generate_orders(10000);$$
);



-- Generate random orders
CREATE OR REPLACE FUNCTION main.generate_large_orders(p_count INT)
RETURNS VOID
LANGUAGE plpgsql
AS $$
DECLARE
    i INT;
    random_user INT;
    random_amount NUMERIC(10, 2);
    random_status VARCHAR(50);
    statuses TEXT[] := ARRAY['Pending', 'Completed', 'Cancelled', 'Refunded'];
    random_date TIMESTAMP;
BEGIN
    FOR i IN 1..p_count LOOP
        -- Generate a random user_id
        SELECT user_id INTO random_user
        FROM main.users
        OFFSET floor(random() * (SELECT COUNT(*) FROM main.users))
        LIMIT 1;

        -- Generate random order details
        random_amount := round((random() * 1000 + 10)::numeric, 2);
        random_status := statuses[floor(random() * 4 + 1)::INT];
        random_date := NOW() - (random() * interval '90 days'); -- Random date within the last 90 days

        -- Insert the order
        INSERT INTO main.orders(order_id, order_date, user_id, total_amount, status)
        VALUES (DEFAULT, random_date, random_user, random_amount, random_status);
    END LOOP;
END;
$$;


-- Schedule daily data generation for the orders table
SELECT cron.schedule(
    'daily_large_order_generation',
    '0 2 * * *', -- Run daily at 2:00 AM
    $$CALL generate_large_orders(50000);$$ -- Generates 50,000 rows daily
);

create schema if not exists archive;
-- Create a foreign table in 'postgres' pointing to the 'archive.orders_archive' table
CREATE FOREIGN TABLE archive.orders_archive (
    order_id INT,
    user_id INT,
    order_date TIMESTAMP,
    total_amount NUMERIC(10, 2),
    status VARCHAR(50),
    updated_at TIMESTAMP
)
SERVER archive_server
OPTIONS (schema_name 'archive_main', table_name 'orders_archive');

-- Trigger function for archiving old orders
CREATE OR REPLACE FUNCTION main.archive_old_orders()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    -- Move the row to the archive table
    INSERT INTO archive.orders_archive
    SELECT OLD.*;

    -- Delete the row from the main table
    DELETE FROM ONLY main.orders WHERE (order_id, order_date) = (OLD.order_id, OLD.order_date);

    RETURN NULL; -- Prevent default operation
END;
$$;

-- Create the trigger on the 'main.orders' table,
-- see its not main.archive_orders_trigger
CREATE TRIGGER archive_orders_trigger
AFTER DELETE
ON main.orders
FOR EACH ROW
EXECUTE FUNCTION main.archive_old_orders();



-- Function to archive data older than 30 days
CREATE OR REPLACE FUNCTION main.move_to_archive()
RETURNS VOID
LANGUAGE plpgsql
AS $$
BEGIN
    INSERT INTO archive.orders_archive
    SELECT * FROM main.orders
    WHERE order_date < NOW() - INTERVAL '30 days';

    DELETE FROM main.orders
    WHERE order_date < NOW() - INTERVAL '30 days';
END;
$$;

-- Schedule the archival process daily
SELECT cron.schedule(
    'daily_archival',
    '0 3 * * *', -- Run daily at 3:00 AM
    $$CALL move_to_archive();$$
);



-- Now, schedule the cron job from the 'postgres' database
-- For archive_db
SELECT cron.schedule(
    'archive_partition_maintenance',
    '0 4 * * *', -- Run daily at 4:00 AM
    $$update SELECT partman.run_maintenance('archive_main.orders_archive');$$
);

select * from cron.job
-- i got the job id for the above job = 5
-- The catch is below ;)
update cron.job set database = 'archive' where jobid=5


-- In the 'postgres' database
IMPORT FOREIGN SCHEMA archive_main
FROM SERVER archive_server
INTO main;


-- Now, the archive tables are accessible from the postgres database
SELECT * FROM main.orders_archive WHERE order_date < NOW() - INTERVAL '90 days';




--------------------------------------------------
-- archive
-- Connect to the 'archive' database
\c archive;

CREATE SCHEMA IF NOT EXISTS archive_main;

CREATE EXTENSION IF NOT EXISTS postgres_fdw;

-- Create the archive schema
CREATE SCHEMA archive_main;

-- Create an archive table for orders
-- Create a range-partitioned table for archived orders
CREATE TABLE archive_main.orders_archive (
    order_id INT NOT NULL,
    user_id INT NOT NULL,
    order_date TIMESTAMP NOT NULL,
    total_amount NUMERIC(10, 2),
    status VARCHAR(50),
    updated_at TIMESTAMP DEFAULT NOW(),
    archived_at TIMESTAMP DEFAULT NOW() not null
) PARTITION BY RANGE (archived_at);


-- Add indexes to the archive table
CREATE INDEX idx_orders_archive_date ON archive_main.orders_archive (order_date);
CREATE INDEX idx_orders_archive_archived_at ON archive_main.orders_archive (archived_at);

-- Create partitions (you can automate this with pg_partman if needed)
CREATE TABLE archive_main.orders_archive_2025_01
PARTITION OF archive_main.orders_archive
FOR VALUES FROM ('2025-01-01') TO ('2025-02-01');

CREATE TABLE archive_main.orders_archive_2025_02
PARTITION OF archive_main.orders_archive
FOR VALUES FROM ('2025-02-01') TO ('2025-03-01');

create schema if not exists partman;
CREATE EXTENSION IF NOT EXISTS pg_partman schema partman;
CREATE EXTENSION IF NOT EXISTS postgres_fdw;

-- Create the partition set for archive_main.orders_archive
SELECT partman.create_parent(
    p_parent_table := 'archive_main.orders_archive',
    p_control := 'archived_at',
    p_interval := '1 month', -- Monthly partitions
    p_premake := 3,         -- Create 3 future partitions
    p_start_partition := '2025-01-01', -- Start date
    p_jobmon := true
);


-----------------------------------------------------

\c archive

-- analytics
CREATE SCHEMA IF NOT EXISTS analytics_main;
CREATE SCHEMA IF NOT EXISTS reports;

------------------------------
-- call stack

\c psotgres
select main.generate_users(100);
select main.generate_large_orders(50000);
select main.move_to_archive();
\c archive
SELECT * FROM archive_main.orders_archive;

-- Schedule daily data generation for the orders table
SELECT cron.schedule(
    'daily_large_order_generation',
    '0 2 * * *', -- Run daily at 2:00 AM
    $$CALL generate_large_orders(50000);$$ -- Generates 50,000 rows daily
);

-- Check if the cron job for generating large orders is scheduled
SELECT * FROM cron.job WHERE jobname = 'generate_large_orders';

-- Check if the partition maintenance job is scheduled
SELECT * FROM cron.job WHERE jobname = 'archive_partition_maintenance';

-- Check the size of the main.orders table
SELECT pg_size_pretty(pg_total_relation_size('main.users'));

\c archive
SELECT pg_size_pretty(pg_total_relation_size('archive_main.orders_archive'));


\c postgres
-- if re-serialize serial column for main.users
truncate table main.users
SELECT setval('main.users_user_id_seq', COALESCE(MAX(user_id), 0) + 1, false) FROM main.users;
