CREATE DATABASE IF NOT EXISTS music_shop DEFAULT CHARACTER SET utf8;
USE music_shop;

-- -----------------------------------------------------
-- Tabela music_shop.user_permissions
-- -----------------------------------------------------

CREATE TABLE IF NOT EXISTS [music_shop].[user_permissions] (
  [ID] [int] PRIMARY KEY IDENTITY(1,1),
  [RoleName] [nvarchar] (128) NOT NULL);

-- -----------------------------------------------------
-- Tabela music_shop.users
-- -----------------------------------------------------

CREATE TABLE IF NOT EXISTS music_shop.users (
  [ID] [int] PRIMARY KEY IDENTITY(1,1),
  [Login] [nvarchar] (60) NOT NULL,
  [PasswordHash] [varchar] (60) NULL,
  [UserPermissions] [tinyint] NOT NULL FOREIGN KEY REFERENCES user_permissions(ID));

-- -----------------------------------------------------
-- Tabela music_shop.users_personal_data
-- -----------------------------------------------------

CREATE TABLE IF NOT EXISTS music_shop.users_personal_data (
  [ID] [int] PRIMARY KEY IDENTITY(1,1),
  [UserId] [int] NOT NULL UNIQUE FOREIGN KEY REFERENCES users(ID),
  [Name] [nvarchar] (128) NOT NULL,
  [Surname] [nvarchar] (128) NOT NULL,
  [EmailAddress] [varchar] (254) NOT NULL,
  [City] [nvarchar] (128) NOT NULL,
  [HomeAddress] [nvarchar] (256) NOT NULL,
  [BuildingNumber] [int] NOT NULL,
  [ApartmentNumber] [smallint] NULL,
  [ZipCode] [varchar] (6) NOT NULL);

-- -----------------------------------------------------
-- Tabela music_shop.product_categories
-- -----------------------------------------------------

CREATE TABLE IF NOT EXISTS music_shop.product_categories (
  [ID] [int] PRIMARY KEY IDENTITY(1,1),
  [CategoryName] [nvarchar] (256) NOT NULL,
  [CategoryDescription] [nvarchar] (256) NULL);

-- -----------------------------------------------------
-- Tabela music_shop.products
-- -----------------------------------------------------

CREATE TABLE IF NOT EXISTS music_shop.products (
  [ID] [int] PRIMARY KEY IDENTITY(1,1),
  [ProductName] NVARCHAR(256) NOT NULL,
  [ProductViewDescription] [ntext] NULL,
  [ProductCategory] [int] NOT NULL FOREIGN KEY REFERENCES product_categories(ID),
  [ProductPrice] [money] [int] NULL,
  [ProductAvailableQuantity] [int] NOT NULL);

-- -----------------------------------------------------
-- Tabela music_shop.order_delivery_methods
-- -----------------------------------------------------

CREATE TABLE IF NOT EXISTS music_shop.order_delivery_methods (
  [ID] [int] PRIMARY KEY IDENTITY(1,1),
  [DeliveryMethod] [nvarchar] (256) NOT NULL,
  [DeliveryMethodDescription] [ntext] NULL);

-- -----------------------------------------------------
-- Tabela music_shop.order_payment_methods
-- -----------------------------------------------------

CREATE TABLE IF NOT EXISTS music_shop.order_payment_methods (
  [ID] [int] PRIMARY KEY IDENTITY(1,1),
  [PaymentMethod] [nvarchar] (256) NOT NULL);

-- -----------------------------------------------------
-- Tabela music_shop.orders
-- -----------------------------------------------------

CREATE TABLE IF NOT EXISTS music_shop.orders (
  [ID] [int] PRIMARY KEY IDENTITY(1,1),
  [OrderedProduct] [int] NOT NULL FOREIGN KEY REFERENCES products(ID),
  [Quantity] [int] NOT NULL,
  [OrderingUser] [int] NOT NULL FOREIGN KEY REFERENCES users(ID),
  [OrderDateTime] [datetime] NOT NULL,
  [DeliveryMethod] [int] NOT NULL FOREIGN KEY REFERENCES order_delivery_methods(ID),
  [Completed] [tinyint] NOT NULL);

-- -----------------------------------------------------
-- Tabela music_shop.order_payments
-- -----------------------------------------------------

CREATE TABLE IF NOT EXISTS music_shop.order_payments (
  [ID] [int] PRIMARY KEY IDENTITY(1,1),
  [OrderId] [int] NOT NULL FOREIGN KEY REFERENCES orders(ID),
  [PaymentValue] [int] NOT NULL,
  [IsMade] [tinyint] NOT NULL);

  -- -----------------------------------------------------
