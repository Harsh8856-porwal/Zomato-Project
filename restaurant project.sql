CREATE DATABASE ZOMATO;

select*from orders;
select*from customers;
select*from deliveries;
select*from riders;
select*from restaurants;

select count(*) from restaurants
where city is not null or restaurant_name is null or
opening_hours is null;

select count(*) from orders
where order_date is null
or order_time is null or total_amount is null or
order_status is not null;

---- time slots which hour most orderer placed by 2 hours

select  floor(extract(hour from order_time)/2)as timesolt,
floor(extract(hour from order_time)/2)*2  as starttime,floor(extract(hour from order_time)/2)*2+2 as endtime,
count(*) as orders from orders
group by 1,2,3
order by 4 desc;


---- time slots which hour most order

SELECT 
    customer_id,
    AVG(total_amount) avgcustomer,
    COUNT(order_id) orders
FROM
    orders o
GROUP BY 1
HAVING COUNT(*) > 40;

--- highvalue customers
--- list the customers who have spent more than 1k in total on food orders in single day

select customer_name,order_item,count(*) as orders ,sum(total_amount) as totalspent from orders o
join customers c on c.customer_id=o.customer_id
group by 1,2
having sum(total_amount)>1000;


-- orders without delivery
--- write querey to find orders that were placed but not delivered 

select restaurant_name,count(o.order_id) as orders from orders o
left join restaurants r on o.restaurant_id=r.restaurant_id
left join deliveries d
on d.order_id=o.order_id
where d.delivery_id is null
group by 1;


select *from orders o 
left join restaurants r
on o.restaurant_id=r.restaurant_id
where o.order_id not in(select order_id from deliveries );

--- find the city wise orders and restaurant_name

select*from(select*,dense_rank() over(partition by city order by orders desc ) ran  from(select city,restaurant_name,count(*) as orders from orders o
join restaurants t
on t.restaurant_id=o.restaurant_id
join customers c
on c.customer_id=o.customer_id
group by 1,2
order by 3 desc)t)m
where ran=1;

----- find city wise restaurant and revenue based top 5 city

select*from(select *,rank() over(order by  revenue desc) as ran from(select city,restaurant_name,sum(total_amount) as revenue from orders o
join restaurants r
on o.restaurant_id=r.restaurant_id
join customers c
on c.customer_id=o.customer_id
group by 1,2
order by 3 desc) t)m
where ran<=5;

--- most popular dish in city

select*from(select*,dense_rank() over(partition by city order by orders desc ) as ran from(select city,order_item ,count(o.order_id) as orders from customers c
left join orders o
on o.customer_id=c.customer_id
join restaurants r
on o.restaurant_id=r.restaurant_id
group by 1,2
order by 1,3 desc)t)m
where ran=1;


--- determine each riders avg delivery time

SELECT 
    d.rider_id,
    r.rider_name,
    ROUND(AVG(TIMESTAMPDIFF(MINUTE, o.order_time, d.delivery_time)/60), 2) 
        AS avg_delivery_time_minutes
FROM deliveries d
JOIN riders r 
    ON r.rider_id = d.rider_id
JOIN orders o 
    ON o.order_id = d.order_id
WHERE d.delivery_status = 'Delivered'
GROUP BY d.rider_id, r.rider_name;


--- monthly restaurant growthratio
-- calculate each restaurants growth ratio based on the total number of delivered orders since its joining
-- cs-ls/ls*100

WITH growthratio AS (
    SELECT  
        o.restaurant_id,
        DATE_FORMAT(o.order_date, '%Y-%m') AS month,
        COUNT(*) AS currentorders,
        LAG(COUNT(*)) OVER (
            PARTITION BY o.restaurant_id
            ORDER BY DATE_FORMAT(o.order_date, '%Y-%m')
        ) AS prev_month_orders
    FROM orders o
    JOIN deliveries d 
        ON o.order_id = d.order_id
    WHERE o.order_status = 'Delivered'
    GROUP BY o.restaurant_id, DATE_FORMAT(o.order_date, '%Y-%m')
)
SELECT 
    restaurant_id,
    month,
    currentorders,
    prev_month_orders,
    ROUND(
        ((currentorders - prev_month_orders) / prev_month_orders) * 100,
        2
    ) AS pct
