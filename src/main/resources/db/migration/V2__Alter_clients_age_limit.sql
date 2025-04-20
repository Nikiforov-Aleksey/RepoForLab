-- Изменение максимального возраста клиентов до 150
ALTER TABLE clients 
DROP CONSTRAINT IF EXISTS clients_age_check;

ALTER TABLE clients 
ADD CONSTRAINT clients_age_check CHECK (age > 0 AND age < 151);
