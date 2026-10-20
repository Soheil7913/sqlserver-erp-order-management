/* Run after 01_schema.sql, 02_order_procedures.sql, and 03_sample_data.sql. */
SET STATISTICS IO ON;
SET STATISTICS TIME ON;
GO

/*
  In SSMS, enable Include Actual Execution Plan (Ctrl+M) before running.
  Compare the YEAR() filter with the half-open date range below.
*/
DECLARE @Year int = YEAR(SYSUTCDATETIME());

/* Non-SARGable form: a function is applied to the indexed column. */
SELECT SalesOrderId, CustomerId, OrderDate, Status, TotalAmount
FROM dbo.SalesOrder
WHERE YEAR(OrderDate) = @Year;
GO

/* SARGable form: keep the indexed column unwrapped. */
DECLARE @Year int = YEAR(SYSUTCDATETIME());
DECLARE @StartOfYear datetime2(0) = DATETIMEFROMPARTS(@Year, 1, 1, 0, 0, 0, 0);
DECLARE @StartOfNextYear datetime2(0) = DATEADD(year, 1, @StartOfYear);

SELECT SalesOrderId, CustomerId, OrderDate, Status, TotalAmount
FROM dbo.SalesOrder
WHERE OrderDate >= @StartOfYear
  AND OrderDate < @StartOfNextYear;
GO

/*
  Compare logical reads, CPU and elapsed time, plus the actual access operators
  in your target environment. The small sample dataset is illustrative, not a
  meaningful performance benchmark.
*/
SET STATISTICS IO OFF;
SET STATISTICS TIME OFF;
GO
