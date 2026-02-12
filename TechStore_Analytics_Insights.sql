

-- 1.Calculating Running Sum of Sales Quantity

WITH running_sales AS (
    SELECT 
        sale_id, 
        product_id, 
        sale_date, 
        quantity,
        SUM(quantity) OVER (PARTITION BY product_id ORDER BY sale_date) AS running_sum
    FROM factsales
)
SELECT 
    sale_id, 
    product_id, 
    sale_date, 
    quantity, 
    running_sum
FROM running_sales
ORDER BY sale_date

-- 2.Calculating the Month-on-Month (MoM) Percentage Change in Sales Quantity

WITH monthly_sales AS (
    SELECT 
        product_id, 
        TO_VARCHAR(sale_date, 'YYYY-MM') AS year_month, 
        SUM(quantity) AS monthly_sales
    FROM factsales
    GROUP BY product_id, year_month
)
SELECT 
    product_id, 
    year_month, 
    monthly_sales, 
    (monthly_sales - LAG(monthly_sales) OVER (PARTITION BY product_id ORDER BY year_month)) * 100.0 /
    LAG(monthly_sales) OVER (PARTITION BY product_id ORDER BY year_month) AS mom_percentage_change
FROM monthly_sales
ORDER BY product_id, year_month


-- 3.Calculating the Rolling Sum of Sales Revenue Over the Last 3 Months

WITH monthly_revenue AS (
    SELECT 
        TO_VARCHAR(s.sale_date, 'YYYY-MM') AS year_month, 
        SUM(s.quantity * p.price * (1 - s.discount)) AS monthly_revenue
    FROM factsales s
    JOIN products p ON s.product_id = p.product_id
    GROUP BY year_month
)
SELECT 
    year_month,
    monthly_revenue,
    SUM(monthly_revenue) OVER (
        ORDER BY year_month
        ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
    ) AS rolling_3_month_revenue
FROM monthly_revenue
ORDER BY year_month

-- 4.Calculating the Total Sales for Each Product by Month

WITH monthly_sales AS (
    SELECT 
        s.product_id,  
        TO_VARCHAR(s.sale_date, 'YYYY-MM') AS year_month, 
        SUM(s.quantity * p.price * (1 - s.discount)) AS total_sales
    FROM factsales s
    JOIN products p ON s.product_id = p.product_id  -- Correct join between factsales and products
    GROUP BY s.product_id, year_month
)
SELECT 
    monthly_sales.product_id,  
    year_month, 
    total_sales, 
    SUM(total_sales) OVER (PARTITION BY monthly_sales.product_id ORDER BY year_month) AS cumulative_sales
FROM monthly_sales
ORDER BY monthly_sales.product_id, year_month

-- 5.Calculating the Change in Sales Quantity Compared to the Previous Sale Using the LAG Window Function

WITH sales_changes AS (
    SELECT 
        customer_id, 
        sale_date, 
        quantity,
        LAG(quantity) OVER (PARTITION BY customer_id ORDER BY sale_date) AS previous_quantity
    FROM factsales
)
SELECT 
    customer_id, 
    sale_date, 
    quantity, 
    quantity - previous_quantity AS quantity_change
FROM sales_changes
ORDER BY customer_id, sale_date

-- 6.Calculating the Discount Percentage Change for Each Product Using the LAG Window Function

WITH discount_changes AS (
    SELECT 
        product_id, 
        sale_date, 
        discount,
        LAG(discount) OVER (PARTITION BY product_id ORDER BY sale_date) AS previous_discount
    FROM factsales
)
SELECT 
    product_id, 
    sale_date, 
    discount,
    CASE 
        WHEN previous_discount = 0 THEN NULL 
        ELSE ROUND((discount - previous_discount) * 100.0 / previous_discount, 2)
    END AS discount_percentage_change
FROM discount_changes
ORDER BY product_id, sale_date;

