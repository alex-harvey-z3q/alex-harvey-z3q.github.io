---
layout: post
title: "The four SQL joins using Linux join and sort"
date: 2018-09-22
author: Alex Harvey
tags: join sort csv data-science
---

Imagine two database tables stored as CSV files with a field in common. How do you "join" them?

While it is easy to do this using the Linux join and sort commands, very little documentation - including the join man page - attempts to relate join to the four types of SQL join that people are likely to be familiar with. This post intends to fill this gap.

- ToC
{:toc}

## Simple example

The Linux join command performs an equality join on two files that have a field in common and writes the result to the standard output. Imagine the following two tables that are related by the id field*:

### customers table

|id|first_name|last_name|email|address|state|zipcode|
|--|----------|---------|-----|-------|-----|-------|
|1|George|Washington|gwashington@usa.gov|3200 Mt Vernon Hwy Mount Vernon|VA|22121|
|2|John|Adams|jadams@usa.gov|1250 Hancock St Quincy|MA|02169|
|3|Thomas|Jefferson|tjefferson@usa.gov|931 Thomas Jefferson Pkwy Charlottesville|VA|22902|
|4|James|Madison|jmadison@usa.gov|11350 Constitution Hwy Orange|VA|22960|
|5|James|Monroe|jmonroe@usa.gov|2050 James Monroe Parkway Charlottesville|VA|22902|

### phone table

|id|phone_number|
|--|------------|
|1|130248|
|2|114254|
|3|234542|
|4|522345|

