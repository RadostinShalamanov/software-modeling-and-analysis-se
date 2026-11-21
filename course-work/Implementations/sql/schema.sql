
IF DB_ID('NetflixDB') IS NULL CREATE DATABASE NetflixDB;
GO
USE NetflixDB;
GO



CREATE TABLE Countries (
    CountryID INT IDENTITY(1,1) PRIMARY KEY,
    Name      NVARCHAR(100) NOT NULL UNIQUE,
    ISOCode   CHAR(2)       NOT NULL UNIQUE
);

CREATE TABLE Plans (
    PlanID       INT IDENTITY(1,1) PRIMARY KEY,
    Name         NVARCHAR(50)  NOT NULL UNIQUE,
    MonthlyPrice DECIMAL(6,2)  NOT NULL CHECK (MonthlyPrice > 0),
    MaxScreens   TINYINT       NOT NULL,
    MaxProfiles  TINYINT       NOT NULL,
    Resolution   NVARCHAR(10)  NOT NULL
);

CREATE TABLE Accounts (
    AccountID    INT IDENTITY(1,1) PRIMARY KEY,
    Email        NVARCHAR(150) NOT NULL UNIQUE,
    PasswordHash NVARCHAR(255) NOT NULL,
    CountryID    INT NOT NULL REFERENCES Countries(CountryID),
    PlanID       INT NOT NULL REFERENCES Plans(PlanID),
    CreatedAt    DATETIME2     NOT NULL DEFAULT SYSDATETIME(),
    Status       NVARCHAR(20)  NOT NULL DEFAULT 'Active'
                 CHECK (Status IN ('Active','Suspended','Cancelled'))
);

CREATE TABLE Profiles (
    ProfileID INT IDENTITY(1,1) PRIMARY KEY,
    AccountID INT NOT NULL REFERENCES Accounts(AccountID) ON DELETE CASCADE,
    Name      NVARCHAR(50) NOT NULL,
    IsKids    BIT          NOT NULL DEFAULT 0,
    Language  NVARCHAR(30) NOT NULL DEFAULT 'English',
    CreatedAt DATETIME2    NOT NULL DEFAULT SYSDATETIME(),
    CONSTRAINT UQ_Profile_Name UNIQUE (AccountID, Name)
);

CREATE TABLE Titles (
    TitleID     INT IDENTITY(1,1) PRIMARY KEY,
    Name        NVARCHAR(200) NOT NULL,
    Type        NVARCHAR(10)  NOT NULL CHECK (Type IN ('Movie','Series')),
    ReleaseYear SMALLINT      NOT NULL,
    AgeRating   NVARCHAR(10)  NOT NULL,
    DurationMin INT           NULL,          -- за филми
    Description NVARCHAR(1000) NULL,
    AddedAt     DATE          NOT NULL DEFAULT CAST(SYSDATETIME() AS DATE)
);

CREATE TABLE Seasons (
    SeasonID     INT IDENTITY(1,1) PRIMARY KEY,
    TitleID      INT NOT NULL REFERENCES Titles(TitleID) ON DELETE CASCADE,
    SeasonNumber TINYINT  NOT NULL,
    ReleaseYear  SMALLINT NOT NULL,
    CONSTRAINT UQ_Season UNIQUE (TitleID, SeasonNumber)
);

CREATE TABLE Episodes (
    EpisodeID     INT IDENTITY(1,1) PRIMARY KEY,
    SeasonID      INT NOT NULL REFERENCES Seasons(SeasonID) ON DELETE CASCADE,
    EpisodeNumber TINYINT       NOT NULL,
    Name          NVARCHAR(200) NOT NULL,
    DurationMin   INT           NOT NULL CHECK (DurationMin > 0),
    CONSTRAINT UQ_Episode UNIQUE (SeasonID, EpisodeNumber)
);

CREATE TABLE Genres (
    GenreID INT IDENTITY(1,1) PRIMARY KEY,
    Name    NVARCHAR(50) NOT NULL UNIQUE
);

CREATE TABLE Title_Genres (            -- M:N
    TitleID INT NOT NULL REFERENCES Titles(TitleID) ON DELETE CASCADE,
    GenreID INT NOT NULL REFERENCES Genres(GenreID),
    PRIMARY KEY (TitleID, GenreID)
);

CREATE TABLE People (
    PersonID  INT IDENTITY(1,1) PRIMARY KEY,
    FullName  NVARCHAR(150) NOT NULL,
    BirthDate DATE NULL,
    CountryID INT NULL REFERENCES Countries(CountryID)
);

CREATE TABLE Title_Cast (              -- M:N
    TitleID       INT NOT NULL REFERENCES Titles(TitleID) ON DELETE CASCADE,
    PersonID      INT NOT NULL REFERENCES People(PersonID),
    RoleType      NVARCHAR(20) NOT NULL CHECK (RoleType IN ('Actor','Director','Writer')),
    CharacterName NVARCHAR(100) NULL,
    PRIMARY KEY (TitleID, PersonID, RoleType)
);

CREATE TABLE Watchlist (               -- M:N
    ProfileID INT NOT NULL REFERENCES Profiles(ProfileID) ON DELETE CASCADE,
    TitleID   INT NOT NULL REFERENCES Titles(TitleID),
    AddedAt   DATETIME2 NOT NULL DEFAULT SYSDATETIME(),
    PRIMARY KEY (ProfileID, TitleID)
);

