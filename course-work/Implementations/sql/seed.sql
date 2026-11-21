
USE NetflixDB;
GO

INSERT INTO Countries (Name, ISOCode) VALUES
(N'България','BG'),(N'Германия','DE'),(N'САЩ','US'),
(N'Франция','FR'),(N'Испания','ES'),(N'Великобритания','GB');

INSERT INTO Plans (Name, MonthlyPrice, MaxScreens, MaxProfiles, Resolution) VALUES
('Basic', 7.99, 1, 2, '720p'),
('Standard', 12.99, 2, 4, '1080p'),
('Premium', 17.99, 4, 5, '4K');

INSERT INTO Genres (Name) VALUES
('Drama'),('Comedy'),('Sci-Fi'),('Thriller'),('Action'),('Documentary'),('Horror');

-- Заглавия
INSERT INTO Titles (Name, Type, ReleaseYear, AgeRating, DurationMin, Description) VALUES
('Stranger Things','Series',2016,'TV-14',NULL,N'Свръхестествени събития в малък град.'),
('The Crown','Series',2016,'TV-MA',NULL,N'Управлението на кралица Елизабет II.'),
('Money Heist','Series',2017,'TV-MA',NULL,N'Обир на Кралския монетен двор.'),
('Wednesday','Series',2022,'TV-14',NULL,N'Приключенията на Сряда Адамс.'),
('The Irishman','Movie',2019,'R',209,N'Живот в организираната престъпност.'),
('Bird Box','Movie',2018,'R',124,N'Оцеляване в постапокалиптичен свят.'),
('Extraction','Movie',2020,'R',116,N'Спасителна мисия в Дака.'),
('Roma','Movie',2018,'R',135,N'Семейна драма в Мексико Сити.'),
('Our Planet','Series',2019,'TV-G',NULL,N'Документален филм за природата.'),
('Glass Onion','Movie',2022,'PG-13',139,N'Детективска мистерия.');

-- Сезони и епизоди
INSERT INTO Seasons (TitleID, SeasonNumber, ReleaseYear) VALUES
(1,1,2016),(1,2,2017),(2,1,2016),(3,1,2017),(4,1,2022),(9,1,2019);

INSERT INTO Episodes (SeasonID, EpisodeNumber, Name, DurationMin) VALUES
(1,1,'Chapter One',49),(1,2,'Chapter Two',56),(1,3,'Chapter Three',52),
(2,1,'Chapter One',48),(2,2,'Chapter Two',55),
(3,1,'Wolferton Splash',57),(3,2,'Hyde Park Corner',60),
(4,1,'Efectuar lo acordado',50),(4,2,'Imprudencias letales',48),
(5,1,'Wednesday''s Child',58),(5,2,'Woe Is the Loneliest Number',45),
(6,1,'One Planet',50),(6,2,'Frozen Worlds',49);

INSERT INTO Title_Genres (TitleID, GenreID) VALUES
(1,3),(1,4),(1,7),(2,1),(3,4),(3,5),(4,2),(4,7),(5,1),(5,4),
(6,4),(6,7),(7,5),(8,1),(9,6),(10,2),(10,4);

INSERT INTO People (FullName, BirthDate, CountryID) VALUES
('Millie Bobby Brown','2004-02-19',6),
('Claire Foy','1984-07-16',6),
('Martin Scorsese','1942-11-17',3),
('Robert De Niro','1943-08-17',3),
('Sandra Bullock','1964-07-26',3),
('Rian Johnson','1973-12-17',3),
('Daniel Craig','1968-03-02',6),
('Jenna Ortega','2002-09-27',3);

INSERT INTO Title_Cast (TitleID, PersonID, RoleType, CharacterName) VALUES
(1,1,'Actor','Eleven'),(2,2,'Actor','Elizabeth II'),
(5,3,'Director',NULL),(5,4,'Actor','Frank Sheeran'),
(6,5,'Actor','Malorie'),(10,6,'Director',NULL),
(10,7,'Actor','Benoit Blanc'),(4,8,'Actor','Wednesday Addams');

/* ---------- Акаунти ---------- */
;WITH n AS (
    SELECT TOP (30) ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS i
    FROM sys.all_objects
)
INSERT INTO Accounts (Email, PasswordHash, CountryID, PlanID, CreatedAt, Status)
SELECT CONCAT('user', i, '@example.com'),
       CONVERT(NVARCHAR(64), HASHBYTES('SHA2_256', CONCAT('pass', i)), 2),
       1 + (i % 6),
       1 + (i % 3),
       DATEADD(DAY, -(i * 11), SYSDATETIME()),
       CASE WHEN i % 15 = 0 THEN 'Cancelled' ELSE 'Active' END
FROM n;

