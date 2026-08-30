-- ============================================
-- Миграция V003: Заполнение данными нормализованной схемы
-- ============================================

-- ============================================
-- 1. Очищаем таблицы (на случай повторного запуска)
-- ============================================
TRUNCATE TABLE order_product CASCADE;
TRUNCATE TABLE orders CASCADE;
TRUNCATE TABLE product CASCADE;

-- ============================================
-- 2. Заполняем таблицу product (товары)
-- ============================================
INSERT INTO product (id, name, picture_url, price) VALUES 
    (1, 'Сливочная', 'https://res.cloudinary.com/sugrobov/image/upload/v1623323635/repos/sausages/6.jpg', 320.00),
    (2, 'Особая', 'https://res.cloudinary.com/sugrobov/image/upload/v1623323635/repos/sausages/5.jpg', 179.00),
    (3, 'Молочная', 'https://res.cloudinary.com/sugrobov/image/upload/v1623323635/repos/sausages/4.jpg', 225.00),
    (4, 'Нюренбергская', 'https://res.cloudinary.com/sugrobov/image/upload/v1623323635/repos/sausages/3.jpg', 315.00),
    (5, 'Мюнхенская', 'https://res.cloudinary.com/sugrobov/image/upload/v1623323635/repos/sausages/2.jpg', 330.00),
    (6, 'Русская', 'https://res.cloudinary.com/sugrobov/image/upload/v1623323635/repos/sausages/1.jpg', 189.00);

-- ============================================
-- 3. Заполняем таблицу orders (заказы)
-- ============================================
-- Генерируем 10 миллионов заказов со случайными статусами и датами
INSERT INTO orders (id, status, date_created)
SELECT 
    i,
    (array['pending', 'shipped', 'cancelled'])[floor(random() * 3 + 1)],
    DATE(NOW() - (random() * (NOW()+'90 days' - NOW())))
FROM generate_series(1, 10000000) s(i);

-- ============================================
-- 4. Заполняем таблицу order_product (связи заказов и товаров)
-- ============================================
-- Генерируем 10 миллионов записей со случайными количествами и товарами
INSERT INTO order_product (quantity, order_id, product_id)
SELECT 
    floor(1 + random() * 50)::int,
    i,
    1 + floor(random() * 6)::int % 6
FROM generate_series(1, 10000000) s(i);

