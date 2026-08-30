# dbops-project

# Проектная работа дисциплины DBOps

```
Пользователь для миграций migrator
DB_HOST: 51.250.83.56
```

## Создание БД store

### Шаг 2. Создайте ещё одну БД в PostgreSQL, допустим, это будет база store. 

```sql
CREATE DATABASE store;
```

### Шаг 3. Создайте нового пользователя PostgreSQL и выдайте ему права на все таблицы в базе store. Под этим логином будут ходить автотесты и выполняться миграции, поэтому важно выдать достаточные для этой работы права. Укажите выполненные для этого запросы в файле репозитория Readme.md

```sql
CREATE USER migrator WITH PASSWORD 'migrator_password';

GRANT CONNECT ON DATABASE store TO migrator;
GRANT ALL PRIVILEGES ON DATABASE store TO migrator;

\c store;

-- Даем права на схему public
GRANT ALL PRIVILEGES ON SCHEMA public TO migrator;

-- Устанавливаем права по умолчанию для будущих объектов
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL PRIVILEGES ON TABLES TO migrator;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL PRIVILEGES ON SEQUENCES TO migrator;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL PRIVILEGES ON FUNCTIONS TO migrator;
```

Проверка, что подключение успешно

```
psql "host=localhost port=5432 dbname=store user=migrator"
```

Удалённо также проверил через DBeaver



## Аналитический запрос: количество проданных сосисок за предыдущую неделю

### Запрос
Для получения количества сосисок, проданных за каждый день предыдущей недели (статус заказа - 'shipped'), используется следующий SQL-запрос:

```sql
SELECT 
    o.date_created, 
    SUM(op.quantity) AS total_sausages_sold
FROM orders AS o
JOIN order_product AS op ON o.id = op.order_id
WHERE o.status = 'shipped' 
    AND o.date_created > NOW() - INTERVAL '7 DAY'
GROUP BY o.date_created
ORDER BY o.date_created DESC;
```

Его план выполнения не самый оптимальный. Присутствуют Parallel Seq Scan (по сути полное чтение таблицы), всё это собирается в несколько потоков воркерами. Стоимость 266к, 32.40 сек

```
|QUERY PLAN                                                                                                                                                          |
|--------------------------------------------------------------------------------------------------------------------------------------------------------------------|
|Finalize GroupAggregate  (cost=266222.50..266245.56 rows=91 width=12) (actual time=28180.021..28186.934 rows=7 loops=1)                                             |
|  Group Key: o.date_created                                                                                                                                         |
|  ->  Gather Merge  (cost=266222.50..266243.74 rows=182 width=12) (actual time=28179.988..28186.899 rows=21 loops=1)                                                |
|        Workers Planned: 2                                                                                                                                          |
|        Workers Launched: 2                                                                                                                                         |
|        ->  Sort  (cost=265222.48..265222.71 rows=91 width=12) (actual time=28159.452..28159.456 rows=7 loops=3)                                                    |
|              Sort Key: o.date_created DESC                                                                                                                         |
|              Sort Method: quicksort  Memory: 25kB                                                                                                                  |
|              Worker 0:  Sort Method: quicksort  Memory: 25kB                                                                                                       |
|              Worker 1:  Sort Method: quicksort  Memory: 25kB                                                                                                       |
|              ->  Partial HashAggregate  (cost=265218.61..265219.52 rows=91 width=12) (actual time=28159.418..28159.423 rows=7 loops=3)                             |
|                    Group Key: o.date_created                                                                                                                       |
|                    Batches: 1  Memory Usage: 24kB                                                                                                                  |
|                    Worker 0:  Batches: 1  Memory Usage: 24kB                                                                                                       |
|                    Worker 1:  Batches: 1  Memory Usage: 24kB                                                                                                       |
|                    ->  Parallel Hash Join  (cost=148378.97..264678.74 rows=107974 width=8) (actual time=17812.376..28140.511 rows=84457 loops=3)                   |
|                          Hash Cond: (op.order_id = o.id)                                                                                                           |
|                          ->  Parallel Seq Scan on order_product op  (cost=0.00..105362.15 rows=4166715 width=12) (actual time=0.043..9344.215 rows=3333333 loops=3)|
|                          ->  Parallel Hash  (cost=147029.29..147029.29 rows=107974 width=12) (actual time=17811.277..17811.278 rows=84457 loops=3)                 |
|                                Buckets: 262144  Batches: 1  Memory Usage: 13984kB                                                                                  |
|                                ->  Parallel Seq Scan on orders o  (cost=0.00..147029.29 rows=107974 width=12) (actual time=24.623..17767.043 rows=84457 loops=3)   |
|                                      Filter: (((status)::text = 'shipped'::text) AND (date_created > (now() - '7 days'::interval)))                                |
|                                      Rows Removed by Filter: 3248877                                                                                               |
|Planning Time: 0.214 ms                                                                                                                                             |
|JIT:                                                                                                                                                                |
|  Functions: 54                                                                                                                                                     |
|  Options: Inlining false, Optimization false, Expressions true, Deforming true                                                                                     |
|  Timing: Generation 2.118 ms, Inlining 0.000 ms, Optimization 1.385 ms, Emission 28.897 ms, Total 32.400 ms                                                        |
|Execution Time: 28187.788 ms                                                                                                                                        |

```


