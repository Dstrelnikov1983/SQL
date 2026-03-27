-- ============================================================
-- Модуль 7. Введение в индексы
-- Примеры на языке SQL (PostgreSQL)
-- Предприятие «Руда+»
-- ============================================================

-- ============================================================
-- 1. ПРОСМОТР ТЕКУЩИХ ИНДЕКСОВ
-- ============================================================

-- 1.1 Все индексы таблицы fact_production
SELECT indexname, indexdef
FROM pg_indexes
WHERE tablename = 'fact_production'
ORDER BY indexname;

-- 1.2 Все индексы схемы public
SELECT tablename, indexname, indexdef
FROM pg_indexes
WHERE schemaname = 'public'
ORDER BY tablename, indexname;

-- 1.3 Размер индексов таблицы
SELECT indexrelname AS index_name,
       pg_size_pretty(pg_relation_size(indexrelid)) AS index_size,
       idx_scan AS times_used,
       idx_tup_read AS tuples_read
FROM pg_stat_user_indexes
WHERE relname = 'fact_production'
ORDER BY pg_relation_size(indexrelid) DESC;

-- 1.4 Размер таблицы vs индексов
SELECT pg_size_pretty(pg_table_size('fact_production')) AS table_size,
       pg_size_pretty(pg_indexes_size('fact_production')) AS indexes_size,
       pg_size_pretty(pg_total_relation_size('fact_production')) AS total_size;

-- 1.5 Физический адрес строк (ctid)
SELECT ctid, equipment_id, equipment_name
FROM dim_equipment
ORDER BY ctid
LIMIT 10;

-- ============================================================
-- 2. SEQUENTIAL SCAN (без индекса)
-- ============================================================

-- 2.1 Seq Scan по таблице добычи
EXPLAIN ANALYZE
SELECT * FROM fact_production
WHERE tons_mined > 150;

-- 2.2 Seq Scan при фильтрации по неиндексированному столбцу
EXPLAIN ANALYZE
SELECT * FROM fact_production
WHERE fuel_consumed_l > 50;

-- ============================================================
-- 3. СОЗДАНИЕ B-TREE ИНДЕКСОВ
-- ============================================================

-- 3.1 Простой индекс на один столбец
CREATE INDEX idx_prod_tons_mined
ON fact_production(tons_mined);

-- Проверяем: теперь Index Scan
EXPLAIN ANALYZE
SELECT * FROM fact_production
WHERE tons_mined > 150;

-- 3.2 Индекс с направлением сортировки
CREATE INDEX idx_prod_date_desc
ON fact_production(date_id DESC NULLS LAST);

-- 3.3 Проверяем использование для ORDER BY
EXPLAIN ANALYZE
SELECT date_id, equipment_id, tons_mined
FROM fact_production
ORDER BY date_id DESC
LIMIT 20;

-- ============================================================
-- 4. UNIQUE ИНДЕКС
-- ============================================================

-- 4.1 Уникальный индекс (уже создан через DDL, демонстрация)
-- CREATE UNIQUE INDEX idx_equip_inventory_unique
-- ON dim_equipment(inventory_number);

-- 4.2 Проверяем уникальность: попытка вставить дубликат
-- INSERT INTO dim_equipment (equipment_type_id, mine_id,
--     equipment_name, inventory_number, manufacturer)
-- VALUES (1, 1, 'ПДМ-тест', 'INV-LHD-001', 'Test');
-- Ожидаем ошибку: duplicate key value

-- 4.3 Индексы, созданные автоматически (PRIMARY KEY, UNIQUE)
SELECT conname AS constraint_name,
       contype AS type,
       pg_get_constraintdef(oid) AS definition
FROM pg_constraint
WHERE conrelid = 'dim_equipment'::regclass;

-- ============================================================
-- 5. ЧАСТИЧНЫЙ ИНДЕКС (Partial Index)
-- ============================================================

-- 5.1 Индекс только по аварийным показаниям телеметрии
CREATE INDEX idx_telemetry_alarm
ON fact_equipment_telemetry(date_id, equipment_id)
WHERE is_alarm = TRUE;

