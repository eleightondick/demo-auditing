USE [master];
GO

-- Make sure the demo databases don't exist
IF EXISTS (SELECT 'x' FROM sys.databases WHERE [name] = 'AuditDemo')
	DROP DATABASE [AuditDemo];
IF EXISTS (SELECT 'x' FROM sys.databases WHERE [name] = 'SecurityAudit')
	DROP DATABASE [SecurityAudit];
GO

-- Create the demo database
CREATE DATABASE [AuditDemo];
ALTER DATABASE [AuditDemo]
	SET TRUSTWORTHY ON;					-- Shortcut for demo purposes; Use certificates in production
GO

CREATE DATABASE [SecurityAudit];
GO

-- Create the Service Broker objects
USE [AuditDemo];
CREATE MASTER KEY ENCRYPTION BY PASSWORD = 'k9#:Fz6p4MW&T-W>Cds.oXyQ';
ALTER DATABASE [AuditDemo] SET ENABLE_BROKER;
GO

CREATE MESSAGE TYPE [//auditdemo.local/msgSecAudit]
	VALIDATION = WELL_FORMED_XML;
CREATE CONTRACT [//auditdemo.local/contractSecAudit]
	([//auditdemo.local/msgSecAudit] SENT BY ANY);
CREATE QUEUE [queueSecAudit_send]
	WITH STATUS = ON;
CREATE SERVICE [//auditdemo.local/svcSecAudit_send]
	ON QUEUE [queueSecAudit_send]
		([//auditdemo.local/contractSecAudit]);
GO

CREATE PROCEDURE spSendAudit (@auditInfo xml)
AS BEGIN
	DECLARE @dialogHandle uniqueidentifier;

	BEGIN DIALOG CONVERSATION @dialogHandle
		FROM SERVICE [//auditdemo.local/svcSecAudit_send]
		TO SERVICE '//auditdemo.local/svcSecAudit_receive'
		ON CONTRACT [//auditdemo.local/contractSecAudit];

	SEND ON CONVERSATION @dialogHandle
		MESSAGE TYPE [//auditdemo.local/msgSecAudit]
			(@auditInfo);
END;
GO

USE [SecurityAudit];
CREATE MASTER KEY ENCRYPTION BY PASSWORD = 'k9#:Fz6p4MW&T-W>Cds.oXyQ';
ALTER DATABASE [SecurityAudit] SET ENABLE_BROKER;
GO

CREATE MESSAGE TYPE [//auditdemo.local/msgSecAudit]
	VALIDATION = WELL_FORMED_XML;
CREATE CONTRACT [//auditdemo.local/contractSecAudit]
	([//auditdemo.local/msgSecAudit] SENT BY ANY);
CREATE QUEUE [queueSecAudit_receive]
	WITH STATUS = ON;
CREATE SERVICE [//auditdemo.local/svcSecAudit_receive]
	ON QUEUE [queueSecAudit_receive]
		([//auditdemo.local/contractSecAudit]);
GO

CREATE TABLE auditRecords
	(Id int NOT NULL IDENTITY(1,1) PRIMARY KEY,
	 auditInfo xml NULL);
CREATE TABLE emailedAlerts
	(Id int NOT NULL IDENTITY(1,1) PRIMARY KEY,
	 message varchar(max) NULL);
GO

IF EXISTS (SELECT 'x' FROM sys.server_principals WHERE [name] = 'newUser')
	DROP LOGIN newUser;
GO