-- Widok music_shop.show_products_out_of_stock
-- -----------------------------------------------------

CREATE VIEW [music_shop].[show_products_out_of_stock] AS
    SELECT 
        *
    FROM
        orders
    WHERE
        orders.Quantity = 0;

-- -----------------------------------------------------
-- Widok music_shop.show_uncompleted_orders
-- -----------------------------------------------------

CREATE VIEW [music_shop].[show_uncompleted_orders] AS
    SELECT 
        *
    FROM
        orders
    WHERE
        orders.Completed = 0;

-- -----------------------------------------------------
-- Widok music_shop.show_uncompleted_orders
-- -----------------------------------------------------

CREATE VIEW [music_shop].[show_complete_customers_data] AS
    SELECT 
        users.Login,
        users_personal_data.Name + ' ' + users_personal_data.Surname AS Identity,
        users_personal_data.EmailAddress,
        users_personal_data.HomeAddress + ' ' + users_personal_data.BuildingNumber + ' ' + users_personal_data.ApartmentNumber
    FROM
        users
            LEFT JOIN
        users_personal_data ON users_personal_data.UserId = users.ID
    WHERE
        users.UserPermissions = 0
    GROUP BY users.ID;

    -- -----------------------------------------------------
-- Funkcja music_shop.get_total_price_of_order
-- -----------------------------------------------------

CREATE FUNCTION [music.shop].[get_total_price_of_order] (@orderId int)
RETURNS money
AS
BEGIN
    DECLARE @output money;
    SELECT @output = orders.Quantity * products.Price
    FROM orders
    RIGHT JOIN products ON products.ID = orders.OrderedProduct
    WHERE ID = @orderId
    RETURN @output;
END;

-- -----------------------------------------------------
-- Funkcja music_shop.get_products_in_category
-- -----------------------------------------------------

CREATE FUNCTION [music_shop].[get_products_in_category] (@categoryId int)
RETURNS @output TABLE
(
    ID int PRIMARY KEY,
    ProductName nvarchar(256) NOT NULL,
    ProductViewDescription ntext NULL,
    ProductPrice money NOT NULL,
    ProductAvailableQuantity int NOT NULL
)
AS
BEGIN
WITH products_CTE(ID, ProductName, ProductViewDescription, ProductPrice, ProductAvailableQuantity)
    AS (
        SELECT products.ID, products.ProductName, products.ProductViewDescription, products.ProductPrice, products.ProductAvailableQuantity
        FROM products
        WHERE ProductCategory = @categoryId
    )
    INSERT @output
    SELECT ID, ProductName, ProductViewDescription, ProductPrice, ProductAvailableQuantity
    FROM products_CTE
    RETURN
END;

-- -----------------------------------------------------
-- Funkcja music_shop.get_user_orders
-- -----------------------------------------------------

CREATE FUNCTION [music_shop].[get_user_orders] (@userId int)
RETURNS @output TABLE
(
    ID int PRIMARY KEY,
    OrderedProduct int NOT NULL,
    Quantity int NOT NULL,
    DeliveryMethod int NOT NULL,
    Completed tinyint NOT NULL
)
WITH orders_CTE(ID, OrderedProduct, Quantity, DeliveryMethod, Completed)
    AS (
        SELECT orders.ID, orders.OrderedProduct, orders.Quantity, orders.DeliveryMethod, orders.Completed
        FROM orders
        WHERE OrderingUser = @userId
    )
    INSERT @output
    SELECT ID, OrderedProduct, Quantity, DeliveryMethod, Completed
    FROM orders_CTE
    RETURN
END;

-- -----------------------------------------------------
-- Funkcja music_shop.get_completed_field_friendly_name
-- -----------------------------------------------------

CREATE FUNCTION [music_shop].[get_completed_field_friendly_name] (@status tinyint)
RETURNS @output NVARCHAR(12)
AS
BEGIN
    IF (@status = 0)
        SET @output = "w realizacji"
    ELSE
        SET @output = "ukończone"
    RETURN(@output)
END;

-- -----------------------------------------------------
-- Procedura music_shop.make_user_an_administrator
-- -----------------------------------------------------

CREATE PROCEDURE [music_shop].[make_user_an_administrator] (@userId int)
AS
    UPDATE music_shop.users
    SET UserPermissions = 1
    WHERE ID = @userID;
GO

-- -----------------------------------------------------
-- Procedura music_shop.make_order_completed
-- -----------------------------------------------------

CREATE PROCEDURE [music_shop].[make_order_completed] (@orderId int)
AS
    UPDATE music_shop.order_payments
    SET IsMade = 1
    WHERE OrderId = @orderId;

    UPDATE music_shop.orders
    SET Completed = 1
    WHERE ID = @orderId;
