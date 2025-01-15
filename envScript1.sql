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
-- Install required extensions
-- Add version tag iff needed , ref $PG_HOME/share/extension/pg_partman.control 
CREATE EXTENSION IF NOT EXISTS pg_partman;-- version '5.2.4';
CREATE EXTENSION IF NOT EXISTS pg_cron;
CREATE EXTENSION IF NOT EXISTS postgres_fdw;

-- Create different databases
CREATE DATABASE main_db;
CREATE DATABASE archive_db;
CREATE DATABASE analytics_db;

\c main_db;

-- Create schemas
CREATE SCHEMA operations;
CREATE SCHEMA logs;
CREATE SCHEMA history;
CREATE SCHEMA archived;
CREATE SCHEMA metrics;

-- Create sequences
CREATE SEQUENCE operations.global_id_seq;
CREATE SEQUENCE operations.order_id_seq;
CREATE SEQUENCE operations.transaction_id_seq;
CREATE SEQUENCE operations.inventory_id_seq;

-- Create FDW connections
CREATE SERVER archive_server
FOREIGN DATA WRAPPER postgres_fdw
OPTIONS (host 'localhost', port '5432', dbname 'archive_db');

CREATE SERVER analytics_server
FOREIGN DATA WRAPPER postgres_fdw
OPTIONS (host 'localhost', port '5432', dbname 'analytics_db');

CREATE USER MAPPING FOR CURRENT_USER
SERVER archive_server
OPTIONS (user 'postgres', password 'your_password');

CREATE USER MAPPING FOR CURRENT_USER
SERVER analytics_server
OPTIONS (user 'postgres', password 'your_password');

-- Create functions for timestamp management
CREATE OR REPLACE FUNCTION operations.update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create main tables
CREATE TABLE operations.customers (
    customer_id BIGINT DEFAULT nextval('operations.global_id_seq'),
    first_name VARCHAR(50) NOT NULL,
    last_name VARCHAR(50) NOT NULL,
    email VARCHAR(100) NOT NULL UNIQUE,
    phone VARCHAR(20),
    address TEXT,
    city VARCHAR(100),
    country VARCHAR(100),
    status VARCHAR(20) DEFAULT 'active',
    customer_type VARCHAR(20) DEFAULT 'regular',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (customer_id)
);

CREATE TABLE operations.products (
    product_id BIGINT DEFAULT nextval('operations.global_id_seq'),
    product_name VARCHAR(100) NOT NULL,
    category VARCHAR(50) NOT NULL,
    subcategory VARCHAR(50),
    price DECIMAL(10,2) NOT NULL,
    cost DECIMAL(10,2) NOT NULL,
    stock_quantity INTEGER NOT NULL,
    supplier_id BIGINT,
    status VARCHAR(20) DEFAULT 'active',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (product_id)
);

CREATE TABLE operations.suppliers (
    supplier_id BIGINT DEFAULT nextval('operations.global_id_seq'),
    supplier_name VARCHAR(100) NOT NULL,
    contact_name VARCHAR(100),
    email VARCHAR(100),
    phone VARCHAR(20),
    address TEXT,
    status VARCHAR(20) DEFAULT 'active',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (supplier_id)
);

CREATE TABLE operations.inventory_transactions (
    transaction_id BIGINT DEFAULT nextval('operations.transaction_id_seq'),
    product_id BIGINT NOT NULL,
    transaction_type VARCHAR(20) NOT NULL,
    quantity INTEGER NOT NULL,
    transaction_date TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    reference_id BIGINT,
    reference_type VARCHAR(20),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (transaction_id, transaction_date)
) PARTITION BY RANGE (transaction_date);

-- Create partitioned orders table with pg_partman
CREATE TABLE operations.orders (
    order_id BIGINT DEFAULT nextval('operations.order_id_seq'),
    customer_id BIGINT NOT NULL,
    order_date TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    total_amount DECIMAL(12,2) NOT NULL,
    discount_amount DECIMAL(12,2) DEFAULT 0,
    tax_amount DECIMAL(12,2) DEFAULT 0,
    status VARCHAR(20) DEFAULT 'pending',
    payment_status VARCHAR(20) DEFAULT 'pending',
    shipping_address TEXT,
    shipping_method VARCHAR(50),
    tracking_number VARCHAR(100),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (order_id, order_date)
) PARTITION BY RANGE (order_date);

-- Setup pg_partman for orders table
SELECT partman.create_parent(
    'operations.orders',
    'order_date',
    'native',
    'weekly',
    p_start_partition := date_trunc('week', CURRENT_DATE)::text
);

-- Create order_items table
CREATE TABLE operations.order_items (
    order_id BIGINT,
    product_id BIGINT,
    quantity INTEGER NOT NULL,
    unit_price DECIMAL(10,2) NOT NULL,
    discount_percent DECIMAL(5,2) DEFAULT 0,
    total_price DECIMAL(10,2) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (order_id, product_id)
);

