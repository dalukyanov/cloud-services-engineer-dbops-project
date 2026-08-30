# dbops-project
Исходный репозиторий для выполнения проекта дисциплины "DBOps"

Пользователь для миграций migrator
DB_HOST: 51.250.83.56

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