GO

-- -----------------------------------------------------
-- Procedura music_shop.remove_user_data
-- -----------------------------------------------------

CREATE PROCEDURE [music.shop].[remove_user_data] (@userId int)
AS
    DELETE FROM music_shop.users_personal_data
    WHERE UserId = @userId;

    UPDATE music_shop.users
    SET PasswordHash = NULL
    WHERE ID = @userId;
GO

-- -----------------------------------------------------
-- Przykładowe dane dla tabeli music_shop.user_permissions
-- -----------------------------------------------------

INSERT INTO music_shop.user_permissions (RoleName)
VALUES
("Klient"),
("Administrator");

-- -----------------------------------------------------
-- Przykładowe dane dla tabeli music_shop.users
-- -----------------------------------------------------

INSERT INTO music_shop.users (Login, PasswordHash, UserPermissions)
VALUES
("kowalskee", "$2y$12$sBIZ.0uqxz7p6V1WWaFO6Ot9bfHHzDErDTN6GZVYDtNxzluXwtPvK", 1),
("kuba207", "$2y$12$WYsFllTqgd5P.OSRm6U.D.lBfpOwzaQ/a/WNgA0iHpWXEQHQINW3C", 0),
("j.nowak", "$2y$12$PU4.Aoj7efvz.uwg4McaYuB3xV1KeD6.F/D/cPkdnHC754dcu49IS", 0);

-- -----------------------------------------------------
-- Przykładowe dane dla tabeli music_shop.users_personal_data
-- -----------------------------------------------------

INSERT INTO music_shop.users_personal_data (UserId, Name, Surname, EmailAddress, City, HomeAddress, BuildingNumber, ApartmentNumber, ZipCode)
VALUES
(1, "Jan", "Kowalski", "kowalskee@gmail.com", "Warszawa", "ulica Różana", 4, 55, "05-075"),
(2, "Kuba", "Nowicki", "k.nowicki@onet.pl", "Gdańsk", "osiedle Stare Przedmieście", 19, 4, "80-823");

-- -----------------------------------------------------
-- Przykładowe dane dla tabeli music_shop.product_categories
-- -----------------------------------------------------

INSERT INTO music_shop.product_categories (CategoryName, CategoryDescription)
VALUES
("Anna Jurksztowicz – muzyka", "Wszystkie albumy solowe Anny Jurksztowicz."),
("Krystyna Prońko – muzyka", "Wszystkie albumy solowe Krystyny Prońko.")
("James Brown – odzież", "Odzież z nadrukami z podobizną Jamesa Browna – prekursora funku i soulu.");

-- -----------------------------------------------------
-- Przykładowe dane dla tabeli music_shop.products
-- -----------------------------------------------------

INSERT INTO music_shop.products (ProductName, ProductViewDescription, ProductCategory, ProductPrice, ProductAvailableQuantity)
VALUES
("Dziękuje, nie tańczę", NULL, 1, 14.99, 14),
("Jestem po prostu...", NULL, 2, 24.99, 7)
("Koszulka z nadrukiem Jamesa Browna", "Koszulka bawełniana", 3, 35.00, 19);

-- -----------------------------------------------------
-- Przykładowe dane dla tabeli music_shop.order_delivery_methods
-- -----------------------------------------------------


INSERT INTO music_shop.order_delivery_methods (DeliveryMethod, DeliveryMethodDescription)
VALUES
("Dostawa do paczkomatu", "Dostawa do lokalnego paczkomatu firmy InPost."),
("Odbiór w kiosku Ruchu", "Odbiór w wybranym kiosku Ruchu."),
("Odbiór na poczcie", "Odbiór w wybranym punkcie pocztowym.");

-- -----------------------------------------------------
-- Przykładowe dane dla tabeli music_shop.order_payment_methods
-- -----------------------------------------------------

INSERT INTO music_shop.order_payment_methods (PaymentMethod)
VALUES
("PayPal"),
("Przelew elektroniczny"),
("BLIK");

-- -----------------------------------------------------
-- Przykładowe dane dla tabeli music_shop.orders
-- -----------------------------------------------------

INSERT INTO music_shop.orders (OrderedProduct, Quantity, OrderingUser, OrderDateTime, DeliveryMethod)
VALUES
(2, 1, 2, "19-12-20 10:45:17 PM", 2),
(3, 1, 1, "14-10-20 11:24:40 PM", 1);

-- -----------------------------------------------------
-- Przykładowe dane dla tabeli music_shop.order_payments
-- -----------------------------------------------------

INSERT INTO music_shop.order_payments (OrderId, PayingUser, PaymentMethod)
VALUES
(2, 1, 3),
(2, 2, 3);