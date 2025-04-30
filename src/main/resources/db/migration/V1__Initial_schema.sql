-- Создание структуры БД без данных
DROP TABLE IF EXISTS orders CASCADE;
DROP TABLE IF EXISTS books CASCADE;
DROP TABLE IF EXISTS clients CASCADE;
DROP TABLE IF EXISTS authors CASCADE;
DROP TABLE IF EXISTS genres CASCADE;

CREATE TABLE genres (
    id int PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
    name varchar NOT NULL UNIQUE
);

CREATE TABLE authors (
    id int PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
    name varchar NOT NULL UNIQUE,
    dateOfBirth varchar NOT NULL,
    dateOfDeath varchar,
    description varchar
);

CREATE TABLE books (
    id int PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
    name varchar NOT NULL UNIQUE,
    genre_id int NOT NULL REFERENCES genres(id) ON DELETE CASCADE,
    author_id int NOT NULL REFERENCES authors(id) ON DELETE CASCADE,
    status varchar NOT NULL,
    year int NOT NULL check (year > 0 AND year < 2050),
    description varchar
);

CREATE TABLE clients (
    id int PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
    name varchar NOT NULL UNIQUE,
    age int NOT NULL check (age > 0 AND age < 111),
    email varchar NOT NULL UNIQUE,
    sex varchar NOT NULL,
    phoneNumber varchar UNIQUE NOT NULL,
    deliveryAddress varchar,
    description varchar,
    favoriteGenre varchar
);

CREATE TABLE orders (
    id int PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
    client_id int NOT NULL REFERENCES clients(id) ON DELETE CASCADE,
    book_id int NOT NULL UNIQUE REFERENCES books(id) ON DELETE CASCADE
);