FROM growthratio;

-- label them as gold othervise label them as silver write an sql query to determine each segments 
-- total no of orders and total revenue

SELECT 
    flag,
    SUM(total_orders) AS orders,
    SUM(total_spending) AS revenue
FROM (
    SELECT 
        customer_id,
        SUM(total_amount) AS total_spending,
        COUNT(*) AS total_orders,
        CASE 
            WHEN SUM(total_amount) > (
                SELECT AVG(total_amount) 
                FROM orders
            ) THEN 'Gold'
            ELSE 'Silver'
        END AS flag
    FROM orders
    GROUP BY customer_id
) t
GROUP BY flag;

--- rider monthly earnings
-- calculate each riders total monthly earnings ,
-- assuming they earn 8% of the order amount

SELECT 
    d.rider_id,
    DATE_FORMAT(o.order_date, '%Y-%m') AS month,
    ROUND(SUM(o.total_amount * 0.08), 2) AS total_earnings
FROM riders r
JOIN deliveries d 
    ON d.rider_id = r.rider_id
JOIN orders o 
    ON d.order_id = o.order_id
WHERE o.order_status = 'Delivered'
GROUP BY d.rider_id, DATE_FORMAT(o.order_date, '%Y-%m')
ORDER BY d.rider_id, month;


--- rider rating analysis
-- find the no of 5 star ,4star,and 3 star ratings each rider has.
-- riders recieve this rating bsed on delivery time
-- if orders are delivered less than 15 min of orders received time the rider .get 5 star rating
-- if they deliver 15 and 20 minute they get 4 star rating
--- if they deliver after 20 minutes they get 3 star rating

SELECT 
    d.rider_id,
    o.order_date,
    o.order_time,
    d.delivery_time,
    ROUND(
        TIMESTAMPDIFF(
            MINUTE,
            CONCAT(o.order_date, ' ', o.order_time),
            CONCAT(o.order_date, ' ', d.delivery_time)
        ), 
        2
    ) AS delivery_minutes,
    CASE 
        WHEN TIMESTAMPDIFF(
            MINUTE,
            CONCAT(o.order_date, ' ', o.order_time),
            CONCAT(o.order_date, ' ', d.delivery_time)
        ) < 15 THEN '5 Star'
        
        WHEN TIMESTAMPDIFF(
            MINUTE,
            CONCAT(o.order_date, ' ', o.order_time),
            CONCAT(o.order_date, ' ', d.delivery_time)
        ) BETWEEN 15 AND 20 THEN '4 Star'
        
        ELSE '3 Star'
    END AS rating
FROM deliveries d
JOIN orders o 
    ON d.order_id = o.order_id
WHERE o.order_status = 'Delivered'
ORDER BY d.rider_id, o.order_date, o.order_time;



--- order frequency by day
-- analyze order frequnecy per day of the week and identify the peak day for each restaurant

SELECT *
FROM (
    SELECT 
        o.restaurant_id,
        r.restaurant_name,
        DAYNAME(o.order_date) AS peak_day,
        COUNT(*) AS order_count,
        DENSE_RANK() OVER (
            PARTITION BY o.restaurant_id
            ORDER BY COUNT(*) DESC
        ) AS day_rank
    FROM orders o
    JOIN restaurants r 
        ON o.restaurant_id = r.restaurant_id
    GROUP BY o.restaurant_id, r.restaurant_name, DAYNAME(o.order_date)
) t
WHERE day_rank = 1
ORDER BY order_count DESC;


--- customer lifetime value
-- calculated the total revenue generated by each customer over all their orders

select o.customer_id,customer_name,sum(total_amount) as revenue ,count(*) as orders from orders o
left  join customers c
on  o.customer_id=c.customer_id
group by 1,2
order by 3 desc;