-- Create history tables
CREATE TABLE history.customers_history (
    history_id BIGINT DEFAULT nextval('operations.global_id_seq'),
    customer_id BIGINT,
    first_name VARCHAR(50),
    last_name VARCHAR(50),
    email VARCHAR(100),
    phone VARCHAR(20),
    address TEXT,
    city VARCHAR(100),
    country VARCHAR(100),
    status VARCHAR(20),
    customer_type VARCHAR(20),
    operation_type CHAR(1),
    changed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    changed_by VARCHAR(50)
);

CREATE TABLE history.products_history (
    history_id BIGINT DEFAULT nextval('operations.global_id_seq'),
    product_id BIGINT,
    product_name VARCHAR(100),
    category VARCHAR(50),
    subcategory VARCHAR(50),
    price DECIMAL(10,2),
    cost DECIMAL(10,2),
    stock_quantity INTEGER,
    supplier_id BIGINT,
    status VARCHAR(20),
    operation_type CHAR(1),
    changed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    changed_by VARCHAR(50)
);

-- Create function for data generation
CREATE OR REPLACE FUNCTION operations.generate_massive_data(
    num_customers INTEGER DEFAULT 100000,
    num_products INTEGER DEFAULT 10000,
    num_suppliers INTEGER DEFAULT 1000,
    num_orders INTEGER DEFAULT 1000000
)
RETURNS void AS $$
DECLARE
    v_customer_id BIGINT;
    v_product_id BIGINT;
    v_supplier_id BIGINT;
    v_order_id BIGINT;
    v_order_date TIMESTAMP;
    v_unit_price DECIMAL(10,2);
    v_quantity INTEGER;
    v_total_amount DECIMAL(12,2);
    v_batch_size INTEGER := 1000;
    v_categories TEXT[] := ARRAY['Electronics', 'Clothing', 'Books', 'Home', 'Sports', 'Food', 'Beauty', 'Toys', 'Automotive', 'Garden'];
    v_subcategories TEXT[] := ARRAY['Premium', 'Standard', 'Budget', 'Luxury', 'Basic'];
    v_cities TEXT[] := ARRAY['New York', 'London', 'Paris', 'Tokyo', 'Sydney', 'Berlin', 'Toronto', 'Singapore'];
    v_countries TEXT[] := ARRAY['USA', 'UK', 'France', 'Japan', 'Australia', 'Germany', 'Canada', 'Singapore'];
