-- ============================================================
-- Руда+ MES: Удаление всех таблиц аналитической базы данных
-- Порядок удаления учитывает зависимости внешних ключей
-- ============================================================

-- Факт-таблицы (зависят от измерений)
DROP TABLE IF EXISTS fact_ore_quality CASCADE;
DROP TABLE IF EXISTS fact_equipment_downtime CASCADE;
DROP TABLE IF EXISTS fact_equipment_telemetry CASCADE;
DROP TABLE IF EXISTS fact_production CASCADE;

-- Таблицы измерений (dimensions)
DROP TABLE IF EXISTS dim_sensor CASCADE;
DROP TABLE IF EXISTS dim_equipment CASCADE;
DROP TABLE IF EXISTS dim_shaft CASCADE;
DROP TABLE IF EXISTS dim_location CASCADE;
DROP TABLE IF EXISTS dim_sensor_type CASCADE;
DROP TABLE IF EXISTS dim_equipment_type CASCADE;
DROP TABLE IF EXISTS dim_mine CASCADE;
DROP TABLE IF EXISTS dim_operator CASCADE;
DROP TABLE IF EXISTS dim_shift CASCADE;
DROP TABLE IF EXISTS dim_ore_grade CASCADE;
DROP TABLE IF EXISTS dim_downtime_reason CASCADE;
DROP TABLE IF EXISTS dim_date CASCADE;
DROP TABLE IF EXISTS dim_time CASCADE;

-- Удаление схемы (если используется отдельная)
-- DROP SCHEMA IF EXISTS ruda_mes CASCADE;
