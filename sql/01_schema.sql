/* Run in an empty database. Target: SQL Server 2019+. */
SET NOCOUNT ON;
GO

CREATE TABLE dbo.Customer
(
    CustomerId int IDENTITY(1,1) NOT NULL CONSTRAINT PK_Customer PRIMARY KEY,
    CustomerCode varchar(20) NOT NULL CONSTRAINT UQ_Customer_CustomerCode UNIQUE,
    CustomerName nvarchar(150) NOT NULL,
    Email nvarchar(254) NULL,
    IsActive bit NOT NULL CONSTRAINT DF_Customer_IsActive DEFAULT (1),
    CreatedAt datetime2(0) NOT NULL CONSTRAINT DF_Customer_CreatedAt DEFAULT (SYSUTCDATETIME())
);
GO

CREATE TABLE dbo.Product
(
    ProductId int IDENTITY(1,1) NOT NULL CONSTRAINT PK_Product PRIMARY KEY,
    SKU varchar(30) NOT NULL CONSTRAINT UQ_Product_SKU UNIQUE,
    ProductName nvarchar(150) NOT NULL,
    ListPrice decimal(12,2) NOT NULL,
    IsActive bit NOT NULL CONSTRAINT DF_Product_IsActive DEFAULT (1),
    CONSTRAINT CK_Product_ListPrice_Nonnegative CHECK (ListPrice >= 0)
);
GO

CREATE TABLE dbo.Inventory
(
    ProductId int NOT NULL CONSTRAINT PK_Inventory PRIMARY KEY,
    AvailableQuantity int NOT NULL,
    UpdatedAt datetime2(0) NOT NULL CONSTRAINT DF_Inventory_UpdatedAt DEFAULT (SYSUTCDATETIME()),
    CONSTRAINT FK_Inventory_Product FOREIGN KEY (ProductId) REFERENCES dbo.Product (ProductId),
    CONSTRAINT CK_Inventory_AvailableQuantity_Nonnegative CHECK (AvailableQuantity >= 0)
);
GO

CREATE TABLE dbo.SalesOrder
(
    SalesOrderId int IDENTITY(1,1) NOT NULL CONSTRAINT PK_SalesOrder PRIMARY KEY,
    CustomerId int NOT NULL,
    OrderDate datetime2(0) NOT NULL CONSTRAINT DF_SalesOrder_OrderDate DEFAULT (SYSUTCDATETIME()),
    Status varchar(20) NOT NULL CONSTRAINT DF_SalesOrder_Status DEFAULT ('Placed'),
    TotalAmount decimal(14,2) NOT NULL CONSTRAINT DF_SalesOrder_TotalAmount DEFAULT (0),
    CONSTRAINT FK_SalesOrder_Customer FOREIGN KEY (CustomerId) REFERENCES dbo.Customer (CustomerId),
    CONSTRAINT CK_SalesOrder_Status CHECK (Status IN ('Placed', 'Cancelled')),
    CONSTRAINT CK_SalesOrder_TotalAmount_Nonnegative CHECK (TotalAmount >= 0)
);
GO

CREATE TABLE dbo.SalesOrderLine
(
    SalesOrderId int NOT NULL,
    ProductId int NOT NULL,
    Quantity int NOT NULL,
    UnitPriceAtOrder decimal(12,2) NOT NULL,
    CONSTRAINT PK_SalesOrderLine PRIMARY KEY (SalesOrderId, ProductId),
    CONSTRAINT FK_SalesOrderLine_SalesOrder FOREIGN KEY (SalesOrderId) REFERENCES dbo.SalesOrder (SalesOrderId),
    CONSTRAINT FK_SalesOrderLine_Product FOREIGN KEY (ProductId) REFERENCES dbo.Product (ProductId),
    CONSTRAINT CK_SalesOrderLine_Quantity_Positive CHECK (Quantity > 0),
    CONSTRAINT CK_SalesOrderLine_UnitPrice_Nonnegative CHECK (UnitPriceAtOrder >= 0)
);
GO

CREATE INDEX IX_SalesOrder_OrderDate_CustomerId
    ON dbo.SalesOrder (OrderDate, CustomerId)
    INCLUDE (Status, TotalAmount);
GO

CREATE INDEX IX_SalesOrderLine_ProductId_SalesOrderId
    ON dbo.SalesOrderLine (ProductId, SalesOrderId)
    INCLUDE (Quantity, UnitPriceAtOrder);
GO
