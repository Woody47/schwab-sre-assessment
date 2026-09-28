SELECT table_name, column_name, data_type
FROM `PROJECT_ID.sre_logs.INFORMATION_SCHEMA.COLUMNS`
ORDER BY table_name, ordinal_position;
SELECT table_name, field_path, data_type
FROM `PROJECT_ID.sre_logs.INFORMATION_SCHEMA.COLUMN_FIELD_PATHS`
WHERE table_name = 'stdout'
ORDER BY field_path;
