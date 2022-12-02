--- Inspecting Data

select * from dbo.sales_data_sample

-- Checking unique values

SELECT DISTINCT status from dbo.sales_data_sample 
SELECT DISTINCT YEAR_ID from dbo.sales_data_sample
SELECT DISTINCT PRODUCTLINE from dbo.sales_data_sample
SELECT DISTINCT COUNTRY from dbo.sales_data_sample
SELECT DISTINCT DEALSIZE from dbo.sales_data_sample
SELECT DISTINCT TERRITORY from dbo.sales_data_sample

SELECT DISTINCT MONTH_id FROM dbo.sales_data_sample
WHERE YEAR_ID=2005


--- ANALYSIS

---Grouping sales by productline
SELECT PRODUCTLINE,sum(sales) AS Revenue
FROM dbo.sales_data_sample
GROUP BY PRODUCTLINE
ORDER BY Revenue DESC


---Grouping sales by Year
SELECT YEAR_ID,sum(sales) AS Revenue
FROM dbo.sales_data_sample
GROUP BY YEAR_ID
ORDER BY Revenue DESC

---Grouping sales by Dealsize
SELECT DEALSIZE,sum(sales) AS Revenue
FROM dbo.sales_data_sample
GROUP BY DEALSIZE
ORDER BY Revenue DESC

--What was the best month 

SELECT month_id,sum(sales) AS Revenue, count(ORDERNUMBER) AS Frequency
FROM dbo.sales_data_sample
WHERE YEAR_ID=2004
GROUP BY month_id
ORDER BY Revenue DESC


--- NOVEMBER seems to be the best month,I'm going to check what products do they sell the most.
SELECT MONTH_ID,PRODUCTLINE,sum(sales) AS Revenue, count(ORDERNUMBER) AS Frequency
FROM dbo.sales_data_sample
WHERE YEAR_ID=2004 AND MONTH_ID=11
GROUP BY MONTH_ID,PRODUCTLINE
ORDER BY Revenue DESC


--- Who is our best customer (RFM Analysis)
DROP TABLE IF EXISTS #rfm
;WITH rfm as 

(	
	SELECT 
		CUSTOMERNAME,
		sum(sales) AS MonetaryValue,
		avg(sales) AS AvgMonetaryValue,
		COUNT(Ordernumber) AS Frequency,
		MAX(ORDERDATE) AS Last_order_date,
		(SELECT MAX(ORDERDATE) FROM dbo.sales_data_sample) max_order_date,
		DATEDIFF(DD,MAX(ORDERDATE),(SELECT MAX(ORDERDATE) FROM dbo.sales_data_sample)) AS Recency
	FROM dbo.sales_data_sample
	GROUP BY CUSTOMERNAME
),


rfm_calc as 
(

	select r.*,
		NTILE(4) OVER (order by Recency DESC)  RFM_Recency,
		NTILE(4) OVER (order by Frequency)  RFM_Frequency,
		NTILE(4) OVER (order by MonetaryValue)  RFM_Monetary
	FROM rfm r
)

SELECT c.*,RFM_Recency+RFM_Frequency+RFM_Monetary AS RFM_Cell,
cast(RFM_Recency AS varchar) + cast(RFM_Frequency AS varchar) + cast(RFM_Monetary AS varchar) AS RFM_cell_string
into #rfm
FROM rfm_calc AS c



-- Using case statement in order to create "bucket customers"
SELECT CUSTOMERNAME,RFM_Recency,RFM_Frequency,RFM_Monetary, 
	case 
		when RFM_cell_string in (111, 112 , 121, 122, 123, 132, 211, 212, 114, 141) then 'lost_customers'  --lost customers
		when RFM_cell_string in (133, 134, 143, 244, 334, 343, 344, 144) then 'slipping away, cannot lose' -- (Big spenders who haven’t purchased lately) slipping away
		when RFM_cell_string in (311, 411, 331) then 'new customers'
		when RFM_cell_string in (222, 223, 233, 322) then 'potential churners'
		when RFM_cell_string in (323, 333,321, 422, 332, 432) then 'active' --(Customers who buy often & recently, but at low price points)
		when rfm_cell_string in (433, 434, 443, 444) then 'loyal'
	end rfm_segment
FROM #rfm


--What product are most often sold together? 1) count of orders are shipped to the customer (processing or hold but not sold)
-- SELECT * FROM dbo.sales_data_sample WHERE ORDERNUMBER = 10411



-- Now I want to see wgich porducts are sold together like this  ORDERNUMBER = 10411 that have been sold 9 different produts at the same time
--  I want to see the productcode for this products for the bottom table which products are sold together 
-- I sue xml path to "append the porductcode in one row" 



SELECT DISTINCT ORDERNUMBER,STUFF(
	(SELECT ','+ PRODUCTCODE
	FROM sales_data_sample AS p
	WHERE ORDERNUMBER IN 
		(

			SELECT ORDERNUMBER
			FROM (

			SELECT ORDERNUMBER,count(ORDERNUMBER) AS rn
			FROM dbo.sales_data_sample
			WHERE status = 'Shipped'
			GROUP BY ORDERNUMBER
			) AS m
			WHERE rn = 3
		)
		and p.ORDERNUMBER=s.ORDERNUMBER
		for xml path (''))
		,1,1,'') AS PorductCodes

FROM dbo.sales_data_sample AS s
ORDER BY 2 DESC




--What city has the highest number of sales in a specific country
select city, sum (sales) Revenue
from dbo.sales_data_sample
where country = 'UK'
group by city
order by 2 desc



---What is the best product in United States?
select country, YEAR_ID, PRODUCTLINE, sum(sales) Revenue
from dbo.sales_data_sample
where country = 'USA'
group by  country, YEAR_ID, PRODUCTLINE
order by 4 desc