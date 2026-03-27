-- ============================================================
-- Модуль 9. Колоночное хранение и оптимизация аналитических запросов
-- Примеры на языке SQL (PostgreSQL)
-- Предприятие «Руда+»
-- ============================================================

-- ============================================================
-- 1. CITUS COLUMNAR: КОЛОНОЧНОЕ ХРАНЕНИЕ
-- ============================================================

-- 1.1 Установка расширения Citus (если не установлено)
CREATE EXTENSION IF NOT EXISTS citus;

-- 1.2 Создание колоночной таблицы телеметрии
CREATE TABLE fact_telemetry_columnar (
    telemetry_id    BIGINT,
    date_id         INTEGER,
    time_id         INTEGER,
    equipment_id    INTEGER,
    sensor_id       INTEGER,
    sensor_value    NUMERIC(12,4),
    quality_flag    VARCHAR(10),
    recorded_at     TIMESTAMP
) USING columnar;

-- 1.3 Загрузка данных из строковой таблицы
INSERT INTO fact_telemetry_columnar
SELECT telemetry_id, date_id, time_id, equipment_id,
       sensor_id, sensor_value, quality_flag, recorded_at
FROM fact_equipment_telemetry;

-- 1.4 Сравнение размеров строковой и колоночной таблиц
SELECT 'fact_equipment_telemetry (row)' AS table_name,
       pg_size_pretty(pg_total_relation_size('fact_equipment_telemetry')) AS total_size,
       pg_size_pretty(pg_relation_size('fact_equipment_telemetry')) AS data_size
UNION ALL
SELECT 'fact_telemetry_columnar (col)',
       pg_size_pretty(pg_total_relation_size('fact_telemetry_columnar')),
       pg_size_pretty(pg_relation_size('fact_telemetry_columnar'));

-- 1.5 Настройка сжатия для колоночной таблицы
ALTER TABLE fact_telemetry_columnar
    SET (columnar.compression = 'zstd');

-- 1.6 Просмотр параметров колоночной таблицы
SELECT * FROM columnar.options
WHERE regclass = 'fact_telemetry_columnar'::regclass;

-- 1.7 Создание колоночной таблицы добычи
CREATE TABLE fact_production_columnar (
    production_id   BIGINT,
    date_id         INTEGER,
    shift_id        INTEGER,
    equipment_id    INTEGER,
    operator_id     INTEGER,
    mine_id         INTEGER,
    location_id     INTEGER,
    tons_mined      NUMERIC(10,2),
    tons_transported NUMERIC(10,2),
    trips_count     INTEGER,
    fuel_consumed_l NUMERIC(8,2),
    operating_hours NUMERIC(6,2),
    distance_km     NUMERIC(8,2),
    avg_speed_kmh   NUMERIC(6,2)
) USING columnar;

INSERT INTO fact_production_columnar
SELECT * FROM fact_production;

-- ============================================================
-- 2. BRIN-ИНДЕКСЫ
-- ============================================================

-- 2.1 BRIN-индекс по date_id для таблицы телеметрии
CREATE INDEX idx_telemetry_date_brin
    ON fact_equipment_telemetry
    USING brin (date_id)
    WITH (pages_per_range = 32);

-- 2.2 BRIN-индекс по recorded_at
CREATE INDEX idx_telemetry_recorded_brin
    ON fact_equipment_telemetry
    USING brin (recorded_at);

-- 2.3 B-tree индекс для сравнения
CREATE INDEX idx_telemetry_date_btree
    ON fact_equipment_telemetry (date_id);

-- 2.4 Сравнение размеров индексов
SELECT indexname,
       pg_size_pretty(pg_relation_size(indexname::regclass)) AS index_size
FROM pg_indexes
WHERE tablename = 'fact_equipment_telemetry'
  AND indexname LIKE 'idx_telemetry_%'
ORDER BY pg_relation_size(indexname::regclass);

