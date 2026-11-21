
IF DB_ID('NetflixDWH') IS NULL CREATE DATABASE NetflixDWH;
GO
USE NetflixDWH;
GO


DROP TABLE IF EXISTS Fact_Viewing;
DROP TABLE IF EXISTS Fact_Ratings;
DROP TABLE IF EXISTS Fact_Payments;
DROP TABLE IF EXISTS Dim_Date;
DROP TABLE IF EXISTS Dim_Time;
DROP TABLE IF EXISTS Dim_Profile;
DROP TABLE IF EXISTS Dim_Title;
DROP TABLE IF EXISTS Dim_Genre;
DROP TABLE IF EXISTS Dim_Country;
DROP TABLE IF EXISTS Dim_Plan;
DROP TABLE IF EXISTS Dim_Device;
GO

CREATE TABLE Dim_Date (
    DateKey     INT         NOT NULL PRIMARY KEY,   
    FullDate    DATE        NOT NULL,
    [Year]      SMALLINT    NOT NULL,
    [Quarter]   TINYINT     NOT NULL,
    [Month]     TINYINT     NOT NULL,
    MonthName   NVARCHAR(20) NOT NULL,
    [Day]       TINYINT     NOT NULL,
    DayOfWeek   TINYINT     NOT NULL,               
    DayName     NVARCHAR(20) NOT NULL,
    IsWeekend   BIT         NOT NULL
);

CREATE TABLE Dim_Time (
    TimeKey  INT          NOT NULL PRIMARY KEY,    
    [Hour]   TINYINT      NOT NULL,
    [Minute] TINYINT      NOT NULL,
    DayPart  NVARCHAR(15) NOT NULL                  
);

CREATE TABLE Dim_Profile (
    ProfileKey         INT IDENTITY(1,1) PRIMARY KEY,
    ProfileID          INT           NOT NULL,      
    ProfileName        NVARCHAR(50)  NOT NULL,
    IsKids             BIT           NOT NULL,
    [Language]         NVARCHAR(30)  NOT NULL,
    AccountID          INT           NOT NULL,
    AccountStatus      NVARCHAR(20)  NOT NULL,
    AccountCreatedDate DATE          NOT NULL
);

CREATE TABLE Dim_Title (
    TitleKey    INT IDENTITY(1,1) PRIMARY KEY,
    TitleID     INT           NOT NULL,
    Name        NVARCHAR(200) NOT NULL,
    TitleType   NVARCHAR(10)  NOT NULL,           
    ReleaseYear SMALLINT      NOT NULL,
    AgeRating   NVARCHAR(10)  NOT NULL,
    DurationMin INT           NULL
);

CREATE TABLE Dim_Genre (
    GenreKey INT IDENTITY(1,1) PRIMARY KEY,
    GenreID  INT          NOT NULL,
    Name     NVARCHAR(50) NOT NULL
);

CREATE TABLE Dim_Country (
    CountryKey INT IDENTITY(1,1) PRIMARY KEY,
    CountryID  INT           NOT NULL,
    Name       NVARCHAR(100) NOT NULL,
    ISOCode    CHAR(2)       NOT NULL
);

CREATE TABLE Dim_Plan (
    PlanKey      INT IDENTITY(1,1) PRIMARY KEY,
    PlanID       INT          NOT NULL,
    Name         NVARCHAR(50) NOT NULL,
    MonthlyPrice DECIMAL(6,2) NOT NULL,
    MaxScreens   TINYINT      NOT NULL,
    MaxProfiles  TINYINT      NOT NULL,
    Resolution   NVARCHAR(10) NOT NULL
);

CREATE TABLE Dim_Device (
    DeviceKey  INT IDENTITY(1,1) PRIMARY KEY,
    DeviceType NVARCHAR(20) NOT NULL UNIQUE
);



