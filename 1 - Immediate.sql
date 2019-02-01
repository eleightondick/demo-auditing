USE AuditDemo;
GO

-- New members of privileged roles
CREATE TRIGGER trgPrivilegedRoleMemberAdded
	ON ALL SERVER
	FOR ADD_SERVER_ROLE_MEMBER
AS BEGIN
	IF EVENTDATA().value('(/EVENT_INSTANCE/RoleName)[1]', 'nvarchar(max)') = 'sysadmin'
		SELECT EVENTDATA();
END;
GO

CREATE LOGIN newUser WITH PASSWORD = '', CHECK_POLICY = OFF;
ALTER SERVER ROLE sysadmin ADD MEMBER newUser;
GO

-- Now modify the trigger to send the event through Service Broker
ALTER TRIGGER trgPrivilegedRoleMemberAdded
	ON ALL SERVER
	FOR ADD_SERVER_ROLE_MEMBER
AS BEGIN
	DECLARE @auditInfo xml = EVENTDATA();
	EXECUTE AuditDemo.dbo.spSendAudit @auditInfo;
END;
GO

DROP LOGIN newUser;
CREATE LOGIN newUser WITH PASSWORD = '', CHECK_POLICY = OFF;
ALTER SERVER ROLE sysadmin ADD MEMBER newUser;
GO

SELECT *, CAST(message_body as xml)
	FROM SecurityAudit.dbo.[queueSecAudit_receive];
GO

-- Create an activation procedure to handle the records the way we want
USE [SecurityAudit];
GO

CREATE PROCEDURE spReceiveAudit
AS BEGIN
	DECLARE @handle uniqueidentifier;
	DECLARE @messageType nvarchar(256);
	DECLARE @message xml;

	BEGIN TRY
		BEGIN TRANSACTION

		WAITFOR (
			RECEIVE TOP (1)
					@handle = conversation_handle,
					@messageType = message_type_name,
					@message = CAST(message_body AS xml)
				FROM [queueSecAudit_receive]),
			TIMEOUT 5000;

		IF (@@ROWCOUNT > 0)
		BEGIN
			SAVE TRANSACTION messageReceived;
			      
			IF @messageType = '//auditdemo.local/msgSecAudit'
			BEGIN
				-- You'd normally want to return an acknowledgement here
				--;SEND ON CONVERSATION @handle
				--	MESSAGE TYPE [//auditdemo.local/ack];

				END CONVERSATION @handle;

				INSERT INTO auditRecords (auditInfo)
					VALUES(@message);

				IF @message.value('(/EVENT_INSTANCE/RoleName)[1]', 'sysname') = 'sysadmin'
					INSERT INTO emailedAlerts (message)
						VALUES('New privileged user in role sysadmin: ' + @message.value('(/EVENT_INSTANCE/ObjectName)[1]', 'varchar(max)'));
			END
		END
	END TRY
	BEGIN CATCH
		ROLLBACK TRANSACTION messageReceived;
		
		END CONVERSATION @handle
			WITH ERROR = 50000
				 DESCRIPTION = 'Something bad happened';
	END CATCH;

	COMMIT TRANSACTION;
END;
GO

ALTER QUEUE [queueSecAudit_receive]
	WITH ACTIVATION (STATUS = ON,
					 PROCEDURE_NAME = [spReceiveAudit],
					 MAX_QUEUE_READERS = 1,
					 EXECUTE AS OWNER);
GO

USE AuditDemo;
GO

DROP LOGIN newUser;
CREATE LOGIN newUser WITH PASSWORD = '', CHECK_POLICY = OFF;
ALTER SERVER ROLE sysadmin ADD MEMBER newUser;
ALTER SERVER ROLE serveradmin ADD MEMBER newUser;
GO

SELECT *
	FROM SecurityAudit.dbo.auditRecords;
SELECT *
	FROM SecurityAudit.dbo.emailedAlerts;
GO

-- Trap failed logins with an event notification
USE SecurityAudit;
GO

CREATE SERVICE [//auditdemo.local/svcSecAudit_receiveNotification]
	ON QUEUE queueSecAudit_receive
		([http://schemas.microsoft.com/SQL/Notifications/PostEventNotification]);
GO

USE AuditDemo;
-- Need to get SecurityAudit's service broker GUID value before running this statement
CREATE EVENT NOTIFICATION enFailedLogins
	ON SERVER
	FOR AUDIT_LOGIN_FAILED
	TO SERVICE '//auditdemo.local/svcSecAudit_receiveNotification', 'C6247CE5-2F78-4CA2-B925-E137689BC9A9';
GO

USE SecurityAudit;
GO

ALTER PROCEDURE spReceiveAudit
AS BEGIN
	DECLARE @handle uniqueidentifier;
	DECLARE @messageType nvarchar(256);
	DECLARE @message xml;

	BEGIN TRY
		BEGIN TRANSACTION

		WAITFOR (
			RECEIVE TOP (1)
					@handle = conversation_handle,
					@messageType = message_type_name,
					@message = CAST(message_body AS xml)
				FROM [queueSecAudit_receive]),
			TIMEOUT 5000;

		IF (@@ROWCOUNT > 0)
		BEGIN
			SAVE TRANSACTION messageReceived;
			      
			IF @messageType = '//auditdemo.local/msgSecAudit'
			BEGIN
				-- You'd normally want to return an acknowledgement here
				--;SEND ON CONVERSATION @handle
				--	MESSAGE TYPE [//auditdemo.local/ack];

				END CONVERSATION @handle;

				INSERT INTO auditRecords (auditInfo)
					VALUES(@message);

				IF @message.value('(/EVENT_INSTANCE/RoleName)[1]', 'sysname') = 'sysadmin'
					INSERT INTO emailedAlerts (message)
						VALUES('New privileged user in role sysadmin: ' + @message.value('(/EVENT_INSTANCE/ObjectName)[1]', 'varchar(max)'));
			END;
			ELSE IF @messageType = 'http://schemas.microsoft.com/SQL/Notifications/EventNotification'
			BEGIN
				INSERT INTO auditRecords (auditInfo)
					VALUES(@message);

				IF @message.value('(/EVENT_INSTANCE/RoleName)[1]', 'sysname') = 'sysadmin'
					INSERT INTO emailedAlerts (message)
						VALUES('New privileged user in role sysadmin: ' + @message.value('(/EVENT_INSTANCE/ObjectName)[1]', 'varchar(max)'));
			END;
		END;
	END TRY
	BEGIN CATCH
		ROLLBACK TRANSACTION messageReceived;
		
		END CONVERSATION @handle
			WITH ERROR = 50000
				 DESCRIPTION = 'Something bad happened';
	END CATCH;

	COMMIT TRANSACTION;
END;
GO

USE AuditDemo;
SELECT * FROM SecurityAudit.dbo.auditRecords;
GO

USE AuditDemo;
-- Need to get SecurityAudit's service broker GUID value before running this statement
CREATE EVENT NOTIFICATION enSuccessfulLogins
	ON SERVER
	FOR AUDIT_LOGIN
	TO SERVICE '//auditdemo.local/svcSecAudit_receiveNotification', 'C6247CE5-2F78-4CA2-B925-E137689BC9A9';
GO

USE AuditDemo;
SELECT * FROM SecurityAudit.dbo.auditRecords;
GO
