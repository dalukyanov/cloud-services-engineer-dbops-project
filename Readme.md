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