CREATE TABLE Fact_Viewing (
    ViewingKey     BIGINT IDENTITY(1,1) PRIMARY KEY,
    DateKey        INT NOT NULL REFERENCES Dim_Date(DateKey),
    TimeKey        INT NOT NULL REFERENCES Dim_Time(TimeKey),
    ProfileKey     INT NOT NULL REFERENCES Dim_Profile(ProfileKey),
    TitleKey       INT NOT NULL REFERENCES Dim_Title(TitleKey),
    GenreKey       INT NULL     REFERENCES Dim_Genre(GenreKey),   
    CountryKey     INT NOT NULL REFERENCES Dim_Country(CountryKey),
    PlanKey        INT NOT NULL REFERENCES Dim_Plan(PlanKey),
    DeviceKey      INT NOT NULL REFERENCES Dim_Device(DeviceKey),
    EpisodeID      INT NULL,                                      
    WatchedMinutes INT NOT NULL,
    ViewCount      INT NOT NULL DEFAULT 1
);

CREATE TABLE Fact_Ratings (
    RatingKey  INT IDENTITY(1,1) PRIMARY KEY,
    DateKey    INT NOT NULL REFERENCES Dim_Date(DateKey),
    TimeKey    INT NOT NULL REFERENCES Dim_Time(TimeKey),
    ProfileKey INT NOT NULL REFERENCES Dim_Profile(ProfileKey),
    TitleKey   INT NOT NULL REFERENCES Dim_Title(TitleKey),
    GenreKey   INT NULL     REFERENCES Dim_Genre(GenreKey),
    CountryKey INT NOT NULL REFERENCES Dim_Country(CountryKey),
    PlanKey    INT NOT NULL REFERENCES Dim_Plan(PlanKey),
    Score      TINYINT NOT NULL,
    RatingCount INT NOT NULL DEFAULT 1
);

CREATE TABLE Fact_Payments (
    PaymentKey    INT IDENTITY(1,1) PRIMARY KEY,
    DateKey       INT NOT NULL REFERENCES Dim_Date(DateKey),
    TimeKey       INT NOT NULL REFERENCES Dim_Time(TimeKey),
    CountryKey    INT NOT NULL REFERENCES Dim_Country(CountryKey),
    PlanKey       INT NOT NULL REFERENCES Dim_Plan(PlanKey),
    AccountID     INT NOT NULL,                                  
    PaymentMethod NVARCHAR(30) NOT NULL,
    PaymentStatus NVARCHAR(20) NOT NULL,
    Amount        DECIMAL(8,2) NOT NULL
);
GO

CREATE INDEX IX_FV_Date  ON Fact_Viewing(DateKey);
CREATE INDEX IX_FV_Title ON Fact_Viewing(TitleKey);
CREATE INDEX IX_FV_Prof  ON Fact_Viewing(ProfileKey);
GO


;WITH d AS (
    SELECT CAST('2020-01-01' AS DATE) AS dt
    UNION ALL
    SELECT DATEADD(DAY, 1, dt) FROM d WHERE dt < '2030-12-31'
)
INSERT INTO Dim_Date (DateKey, FullDate, [Year], [Quarter], [Month], MonthName,
                      [Day], DayOfWeek, DayName, IsWeekend)
SELECT YEAR(dt) * 10000 + MONTH(dt) * 100 + DAY(dt),
       dt,
       YEAR(dt),
       DATEPART(QUARTER, dt),
       MONTH(dt),
       DATENAME(MONTH, dt),
       DAY(dt),
       (DATEDIFF(DAY, '19000101', dt) % 7) + 1,      -- 1900-01-01 е понеделник
       DATENAME(WEEKDAY, dt),
       CASE WHEN (DATEDIFF(DAY, '19000101', dt) % 7) + 1 >= 6 THEN 1 ELSE 0 END
FROM d
OPTION (MAXRECURSION 0);

;WITH t AS (
    SELECT 0 AS n
    UNION ALL
    SELECT n + 1 FROM t WHERE n < 1439
)
INSERT INTO Dim_Time (TimeKey, [Hour], [Minute], DayPart)
SELECT (n / 60) * 100 + (n % 60),
       n / 60,
       n % 60,
       CASE WHEN n / 60 < 6  THEN 'Night'
            WHEN n / 60 < 12 THEN 'Morning'
            WHEN n / 60 < 18 THEN 'Afternoon'
            ELSE 'Evening' END
FROM t
OPTION (MAXRECURSION 0);


INSERT INTO Dim_Device (DeviceType) VALUES ('TV'), ('Mobile'), ('Laptop'), ('Tablet');
GO
