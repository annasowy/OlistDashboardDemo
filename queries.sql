use Olist

-- monthly revenue
-- Olist did not have sales in 2016 Nov
-- creating a calender cte to show 0 sales in 2016 Nov

declare @start_date datetime, @end_date datetime
set @start_date = '2016-09-01'
set @end_date = '2018-08-01'

;WITH CTE AS (
    SELECT @start_date AS cte_start_date
    UNION ALL
    SELECT DATEADD(MONTH, 1, cte_start_date)
    FROM CTE
    WHERE DATEADD(MONTH, 1, cte_start_date) <= @end_date   
), 
order_sum as (
select 
	order_id, 
	sum(price) as total_price,
	sum(freight_value) as shipping,
	sum(price) + sum(freight_value) as total
from order_items$ 
group by order_id
),
main as (
select 
	--year(orders$.order_approved_at) as 'year',
	--month(orders$.order_approved_at) as 'month',
	DATEFROMPARTS(year(orders$.order_approved_at), month(orders$.order_approved_at), 1) as 'month',
	sum(order_sum.total_price) as revenue
from order_sum 
left join orders$ on orders$.order_id = order_sum.order_id
where 1=1
and order_status = 'delivered'
and orders$.order_approved_at is not null
group by year(orders$.order_approved_at), month(orders$.order_approved_at)
--order by 'month' desc
)

select 
	cte_start_date as MonthYear,
	coalesce(revenue, 0) as revenue
from CTE
left join main on main.month = cte.cte_start_date
order by MonthYear desc

-- avg order spending

with order_sum as (
select 
	order_id, 
	sum(price) as total_price,
	sum(freight_value) as shipping,
	sum(price) + sum(freight_value) as total
from order_items$ 
group by order_id
)

select AVG(total_price) as avg_spending
from order_sum

-- Best selling category

select 
	top 20 product_category_name_english,
	sum(price) as total_revenue
from order_items$
left join products$ on order_items$.product_id = products$.product_id
left join product_category_translation$ on products$.product_category_name = product_category_translation$.product_category_name
group by product_category_name_english
order by total_revenue desc;

-- Peak sales time

with order_sum as (
select 
	distinct order_id, 
	sum(price) as total_price,
	sum(freight_value) as shipping,
	sum(price) + sum(freight_value) as total
from order_items$ 
group by order_id
),
main as (
select 
	orders$.order_id,
	total_price,
	year(order_approved_at) as [year],
	month(order_approved_at) as [Month],
	DATEPART(ISO_WEEK, order_approved_at) as [Week],
	DATEPART(hour, order_approved_at) as [Hour],
	DATENAME(weekday, order_approved_at) as [weekday],
	case when DATEPART(hour, order_approved_at) >= 5 and DATEPART(hour, order_approved_at) < 12 then 'Morning'
		when DATEPART(hour, order_approved_at) >= 12 and DATEPART(hour, order_approved_at) < 17 then 'Afternoon'
		when DATEPART(hour, order_approved_at) >= 17 and DATEPART(hour, order_approved_at) < 21 then 'Evening'
		else 'Night' 
		end as time_period
from orders$
left join order_sum on orders$.order_id = order_sum.order_id
where order_status = 'delivered'
and year(order_approved_at) = 2018
)

select 
	top 1 concat([weekday],' ', time_period) as wd_time_period,
	--count(distinct order_id) as sales,
	--avg(total_price) as avg_order_value,
	(count(distinct order_id)/count(distinct [Week])) * avg(total_price) as est_revenue
from main
group by [weekday], time_period
order by est_revenue desc

-- revenue by customer location

with order_sum as (
select 
	order_id, 
	sum(price) as total_price,
	sum(freight_value) as shipping,
	sum(price) + sum(freight_value) as total
from order_items$ 
group by order_id
)

select 
	top 10 customer_city,
	customer_state, 
	sum(total_price) as total_revenue
from order_sum
left join orders$ on order_sum.order_id = orders$.order_id
left join customers$ on orders$.customer_id = customers$.customer_id
group by customer_state, customer_city
order by total_revenue desc


/* Analysis not included in Tableau Dashboard */

-- Largest category

select 
	top 10 product_category_name_english,
	count(distinct product_id) as listing
from products$
left join product_category_translation$ on products$.product_category_name = product_category_translation$.product_category_name
group by product_category_name_english
order by listing desc

-- Bestseller product category

select 
	top 20 order_items$.product_id,
	product_category_name_english,
	order_items$.price,
	count(order_items$.product_id) as quantity_sold
from order_items$
left join products$ on order_items$.product_id = products$.product_id
left join product_category_translation$ on products$.product_category_name = product_category_translation$.product_category_name
group by order_items$.product_id, products$.product_category_name, product_category_name_english, order_items$.price
order by quantity_sold desc

-- product sold at different price (price elasticity) In Progress

with main as (
select
	order_items$.product_id,
	product_category_name_english,
	order_items$.price,
	count(order_items$.product_id) as quantity_sold
from order_items$
left join products$ on order_items$.product_id = products$.product_id
left join product_category_translation$ on products$.product_category_name = product_category_translation$.product_category_name
group by order_items$.product_id, products$.product_category_name, product_category_name_english, order_items$.price
--order by order_items$.product_id, price desc
),
total_sale as (
select 
	product_id,
	sum(quantity_sold) as total_sales
from main
group by product_id
)

select 
	main.*,
	total_sales
from main
left join total_sale on main.product_id = total_sale.product_id
where main.product_id in (select product_id from main group by product_id having count(product_id) > 1)
order by total_sales desc, product_id, price desc

-- revenue by customer location

with order_sum as (
select 
	order_id, 
	sum(price) as total_price,
	sum(freight_value) as shipping,
	sum(price) + sum(freight_value) as total
from order_items$ 
group by order_id
)

select 
	customer_state,
	customer_city, 
	sum(total_price) as total_revenue
from order_sum
left join orders$ on order_sum.order_id = orders$.order_id
left join customers$ on orders$.customer_id = customers$.customer_id
group by customer_state, customer_city
order by total_revenue desc

-- revenue by seller location

with order_sum as (
select 
	order_id, 
	sum(price) as total_price,
	sum(freight_value) as shipping,
	sum(price) + sum(freight_value) as total
from order_items$ 
group by order_id
)

select 
	seller_state,
	seller_city, 
	sum(total_price) as total_revenue
from order_sum
left join order_items$ on order_sum.order_id = order_items$.order_id
left join sellers$ on order_items$.seller_id = sellers$.seller_id
group by seller_state, seller_city
order by total_revenue desc

-- avg_reviews

select avg(review_score) as avg_review_score from order_reviews$

-- yearly revenue

with order_sum as (
select 
	order_id, 
	sum(price) as total_price,
	sum(freight_value) as shipping,
	sum(price) + sum(freight_value) as total
from order_items$ 
group by order_id
)

select 
	year(orders$.order_approved_at) as 'year',
	sum(order_sum.total_price) as revenue
from order_sum 
left join orders$ on orders$.order_id = order_sum.order_id
where 1=1
and order_status = 'delivered'
and orders$.order_approved_at is not null
group by year(orders$.order_approved_at)
order by 'year' desc