/* ---------- Профили (по 2 на акаунт - в рамките на лимита) ---------- */
INSERT INTO Profiles (AccountID, Name, IsKids, Language)
SELECT AccountID, N'Основен', 0, 'English' FROM Accounts;
INSERT INTO Profiles (AccountID, Name, IsKids, Language)
SELECT AccountID, N'Деца', 1, 'Bulgarian' FROM Accounts;

/* ---------- Плащания ---------- */

INSERT INTO Payments (AccountID, Amount, PaidAt, PaymentMethod, Status)
SELECT a.AccountID, p.MonthlyPrice,
       DATEADD(MONTH, -m.k, SYSDATETIME()),
       CHOOSE(1 + (a.AccountID + m.k) % 3, 'Card', 'PayPal', 'GiftCard'),
       'Paid'
FROM Accounts a
JOIN Plans p ON p.PlanID = a.PlanID
CROSS JOIN (VALUES (0),(1),(2),(3),(4),(5)) m(k);

/* ---------- ViewingHistory (~5000 реда) ---------- */

IF OBJECT_ID('tempdb..#p') IS NOT NULL DROP TABLE #p;
IF OBJECT_ID('tempdb..#t') IS NOT NULL DROP TABLE #t;
IF OBJECT_ID('tempdb..#r') IS NOT NULL DROP TABLE #r;

SELECT ProfileID, ROW_NUMBER() OVER (ORDER BY ProfileID) AS rn INTO #p FROM Profiles;
SELECT TitleID,   ROW_NUMBER() OVER (ORDER BY TitleID)   AS rn INTO #t FROM Titles;

DECLARE @pc INT = (SELECT COUNT(*) FROM #p);
DECLARE @tc INT = (SELECT COUNT(*) FROM #t);

SELECT TOP (5000)
       ABS(CHECKSUM(NEWID())) AS rp,
       ABS(CHECKSUM(NEWID())) AS rt,
       ABS(CHECKSUM(NEWID())) AS rd,
       ABS(CHECKSUM(NEWID())) AS rm,
       ABS(CHECKSUM(NEWID())) AS rw
INTO #r
FROM sys.all_objects a CROSS JOIN sys.all_objects b;

INSERT INTO ViewingHistory (ProfileID, TitleID, EpisodeID, DeviceType, StartedAt, WatchedMinutes)
SELECT p.ProfileID,
       t.TitleID,
       NULL,
       CHOOSE(1 + r.rd % 4, 'TV', 'Mobile', 'Laptop', 'Tablet'),
       DATEADD(MINUTE, -(r.rm % 262800), SYSDATETIME()),   -- последните ~6 месеца
       5 + r.rw % 120
FROM #r r
JOIN #p p ON p.rn = 1 + r.rp % @pc
JOIN #t t ON t.rn = 1 + r.rt % @tc;

-- Епизод за гледанията на сериали, които имат епизоди
UPDATE v
SET EpisodeID = (
    SELECT TOP 1 e.EpisodeID
    FROM Episodes e JOIN Seasons s ON s.SeasonID = e.SeasonID
    WHERE s.TitleID = v.TitleID
    ORDER BY CHECKSUM(NEWID(), v.ViewID))
FROM ViewingHistory v
WHERE v.TitleID IN (SELECT DISTINCT TitleID FROM Seasons);

/* ---------- Оценки ---------- */
INSERT INTO Ratings (ProfileID, TitleID, Score, RatedAt)
SELECT TOP (300) p.ProfileID, t.TitleID,
       1 + ABS(CHECKSUM(NEWID())) % 5,
       DATEADD(DAY, -ABS(CHECKSUM(NEWID())) % 180, SYSDATETIME())
FROM Profiles p CROSS JOIN Titles t
ORDER BY NEWID();

/* ---------- Watchlist ---------- */
INSERT INTO Watchlist (ProfileID, TitleID)
SELECT TOP (150) p.ProfileID, t.TitleID
FROM Profiles p CROSS JOIN Titles t
ORDER BY NEWID();
GO

/* ---------- ТЕСТОВЕ ---------- */
-- Процедура
EXEC dbo.sp_AddViewing @ProfileID = 1, @TitleID = 5, @EpisodeID = NULL,
                       @Device = 'TV', @Minutes = 90;

-- Функции
SELECT dbo.fn_ProfileWatchMinutes(1)  AS TotalMinutes,
       dbo.fn_AccountMonthlyCost(1)   AS MonthlyCost;

-- Тригер: акаунт 1 е на план Standard (макс. 4 профила) - третият и четвъртият минават, петият се отхвърля
-- INSERT INTO Profiles (AccountID, Name) VALUES (1,'P3'),(1,'P4'),(1,'P5');

-- Изглед
SELECT TOP 5 * FROM dbo.vw_TopTitles ORDER BY Views DESC;
