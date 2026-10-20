/* Fictional portfolio data. Run after 01_schema.sql and 02_order_procedures.sql. */
SET NOCOUNT ON;
GO

INSERT INTO dbo.Customer (CustomerCode, CustomerName, Email)
VALUES
    ('CUST-1001', N'Aria Office Supplies', 'orders@aria.example'),
    ('CUST-1002', N'Northstar Retail', 'procurement@northstar.example'),
    ('CUST-1003', N'Blue Cedar Trading', 'buying@bluecedar.example');
GO

INSERT INTO dbo.Product (SKU, ProductName, ListPrice)
VALUES
    ('SKU-100', N'Wireless Barcode Scanner', 89.90),
    ('SKU-200', N'Thermal Receipt Printer', 159.00),
    ('SKU-300', N'Label Roll - Pack of 10', 24.50),
    ('SKU-400', N'USB-C Docking Station', 119.00),
    ('SKU-500', N'Inventory Tablet Stand', 38.75);
GO

INSERT INTO dbo.Inventory (ProductId, AvailableQuantity)
SELECT ProductId, 25 FROM dbo.Product;
GO

DECLARE @Lines dbo.OrderLineInput;
DECLARE @OrderId int;

INSERT INTO @Lines (ProductId, Quantity) VALUES (1, 2), (3, 4);
EXEC dbo.CreateSalesOrder @CustomerId = 1, @Lines = @Lines,
    @SalesOrderId = @OrderId OUTPUT;

DELETE FROM @Lines;
INSERT INTO @Lines (ProductId, Quantity) VALUES (2, 1), (5, 2);
EXEC dbo.CreateSalesOrder @CustomerId = 2, @Lines = @Lines,
    @SalesOrderId = @OrderId OUTPUT;

DELETE FROM @Lines;
INSERT INTO @Lines (ProductId, Quantity) VALUES (1, 1), (4, 1), (3, 2);
EXEC dbo.CreateSalesOrder @CustomerId = 3, @Lines = @Lines,
    @SalesOrderId = @OrderId OUTPUT;
GO
