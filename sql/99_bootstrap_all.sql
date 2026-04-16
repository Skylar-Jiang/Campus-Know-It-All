-- 99_bootstrap_all.sql
-- One-shot bootstrap for full database rebuild
-- Usage (MySQL CLI): source sql/99_bootstrap_all.sql;

SOURCE sql/00_reset_database.sql;
SOURCE sql/02_create_tables.sql;
SOURCE sql/03_insert_init_data.sql;
SOURCE sql/04_trigger.sql;
SOURCE sql/05_procedure.sql;
SOURCE sql/06_view.sql;
SOURCE sql/07_event.sql;
SOURCE sql/08_add_trade_community.sql;
SOURCE sql/09_add_post_like.sql;

-- For legacy database incremental upgrade only (usually not needed after full rebuild):
-- SOURCE sql/10_add_borrow_order_uid.sql;
