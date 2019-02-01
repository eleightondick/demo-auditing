USE AuditDemo;
GO

-- Check passwords
CREATE TABLE dontUseThesePasswords (pwd varchar(100));
INSERT INTO dontUseThesePasswords (pwd)
	VALUES ('password'),('password123'),('123456'),('p4ssw0rd!');
GO

IF EXISTS (SELECT 'x' FROM sys.server_principals WHERE [name] = 'weakPassword')
	DROP LOGIN weakPassword;
CREATE LOGIN weakPassword WITH PASSWORD = 'p4ssw0rd!';
SELECT l.[name]
	FROM master.sys.sql_logins l
		CROSS JOIN dontUseThesePasswords pl
	WHERE PWDCOMPARE(pl.pwd, l.password_hash) = 1;
GO

-- Test for orphaned users
IF NOT EXISTS (SELECT 'x' FROM sys.server_principals WHERE [name] = 'unnecessaryUser')
	CREATE LOGIN [DEMO-SQL16\unnecessaryUser] FROM WINDOWS;
GO
-- Now delete that Windows user
-- Execute the procedure
EXECUTE sp_validatelogins;
GO