--7.Calculating the Cumulative Sales Revenue for Top 5 Products using RANK

WITH product_sales AS (
    SELECT 
        s.product_id, 
        SUM(quantity * p.price * (1 - s.discount)) AS total_revenue
    FROM factsales s
    JOIN products p ON s.product_id = p.product_id
    GROUP BY s.product_id
),
ranked_sales AS (
    SELECT 
        product_id, 
        total_revenue,
        RANK() OVER (ORDER BY total_revenue DESC) AS revenue_rank
    FROM product_sales
)
SELECT 
    ranked_sales.product_id,  
    total_revenue
FROM ranked_sales
WHERE revenue_rank <= 5
ORDER BY total_revenue DESC

-- 8.Calculating Previous and Next Sale Price for Each Product using LAG and LEAD Window functions

WITH price_changes AS (
    SELECT 
        s.product_id, 
        s.sale_date, 
        p.price,  
        LAG(p.price) OVER (PARTITION BY s.product_id ORDER BY s.sale_date) AS previous_price,
        LEAD(p.price) OVER (PARTITION BY s.product_id ORDER BY s.sale_date) AS next_price
    FROM factsales s
    JOIN products p ON s.product_id = p.product_id  
)
SELECT 
    product_id, 
    sale_date, 
    price, 
    previous_price, 
    next_price
FROM price_changes
ORDER BY product_id, sale_date;

-- 9.Calculating Total Quantity Sold for Each Product in a Rolling Window

WITH product_sales AS (
    SELECT 
        product_id, 
        sale_date, 
        quantity,
        ROW_NUMBER() OVER (PARTITION BY product_id ORDER BY sale_date) AS sale_rank
    FROM factsales
)
SELECT 
    product_id, 
    sale_date, 
    quantity,
    SUM(quantity) OVER (
        PARTITION BY product_id 
        ORDER BY sale_date 
        ROWS BETWEEN 5 PRECEDING AND CURRENT ROW
    ) AS rolling_sales_quantity
FROM product_sales
ORDER BY product_id, sale_date;

-- 10.Calculating Sales Growth for Each Product Over 6 Months

--Without product_name column

WITH monthly_sales AS (
    SELECT 
        s.product_id, 
        TO_VARCHAR(sale_date, 'YYYY-MM') AS year_month, 
        SUM(quantity * p.price * (1 - s.discount)) AS monthly_sales
    FROM factsales s
    JOIN products p ON s.product_id = p.product_id
    GROUP BY s.product_id, year_month
)
SELECT 
    monthly_sales.product_id, 
    year_month, 
    monthly_sales,
    (monthly_sales - LAG(monthly_sales, 6)
    OVER (PARTITION BY product_id ORDER BY year_month)) * 100.0 / LAG(monthly_sales, 6) 
    OVER (PARTITION BY product_id ORDER BY year_month) AS sales_growth
FROM monthly_sales
ORDER BY monthly_sales.product_id, year_month;


-- With product_name column

WITH monthly_sales AS (
    SELECT 
        s.product_id, 
        TO_VARCHAR(s.sale_date, 'YYYY-MM') AS year_month, 
        SUM(s.quantity * p.price * (1 - s.discount)) AS monthly_sales
    FROM factsales s
    JOIN products p ON s.product_id = p.product_id
    GROUP BY s.product_id, year_month
)
SELECT 
    ms.product_id, 
    p.product_name,  
    ms.year_month, 
    ms.monthly_sales,
    (ms.monthly_sales - LAG(ms.monthly_sales, 6)
    OVER (PARTITION BY ms.product_id ORDER BY ms.year_month)) * 100.0 / LAG(ms.monthly_sales, 6) 
    OVER (PARTITION BY ms.product_id ORDER BY ms.year_month) AS sales_growth
FROM monthly_sales ms
JOIN products p ON ms.product_id = p.product_id  
ORDER BY ms.product_id, ms.year_month;