BEGIN
    -- Generate suppliers in batches
    FOR i IN 1..num_suppliers LOOP
        IF i % v_batch_size = 0 THEN
            COMMIT;
        END IF;
        
        INSERT INTO operations.suppliers (
            supplier_name, contact_name, email, phone, address, status
        ) VALUES (
            'Supplier' || i,
            'Contact' || i,
            'supplier' || i || '@example.com',
            LPAD(i::text, 10, '0'),
            'Address ' || i,
            CASE (random() * 2)::INTEGER
                WHEN 0 THEN 'active'
                WHEN 1 THEN 'inactive'
                ELSE 'pending'
            END
        );
    END LOOP;

    -- Generate customers in batches
    FOR i IN 1..num_customers LOOP
        IF i % v_batch_size = 0 THEN
            COMMIT;
        END IF;
        
        INSERT INTO operations.customers (
            first_name, last_name, email, phone, address, city, country, customer_type
        ) VALUES (
            'Customer' || i,
            'LastName' || i,
            'customer' || i || '@example.com',
            LPAD(i::text, 10, '0'),
            'Address ' || i,
            v_cities[(random() * array_length(v_cities, 1))::integer + 1],
            v_countries[(random() * array_length(v_countries, 1))::integer + 1],
            CASE (random() * 2)::INTEGER
                WHEN 0 THEN 'regular'
                WHEN 1 THEN 'premium'
                ELSE 'vip'
            END
        );
    END LOOP;

    -- Generate products in batches
    FOR i IN 1..num_products LOOP
        IF i % v_batch_size = 0 THEN
            COMMIT;
        END IF;
        
        SELECT supplier_id INTO v_supplier_id
        FROM operations.suppliers
        ORDER BY random()
        LIMIT 1;

        INSERT INTO operations.products (
            product_name, category, subcategory, price, cost, stock_quantity, supplier_id
        ) VALUES (
            'Product' || i,
            v_categories[(random() * array_length(v_categories, 1))::integer + 1],
            v_subcategories[(random() * array_length(v_subcategories, 1))::integer + 1],
            (random() * 1000 + 10)::DECIMAL(10,2),
            (random() * 800 + 5)::DECIMAL(10,2),
            (random() * 1000 + 100)::INTEGER,
            v_supplier_id
        );
    END LOOP;

    -- Generate orders and order items in batches
    FOR i IN 1..num_orders LOOP
        IF i % v_batch_size = 0 THEN
            COMMIT;
        END IF;

        -- Select random customer
        SELECT customer_id INTO v_customer_id
        FROM operations.customers
        ORDER BY random()
        LIMIT 1;

        -- Generate order date within last 90 days
        v_order_date := CURRENT_TIMESTAMP - (random() * 90)::INTEGER * interval '1 day';
        
        -- Create order
        INSERT INTO operations.orders (
            customer_id, order_date, total_amount, status, payment_status,
            shipping_method, tracking_number
        ) VALUES (
            v_customer_id,
            v_order_date,
            0,
            CASE (random() * 3)::INTEGER
                WHEN 0 THEN 'pending'
                WHEN 1 THEN 'processing'
                WHEN 2 THEN 'completed'
                ELSE 'cancelled'
            END,
            CASE (random() * 2)::INTEGER
                WHEN 0 THEN 'pending'
                WHEN 1 THEN 'paid'
                ELSE 'refunded'
            END,
            CASE (random() * 2)::INTEGER
                WHEN 0 THEN 'standard'
                WHEN 1 THEN 'express'
                ELSE 'overnight'
            END,
            'TRK' || LPAD(i::text, 10, '0')
        ) RETURNING order_id INTO v_order_id;

        -- Generate 1-10 order items
        v_total_amount := 0;
        FOR j IN 1..((random() * 9 + 1)::INTEGER) LOOP
            -- Select random product
            SELECT product_id, price INTO v_product_id, v_unit_price
            FROM operations.products
            ORDER BY random()
            LIMIT 1;

            v_quantity := (random() * 5 + 1)::INTEGER;

            -- Add order item
            INSERT INTO operations.order_items (
                order_id, product_id, quantity, unit_price, 
                discount_percent, total_price
            ) VALUES (
                v_order_id,
                v_product_id,
                v_quantity,
                v_unit_price,
                (random() * 25)::DECIMAL(5,2),
                v_quantity * v_unit_price * (1 - (random() * 0.25))
            );

            -- Update inventory
            INSERT INTO operations.inventory_transactions (
                product_id, transaction_type, quantity, 
                reference_id, reference_type
            ) VALUES (
                v_product_id,
                'sale',
                -v_quantity,
                v_order_id,
                'order'
            );

            v_total_amount := v_total_amount + (v_quantity * v_unit_price * (1 - (random() * 0.25)));
        END LOOP;

        -- Update order total
        UPDATE operations.orders
        SET total_amount = v_total_amount,
            tax_amount = v_total_amount * 0.1,
            discount_amount = v_total_amount * (random() * 0.15)
        WHERE order_id = v_order_id;
    END LOOP;
    
    COMMIT;
END;
$$ LANGUAGE plpgsql;

-- Create maintenance functions
CREATE OR REPLACE FUNCTION operations.maintain_partitions()
RETURNS void AS $$
BEGIN
    -- Maintain partitions using pg_partman
    PERFORM partman.run_maintenance(p_analyze := true);
    
    -- Archive old data if needed
    INSERT INTO archived.orders_archive
    SELECT * FROM operations.orders
    WHERE order_date < CURRENT_DATE - INTERVAL '6 months';
    
    -- Delete archived data
    DELETE FROM operations.orders
    WHERE order_date < CURRENT_DATE - INTERVAL '6 months';
END;
$$ LANGUAGE plpgsql;

-- Create triggers
CREATE TRIGGER customers_history_trigger
AFTER UPDATE OR DELETE ON operations.customers
FOR EACH ROW EXECUTE FUNCTION logs.record_history();

CREATE TRIGGER products_history_trigger
AFTER UPDATE OR DELETE ON operations.products
FOR EACH ROW EXECUTE FUNCTION logs.record_history();

CREATE TRIGGER suppliers_history_trigger
AFTER UPDATE OR DELETE ON operations.suppliers
FOR EACH ROW EXECUTE FUNCTION logs.record_history();

CREATE TRIGGER customers_updated_at_trigger
BEFORE UPDATE ON operations.customers
FOR EACH ROW EXECUTE FUNCTION operations.update_updated_at();

CREATE TRIGGER products_updated_at_trigger
BEFORE UPDATE ON operations.products
FOR EACH ROW EXECUTE FUNCTION operations.update_updated_at();

CREATE TRIGGER orders_updated_at_trigger
BEFORE UPDATE ON operations.orders
FOR EACH ROW EXECUTE FUNCTION operations.update_updated_at();

-- Create indexes
CREATE INDEX idx_customers_email ON operations.customers(email);
CREATE INDEX idx_customers_status ON operations.customers(status);
CREATE INDEX idx_products_category ON operations.products(category);
CREATE INDEX idx_products_supplier ON operations.products(supplier_id);
CREATE INDEX idx_order_items_product ON operations.order_items(product_id);
