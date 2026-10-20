# SQL Server ERP Order Management Sample

A portfolio project that models a small order-to-fulfillment workflow with Microsoft SQL Server and T-SQL. It uses fictional customers, products, and orders; it contains no employer or production data.

## What this demonstrates

- Relational schema design for customers, products, inventory, sales orders, and order lines
- A table-valued parameter for submitting multiple order lines
- Transaction-safe order creation with inventory checks and rollback on failure
- Idempotent order cancellation that restores inventory once
- Reporting queries using joins, common table expressions, window functions, and date ranges
- Index choices and a reproducible method for reviewing execution plans and IO

## Requirements

- SQL Server 2019 or later
- SQL Server Management Studio, Azure Data Studio, or another SQL client

Create an empty database named ErpOrderManagement (or choose another name), connect to it, then run the scripts below in order. Each script is intended to be run once in a fresh database.

## Setup

1. Run [sql/01_schema.sql](sql/01_schema.sql).
2. Run [sql/02_order_procedures.sql](sql/02_order_procedures.sql).
3. Run [sql/03_sample_data.sql](sql/03_sample_data.sql).
4. Run [sql/04_reporting_queries.sql](sql/04_reporting_queries.sql) when you want to explore reports.
5. Run [sql/05_performance_review.sql](sql/05_performance_review.sql) to compare query shapes and inspect the actual execution plan.

## Verified run

The scripts were run in SSMS against a separate ErpOrderManagement database on SQL Server 17.0 RTM. The schema, procedures, sample data, reporting queries, and performance review completed successfully.

The seed data contains 3 customers, 5 products, 3 placed orders, and 7 order lines. The reporting script returned 15 rows across its four result sets. The performance review returned the same 3 seed orders for both date filters; its small sample is for demonstration, not a performance benchmark.

The create-and-cancel workflow was also run for 2 units of SKU-100. Available stock changed from 22 to 20 when the order was placed, then returned to 22 when it was cancelled. Repeating the cancellation left stock at 22, and the order status remained Cancelled. The demonstration order remains in the local database as a cancelled order.

## Try the order workflow

~~~sql
DECLARE @Lines dbo.OrderLineInput;

INSERT INTO @Lines (ProductId, Quantity)
VALUES (1, 2), (3, 1);

DECLARE @NewOrderId int;

EXEC dbo.CreateSalesOrder
    @CustomerId = 1,
    @Lines = @Lines,
    @SalesOrderId = @NewOrderId OUTPUT;

SELECT @NewOrderId AS SalesOrderId;
SELECT * FROM dbo.SalesOrder WHERE SalesOrderId = @NewOrderId;
SELECT * FROM dbo.SalesOrderLine WHERE SalesOrderId = @NewOrderId;
~~~

The sample data starts each product with 25 units. To see rollback behavior, request more units than are available. The procedure raises an error and does not leave a partial order or inventory change.

To cancel an order that is still Placed:

~~~sql
EXEC dbo.CancelSalesOrder @SalesOrderId = 1;
~~~

Canceling an already-canceled order is safe to repeat. Orders in any other state are not changed by this sample workflow.

## Design notes

- SalesOrderLine.UnitPriceAtOrder stores the price at the time the order was placed, so later catalog price changes do not rewrite history.
- Inventory is represented as available quantity. Placing an order decrements it; canceling a placed order restores it.
- Order creation and cancellation use explicit transactions with XACT_ABORT ON so an error rolls back the full operation.
- OrderLineInput rejects duplicate product IDs in a request through its primary key.
- The procedures validate inputs and use THROW for actionable failures.
- The performance script demonstrates a non-SARGable year filter and a date-range alternative. No benchmark numbers are claimed; results depend on data volume, statistics, and the SQL Server environment.

## Project layout

~~~text
sql/
  01_schema.sql
  02_order_procedures.sql
  03_sample_data.sql
  04_reporting_queries.sql
  05_performance_review.sql
~~~

## Limitations

This is a learning and portfolio sample, not a production ERP. It intentionally omits authentication, payment processing, shipping, taxes, permissions, audit retention, and integration with external systems.