-- 5.2 Запрос использует частичный индекс
EXPLAIN ANALYZE
SELECT * FROM fact_equipment_telemetry
WHERE date_id = 20240315
  AND equipment_id = 3
  AND is_alarm = TRUE;

-- 5.3 Запрос БЕЗ условия is_alarm — частичный индекс НЕ используется
EXPLAIN ANALYZE
SELECT * FROM fact_equipment_telemetry
WHERE date_id = 20240315
  AND equipment_id = 3;

-- 5.4 Частичный индекс для внеплановых простоев
CREATE INDEX idx_downtime_unplanned
ON fact_equipment_downtime(date_id, equipment_id)
WHERE is_planned = FALSE;

-- 5.5 Сравнение размеров: полный vs частичный индекс
SELECT indexrelname,
       pg_size_pretty(pg_relation_size(indexrelid)) AS size
FROM pg_stat_user_indexes
WHERE relname = 'fact_equipment_telemetry'
ORDER BY indexrelname;

-- ============================================================
-- 6. ИНДЕКС ПО ВЫРАЖЕНИЮ (Expression Index)
-- ============================================================

-- 6.1 Индекс по году-месяцу (извлечённому из date_id)
CREATE INDEX idx_prod_year_month
ON fact_production ((date_id / 100));

-- Используется при запросе:
EXPLAIN ANALYZE
SELECT * FROM fact_production
WHERE date_id / 100 = 202403;

-- 6.2 Индекс для регистронезависимого поиска
CREATE INDEX idx_operator_lastname_lower
ON dim_operator (LOWER(last_name));

EXPLAIN ANALYZE
SELECT * FROM dim_operator
WHERE LOWER(last_name) = 'петров';

-- 6.3 Индекс по извлечённому году из даты
CREATE INDEX idx_equip_commission_year
ON dim_equipment ((EXTRACT(YEAR FROM commissioning_date)));

EXPLAIN ANALYZE
SELECT * FROM dim_equipment
WHERE EXTRACT(YEAR FROM commissioning_date) = 2021;

-- ============================================================
-- 7. КОМПОЗИТНЫЙ ИНДЕКС
-- ============================================================

-- 7.1 Композитный индекс: equipment_id + date_id
CREATE INDEX idx_prod_equip_date
ON fact_production(equipment_id, date_id);

-- Используется для запроса с обоими условиями
EXPLAIN ANALYZE
SELECT * FROM fact_production
WHERE equipment_id = 5
  AND date_id BETWEEN 20240301 AND 20240331;

-- 7.2 Используется для запроса только с ведущим столбцом
EXPLAIN ANALYZE
SELECT * FROM fact_production
WHERE equipment_id = 5;

-- 7.3 НЕ используется для запроса без ведущего столбца
EXPLAIN ANALYZE
SELECT * FROM fact_production
WHERE date_id = 20240315;
-- Здесь будет использован idx_fact_production_date (одноколоночный)

-- 7.4 Демонстрация Bitmap Index Scan (два отдельных индекса)
EXPLAIN ANALYZE
SELECT * FROM fact_production
WHERE equipment_id = 5
  AND shift_id = 2;
-- PostgreSQL может объединить idx_fact_production_equip и idx_fact_production_shift

-- ============================================================
-- 8. ПОКРЫВАЮЩИЙ ИНДЕКС (INCLUDE)
-- ============================================================

-- 8.1 Покрывающий индекс для частого запроса
CREATE INDEX idx_prod_date_covering
ON fact_production(date_id)
INCLUDE (equipment_id, tons_mined);

-- Index Only Scan: не обращается к heap
EXPLAIN ANALYZE
SELECT date_id, equipment_id, tons_mined
FROM fact_production
WHERE date_id = 20240315;

-- 8.2 Покрывающий индекс для агрегатного запроса
CREATE INDEX idx_prod_equip_covering
ON fact_production(equipment_id)
INCLUDE (tons_mined, operating_hours);

EXPLAIN ANALYZE
SELECT equipment_id,
       SUM(tons_mined) AS total_tons,
       SUM(operating_hours) AS total_hours
FROM fact_production
WHERE equipment_id IN (1, 2, 3)
GROUP BY equipment_id;

-- ============================================================
-- 9. ТИПЫ ИНДЕКСОВ: HASH, BRIN
-- ============================================================

