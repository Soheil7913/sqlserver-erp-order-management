/* Run after 01_schema.sql, 02_order_procedures.sql, and 03_sample_data.sql. */

/* Order detail with customer, product, and line totals. */
SELECT salesOrder.SalesOrderId, salesOrder.OrderDate, salesOrder.Status,
       customer.CustomerCode, customer.CustomerName,
       product.SKU, product.ProductName, line.Quantity, line.UnitPriceAtOrder,
       CONVERT(decimal(14,2), line.Quantity * line.UnitPriceAtOrder) AS LineTotal
FROM dbo.SalesOrder AS salesOrder
JOIN dbo.Customer AS customer ON customer.CustomerId = salesOrder.CustomerId
JOIN dbo.SalesOrderLine AS line ON line.SalesOrderId = salesOrder.SalesOrderId
JOIN dbo.Product AS product ON product.ProductId = line.ProductId
ORDER BY salesOrder.OrderDate DESC, salesOrder.SalesOrderId DESC, product.ProductName;
GO

/* Monthly revenue and running total, excluding cancelled orders. */
WITH MonthlySales AS
(
    SELECT DATEFROMPARTS(YEAR(OrderDate), MONTH(OrderDate), 1) AS SalesMonth,
           SUM(TotalAmount) AS Revenue,
           COUNT_BIG(*) AS OrderCount
    FROM dbo.SalesOrder
    WHERE Status = 'Placed'
    GROUP BY DATEFROMPARTS(YEAR(OrderDate), MONTH(OrderDate), 1)
)
SELECT SalesMonth, Revenue, OrderCount,
       SUM(Revenue) OVER (ORDER BY SalesMonth ROWS UNBOUNDED PRECEDING) AS RunningRevenue
FROM MonthlySales
ORDER BY SalesMonth;
GO

/* Rank products by monthly revenue using a window function. */
WITH ProductMonthSales AS
(
    SELECT DATEFROMPARTS(YEAR(salesOrder.OrderDate), MONTH(salesOrder.OrderDate), 1) AS SalesMonth,
           product.ProductId, product.ProductName,
           SUM(CONVERT(decimal(14,2), line.Quantity * line.UnitPriceAtOrder)) AS Revenue
    FROM dbo.SalesOrder AS salesOrder
    JOIN dbo.SalesOrderLine AS line ON line.SalesOrderId = salesOrder.SalesOrderId
    JOIN dbo.Product AS product ON product.ProductId = line.ProductId
    WHERE salesOrder.Status = 'Placed'
    GROUP BY DATEFROMPARTS(YEAR(salesOrder.OrderDate), MONTH(salesOrder.OrderDate), 1),
             product.ProductId, product.ProductName
)
SELECT SalesMonth, ProductName, Revenue,
       DENSE_RANK() OVER (PARTITION BY SalesMonth ORDER BY Revenue DESC) AS RevenueRank
FROM ProductMonthSales
ORDER BY SalesMonth, RevenueRank, ProductName;
GO

/* Customers whose spend is above the average across all customers. */
WITH CustomerSpend AS
(
    SELECT customer.CustomerId, customer.CustomerName,
           COALESCE(SUM(salesOrder.TotalAmount), 0) AS TotalSpend
    FROM dbo.Customer AS customer
    LEFT JOIN dbo.SalesOrder AS salesOrder
      ON salesOrder.CustomerId = customer.CustomerId AND salesOrder.Status = 'Placed'
    GROUP BY customer.CustomerId, customer.CustomerName
)
SELECT CustomerName, TotalSpend
FROM CustomerSpend
WHERE TotalSpend > (SELECT AVG(TotalSpend) FROM CustomerSpend)
ORDER BY TotalSpend DESC;
GO
