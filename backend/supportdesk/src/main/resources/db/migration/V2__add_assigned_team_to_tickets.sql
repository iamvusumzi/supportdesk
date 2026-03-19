CREATE TYPE team_name AS ENUM ('GENERAL_SUPPORT', 'ESCALATIONS');

ALTER TABLE tickets
  ADD COLUMN assigned_team team_name;