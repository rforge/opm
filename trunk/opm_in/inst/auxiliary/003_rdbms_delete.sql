

-- -----------------------------------------------------------------------------
--
-- Code for deleting all rows from the tables that hold PM data in the correct
-- order, i.e. the order that would be necessary if we would not use the "ON
-- DELETE CASCADE" setting. Tested with PostgreSQL (9.1, 9.3.8), SQLite (3.7.9,
-- 3.8.2) and MySQL (5.5.32, 5.5.43).
--
-- -----------------------------------------------------------------------------

BEGIN;

DELETE FROM discretized;
DELETE FROM disc_settings;

DELETE FROM aggregated;
DELETE FROM aggr_settings;

DELETE FROM measurements;

DELETE FROM wells;
DELETE FROM plates;

COMMIT;


