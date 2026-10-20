CREATE TYPE dbo.OrderLineInput AS TABLE
(
    ProductId int NOT NULL PRIMARY KEY,
    Quantity int NOT NULL CHECK (Quantity > 0)
);
GO

CREATE OR ALTER PROCEDURE dbo.CreateSalesOrder
    @CustomerId int,
    @Lines dbo.OrderLineInput READONLY,
    @SalesOrderId int OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    SET @SalesOrderId = NULL;

    IF @CustomerId IS NULL OR @CustomerId <= 0
        THROW 51001, 'CustomerId must be a positive integer.', 1;
    IF NOT EXISTS (SELECT 1 FROM @Lines)
        THROW 51002, 'An order must contain at least one line.', 1;

    BEGIN TRY
        BEGIN TRANSACTION;
        IF NOT EXISTS (SELECT 1 FROM dbo.Customer WITH (UPDLOCK, HOLDLOCK)
                       WHERE CustomerId = @CustomerId AND IsActive = 1)
            THROW 51004, 'Customer does not exist or is inactive.', 1;
        IF EXISTS (SELECT 1 FROM @Lines AS requested
                   LEFT JOIN dbo.Product AS product WITH (HOLDLOCK)
                     ON product.ProductId = requested.ProductId AND product.IsActive = 1
                   WHERE product.ProductId IS NULL)
            THROW 51005, 'An order line contains an unknown or inactive product.', 1;

        INSERT INTO dbo.SalesOrder (CustomerId) VALUES (@CustomerId);
        SET @SalesOrderId = CONVERT(int, SCOPE_IDENTITY());
        INSERT INTO dbo.SalesOrderLine (SalesOrderId, ProductId, Quantity, UnitPriceAtOrder)
        SELECT @SalesOrderId, requested.ProductId, requested.Quantity, product.ListPrice
        FROM @Lines AS requested JOIN dbo.Product AS product
          ON product.ProductId = requested.ProductId;

        DECLARE @UpdatedInventory int;
        UPDATE inventory WITH (UPDLOCK, HOLDLOCK)
        SET inventory.AvailableQuantity = inventory.AvailableQuantity - requested.Quantity,
            inventory.UpdatedAt = SYSUTCDATETIME()
        FROM dbo.Inventory AS inventory JOIN @Lines AS requested
          ON requested.ProductId = inventory.ProductId
        WHERE inventory.AvailableQuantity >= requested.Quantity;
        SET @UpdatedInventory = @@ROWCOUNT;
        IF @UpdatedInventory <> (SELECT COUNT(*) FROM @Lines)
            THROW 51006, 'Insufficient inventory for one or more products.', 1;

        UPDATE dbo.SalesOrder
        SET TotalAmount = totals.TotalAmount
        FROM dbo.SalesOrder AS salesOrder
        CROSS APPLY (SELECT SUM(CONVERT(decimal(14,2), line.Quantity * line.UnitPriceAtOrder)) AS TotalAmount
                     FROM dbo.SalesOrderLine AS line
                     WHERE line.SalesOrderId = salesOrder.SalesOrderId) AS totals
        WHERE salesOrder.SalesOrderId = @SalesOrderId;
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        SET @SalesOrderId = NULL;
        THROW;
    END CATCH;
END;
GO

CREATE OR ALTER PROCEDURE dbo.CancelSalesOrder @SalesOrderId int
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    IF @SalesOrderId IS NULL OR @SalesOrderId <= 0
        THROW 51011, 'SalesOrderId must be a positive integer.', 1;
    BEGIN TRY
        BEGIN TRANSACTION;
        DECLARE @CurrentStatus varchar(20);
        SELECT @CurrentStatus = Status FROM dbo.SalesOrder WITH (UPDLOCK, HOLDLOCK)
        WHERE SalesOrderId = @SalesOrderId;
        IF @CurrentStatus IS NULL THROW 51012, 'Sales order was not found.', 1;
        IF @CurrentStatus = 'Cancelled' BEGIN COMMIT TRANSACTION; RETURN; END;
        IF @CurrentStatus <> 'Placed' THROW 51013, 'Only a placed order can be cancelled.', 1;
        UPDATE inventory WITH (UPDLOCK, HOLDLOCK)
        SET inventory.AvailableQuantity = inventory.AvailableQuantity + line.Quantity,
            inventory.UpdatedAt = SYSUTCDATETIME()
        FROM dbo.Inventory AS inventory JOIN dbo.SalesOrderLine AS line
          ON line.ProductId = inventory.ProductId
        WHERE line.SalesOrderId = @SalesOrderId;
        UPDATE dbo.SalesOrder SET Status = 'Cancelled' WHERE SalesOrderId = @SalesOrderId;
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO
