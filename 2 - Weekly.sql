USE AuditDemo;
GO

IF EXISTS (SELECT 'x' FROM sys.server_principals WHERE [name] = 'anotherLogin')
	DROP LOGIN anotherLogin;
GO

CREATE TABLE serverPrincipals
	([name] sysname,
	 lastAudit date);
WITH currentLogins AS
	(SELECT [name] FROM sys.server_principals)
MERGE INTO serverPrincipals t
	USING currentLogins s
		ON s.[name] = t.[name]
	WHEN MATCHED
		THEN UPDATE SET lastAudit = CAST(GETDATE() AS date)
	WHEN NOT MATCHED BY TARGET
		THEN INSERT ([name], lastAudit)
			VALUES (s.[name], CAST(GETDATE() AS date));
GO

SELECT *
	FROM serverPrincipals;
GO

CREATE LOGIN anotherLogin WITH PASSWORD = 's0me-Password';
WITH currentLogins AS
	(SELECT [name] FROM sys.server_principals)
MERGE INTO serverPrincipals t
	USING currentLogins s
		ON s.[name] = t.[name]
	WHEN MATCHED
		THEN UPDATE SET lastAudit = CAST(GETDATE() AS date)
	WHEN NOT MATCHED BY TARGET
		THEN INSERT ([name], lastAudit)
			VALUES (s.[name], CAST(GETDATE() AS date));
GO

SELECT *
	FROM serverPrincipals;
GO
