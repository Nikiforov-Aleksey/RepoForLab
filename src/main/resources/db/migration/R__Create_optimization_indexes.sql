-- Создание индексов для оптимизации запросов
CREATE INDEX IF NOT EXISTS idx_orders_client_book ON orders(client_id, book_id);
CREATE INDEX IF NOT EXISTS idx_orders_client ON orders(client_id);
CREATE INDEX IF NOT EXISTS idx_orders_client_id_filter ON orders(client_id) WHERE client_id = 7;