\* These example tables are based on examples found at [www.sql-join.com](http://www.sql-join.com).

### Simple join

How do we join them? In SQL, of course, we could write the following SELECT statement:

~~~ sql
SELECT * FROM customers JOIN phone ON customers.id = phone.id;
~~~

What is less well-known, though, is that in Linux, it is possible to join these tables in the same way using join:

~~~ text
▶ join -t, -1 1 -2 1 -o 1.1,1.2,1.3,1.4,1.5,1.6,2.2 customers.csv phone.csv
id,first_name,last_name,address,state,zipcode,phone_number
1,George,Washington,3200 Mt Vernon Hwy Mount Vernon,VA,11238,130248
2,John,Adams,1250 Hancock St Quincy,MA,02169,114254
3,Thomas,Jefferson,931 Thomas Jefferson Pkwy Charlottesville,VA,22902,234542
4,James,Madison,11350 Constitution Hwy Orange,VA,22960,522345
~~~

This doesn't immediately look like an SQL statement, but it actually almost is. The following table explains:

|option|explanation|
|------|-----------|
|-o 1.1,1.2,1.3,1.4,1.5,1.6,2.2|a bit like an SQL SELECT clause. It says "select the first file's first field, then the first file's second field", and so on|
|-1 1 -2 1|like the JOIN ON (or WHERE) clause. -1 identifies the left table and -2 the right table. Thus -1 1 -2 1 says join on the first field from both tables|
|customers.csv phone.csv|like the FROM clause. It lists the tables to select from|
|-t,|just specifies the field separator|

## More complex example

Now imagine an additional table detailing customer orders:

### orders table

|order_id|order_date|amount|id|
|--------|----------|------|--|
|1|07/04/1776|$234.56|1|
|2|03/14/1760|$78.50|3|
|3|05/23/1784|$124.00|2|
|4|09/03/1790|$65.50|3|
|5|07/21/1795|$25.50|10|
|6|11/27/1787|$14.40|9|

## Inner join

### What is an inner join

An SQL JOIN clause is used to combine rows from two or more tables, based on a related column between them. An INNER JOIN returns only records that have matching values in both tables:

![Inner join]({{ "/assets/img_innerjoin.png" | absolute_url }})

### SQL example

Suppose we want the customers who placed an order and the details of the order they placed. This is an inner join:

~~~ sql
SELECT first_name, last_name, order_date, order_amount
FROM customers
INNER JOIN orders
ON customers.id = orders.id;
~~~

This returns:

|first_name|last_name|order_date|order_amount|
|----------|---------|----------|------------|
|George|Washington|07/4/1776|$234.56|
|John|Adams|05/23/1784|$124.00|
|Thomas|Jefferson|03/14/1760|$78.50|
|Thomas|Jefferson|09/03/1790|$65.50|

### Using Linux sort

We can also join the tables using Linux join, but only if the CSV tables are sorted. We can use the Linux sort command for this:

~~~ text
▶ sort -n -k4 -t, orders.csv
order_id,order_date,amount,id
1,07/04/1776,$234.56,1
3,05/23/1784,$124.00,2
2,03/14/1760,$78.50,3
4,09/03/1790,$65.50,3
6,11/27/1787,$14.40,9
5,07/21/1795,$25.50,10
~~~

These options to sort are:

|option|explanation|
|------|-----------|
|`-n`|sort numerically|
|`-k4`|sort on the 4th field|
|`-t,`|use comma as the field separator|

### Using Linux join

To perform an inner join on the sorted CSV tables in one line, we can write:

~~~ text
▶ join -t, -1 1 -2 4 -o 1.2,1.3,2.2,2.3 customers.csv <(sort -n -k4 -t, orders.csv)
first_name,last_name,order_date,amount
George,Washington,07/04/1776,$234.56
John,Adams,05/23/1784,$124.00
Thomas,Jefferson,03/14/1760,$78.50
Thomas,Jefferson,09/03/1790,$65.50
~~~

To avoid repeating this in subsequent examples let's save the sorted CSV file:

~~~ text
▶ sort -n -k4 -t, orders.csv > x ; mv x orders.csv
~~~

## Left outer join

### What is a left outer join

A LEFT JOIN a.k.a. LEFT OUTER JOIN returns all records from the left table and the matched records from the right table. The result is NULL from the right side if there is no match.

![Left join]({{ "/assets/img_leftjoin.png" | absolute_url }})

### SQL example

Extending our example of the inner join to a left join from above, we get:

~~~ sql
SELECT first_name, last_name, order_date, order_amount
FROM customers
LEFT OUTER JOIN orders
ON customers.id = orders.id
~~~

This returns:

|first_name|last_name|order_date|order_amount|
|----------|---------|----------|------------|
|George|Washington|07/4/1776|$234.56|
|John|Adams|05/23/1784|$124.00|
|Thomas|Jefferson|03/14/1760|$78.50|
|Thomas|Jefferson|09/03/1790|$65.50|
|James|Madison|NULL|NULL|
|James|Monroe|NULL|NULL|

### Using Linux join

The Linux join commands provides two extra options to add if we want outer joins:

|option|explanation|
|------|-----------|
|`-a file_number`|In addition to the default output, produce a line for each unpairable line in file file_number|
|`-e string`|Replace empty output fields with string|

So, we can perform a left outer join using:

~~~ text
▶ join -a 1 -e NULL -t, -1 1 -2 4 -o 1.2,1.3,2.2,2.3 customers.csv orders.csv
first_name,last_name,order_date,amount
George,Washington,07/04/1776,$234.56
John,Adams,05/23/1784,$124.00
Thomas,Jefferson,03/14/1760,$78.50
Thomas,Jefferson,09/03/1790,$65.50
James,Madison,NULL,NULL
James,Monroe,NULL,NULL
~~~

## Right outer join

### What is a right outer join

A RIGHT JOIN a.k.a. RIGHT OUTER JOIN returns all records from the right table and the matched records from the left table. The result is NULL from the left side when there is no match.

![Right join]({{ "/assets/img_rightjoin.png" | absolute_url }})

### SQL example

Changing our left join to a right join from above:

~~~ sql
SELECT first_name, last_name, order_date, order_amount
FROM customers
RIGHT OUTER JOIN orders
ON customers.id = orders.id
~~~

### Using Linux join

Using the Linux command, we just need to change `-a 1` to `-a 2` if we want a right join:

~~~ text
▶ join -a 2 -e NULL -t, -1 1 -2 4 -o 1.2,1.3,2.2,2.3 customers.csv orders.csv
first_name,last_name,order_date,amount
George,Washington,07/04/1776,$234.56
John,Adams,05/23/1784,$124.00
Thomas,Jefferson,03/14/1760,$78.50
Thomas,Jefferson,09/03/1790,$65.50
NULL,NULL,11/27/1787,$14.40
NULL,NULL,07/21/1795,$25.50
~~~

## Full outer join

### What is a full outer join

A FULL OUTER JOIN returns all records when there is a match in either left or right table records. It can potentially return very large result-sets and not all databases support it.

![Full join]({{ "/assets/img_fulljoin.png" | absolute_url }})

### SQL example

Now changing our right join from above to a full outer join:

~~~ sql
SELECT first_name, last_name, order_date, order_amount
FROM customers
FULL JOIN orders
ON customers.id = orders.id
~~~

This would return:

|first_name|last_name|order_date|order_amount|
|----------|---------|----------|------------|
|George|Washington|07/4/1776|$234.56|
|John|Adams|05/23/1784|$124.00|
|Thomas|Jefferson|03/14/1760|$78.50|
|Thomas|Jefferson|09/03/1790|$65.50|
|James|Madison|NULL|NULL|
|James|Monroe|NULL|NULL|
|NULL|NULL|11/27/1787|$14.40|
|NULL|NULL|07/21/1795|$25.50|

### Using Linux join

Using the Linux command, we just need to add both `-a 1` and `-a 2` if we want a full join:

~~~ text
▶ join -a 1 -a 2 -e NULL -t, -1 1 -2 4 -o 1.2,1.3,2.2,2.3 customers.csv orders.csv
first_name,last_name,order_date,amount
George,Washington,07/04/1776,$234.56
John,Adams,05/23/1784,$124.00
Thomas,Jefferson,03/14/1760,$78.50
Thomas,Jefferson,09/03/1790,$65.50
James,Madison,NULL,NULL
NULL,NULL,11/27/1787,$14.40
NULL,NULL,07/21/1795,$25.50
~~~

## Conclusion

In this post, I have looked at the four SQL joins, being the INNER JOIN, LEFT (OUTER) JOIN, RIGHT (OUTER) JOIN and FULL JOIN, on CSV tables related by a common field esing only the Linux join and sort commands. I hope some others find it useful!

## Further reading

See also:

- [Linux and Unix join command tutorial with examples](http://shapeshed.com/unix-join/)
- [Join man page](http://linux.die.net/man/1/join)
- [SQL Joins Explained](http://www.sql-join.com/sql-join-types/).
