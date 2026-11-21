USE NetflixDWH;
GO

DELETE FROM Fact_Viewing;
DELETE FROM Fact_Ratings;
DELETE FROM Fact_Payments;

DELETE FROM Dim_Profile;
DELETE FROM Dim_Title;
DELETE FROM Dim_Genre;
DELETE FROM Dim_Country;
DELETE FROM Dim_Plan;

DBCC CHECKIDENT ('Fact_Viewing',  RESEED, 0);
DBCC CHECKIDENT ('Fact_Ratings',  RESEED, 0);
DBCC CHECKIDENT ('Fact_Payments', RESEED, 0);
DBCC CHECKIDENT ('Dim_Profile',   RESEED, 0);
DBCC CHECKIDENT ('Dim_Title',     RESEED, 0);
DBCC CHECKIDENT ('Dim_Genre',     RESEED, 0);
DBCC CHECKIDENT ('Dim_Country',   RESEED, 0);
DBCC CHECKIDENT ('Dim_Plan',      RESEED, 0);
GO



INSERT INTO Dim_Country (CountryID, Name, ISOCode)
SELECT CountryID, Name, ISOCode
FROM NetflixDB.dbo.Countries;

INSERT INTO Dim_Plan (PlanID, Name, MonthlyPrice, MaxScreens, MaxProfiles, Resolution)
SELECT PlanID, Name, MonthlyPrice, MaxScreens, MaxProfiles, Resolution
FROM NetflixDB.dbo.Plans;

INSERT INTO Dim_Genre (GenreID, Name)
SELECT GenreID, Name
FROM NetflixDB.dbo.Genres;

INSERT INTO Dim_Title (TitleID, Name, TitleType, ReleaseYear, AgeRating, DurationMin)
SELECT TitleID, Name, Type, ReleaseYear, AgeRating, DurationMin
FROM NetflixDB.dbo.Titles;

INSERT INTO Dim_Profile (ProfileID, ProfileName, IsKids, [Language],
                         AccountID, AccountStatus, AccountCreatedDate)
SELECT p.ProfileID, p.Name, p.IsKids, p.Language,
       a.AccountID, a.Status, CAST(a.CreatedAt AS DATE)
FROM NetflixDB.dbo.Profiles p
JOIN NetflixDB.dbo.Accounts a ON a.AccountID = p.AccountID;
GO


INSERT INTO Fact_Viewing (DateKey, TimeKey, ProfileKey, TitleKey, GenreKey,
                          CountryKey, PlanKey, DeviceKey, EpisodeID,
                          WatchedMinutes, ViewCount)
SELECT YEAR(v.StartedAt) * 10000 + MONTH(v.StartedAt) * 100 + DAY(v.StartedAt),
       DATEPART(HOUR, v.StartedAt) * 100 + DATEPART(MINUTE, v.StartedAt),
       dp.ProfileKey,
       dt.TitleKey,
       dg.GenreKey,
       dc.CountryKey,
       dpl.PlanKey,
       dd.DeviceKey,
       v.EpisodeID,
       v.WatchedMinutes,
       1
FROM NetflixDB.dbo.ViewingHistory v
JOIN NetflixDB.dbo.Profiles pr ON pr.ProfileID = v.ProfileID
JOIN NetflixDB.dbo.Accounts a  ON a.AccountID  = pr.AccountID
JOIN Dim_Profile dp  ON dp.ProfileID  = v.ProfileID
JOIN Dim_Title   dt  ON dt.TitleID    = v.TitleID
JOIN Dim_Country dc  ON dc.CountryID  = a.CountryID
JOIN Dim_Plan    dpl ON dpl.PlanID    = a.PlanID
JOIN Dim_Device  dd  ON dd.DeviceType = v.DeviceType
OUTER APPLY (SELECT TOP 1 tg.GenreID
             FROM NetflixDB.dbo.Title_Genres tg
             WHERE tg.TitleID = v.TitleID
             ORDER BY tg.GenreID) g                 -- основен жанр
LEFT JOIN Dim_Genre dg ON dg.GenreID = g.GenreID;
GO


INSERT INTO Fact_Ratings (DateKey, TimeKey, ProfileKey, TitleKey, GenreKey,
                          CountryKey, PlanKey, Score, RatingCount)
SELECT YEAR(r.RatedAt) * 10000 + MONTH(r.RatedAt) * 100 + DAY(r.RatedAt),
       DATEPART(HOUR, r.RatedAt) * 100 + DATEPART(MINUTE, r.RatedAt),
       dp.ProfileKey,
       dt.TitleKey,
       dg.GenreKey,
       dc.CountryKey,
       dpl.PlanKey,
       r.Score,
       1
FROM NetflixDB.dbo.Ratings r
JOIN NetflixDB.dbo.Profiles pr ON pr.ProfileID = r.ProfileID
JOIN NetflixDB.dbo.Accounts a  ON a.AccountID  = pr.AccountID
JOIN Dim_Profile dp  ON dp.ProfileID = r.ProfileID
JOIN Dim_Title   dt  ON dt.TitleID   = r.TitleID
JOIN Dim_Country dc  ON dc.CountryID = a.CountryID
JOIN Dim_Plan    dpl ON dpl.PlanID   = a.PlanID
OUTER APPLY (SELECT TOP 1 tg.GenreID
             FROM NetflixDB.dbo.Title_Genres tg
             WHERE tg.TitleID = r.TitleID
             ORDER BY tg.GenreID) g
LEFT JOIN Dim_Genre dg ON dg.GenreID = g.GenreID;
GO

INSERT INTO Fact_Payments (DateKey, TimeKey, CountryKey, PlanKey, AccountID,
                           PaymentMethod, PaymentStatus, Amount)
SELECT YEAR(p.PaidAt) * 10000 + MONTH(p.PaidAt) * 100 + DAY(p.PaidAt),
       DATEPART(HOUR, p.PaidAt) * 100 + DATEPART(MINUTE, p.PaidAt),
       dc.CountryKey,
       dpl.PlanKey,
       p.AccountID,
       p.PaymentMethod,
       p.Status,
       p.Amount
FROM NetflixDB.dbo.Payments p
JOIN NetflixDB.dbo.Accounts a ON a.AccountID = p.AccountID
JOIN Dim_Country dc  ON dc.CountryID = a.CountryID
JOIN Dim_Plan    dpl ON dpl.PlanID   = a.PlanID;
GO


SELECT 'Fact_Viewing'  AS TableName, COUNT(*) AS Rows FROM Fact_Viewing
UNION ALL SELECT 'Fact_Ratings',  COUNT(*) FROM Fact_Ratings
UNION ALL SELECT 'Fact_Payments', COUNT(*) FROM Fact_Payments
UNION ALL SELECT 'Dim_Profile',   COUNT(*) FROM Dim_Profile
UNION ALL SELECT 'Dim_Title',     COUNT(*) FROM Dim_Title;


SELECT d.[Year], d.[Month], d.MonthName,
       SUM(f.WatchedMinutes) / 60.0 AS WatchedHours
FROM Fact_Viewing f
JOIN Dim_Date d ON d.DateKey = f.DateKey
GROUP BY d.[Year], d.[Month], d.MonthName
ORDER BY d.[Year], d.[Month];
GO