-- 9.1 Hash-индекс
CREATE INDEX idx_sensor_code_hash
ON dim_sensor USING hash (sensor_code);

EXPLAIN ANALYZE
SELECT * FROM dim_sensor
WHERE sensor_code = 'SENS-T-LHD01';

-- 9.2 BRIN-индекс для телеметрии
CREATE INDEX idx_telemetry_date_brin
ON fact_equipment_telemetry USING brin (date_id)
WITH (pages_per_range = 128);

EXPLAIN ANALYZE
SELECT * FROM fact_equipment_telemetry
WHERE date_id BETWEEN 20240301 AND 20240331;

-- 9.3 Сравнение размеров B-tree vs BRIN
SELECT indexrelname,
       pg_size_pretty(pg_relation_size(indexrelid)) AS size
FROM pg_stat_user_indexes
WHERE relname = 'fact_equipment_telemetry'
  AND indexrelname IN ('idx_fact_telemetry_date', 'idx_telemetry_date_brin')
ORDER BY indexrelname;

-- ============================================================
-- 10. КОМАНДА CLUSTER
-- ============================================================

-- 10.1 Кластеризовать таблицу добычи по дате
CLUSTER fact_production USING idx_fact_production_date;

-- 10.2 Проверить физический порядок
SELECT ctid, date_id, equipment_id, tons_mined
FROM fact_production
ORDER BY ctid
LIMIT 20;

-- 10.3 Обновить статистику после CLUSTER
ANALYZE fact_production;

-- 10.4 Повторная кластеризация (запоминает индекс)
-- CLUSTER fact_production;

-- ============================================================
-- 11. ОБНАРУЖЕНИЕ НЕИСПОЛЬЗУЕМЫХ ИНДЕКСОВ
-- ============================================================

-- 11.1 Индексы, которые ни разу не использовались
SELECT s.relname AS table_name,
       s.indexrelname AS index_name,
       s.idx_scan AS scan_count,
       pg_size_pretty(pg_relation_size(s.indexrelid)) AS size
FROM pg_stat_user_indexes s
JOIN pg_index i ON s.indexrelid = i.indexrelid
WHERE s.idx_scan = 0
  AND NOT i.indisunique
ORDER BY pg_relation_size(s.indexrelid) DESC;

-- 11.2 Наиболее используемые индексы
SELECT s.relname AS table_name,
       s.indexrelname AS index_name,
       s.idx_scan AS scan_count,
       s.idx_tup_read AS tuples_read,
       s.idx_tup_fetch AS tuples_fetched
FROM pg_stat_user_indexes s
WHERE s.idx_scan > 0
ORDER BY s.idx_scan DESC
LIMIT 20;

-- ============================================================
-- 12. CONCURRENTLY — создание без блокировки
-- ============================================================

-- 12.1 Создание индекса без блокировки (для продуктива)
-- Нельзя использовать внутри транзакции!
CREATE INDEX CONCURRENTLY idx_prod_location
ON fact_production(location_id);

-- ============================================================
-- 13. УДАЛЕНИЕ ИНДЕКСОВ
-- ============================================================

-- 13.1 Удаление индекса
DROP INDEX IF EXISTS idx_prod_tons_mined;
DROP INDEX IF EXISTS idx_prod_date_desc;
DROP INDEX IF EXISTS idx_prod_year_month;
DROP INDEX IF EXISTS idx_operator_lastname_lower;
DROP INDEX IF EXISTS idx_equip_commission_year;
DROP INDEX IF EXISTS idx_prod_equip_date;
DROP INDEX IF EXISTS idx_prod_date_covering;
DROP INDEX IF EXISTS idx_prod_equip_covering;
DROP INDEX IF EXISTS idx_sensor_code_hash;
DROP INDEX IF EXISTS idx_telemetry_date_brin;
DROP INDEX IF EXISTS idx_telemetry_alarm;
DROP INDEX IF EXISTS idx_downtime_unplanned;
DROP INDEX IF EXISTS idx_prod_location;

-- 13.2 Удаление с CONCURRENTLY
-- DROP INDEX CONCURRENTLY IF EXISTS idx_example;