--- monthly sales trends 
-- identify sales trends by comparing each monthds total sales to the previous month
WITH monthly_sales AS (
    SELECT 
        DATE_FORMAT(order_date, '%Y-%m-01') AS month,
        SUM(total_amount) AS total_sales
    FROM orders
    GROUP BY DATE_FORMAT(order_date, '%Y-%m-01')
),
sales_with_change AS (
    SELECT 
        month,
        total_sales,
        LAG(total_sales) OVER (ORDER BY month) AS prev_month_sales,
        LAG(month) OVER (ORDER BY month) AS prev_month_date,
        ROUND(
            CASE 
                WHEN LAG(total_sales) OVER (ORDER BY month) IS NOT NULL
                     AND LAG(total_sales) OVER (ORDER BY month) != 0
                THEN ((total_sales - LAG(total_sales) OVER (ORDER BY month)) 
                      / LAG(total_sales) OVER (ORDER BY month)) * 100
                ELSE NULL
            END, 2
        ) AS pct_change
    FROM monthly_sales
)
SELECT 
    DATE_FORMAT(month, '%b-%Y') AS month,
    total_sales,
    DATE_FORMAT(prev_month_date, '%b-%Y') AS prev_month,
    prev_month_sales,
    pct_change
FROM sales_with_change
ORDER BY month;

--- track the populartity of specific order items over time and identify seasonal demand spikes

WITH item_seasonal AS (
    SELECT 
        order_item,
        EXTRACT(YEAR FROM order_date) AS year,
		EXTRACT(month FROM order_date) as month,
        CASE 
            WHEN EXTRACT(MONTH FROM order_date) IN (12, 1, 2) THEN 'Winter'
            WHEN EXTRACT(MONTH FROM order_date) IN (3, 4, 5) THEN 'Spring'
            WHEN EXTRACT(MONTH FROM order_date) IN (6, 7, 8) THEN 'Summer'
            WHEN EXTRACT(MONTH FROM order_date) IN (9, 10, 11) THEN 'Fall'
        END AS season,
        COUNT(*) AS total_orders
    FROM orders
    GROUP BY order_item, year,month, season
)
SELECT 
    order_item,
    year,
	month,
    season,
    total_orders
FROM item_seasonal
ORDER BY order_item, year, season;

-- monthly restaurant growth ratio
-- calaculate each restuarnats growth ratio based on the total no of delivered orders since its joining

WITH monthly_orders AS (
    SELECT
        r.restaurant_id,
        r.restaurant_name,
        DATE_FORMAT(o.order_date, '%Y-%m-01') AS month,
        COUNT(*) AS orders
    FROM restaurants r
    JOIN orders o 
        ON o.restaurant_id = r.restaurant_id
    WHERE o.order_status = 'Delivered'
    GROUP BY 
        r.restaurant_id, 
        r.restaurant_name, 
        DATE_FORMAT(o.order_date, '%Y-%m-01')
),
growth_calc AS (
    SELECT
        restaurant_id,
        restaurant_name,
        month,
        orders,
        LAG(orders) OVER (
            PARTITION BY restaurant_id 
            ORDER BY month
        ) AS prev_month_orders,
        CASE 
            WHEN LAG(orders) OVER (PARTITION BY restaurant_id ORDER BY month) IS NULL THEN NULL
            WHEN LAG(orders) OVER (PARTITION BY restaurant_id ORDER BY month) = 0 THEN NULL
            ELSE ROUND(
                ((orders - LAG(orders) OVER (PARTITION BY restaurant_id ORDER BY month)) 
                 / LAG(orders) OVER (PARTITION BY restaurant_id ORDER BY month)) * 100,
                2
            )
        END AS growth_ratio_pct
    FROM monthly_orders
)
SELECT 
    restaurant_name,
    DATE_FORMAT(month, '%b-%Y') AS month,
    orders,
    prev_month_orders,
    growth_ratio_pct
FROM growth_calc
ORDER BY restaurant_name, month;


-- rank each city based on total revenue for lastyear 2023

SELECT 
    city,
    revenue,
    RANK() OVER (ORDER BY revenue DESC) AS city_rank
FROM (
    SELECT 
        r.city AS city,
        SUM(o.total_amount) AS revenue
    FROM orders o
    JOIN customers c 
        ON c.customer_id = o.customer_id
    JOIN restaurants r 
        ON r.restaurant_id = o.restaurant_id
    WHERE YEAR(o.order_date) = 2023
    GROUP BY r.city
) t
ORDER BY city_rank;


