/* Answering Business Questions with SQL using chinook.db */
/* This document contains all the sql queries used for this analysis, you can run them individually or altogether*/

-- Tables in the database
SELECT
	name,
	type
FROM sqlite_master
WHERE type IN ("table","view");


-- invoice table
SELECT * FROM invoice

-- invoice_line table
SELECT * FROM invoice_line

-- employee table
SELECT * FROM employee

-- customer table
SELECT * FROM customer

-- album table
SELECT * FROM album

-- track table
SELECT * FROM track

-- genre table
SELECT * FROM genre 

-- media_type table
SELECT * FROM media_type


-- -----   ANALYSIS  ---------

-- How many customers patronize the media store?
SELECT
    COUNT(DISTINCT customer_id) AS number_of_customers
FROM customer


-- How many orders have been made?
SELECT
    COUNT(DISTINCT invoice_id) AS number_of_orders
FROM invoice


-- What are the top 10 most popular albums?
SELECT 
    a.album_id,
    a.title,
    SUM(quantity) AS units_sold,
    artist.name AS artist
FROM invoice_line il
    INNER JOIN track t
        ON t.track_id = il.track_id 
    INNER JOIN album a
        ON t.album_id = a.album_id
    LEFT JOIN artist
        ON a.artist_id = artist.artist_id 
GROUP BY
    t.album_id 
ORDER BY units_sold DESC
LIMIT 10;


-- Top 10 Artist Based on Track Sales
SELECT 
    artist.name AS artist,
    SUM(quantity) AS units_sold
FROM invoice_line il
    INNER JOIN track t
        ON t.track_id = il.track_id 
    INNER JOIN album a
        ON t.album_id = a.album_id
    LEFT JOIN artist
        ON a.artist_id = artist.artist_id 
GROUP BY
    artist.artist_id
ORDER BY units_sold DESC
LIMIT 10;


-- Top Genres
WITH usa_tracks_sold AS
   (
    SELECT il.* FROM invoice_line il
    INNER JOIN invoice i on il.invoice_id = i.invoice_id
    INNER JOIN customer c on i.customer_id = c.customer_id
)

SELECT
    g.name genre,
    count(uts.invoice_line_id) tracks_sold,
    cast(count(uts.invoice_line_id) AS FLOAT) / (
        SELECT COUNT(*) from usa_tracks_sold
    ) percentage_sold
FROM usa_tracks_sold uts
INNER JOIN track t on t.track_id = uts.track_id
INNER JOIN genre g on g.genre_id = t.genre_id
GROUP BY 1
ORDER BY 2 DESC
LIMIT 10;


-- Best Performing Employee
		-- 1 --
CREATE TEMPORARY TABLE support_rep_amt AS
SELECT 
    support_rep_id, 
    SUM(i.total) AS amt_spent
FROM customer c
    INNER JOIN invoice i
        ON c.customer_id = i.customer_id 
GROUP BY 
    c.customer_id;
   
   	-- 2 --
SELECT 
    e.first_name || " " || e.last_name employee,
    ROUND(SUM(su.amt_spent),1) AS total_sales
FROM support_rep_amt AS su
    LEFT JOIN employee e
        ON e.employee_id = su.support_rep_id
GROUP BY 
    e.employee_id
ORDER BY 
    total_sales DESC;
   
   
-- Number of customers, orders and lifetime value of customers from different countries
WITH country_or_other AS
    (
     SELECT
       CASE
           WHEN (
                 SELECT count(*)
                 FROM customer
                 where country = c.country
                ) = 1 THEN "Other"
           ELSE c.country
       END AS country,
       c.customer_id,
       il.*
     FROM invoice_line il
     INNER JOIN invoice i ON i.invoice_id = il.invoice_id
     INNER JOIN customer c ON c.customer_id = i.customer_id
    )

SELECT
    country,
    customers,
    total_sales,
    average_order,
    customer_lifetime_value

