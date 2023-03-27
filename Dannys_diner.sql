-- I love to see what my dataset looks like before starting the main work.
select * from dannys_diner.sales;
select * from dannys_diner.menu;
select * from dannys_diner.members;

--What is the total amount each customer spent at the restaurant?

SELECT customer_id, SUM(price) AS amount_spent
FROM dannys_diner.sales as s
INNER JOIN dannys_diner.menu as m
USING(product_id)
GROUP BY customer_id
ORDER BY amount_spent DESC;

-- How many days has each customer visited the restaurant?

SELECT customer_id, COUNT(DISTINCT order_date) AS check_in
FROM dannys_diner.sales 
GROUP BY customer_id;

-- What was the first item from the menu purchased by each customer?
WITH first_item_bought AS (
	SELECT customer_id, product_id, order_date,
	DENSE_RANK()OVER(PARTITION BY customer_id ORDER BY order_date) AS rank
	FROM dannys_diner.sales)
	
SELECT s.customer_id, s.order_date, m.product_name
FROM first_item_bought as s
INNER JOIN dannys_diner.menu AS m
USING(product_id)
WHERE rank = 1
ORDER BY customer_id;

-- What is the most purchased item on the menu and how many times was it purchased by all customers?

SELECT product_name, COUNT(s.product_id) AS times_bought
FROM dannys_diner.sales AS s
INNER JOIN dannys_diner.menu AS m
USING(product_id)
GROUP BY product_name
ORDER BY times_bought DESC
LIMIT 1;

--Which item was the most popular for each customer?

WITH fav_items AS(
	SELECT s.customer_id, m.product_name, COUNT(m.product_id) AS qty_bought,
	DENSE_RANK() OVER (PARTITION BY s.customer_id ORDER BY COUNT(m.product_id) DESC) AS rank
	FROM dannys_diner.sales AS s
	INNER JOIN dannys_diner.menu AS m
	USING (product_id)
	GROUP BY customer_id, product_name
)

SELECT customer_id, product_name, qty_bought
FROM fav_items
WHERE rank = 1;

--Which item was purchased first by the customer after they became a member?
WITH members_sales AS(
	SELECT s.customer_id, m.join_date, s.order_date,  product_id,
	DENSE_RANK()OVER(PARTITION BY customer_id ORDER BY order_date) AS rank
	FROM dannys_diner.sales AS s
	INNER JOIN dannys_diner.members as m
	USING(customer_id)
	WHERE order_date >= join_date)
	
SELECT s.customer_id, me.product_name, s.order_date
FROM dannys_diner.menu AS me 
INNER JOIN members_sales AS s
USING(product_id)
WHERE rank = 1;

-- Which item was purchased just before the customer became a member?

WITH sales_before_membership AS(
	SELECT s.customer_id, s.product_id,  me.join_date, s.order_date,
	DENSE_RANK()OVER(PARTITION BY customer_id ORDER BY order_date DESC) AS rank
	FROM dannys_diner.sales AS s
	INNER JOIN dannys_diner.members AS me
	USING(customer_id)
	WHERE order_date < join_date
)

SELECT s.customer_id, s.order_date, m.product_name
FROM sales_before_membership as s
INNER JOIN dannys_diner.menu as m
USING(product_id)
WHERE rank = 1
ORDER BY customer_id;

--What is the total items and amount spent for each member before they became a member?


SELECT s.customer_id, COUNT(s.product_id) AS quantity, SUM(m.price) AS amount_spent
FROM dannys_diner.sales AS s
INNER JOIN dannys_diner.menu as m
USING(product_id)
INNER JOIN dannys_diner.members as me
USING(customer_id)
WHERE order_date < join_date
GROUP BY s.customer_id
ORDER BY customer_id

-- If each $1 spent equates to 10 points and sushi has a 2x points multiplier - how many points would each customer have?
WITH points AS (
	SELECT s.customer_id, s.product_id, m.product_name, m.price,
	CASE WHEN m.product_name = 'sushi' THEN m.price * 20
		ELSE m.price * 10 END AS point
	FROM dannys_diner.sales AS s
	INNER JOIN dannys_diner.menu AS m
	USING(product_id)
)

SELECT customer_id, SUM(price) AS total_spent, SUM(point) AS total_point
FROM points
GROUP BY customer_id
ORDER BY customer_id, total_point;

/*In the first week after a customer joins the program (including their join date) 
they earn 2x points on all items, not just sushi - 
how many points do customer A and B have at the end of January?*/

WITH validity_check AS (
	SELECT s.customer_id, s.product_id, me.product_name, me.price, s.order_date, 
	DATE (join_date + INTERVAL '6 days') AS validity_date, m.join_date,  
	DATE('2021-01-31') AS end_of_month
	FROM dannys_diner.sales as s
	INNER JOIN dannys_diner.members AS m
	USING (customer_id)
	INNER JOIN dannys_diner.menu AS me
	USING(product_id)
)

SELECT customer_id,
SUM (CASE WHEN product_name = 'sushi' THEN 2 * 10 * price
	 WHEN order_date BETWEEN join_date AND validity_date THEN 2 * 10 * price
	 ELSE 10 * price END) AS points
FROM validity_check
WHERE order_date <= end_of_month AND order_date >= join_date
GROUP BY customer_id

	