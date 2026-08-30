-- ============================================
-- Миграция V002: Нормализация схемы БД
-- Цель: объединить дублирующиеся таблицы и добавить связи
-- ============================================

-- Шаг 1: Добавляем колонку price в таблицу product
ALTER TABLE product ADD COLUMN price NUMERIC(10, 2);

-- Шаг 2: Переносим цены из таблицы product_info
UPDATE product 
SET price = pi.price 
FROM product_info pi 
WHERE product.id = pi.product_id;

-- Шаг 3: Делаем колонку price обязательной (NOT NULL)
ALTER TABLE product ALTER COLUMN price SET NOT NULL;

-- Шаг 4: Добавляем колонку date_created в таблицу orders
ALTER TABLE orders ADD COLUMN date_created DATE DEFAULT CURRENT_DATE;

-- Шаг 5: Переносим даты из таблицы orders_date
UPDATE orders 
SET date_created = od.date_created 
FROM orders_date od 
WHERE orders.id = od.order_id;

-- Шаг 6: Делаем колонку date_created обязательной (NOT NULL)
ALTER TABLE orders ALTER COLUMN date_created SET NOT NULL;

-- Шаг 7: Удаляем дублирующиеся таблицы (после переноса данных)
DROP TABLE IF EXISTS product_info;
DROP TABLE IF EXISTS orders_date;

-- Шаг 8: Добавляем внешние ключи в таблицу order_product
-- Связь с таблицей orders
ALTER TABLE order_product 
ADD CONSTRAINT fk_order_product_order 
FOREIGN KEY (order_id) REFERENCES orders(id);

-- Связь с таблицей product
ALTER TABLE order_product 
ADD CONSTRAINT fk_order_product_product 
FOREIGN KEY (product_id) REFERENCES product(id);
