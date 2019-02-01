USE [AuditDemo];
GO

DECLARE @dialogHandle uniqueidentifier;

BEGIN DIALOG CONVERSATION @dialogHandle
	FROM SERVICE [//auditdemo.local/svcSecAudit_send]
	TO SERVICE '//auditdemo.local/svcSecAudit_receive'
	ON CONTRACT [//auditdemo.local/contractSecAudit];

SEND ON CONVERSATION @dialogHandle
	MESSAGE TYPE [//auditdemo.local/msgSecAudit]
		('<msg>Test message</msg>');
GO

-- Show what's in the queues
SELECT * FROM [queueSecAudit_send];
SELECT * FROM [SecurityAudit].dbo.[queueSecAudit_receive];
SELECT * FROM sys.conversation_endpoints;
SELECT * FROM sys.transmission_queue;
GO

SELECT CAST(message_body AS xml) FROM [SecurityAudit].dbo.[queueSecAudit_receive];
GO

-- Send a return message - Copy the conversation_handle here before proceeding
SEND ON CONVERSATION '091CB497-8D40-E411-B4C4-000C290734EA'
	MESSAGE TYPE [//auditdemo.local/msgSecAudit]
		('<ack />');
GO

-- Show what's in the queues
SELECT *, CAST(message_body AS xml) FROM [queueSecAudit_send];
SELECT *, CAST(message_body AS xml) FROM [SecurityAudit].dbo.[queueSecAudit_receive];
SELECT * FROM sys.conversation_endpoints;
GO
