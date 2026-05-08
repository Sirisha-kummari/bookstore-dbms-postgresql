-- =========================
-- PART 1: Drop Existing Tables (in correct order)
-- =========================
-- Drop order_items table first (since it depends on orders)
DROP TABLE IF EXISTS order_items;

-- Drop orders table second (since it depends on customers)
DROP TABLE IF EXISTS orders;

-- Drop customers table third (no dependencies left after orders and order_items are dropped)
DROP TABLE IF EXISTS customers;

-- Drop books table last (no dependencies)
DROP TABLE IF EXISTS books;

-- =========================
-- PART 2: Recreate Tables and Insert Data
-- =========================

-- Recreate books table
CREATE TABLE books (
    book_id SERIAL PRIMARY KEY,
    title VARCHAR(100) NOT NULL,
    author VARCHAR(50) NOT NULL,
    isbn VARCHAR(20) NOT NULL,
    price DECIMAL(8,2) NOT NULL,
    stock_quantity INTEGER NOT NULL
);

-- Insert books data
INSERT INTO books (title, author, isbn, price, stock_quantity) VALUES
('To Kill a Mockingbird', 'Harper Lee', '9780061120084', 599.00, 10),
('1984', 'George Orwell', '9780451524935', 499.00, 15),
('Pride and Prejudice', 'Jane Austen', '9780141439518', 399.00, 5),
('The Hobbit', 'J.R.R. Tolkien', '9780261103344', 699.00, 20),
('The Catcher in the Rye', 'J.D. Salinger', '9780316769488', 550.00, 8);

-- Verify books data
SELECT * FROM books;

-- Show books with ₹ symbol in price
SELECT 
    book_id, 
    title, 
    author, 
    isbn, 
    '₹' || price AS price,  -- Adds ₹ before the price
    stock_quantity
FROM books;


-- Recreate customers table
CREATE TABLE customers (
    customer_id SERIAL PRIMARY KEY,
    first_name VARCHAR(50) NOT NULL,
    last_name VARCHAR(50) NOT NULL,
    customer_type VARCHAR(20) NOT NULL,
    email VARCHAR(100) NOT NULL,
    phone VARCHAR(15),
    age INTEGER,
    student_id VARCHAR(20)
);

-- Insert customers data
INSERT INTO customers (first_name, last_name, customer_type, email, phone, age, student_id) VALUES
('Alice', 'Johnson', 'Student', 'alice.johnson@email.com', '9876543210', 20, 'S12345'),
('Robert', 'Smith', 'Student', 'robert.smith@email.com', '9123456780', 35, 'S67890'),
('Priya', 'Sharma', 'Student', 'priya.sharma@email.com', '9988776655', 22, 'S54321');

-- Verify customers data
SELECT * FROM customers;

-- Recreate orders table
CREATE TABLE orders (
    order_id SERIAL PRIMARY KEY,
    customer_id INTEGER REFERENCES customers(customer_id),
    order_date DATE NOT NULL,
    total_amount DECIMAL(10,2) NOT NULL
);
-- Insert orders data
INSERT INTO orders (customer_id, order_date, total_amount) VALUES
(1, '2025-10-10', 1198.00),
(3, '2025-10-12', 799.00);
-- Verify orders data
SELECT * FROM orders;
-- Recreate order_items table
CREATE TABLE order_items (
    order_item_id SERIAL PRIMARY KEY,
    order_id INTEGER REFERENCES orders(order_id),
    book_id INTEGER REFERENCES books(book_id),
    quantity INTEGER NOT NULL,
    price DECIMAL(8,2) NOT NULL
);

-- Insert order items data (linking books to orders)
INSERT INTO order_items (order_id, book_id, quantity, price) VALUES
(1, 1, 1, 599.00),  -- Order 1, Book 1 (1 quantity)
(1, 4, 2, 699.00),  -- Order 1, Book 4 (2 quantities)
(2, 3, 1, 399.00),  -- Order 2, Book 3 (1 quantity)
(2, 5, 1, 550.00);  -- Order 2, Book 5 (1 quantity)

-- Verify order_items data
SELECT * FROM order_items;

-- Verify order_items data
SELECT 
    order_item_id, 
    order_id, 
    book_id, 
    quantity, 
    '₹' || price AS price -- Adds ₹ symbol to the price for display
FROM order_items;

-- =========================
-- PART 3: Operational Queries (Daily Operations)
-- =========================

-- 1. Show all books currently in stock
SELECT 
    book_id, 
    title, 
    author, 
    isbn, 
    price, 
    stock_quantity
FROM books
WHERE stock_quantity > 0;

-- 2. Find a customer by last name
SELECT 
    customer_id, 
    first_name, 
    last_name, 
    email, 
    phone 
FROM customers
WHERE last_name = 'Smith';  -- Replace 'Smith' with the last name you're searching for.

