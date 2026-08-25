# Data Catalog for Gold Layer

## Overview
The Gold Layer is the business-level data representation, structured to support analytical and reporting use cases. It consists of **dimension tables** and **fact tables** for specific business metrics.

---

### 1. **gold.dim_customers**
- **Purpose:** Stores customer details enriched with demographic and geographic data.
- **Columns:**

| Column Name      | Data Type    | Description                                                                            |
|------------------|--------------|---------------------------------------------------------------------------------------|
| customer_key     | INT          | Surrogate key uniquely identifying each customer record in the dimension table.        |
| customer_id      | INT          | Unique numerical identifier assigned to each customer (from CRM).                      |
| customer_number  | VARCHAR(50)  | Alphanumeric identifier representing the customer, used for tracking and referencing.  |
| first_name       | VARCHAR(50)  | The customer's first name, as recorded in the system.                                 |
| last_name        | VARCHAR(50)  | The customer's last name or family name.                                              |
| country          | VARCHAR(50)  | The country of residence for the customer (e.g., 'Germany'), sourced from ERP.        |
| marital_status   | VARCHAR(50)  | The marital status of the customer (e.g., 'Married', 'Single').                       |
| gender           | VARCHAR(50)  | The gender of the customer (e.g., 'Male', 'Female', 'n/a'). CRM is master, ERP fallback. |
| birthdate        | DATE         | The date of birth of the customer, formatted as YYYY-MM-DD (e.g., 1971-10-06).        |
| create_date      | DATE         | The date on which the customer record was created in the source system.               |

---

### 2. **gold.dim_products**
- **Purpose:** Provides information about the products and their attributes. Contains only the **current** version of each product (historical versions are filtered out).
- **Columns:**

| Column Name    | Data Type    | Description                                                                                           |
|----------------|--------------|------------------------------------------------------------------------------------------------------|
| product_key    | INT          | Surrogate key uniquely identifying each product record in the product dimension table.               |
| product_id     | INT          | A unique identifier assigned to the product for internal tracking and referencing.                   |
| product_number | VARCHAR(50)  | A structured alphanumeric code representing the product, often used for categorization or inventory.  |
| product_name   | VARCHAR(50)  | Descriptive name of the product, including key details such as type, color, and size.                |
| category_id    | VARCHAR(50)  | A unique identifier for the product's category, linking to its high-level classification.            |
| category       | VARCHAR(50)  | The broader classification of the product (e.g., Bikes, Components) to group related items.           |
| subcategory    | VARCHAR(50)  | A more detailed classification of the product within the category, such as product type.             |
| maintenance    | VARCHAR(50)  | Indicates whether the product requires maintenance (e.g., 'Yes', 'No').                              |
| product_cost   | INT          | The cost or base price of the product, measured in monetary units.                                   |
| product_line   | VARCHAR(50)  | The specific product line or series to which the product belongs (e.g., Road, Mountain).             |
| start_date     | DATE         | The date on which the (current) product version became available for sale or use.                    |

---

### 3. **gold.dim_date**
- **Purpose:** Calendar date dimension enabling time-based analysis (year, quarter, month, weekday, weekend). Generated for the full range of dates covered by fact_sales (2010-01-01 to 2014-12-31). Acts as a role-playing dimension: fact_sales joins to it once per date role (order, shipping, due).
- **Columns:**

| Column Name  | Data Type    | Description                                                                          |
|--------------|--------------|--------------------------------------------------------------------------------------|
| date_key     | INT          | Surrogate key in YYYYMMDD form (e.g., 20130115); joined from fact_sales date keys.   |
| full_date    | DATE         | The actual calendar date (e.g., 2013-01-15).                                          |
| year         | INT          | The calendar year (e.g., 2013).                                                       |
| quarter      | INT          | The calendar quarter, 1 to 4.                                                         |
| month        | INT          | The month number, 1 to 12.                                                            |
| month_name   | TEXT         | The full month name (e.g., 'January').                                                |
| day          | INT          | The day of the month, 1 to 31.                                                        |
| day_of_week  | INT          | ISO day of week, 1 (Monday) to 7 (Sunday).                                            |
| day_name     | TEXT         | The full weekday name (e.g., 'Monday').                                               |
| week_of_year | INT          | The ISO week number of the year.                                                     |
| is_weekend   | BOOLEAN      | TRUE if the date falls on Saturday or Sunday, otherwise FALSE.                        |

---

### 4. **gold.fact_sales**
- **Purpose:** Stores transactional sales data for analytical purposes. Grain: one row per product line item within an order.
- **Columns:**

| Column Name       | Data Type    | Description                                                                                 |
|-------------------|--------------|---------------------------------------------------------------------------------------------|
| order_number      | VARCHAR(50)  | A unique alphanumeric identifier for each sales order (e.g., 'SO54496').                     |
| product_key       | INT          | Surrogate key linking the order line to the product dimension (gold.dim_products).          |
| customer_key      | INT          | Surrogate key linking the order line to the customer dimension (gold.dim_customers).        |
| order_date_key    | INT          | Surrogate date key (YYYYMMDD) for when the order was placed; joins to gold.dim_date.        |
| shipping_date_key | INT          | Surrogate date key (YYYYMMDD) for when the order was shipped; joins to gold.dim_date.       |
| due_date_key      | INT          | Surrogate date key (YYYYMMDD) for when the order payment was due; joins to gold.dim_date.   |
| sales_amount      | INT          | The total monetary value of the sale for the line item, in whole currency units (e.g., 25). |
| quantity          | INT          | The number of units of the product ordered for the line item (e.g., 1).                     |
| price             | INT          | The price per unit of the product for the line item, in whole currency units (e.g., 25).    |