## Оптимизация запроса с помощью индексов

### 1. Запрос для оптимизации

```sql
SELECT 
    o.date_created, 
    SUM(op.quantity) AS total_sausages_sold
FROM orders AS o
JOIN order_product AS op ON o.id = op.order_id
WHERE o.status = 'shipped' 
    AND o.date_created > NOW() - INTERVAL '7 DAY'
GROUP BY o.date_created
ORDER BY o.date_created DESC;
```

```
|QUERY PLAN                                                                                                                                                                      |
|--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
|Finalize GroupAggregate  (cost=188599.62..188622.68 rows=91 width=12) (actual time=1901.897..1910.661 rows=7 loops=1)                                                           |
|  Group Key: o.date_created                                                                                                                                                     |
|  ->  Gather Merge  (cost=188599.62..188620.86 rows=182 width=12) (actual time=1901.861..1910.622 rows=21 loops=1)                                                              |
|        Workers Planned: 2                                                                                                                                                      |
|        Workers Launched: 2                                                                                                                                                     |
|        ->  Sort  (cost=187599.60..187599.83 rows=91 width=12) (actual time=1826.551..1826.556 rows=7 loops=3)                                                                  |
|              Sort Key: o.date_created DESC                                                                                                                                     |
|              Sort Method: quicksort  Memory: 25kB                                                                                                                              |
|              Worker 0:  Sort Method: quicksort  Memory: 25kB                                                                                                                   |
|              Worker 1:  Sort Method: quicksort  Memory: 25kB                                                                                                                   |
|              ->  Partial HashAggregate  (cost=187595.73..187596.64 rows=91 width=12) (actual time=1826.525..1826.530 rows=7 loops=3)                                           |
|                    Group Key: o.date_created                                                                                                                                   |
|                    Batches: 1  Memory Usage: 24kB                                                                                                                              |
|                    Worker 0:  Batches: 1  Memory Usage: 24kB                                                                                                                   |
|                    Worker 1:  Batches: 1  Memory Usage: 24kB                                                                                                                   |
|                    ->  Parallel Hash Join  (cost=70756.69..187055.86 rows=107973 width=8) (actual time=294.335..1802.945 rows=84457 loops=3)                                   |
|                          Hash Cond: (op.order_id = o.id)                                                                                                                       |
|                          ->  Parallel Seq Scan on order_product op  (cost=0.00..105361.67 rows=4166667 width=12) (actual time=0.027..442.978 rows=3333333 loops=3)             |
|                          ->  Parallel Hash  (cost=69407.03..69407.03 rows=107973 width=12) (actual time=292.350..292.351 rows=84457 loops=3)                                   |
|                                Buckets: 262144  Batches: 1  Memory Usage: 13984kB                                                                                              |
|                                ->  Parallel Bitmap Heap Scan on orders o  (cost=3552.57..69407.03 rows=107973 width=12) (actual time=32.480..261.923 rows=84457 loops=3)       |
|                                      Recheck Cond: (((status)::text = 'shipped'::text) AND (date_created > (now() - '7 days'::interval)))                                      |
|                                      Heap Blocks: exact=25829                                                                                                                  |
|                                      ->  Bitmap Index Scan on idx_orders_status_date  (cost=0.00..3487.79 rows=259135 width=0) (actual time=52.835..52.836 rows=253370 loops=1)|
|                                            Index Cond: (((status)::text = 'shipped'::text) AND (date_created > (now() - '7 days'::interval)))                                  |
|Planning Time: 57.438 ms                                                                                                                                                        |
|JIT:                                                                                                                                                                            |
|  Functions: 57                                                                                                                                                                 |
|  Options: Inlining false, Optimization false, Expressions true, Deforming true                                                                                                 |
|  Timing: Generation 4.088 ms, Inlining 0.000 ms, Optimization 1.415 ms, Emission 35.631 ms, Total 41.134 ms                                                                    |
|Execution Time: 1911.605 ms                                                                                                                                                     |

```

После построения индекса запрос стал выполняться значительно быстрее, т.к. были построены индексы на внешних ключах, а также предикатах, участвующих в запросе.
Впрочем, результат мог быть ещё лучше, если бы в столбце status было больше уникальных значений. Там всего три значения, распределённых примерно равномерно, а индексы
эффективны, когда идет запрос к не более, чем 2% строк.