-- 3. Calculate total sales for the current month
SELECT 
    SUM(total_amount) AS total_sales
FROM orders
WHERE EXTRACT(MONTH FROM order_date) = EXTRACT(MONTH FROM CURRENT_DATE)
  AND EXTRACT(YEAR FROM order_date) = EXTRACT(YEAR FROM CURRENT_DATE);

  -- 4. Update stock when a book is sold
UPDATE books
SET stock_quantity = stock_quantity - 1
WHERE book_id = 1;  -- Example: Decrease stock of book ID 1 by 1

-- 5. List all orders for a specific customer with price in ₹ symbol
SELECT 
    o.order_id, 
    o.order_date, 
    o.total_amount, 
    oi.book_id, 
    oi.quantity, 
    '₹' || oi.price AS price  -- Adds ₹ symbol before the price
FROM orders o
JOIN order_items oi ON o.order_id = oi.order_id
WHERE o.customer_id = 1;  -- Replace '1' with the customer_id you're interested in

 -- Create schema
CREATE SCHEMA IF NOT EXISTS dwh;

-- Drop fact table first (depends on dimension tables)
DROP TABLE IF EXISTS dwh.fact_sales;

-- Drop dimension tables
DROP TABLE IF EXISTS dwh.dim_book;
DROP TABLE IF EXISTS dwh.dim_customer;
DROP TABLE IF EXISTS dwh.dim_date;

-- Then run the CREATE TABLE statements again


-- Dimension Tables
CREATE TABLE dwh.dim_book (
    book_id INT PRIMARY KEY,
    title VARCHAR(100),
    author VARCHAR(50),
    price NUMERIC(10,2)
);

CREATE TABLE dwh.dim_customer (
    customer_id INT PRIMARY KEY,
    first_name VARCHAR(50),
    last_name VARCHAR(50),
    customer_type VARCHAR(20),
    email VARCHAR(100)
);

CREATE TABLE dwh.dim_date (
    date_id SERIAL PRIMARY KEY,
    order_date DATE,
    month INT,
    year INT
);

-- Fact Table
CREATE TABLE dwh.fact_sales (
    fact_id SERIAL PRIMARY KEY,
    order_id INT,
    book_id INT REFERENCES dwh.dim_book(book_id),
    customer_id INT REFERENCES dwh.dim_customer(customer_id),
    date_id INT REFERENCES dwh.dim_date(date_id),
    quantity_sold INT,
    total_amount NUMERIC(10,2)
);

-- Load data from OLTP into dimensions
INSERT INTO dwh.dim_book (book_id, title, author, price)
SELECT book_id, title, author, price FROM books;

INSERT INTO dwh.dim_customer (customer_id, first_name, last_name, customer_type, email)
SELECT customer_id, first_name, last_name, customer_type, email FROM customers;

INSERT INTO dwh.dim_date (order_date, month, year)
SELECT DISTINCT order_date, EXTRACT(MONTH FROM order_date)::INT, EXTRACT(YEAR FROM order_date)::INT
FROM orders;

-- Load data into fact table
INSERT INTO dwh.fact_sales (order_id, book_id, customer_id, date_id, quantity_sold, total_amount)
SELECT 
    oi.order_id,
    oi.book_id,
    o.customer_id,
    d.date_id,
    oi.quantity,
    oi.price * oi.quantity
FROM order_items oi
JOIN orders o ON oi.order_id = o.order_id
JOIN dwh.dim_date d ON o.order_date = d.order_date;

-- Total sales by book
SELECT b.title, SUM(f.total_amount) AS total_sales
FROM dwh.fact_sales f
JOIN dwh.dim_book b ON f.book_id = b.book_id
GROUP BY b.title;

-- Total sales by month
SELECT d.month, d.year, SUM(f.total_amount) AS total_sales
FROM dwh.fact_sales f
JOIN dwh.dim_date d ON f.date_id = d.date_id
GROUP BY d.year, d.month
ORDER BY d.year, d.month;

-- Top 3 customers by total purchase
SELECT c.first_name, c.last_name, SUM(f.total_amount) AS total_spent
FROM dwh.fact_sales f
JOIN dwh.dim_customer c ON f.customer_id = c.customer_id
GROUP BY c.customer_id
ORDER BY total_spent DESC
LIMIT 3;

-- Average order value per customer
SELECT c.first_name, c.last_name, AVG(f.total_amount) AS avg_order_value
FROM dwh.fact_sales f
JOIN dwh.dim_customer c ON f.customer_id = c.customer_id
GROUP BY c.customer_id;

-- Sales trend by year
SELECT d.year, SUM(f.total_amount) AS total_sales
FROM dwh.fact_sales f
JOIN dwh.dim_date d ON f.date_id = d.date_id
GROUP BY d.year
ORDER BY d.year;