FROM
    (
    SELECT
        country,
        count(distinct customer_id) customers,
        ROUND(SUM(unit_price),1) total_sales,
        ROUND(SUM(unit_price) / count(distinct customer_id),1) customer_lifetime_value,
        ROUND(SUM(unit_price) / count(distinct invoice_id),1) average_order,
        CASE
            WHEN country = "Other" THEN 1
            ELSE 0
        END AS sort
    FROM country_or_other
    GROUP BY country
    ORDER BY sort ASC, total_sales DESC
    );

   
-- Album purchases vs Non Album purchases
   
WITH invoice_first_track AS
    (
     SELECT
         il.invoice_id invoice_id,
         MIN(il.track_id) first_track_id
     FROM invoice_line il
     GROUP BY 1
    )

SELECT
    album_purchase,
    COUNT(invoice_id) number_of_invoices,
    CAST(count(invoice_id) AS FLOAT) / (
                                         SELECT COUNT(*) FROM invoice
                                      ) percent
FROM
    (
    SELECT
        ifs.*,
        CASE
            WHEN
                 (
                  SELECT t.track_id FROM track t
                  WHERE t.album_id = (
                                      SELECT t2.album_id FROM track t2
                                      WHERE t2.track_id = ifs.first_track_id
                                     ) 

                  EXCEPT 

                  SELECT il2.track_id FROM invoice_line il2
                  WHERE il2.invoice_id = ifs.invoice_id
                 ) IS NULL
             AND
                 (
                  SELECT il2.track_id FROM invoice_line il2
                  WHERE il2.invoice_id = ifs.invoice_id

                  EXCEPT 

                  SELECT t.track_id FROM track t
                  WHERE t.album_id = (
                                      SELECT t2.album_id FROM track t2
                                      WHERE t2.track_id = ifs.first_track_id
                                     ) 
                 ) IS NULL
        THEN "yes"
             ELSE "no"
         END AS "album_purchase"
     FROM invoice_first_track ifs
    )
GROUP BY album_purchase;


-- Highest paying customers
SELECT 
    SUM(i.total) AS amount_spent,
    SUM(il.quantity),
    i.customer_id,
    c.first_name || " " || c.last_name customer,
    c.country
FROM invoice i
    LEFT JOIN customer c 
        ON c.customer_id = i.customer_id
    LEFT JOIN invoice_line il 
        ON i.invoice_id = il.invoice_id
GROUP BY 
    i.customer_id
ORDER BY amount_spent DESC;


-- Why did some customers spend so much more for fewer items?
-- Answer: Some 'Protected MPEG-4 video files' cost more than the other media types.---
SELECT DISTINCT 
    m.media_type_id,
    m.name AS _type, 
    unit_price 
from track
    INNER JOIN media_type AS m
        ON m.media_type_id = track.media_type_id;
    
       
-- Albums with 10 or more tracks
 	-- 1  ---
       
CREATE TEMPORARY TABLE track_counts AS
SELECT 
    a.title,
    COUNT(t.track_id) AS number_of_tracks
FROM album a
    INNER JOIN track t
        ON a.album_id = t.album_id
GROUP BY a.album_id
ORDER BY number_of_tracks;

	-- 2 ---
SELECT 
    title,
    number_of_tracks
FROM track_counts
WHERE number_of_tracks >= 10;


-- Number of Albums and Tracks released by each artist
SELECT 
    ar.name AS artist,
    COUNT(DISTINCT t.track_id) AS number_of_tracks,
    COUNT(DISTINCT a.album_id) AS number_of_albums 
FROM artist ar
    INNER JOIN album a
        ON a.artist_id = ar.artist_id 
    INNER JOIN track t 
        ON t.album_id = a.album_id
GROUP BY artist
ORDER BY 
    number_of_tracks DESC, 
    number_of_albums DESC;
    
 
-- Yearly Revenue
SELECT
    STRFTIME('%Y', invoice_date) AS yr,
    ROUND(SUM(total),1) AS revenue
FROM invoice
GROUP BY 1;