-- 2.5 Запрос с BRIN-индексом: телеметрия за январь 2024
EXPLAIN (ANALYZE, BUFFERS)
SELECT equipment_id,
       AVG(sensor_value) AS avg_value,
       MIN(sensor_value) AS min_value,
       MAX(sensor_value) AS max_value,
       COUNT(*) AS readings_count
FROM fact_equipment_telemetry
WHERE date_id BETWEEN 20240101 AND 20240131
GROUP BY equipment_id;

-- 2.6 Тот же запрос без BRIN (для сравнения)
SET enable_bitmapscan = off;

EXPLAIN (ANALYZE, BUFFERS)
SELECT equipment_id,
       AVG(sensor_value) AS avg_value,
       MIN(sensor_value) AS min_value,
       MAX(sensor_value) AS max_value,
       COUNT(*) AS readings_count
FROM fact_equipment_telemetry
WHERE date_id BETWEEN 20240101 AND 20240131
GROUP BY equipment_id;

SET enable_bitmapscan = on;

-- 2.7 BRIN для таблицы простоев
CREATE INDEX idx_downtime_date_brin
    ON fact_equipment_downtime
    USING brin (date_id)
    WITH (pages_per_range = 16);

-- ============================================================
-- 3. СЕКЦИОНИРОВАНИЕ ТАБЛИЦ (PARTITIONING)
-- ============================================================

-- 3.1 RANGE-секционирование по месяцам (телеметрия)
CREATE TABLE fact_telemetry_partitioned (
    telemetry_id    BIGINT,
    date_id         INTEGER NOT NULL,
    time_id         INTEGER,
    equipment_id    INTEGER,
    sensor_id       INTEGER,
    sensor_value    NUMERIC(12,4),
    quality_flag    VARCHAR(10),
    recorded_at     TIMESTAMP
) PARTITION BY RANGE (date_id);

-- Создание секций по месяцам
CREATE TABLE fact_telemetry_p2024_01
    PARTITION OF fact_telemetry_partitioned
    FOR VALUES FROM (20240101) TO (20240201);

CREATE TABLE fact_telemetry_p2024_02
    PARTITION OF fact_telemetry_partitioned
    FOR VALUES FROM (20240201) TO (20240301);

CREATE TABLE fact_telemetry_p2024_03
    PARTITION OF fact_telemetry_partitioned
    FOR VALUES FROM (20240301) TO (20240401);

CREATE TABLE fact_telemetry_p2024_04
    PARTITION OF fact_telemetry_partitioned
    FOR VALUES FROM (20240401) TO (20240501);

CREATE TABLE fact_telemetry_p2024_05
    PARTITION OF fact_telemetry_partitioned
    FOR VALUES FROM (20240501) TO (20240601);

CREATE TABLE fact_telemetry_p2024_06
    PARTITION OF fact_telemetry_partitioned
    FOR VALUES FROM (20240601) TO (20240701);

-- 3.2 Загрузка данных (распределяются автоматически)
INSERT INTO fact_telemetry_partitioned
SELECT telemetry_id, date_id, time_id, equipment_id,
       sensor_id, sensor_value, quality_flag, recorded_at
FROM fact_equipment_telemetry;

-- 3.3 Проверка распределения данных по секциям
SELECT tableoid::regclass AS partition_name,
       COUNT(*) AS row_count,
       MIN(date_id) AS min_date,
       MAX(date_id) AS max_date
FROM fact_telemetry_partitioned
GROUP BY tableoid
ORDER BY partition_name;

-- 3.4 Демонстрация partition pruning
EXPLAIN (ANALYZE, COSTS OFF)
SELECT equipment_id, AVG(sensor_value) AS avg_value
FROM fact_telemetry_partitioned
WHERE date_id BETWEEN 20240115 AND 20240120
GROUP BY equipment_id;

-- 3.5 LIST-секционирование по шахтам (добыча)
CREATE TABLE fact_production_by_mine (
    production_id   BIGINT,
    date_id         INTEGER NOT NULL,
    mine_id         INTEGER NOT NULL,
    shift_id        INTEGER,
    equipment_id    INTEGER,
    operator_id     INTEGER,
    location_id     INTEGER,
    tons_mined      NUMERIC(10,2),
    tons_transported NUMERIC(10,2),
    trips_count     INTEGER,
    fuel_consumed_l NUMERIC(8,2),
    operating_hours NUMERIC(6,2)
) PARTITION BY LIST (mine_id);

