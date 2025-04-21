-- Наполнение базы демо-данными

-- Вставляем жанры (с проверкой на существование)
INSERT INTO genres (name)
SELECT 'Роман' WHERE NOT EXISTS (SELECT 1 FROM genres WHERE name = 'Роман');

INSERT INTO genres (name)
SELECT 'Антиутопия' WHERE NOT EXISTS (SELECT 1 FROM genres WHERE name = 'Антиутопия');

INSERT INTO genres (name)
SELECT 'Драма' WHERE NOT EXISTS (SELECT 1 FROM genres WHERE name = 'Драма');

INSERT INTO genres (name)
SELECT 'Сатира' WHERE NOT EXISTS (SELECT 1 FROM genres WHERE name = 'Сатира');

INSERT INTO genres (name)
SELECT 'Фэнтези' WHERE NOT EXISTS (SELECT 1 FROM genres WHERE name = 'Фэнтези');

INSERT INTO genres (name)
SELECT 'Ужасы' WHERE NOT EXISTS (SELECT 1 FROM genres WHERE name = 'Ужасы');

INSERT INTO genres (name)
SELECT 'Комедия' WHERE NOT EXISTS (SELECT 1 FROM genres WHERE name = 'Комедия');

-- Вставляем авторов (с проверкой на существование)
INSERT INTO authors(name, dateOfBirth, dateOfDeath, description)
SELECT 'Джейн Остен', '1939', '1945', 'Информация о писателе...'
WHERE NOT EXISTS (SELECT 1 FROM authors WHERE name = 'Джейн Остен');

INSERT INTO authors(name, dateOfBirth, dateOfDeath, description)
SELECT 'Джордж Оруэлл', '1939', '1945', ''
WHERE NOT EXISTS (SELECT 1 FROM authors WHERE name = 'Джордж Оруэлл');

-- ... аналогично для остальных авторов ...

-- Вставляем книги (с проверкой на существование)
INSERT INTO books (name, genre_id, author_id, year, description, status)
SELECT 
    'Гордость и предубеждение', 
    (SELECT id FROM genres WHERE name = 'Роман'), 
    (SELECT id FROM authors WHERE name = 'Джейн Остен'), 
    1813, '', 'Свободна'
WHERE NOT EXISTS (SELECT 1 FROM books WHERE name = 'Гордость и предубеждение');

INSERT INTO books (name, genre_id, author_id, year, description, status)
SELECT 
    '1984', 
    (SELECT id FROM genres WHERE name = 'Антиутопия'), 
    (SELECT id FROM authors WHERE name = 'Джордж Оруэлл'), 
    1948, '', 'Свободна'
WHERE NOT EXISTS (SELECT 1 FROM books WHERE name = '1984');

-- ... аналогично для остальных книг ...

-- Вставляем клиентов (с проверкой на существование)
INSERT INTO clients (name, age, email, sex, phoneNumber, favoriteGenre, description)
SELECT 'Березнев Никита', 20, 'bernikcooldude@yandex.ru', 'Мужчина', '89031111112', '-', '-'
WHERE NOT EXISTS (SELECT 1 FROM clients WHERE name = 'Березнев Никита');

-- ... аналогично для остальных клиентов ...

-- Вставляем заказы (с проверкой на существование)
INSERT INTO orders (client_id, book_id)
SELECT 
    (SELECT id FROM clients WHERE name = 'Хью Джекман'),
    (SELECT id FROM books WHERE name = 'Маленькие женщины')
WHERE NOT EXISTS (
    SELECT 1 FROM orders 
    WHERE client_id = (SELECT id FROM clients WHERE name = 'Хью Джекман')
    AND book_id = (SELECT id FROM books WHERE name = 'Маленькие женщины')
);

INSERT INTO orders (client_id, book_id)
SELECT 
    (SELECT id FROM clients WHERE name = 'Хью Джекман'),
    (SELECT id FROM books WHERE name = 'Хроники Нарнии')
WHERE NOT EXISTS (
    SELECT 1 FROM orders 
    WHERE client_id = (SELECT id FROM clients WHERE name = 'Хью Джекман')
    AND book_id = (SELECT id FROM books WHERE name = 'Хроники Нарнии')
);