CREATE TABLE ViewingHistory (
    ViewID         BIGINT IDENTITY(1,1) PRIMARY KEY,
    ProfileID      INT NOT NULL REFERENCES Profiles(ProfileID) ON DELETE CASCADE,
    TitleID        INT NOT NULL REFERENCES Titles(TitleID),
    EpisodeID      INT NULL REFERENCES Episodes(EpisodeID),
    DeviceType     NVARCHAR(20) NOT NULL
                   CHECK (DeviceType IN ('TV','Mobile','Laptop','Tablet')),
    StartedAt      DATETIME2 NOT NULL DEFAULT SYSDATETIME(),
    WatchedMinutes INT NOT NULL CHECK (WatchedMinutes >= 0)
);

CREATE TABLE Ratings (
    RatingID  INT IDENTITY(1,1) PRIMARY KEY,
    ProfileID INT NOT NULL REFERENCES Profiles(ProfileID) ON DELETE CASCADE,
    TitleID   INT NOT NULL REFERENCES Titles(TitleID),
    Score     TINYINT NOT NULL CHECK (Score BETWEEN 1 AND 5),
    RatedAt   DATETIME2 NOT NULL DEFAULT SYSDATETIME(),
    CONSTRAINT UQ_Rating UNIQUE (ProfileID, TitleID)
);

CREATE TABLE Payments (
    PaymentID     INT IDENTITY(1,1) PRIMARY KEY,
    AccountID     INT NOT NULL REFERENCES Accounts(AccountID),
    Amount        DECIMAL(8,2) NOT NULL CHECK (Amount > 0),
    PaidAt        DATETIME2 NOT NULL DEFAULT SYSDATETIME(),
    PaymentMethod NVARCHAR(30) NOT NULL
                  CHECK (PaymentMethod IN ('Card','PayPal','GiftCard')),
    Status        NVARCHAR(20) NOT NULL DEFAULT 'Paid'
                  CHECK (Status IN ('Paid','Failed','Refunded'))
);
GO

/* ---------- ИНДЕКСИ ---------- */
CREATE INDEX IX_Viewing_Profile ON ViewingHistory(ProfileID);
CREATE INDEX IX_Viewing_Title   ON ViewingHistory(TitleID, StartedAt);
CREATE INDEX IX_Payments_Acc    ON Payments(AccountID, PaidAt);
GO

/* ---------- ФУНКЦИИ ---------- */

-- Общо изгледани минути от профил
CREATE OR ALTER FUNCTION dbo.fn_ProfileWatchMinutes (@ProfileID INT)
RETURNS INT
AS
BEGIN
    RETURN ISNULL((SELECT SUM(WatchedMinutes)
                   FROM ViewingHistory
                   WHERE ProfileID = @ProfileID), 0);
END;
GO

-- Месечна цена на акаунта според плана
CREATE OR ALTER FUNCTION dbo.fn_AccountMonthlyCost (@AccountID INT)
RETURNS DECIMAL(6,2)
AS
BEGIN
    RETURN (SELECT p.MonthlyPrice
            FROM Accounts a JOIN Plans p ON p.PlanID = a.PlanID
            WHERE a.AccountID = @AccountID);
END;
GO

/* ---------- СЪХРАНЕНА ПРОЦЕДУРА ---------- */

CREATE OR ALTER PROCEDURE dbo.sp_AddViewing
    @ProfileID INT,
    @TitleID   INT,
    @EpisodeID INT = NULL,
    @Device    NVARCHAR(20),
    @Minutes   INT
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT EXISTS (SELECT 1 FROM Profiles WHERE ProfileID = @ProfileID)
        THROW 50001, 'Профилът не съществува.', 1;

    IF NOT EXISTS (SELECT 1 FROM Titles WHERE TitleID = @TitleID)
        THROW 50002, 'Заглавието не съществува.', 1;

    IF @EpisodeID IS NOT NULL AND NOT EXISTS (
        SELECT 1
        FROM Episodes e JOIN Seasons s ON s.SeasonID = e.SeasonID
        WHERE e.EpisodeID = @EpisodeID AND s.TitleID = @TitleID)
        THROW 50003, 'Епизодът не принадлежи на това заглавие.', 1;

    IF @Minutes < 0
        THROW 50004, 'Минутите не могат да са отрицателни.', 1;

    INSERT INTO ViewingHistory (ProfileID, TitleID, EpisodeID, DeviceType, WatchedMinutes)
    VALUES (@ProfileID, @TitleID, @EpisodeID, @Device, @Minutes);

    SELECT SCOPE_IDENTITY() AS NewViewID;
END;
GO

/* ---------- ТРИГЕР ---------- */

-- Не позволява повече профили от лимита на плана
CREATE OR ALTER TRIGGER dbo.trg_Profiles_MaxLimit
ON Profiles
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS (
        SELECT 1
        FROM Accounts a
        JOIN Plans p ON p.PlanID = a.PlanID
        WHERE a.AccountID IN (SELECT AccountID FROM inserted)
          AND (SELECT COUNT(*) FROM Profiles pr WHERE pr.AccountID = a.AccountID) > p.MaxProfiles
    )
    BEGIN
        ROLLBACK TRANSACTION;
        THROW 50010, 'Надвишен е максималният брой профили за плана.', 1;
    END
END;
GO

/* ---------- ИЗГЛЕД (допълнителна точка) ---------- */

CREATE OR ALTER VIEW dbo.vw_TopTitles
AS
SELECT t.TitleID, t.Name, t.Type,
       COUNT(*)                AS Views,
       SUM(v.WatchedMinutes)   AS TotalMinutes,
       AVG(CAST(r.Score AS FLOAT)) AS AvgScore
FROM Titles t
JOIN ViewingHistory v ON v.TitleID = t.TitleID
LEFT JOIN Ratings r   ON r.TitleID = t.TitleID
GROUP BY t.TitleID, t.Name, t.Type;
GO