CREATE TABLE fact_production_mine_north
    PARTITION OF fact_production_by_mine
    FOR VALUES IN (1);

CREATE TABLE fact_production_mine_south
    PARTITION OF fact_production_by_mine
    FOR VALUES IN (2);

-- 3.6 Загрузка данных
INSERT INTO fact_production_by_mine
SELECT production_id, date_id, mine_id, shift_id, equipment_id,
       operator_id, location_id, tons_mined, tons_transported,
       trips_count, fuel_consumed_l, operating_hours
FROM fact_production;

-- 3.7 Partition pruning по шахте
EXPLAIN (ANALYZE, COSTS OFF)
SELECT date_id, SUM(tons_mined) AS total_mined
FROM fact_production_by_mine
WHERE mine_id = 1
GROUP BY date_id
ORDER BY date_id;

-- ============================================================
-- 4. КОМБИНИРОВАННЫЕ СТРАТЕГИИ
-- ============================================================

-- 4.1 Секционирование + BRIN внутри секций
-- Создаём BRIN-индекс внутри каждой секции
CREATE INDEX idx_tel_p2024_01_brin
    ON fact_telemetry_p2024_01 USING brin (recorded_at);
CREATE INDEX idx_tel_p2024_02_brin
    ON fact_telemetry_p2024_02 USING brin (recorded_at);
CREATE INDEX idx_tel_p2024_03_brin
    ON fact_telemetry_p2024_03 USING brin (recorded_at);
CREATE INDEX idx_tel_p2024_04_brin
    ON fact_telemetry_p2024_04 USING brin (recorded_at);
CREATE INDEX idx_tel_p2024_05_brin
    ON fact_telemetry_p2024_05 USING brin (recorded_at);
CREATE INDEX idx_tel_p2024_06_brin
    ON fact_telemetry_p2024_06 USING brin (recorded_at);

-- 4.2 Запрос с двойной оптимизацией (pruning + BRIN)
EXPLAIN (ANALYZE, BUFFERS)
SELECT e.equipment_name,
       AVG(t.sensor_value) AS avg_value,
       COUNT(*) AS readings
FROM fact_telemetry_partitioned t
JOIN dim_equipment e ON t.equipment_id = e.equipment_id
WHERE t.date_id BETWEEN 20240201 AND 20240315
GROUP BY e.equipment_name
ORDER BY avg_value DESC;

-- 4.3 Аналитический запрос: средняя температура ПДМ по месяцам
-- Использует partition pruning + BRIN + JOIN с измерениями
EXPLAIN (ANALYZE, BUFFERS)
SELECT m.mine_name,
       d.month_name,
       AVG(t.sensor_value) AS avg_temperature,
       MIN(t.sensor_value) AS min_temperature,
       MAX(t.sensor_value) AS max_temperature
FROM fact_telemetry_partitioned t
JOIN dim_equipment e ON t.equipment_id = e.equipment_id
JOIN dim_mine m ON e.mine_id = m.mine_id
JOIN dim_sensor s ON t.sensor_id = s.sensor_id
JOIN dim_date d ON t.date_id = d.date_id
WHERE s.sensor_type_id = 1  -- температура
  AND t.date_id BETWEEN 20240101 AND 20240331
GROUP BY m.mine_name, d.month_name, d.month
ORDER BY d.month;

-- ============================================================
-- 5. ПОЛЕЗНЫЕ ЗАПРОСЫ ДЛЯ МОНИТОРИНГА
-- ============================================================

-- 5.1 Список всех секций таблицы
SELECT parent.relname AS parent_table,
       child.relname AS partition_name,
       pg_size_pretty(pg_relation_size(child.oid)) AS partition_size
