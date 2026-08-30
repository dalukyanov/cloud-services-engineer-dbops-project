-- ============================================
-- Миграция V004: Создание индексов для оптимизации запросов
-- ============================================

-- Индекс для внешнего ключа order_id в таблице order_product
-- Ускоряет JOIN между orders и order_product
CREATE INDEX IF NOT EXISTS idx_order_product_order_id ON order_product(order_id);

-- Композитный индекс для таблицы orders
-- Ускоряет фильтрацию по статусу и дате (WHERE status='shipped' AND date_created > NOW() - INTERVAL '7 DAY')
CREATE INDEX IF NOT EXISTS idx_orders_status_date ON orders(status, date_created);

-- Дополнительный индекс для поиска по дате создания (если потребуется)
-- CREATE INDEX IF NOT EXISTS idx_orders_date_created ON orders(date_created);

-- Индекс для поиска по продуктам в order_product
CREATE INDEX IF NOT EXISTS idx_order_product_product_id ON order_product(product_id);
