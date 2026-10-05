-- Update UPLOADER role to USER and update descriptions

UPDATE roles 
SET 
    name = 'USER', 
    description = 'Can manage jobs, view logs, export data, requeue DLQ, and upload files' 
WHERE name = 'UPLOADER';

UPDATE roles 
SET 
    description = 'Read-only access to dashboard and scheduler' 
WHERE name = 'VIEWER';