FROM pg_inherits
JOIN pg_class parent ON pg_inherits.inhparent = parent.oid
JOIN pg_class child ON pg_inherits.inhrelid = child.oid
WHERE parent.relname = 'fact_telemetry_partitioned'
ORDER BY child.relname;

-- 5.2 Все BRIN-индексы в базе данных
SELECT schemaname, tablename, indexname,
       pg_size_pretty(pg_relation_size(indexname::regclass)) AS index_size
FROM pg_indexes
WHERE indexdef LIKE '%brin%'
ORDER BY tablename, indexname;

-- 5.3 Сравнение размеров всех вариантов хранения телеметрии
SELECT 'heap (original)' AS storage_type,
       pg_size_pretty(pg_total_relation_size('fact_equipment_telemetry')) AS total_size
UNION ALL
SELECT 'columnar (Citus)',
       pg_size_pretty(pg_total_relation_size('fact_telemetry_columnar'))
UNION ALL
SELECT 'partitioned (RANGE)',
       pg_size_pretty(
           (SELECT SUM(pg_total_relation_size(child.oid))
            FROM pg_inherits
            JOIN pg_class child ON pg_inherits.inhrelid = child.oid
            JOIN pg_class parent ON pg_inherits.inhparent = parent.oid
            WHERE parent.relname = 'fact_telemetry_partitioned')
       );

-- 5.4 Статистика использования индексов
SELECT schemaname, relname, indexrelname,
       idx_scan AS index_scans,
       pg_size_pretty(pg_relation_size(indexrelid)) AS index_size
FROM pg_stat_user_indexes
WHERE relname LIKE 'fact_%telemetry%'
ORDER BY idx_scan DESC;

-- ============================================================
-- 6. СТРАТЕГИЯ «ГОРЯЧИЕ / ТЁПЛЫЕ / ХОЛОДНЫЕ» ДАННЫЕ
-- ============================================================

-- 6.1 Горячие данные (последние 3 месяца) — heap + B-tree
-- Стандартная таблица fact_equipment_telemetry с B-tree индексами
-- Быстрая вставка и обновление

-- 6.2 Тёплые данные (3-12 месяцев) — heap + BRIN
-- Секционированная таблица с BRIN-индексами
-- Только чтение, но всё ещё на heap-хранении

-- 6.3 Холодные данные (> 12 месяцев) — columnar
-- Citus Columnar: максимальное сжатие, только чтение
CREATE TABLE fact_telemetry_archive_2023 (
    telemetry_id    BIGINT,
    date_id         INTEGER,
    time_id         INTEGER,
    equipment_id    INTEGER,
    sensor_id       INTEGER,
    sensor_value    NUMERIC(12,4),
    quality_flag    VARCHAR(10),
    recorded_at     TIMESTAMP
) USING columnar;

-- Перенос старых данных в архив
INSERT INTO fact_telemetry_archive_2023
SELECT telemetry_id, date_id, time_id, equipment_id,
       sensor_id, sensor_value, quality_flag, recorded_at
FROM fact_equipment_telemetry
WHERE date_id < 20240101;

-- Удаление перенесённых данных из основной таблицы
-- DELETE FROM fact_equipment_telemetry WHERE date_id < 20240101;
-- VACUUM fact_equipment_telemetry;

-- ============================================================
-- 7. ОЧИСТКА (выполнять после завершения работы)
-- ============================================================

-- DROP TABLE IF EXISTS fact_telemetry_columnar;
-- DROP TABLE IF EXISTS fact_production_columnar;
-- DROP TABLE IF EXISTS fact_telemetry_partitioned;
-- DROP TABLE IF EXISTS fact_production_by_mine;
-- DROP TABLE IF EXISTS fact_telemetry_archive_2023;
-- DROP INDEX IF EXISTS idx_telemetry_date_brin;
-- DROP INDEX IF EXISTS idx_telemetry_recorded_brin;
-- DROP INDEX IF EXISTS idx_telemetry_date_btree;
-- DROP INDEX IF EXISTS idx_downtime_date_brin;
