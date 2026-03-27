-- ============================================================
-- Модуль 8. Проектирование стратегий оптимизированных индексов
-- Примеры на языке SQL (PostgreSQL)
-- Предприятие «Руда+»
-- ============================================================

-- ============================================================
-- 1. АНАЛИЗ СУЩЕСТВУЮЩИХ ИНДЕКСОВ
-- ============================================================

-- 1.1 Список всех индексов в базе данных
SELECT
    schemaname,
    tablename,
    indexname,
    indexdef,
    pg_size_pretty(pg_relation_size(indexname::regclass)) AS index_size
FROM pg_indexes
WHERE schemaname = 'public'
ORDER BY tablename, indexname;

-- 1.2 Статистика использования индексов
SELECT
    schemaname || '.' || relname AS table_name,
    indexrelname AS index_name,
    idx_scan AS index_scans,
    idx_tup_read AS tuples_read,
    idx_tup_fetch AS tuples_fetched,
    pg_size_pretty(pg_relation_size(indexrelid)) AS index_size
FROM pg_stat_user_indexes
WHERE schemaname = 'public'
ORDER BY idx_scan DESC;

-- 1.3 Неиспользуемые индексы (кандидаты на удаление)
SELECT
    indexrelname AS index_name,
    relname AS table_name,
    idx_scan AS scans,
    pg_size_pretty(pg_relation_size(indexrelid)) AS size
FROM pg_stat_user_indexes
WHERE idx_scan = 0
  AND schemaname = 'public'
ORDER BY pg_relation_size(indexrelid) DESC;

-- 1.4 Соотношение размеров таблиц и индексов
SELECT
    relname AS table_name,
    pg_size_pretty(pg_total_relation_size(relid)) AS total_size,
    pg_size_pretty(pg_relation_size(relid)) AS table_size,
    pg_size_pretty(pg_total_relation_size(relid) - pg_relation_size(relid)) AS indexes_size
FROM pg_catalog.pg_statio_user_tables
WHERE schemaname = 'public'
ORDER BY pg_total_relation_size(relid) DESC;


-- ============================================================
-- 2. СЕЛЕКТИВНОСТЬ И КАРДИНАЛЬНОСТЬ
-- ============================================================

-- 2.1 Статистика столбцов таблицы fact_production
SELECT
    attname AS column_name,
    n_distinct,
    null_frac,
    correlation,
    most_common_vals::text AS common_values,
    most_common_freqs::text AS common_freqs
FROM pg_stats
WHERE tablename = 'fact_production'
ORDER BY attname;

-- 2.2 Расчёт селективности вручную
SELECT
    'equipment_id' AS column_name,
    COUNT(DISTINCT equipment_id) AS unique_values,
    COUNT(*) AS total_rows,
    ROUND(COUNT(DISTINCT equipment_id)::numeric / COUNT(*)::numeric, 6) AS selectivity
FROM fact_production
UNION ALL
SELECT
    'mine_id',
    COUNT(DISTINCT mine_id),
    COUNT(*),
    ROUND(COUNT(DISTINCT mine_id)::numeric / COUNT(*)::numeric, 6)
FROM fact_production
UNION ALL
SELECT
    'date_id',
    COUNT(DISTINCT date_id),
    COUNT(*),
    ROUND(COUNT(DISTINCT date_id)::numeric / COUNT(*)::numeric, 6)
FROM fact_production
UNION ALL
SELECT
    'shift_id',
    COUNT(DISTINCT shift_id),
    COUNT(*),
    ROUND(COUNT(DISTINCT shift_id)::numeric / COUNT(*)::numeric, 6)
FROM fact_production
ORDER BY selectivity DESC;


-- ============================================================
-- 3. EXPLAIN — ВАРИАНТЫ И ПРИМЕРЫ
-- ============================================================

-- 3.1 Простой EXPLAIN (оценочный план, запрос НЕ выполняется)
EXPLAIN
SELECT *
FROM fact_production
WHERE equipment_id = 5;

-- 3.2 EXPLAIN ANALYZE (реальный план, запрос ВЫПОЛНЯЕТСЯ)
EXPLAIN ANALYZE
SELECT *
FROM fact_production
WHERE equipment_id = 5;

-- 3.3 EXPLAIN с буферами (информация о I/O)
EXPLAIN (ANALYZE, BUFFERS)
SELECT *
FROM fact_production
WHERE equipment_id = 5;

-- 3.4 EXPLAIN в формате JSON (удобно для программной обработки)
EXPLAIN (ANALYZE, BUFFERS, FORMAT JSON)
SELECT *
FROM fact_production
WHERE equipment_id = 5;

-- 3.5 EXPLAIN в формате YAML
EXPLAIN (ANALYZE, BUFFERS, FORMAT YAML)
SELECT *
FROM fact_production
WHERE equipment_id = 5;

-- 3.6 Безопасный EXPLAIN ANALYZE для UPDATE/DELETE
BEGIN;
EXPLAIN ANALYZE
DELETE FROM fact_production WHERE production_id = -1;
ROLLBACK;


-- ============================================================
-- 4. ТИПЫ СКАНИРОВАНИЯ
-- ============================================================

-- 4.1 Seq Scan — полное сканирование таблицы
-- Когда нет индекса или нужно большинство строк
EXPLAIN ANALYZE
SELECT *
FROM fact_production;

-- 4.2 Index Scan — поиск по индексу + чтение из таблицы
EXPLAIN ANALYZE
SELECT *
FROM fact_production
WHERE equipment_id = 5;

-- 4.3 Bitmap Index Scan — промежуточный вариант
EXPLAIN ANALYZE
SELECT *
FROM fact_equipment_downtime
WHERE date_id BETWEEN 20240101 AND 20240331;

-- 4.4 Index Only Scan — все данные из индекса
-- Сначала создадим покрывающий индекс
CREATE INDEX idx_demo_covering
    ON fact_production(equipment_id, date_id)
    INCLUDE (tons_mined);

-- Обновим Visibility Map
VACUUM fact_production;

-- Запрос, который может использовать Index Only Scan
EXPLAIN (ANALYZE, BUFFERS)
SELECT date_id, tons_mined
FROM fact_production
WHERE equipment_id = 5;
-- Обратите внимание на Heap Fetches: 0

-- Очистка
DROP INDEX idx_demo_covering;


-- ============================================================
-- 5. ТИПЫ СОЕДИНЕНИЙ
-- ============================================================

-- 5.1 Nested Loop (маленькая внешняя таблица + индекс)
EXPLAIN ANALYZE
SELECT e.equipment_name, p.tons_mined
FROM dim_equipment e
JOIN fact_production p ON p.equipment_id = e.equipment_id
WHERE e.equipment_id = 5
  AND p.date_id = 20240315;

-- 5.2 Hash Join (средние таблицы, без подходящего индекса)
EXPLAIN ANALYZE
SELECT d.full_date, SUM(p.tons_mined)
FROM fact_production p
JOIN dim_date d ON d.date_id = p.date_id
WHERE d.year = 2024 AND d.quarter = 1
GROUP BY d.full_date;

-- 5.3 Merge Join (обе таблицы большие, отсортированы)
-- PostgreSQL выбирает Merge Join, если данные уже отсортированы
EXPLAIN ANALYZE
SELECT p.production_id, fd.downtime_id
FROM fact_production p
JOIN fact_equipment_downtime fd
    ON fd.equipment_id = p.equipment_id
   AND fd.date_id = p.date_id;


-- ============================================================
-- 6. ПОКРЫВАЮЩИЕ ИНДЕКСЫ (INCLUDE)
-- ============================================================

-- 6.1 Запрос без покрывающего индекса
EXPLAIN (ANALYZE, BUFFERS)
SELECT date_id,
       SUM(tons_mined) AS total_tons,
       SUM(trips_count) AS total_trips
FROM fact_production
WHERE equipment_id = 5
  AND date_id BETWEEN 20240101 AND 20240331
GROUP BY date_id
ORDER BY date_id;

-- 6.2 Создаём покрывающий индекс
CREATE INDEX idx_prod_equip_date_cover
    ON fact_production(equipment_id, date_id)
    INCLUDE (tons_mined, trips_count);

-- Обновляем VM для Index Only Scan
VACUUM fact_production;

-- 6.3 Тот же запрос — теперь Index Only Scan
EXPLAIN (ANALYZE, BUFFERS)
SELECT date_id,
       SUM(tons_mined) AS total_tons,
       SUM(trips_count) AS total_trips
FROM fact_production
WHERE equipment_id = 5
  AND date_id BETWEEN 20240101 AND 20240331
GROUP BY date_id
ORDER BY date_id;

-- Очистка
DROP INDEX idx_prod_equip_date_cover;


-- ============================================================
-- 7. ЧАСТИЧНЫЕ ИНДЕКСЫ (PARTIAL INDEXES)
-- ============================================================

-- 7.1 Внеплановые простои — частый аналитический запрос
EXPLAIN (ANALYZE, BUFFERS)
SELECT fd.date_id, e.equipment_name, dr.reason_name, fd.duration_min
FROM fact_equipment_downtime fd
JOIN dim_equipment e ON e.equipment_id = fd.equipment_id
JOIN dim_downtime_reason dr ON dr.reason_id = fd.reason_id
WHERE fd.is_planned = FALSE
  AND fd.date_id BETWEEN 20240301 AND 20240331
ORDER BY fd.duration_min DESC;

-- 7.2 Создаём частичный индекс (только внеплановые)
CREATE INDEX idx_downtime_unplanned
    ON fact_equipment_downtime(date_id, equipment_id, reason_id)
    INCLUDE (duration_min)
    WHERE is_planned = FALSE;

-- 7.3 Повторяем — видим улучшение
EXPLAIN (ANALYZE, BUFFERS)
SELECT fd.date_id, e.equipment_name, dr.reason_name, fd.duration_min
FROM fact_equipment_downtime fd
JOIN dim_equipment e ON e.equipment_id = fd.equipment_id
JOIN dim_downtime_reason dr ON dr.reason_id = fd.reason_id
WHERE fd.is_planned = FALSE
  AND fd.date_id BETWEEN 20240301 AND 20240331
ORDER BY fd.duration_min DESC;

-- 7.4 Сравнение размеров: частичный vs полный
SELECT pg_size_pretty(pg_relation_size('idx_downtime_unplanned')) AS partial_size;

CREATE INDEX idx_downtime_full
    ON fact_equipment_downtime(date_id, equipment_id, reason_id)
    INCLUDE (duration_min);

SELECT pg_size_pretty(pg_relation_size('idx_downtime_full')) AS full_size;

-- Очистка
DROP INDEX idx_downtime_unplanned;
DROP INDEX idx_downtime_full;


-- ============================================================
-- 8. ИНДЕКСЫ НА ВЫРАЖЕНИЯХ
-- ============================================================

-- 8.1 Обычный индекс НЕ работает для выражения
EXPLAIN ANALYZE
SELECT *
FROM fact_equipment_downtime
WHERE duration_min / 60.0 > 2;

-- 8.2 Создаём индекс на выражении
CREATE INDEX idx_downtime_hours_expr
    ON fact_equipment_downtime((duration_min / 60.0));

-- 8.3 Теперь индекс используется
EXPLAIN ANALYZE
SELECT *
FROM fact_equipment_downtime
WHERE duration_min / 60.0 > 2;

-- 8.4 Индекс на LOWER() — поиск без учёта регистра
CREATE INDEX idx_equip_name_lower
    ON dim_equipment(LOWER(equipment_name));

EXPLAIN ANALYZE
SELECT *
FROM dim_equipment
WHERE LOWER(equipment_name) LIKE '%северная%';

-- Очистка
DROP INDEX idx_downtime_hours_expr;
DROP INDEX idx_equip_name_lower;


-- ============================================================
-- 9. СОСТАВНЫЕ ИНДЕКСЫ: ПОРЯДОК СТОЛБЦОВ
-- ============================================================

-- 9.1 Запрос: конкретное оборудование, диапазон дат, сортировка по времени
EXPLAIN (ANALYZE, BUFFERS)
SELECT sensor_id, sensor_value, is_alarm
FROM fact_equipment_telemetry
WHERE equipment_id = 7
  AND date_id BETWEEN 20240301 AND 20240331
ORDER BY time_id;

-- 9.2 Вариант A: equality, range, sort (ОПТИМАЛЬНЫЙ)
CREATE INDEX idx_telemetry_a
    ON fact_equipment_telemetry(equipment_id, date_id, time_id);

EXPLAIN (ANALYZE, BUFFERS)
SELECT sensor_id, sensor_value, is_alarm
FROM fact_equipment_telemetry
WHERE equipment_id = 7
  AND date_id BETWEEN 20240301 AND 20240331
ORDER BY time_id;

DROP INDEX idx_telemetry_a;

-- 9.3 Вариант B: range первым (МЕНЕЕ ОПТИМАЛЬНЫЙ)
CREATE INDEX idx_telemetry_b
    ON fact_equipment_telemetry(date_id, equipment_id, time_id);

EXPLAIN (ANALYZE, BUFFERS)
SELECT sensor_id, sensor_value, is_alarm
FROM fact_equipment_telemetry
WHERE equipment_id = 7
  AND date_id BETWEEN 20240301 AND 20240331
ORDER BY time_id;

DROP INDEX idx_telemetry_b;


-- ============================================================
-- 10. BRIN-ИНДЕКСЫ
-- ============================================================

-- 10.1 Проверяем корреляцию (физическую упорядоченность)
SELECT attname, correlation
FROM pg_stats
WHERE tablename = 'fact_equipment_telemetry'
  AND attname = 'date_id';

-- 10.2 Создаём BRIN-индекс
CREATE INDEX idx_telemetry_date_brin
    ON fact_equipment_telemetry USING BRIN (date_id)
    WITH (pages_per_range = 64);

-- 10.3 Создаём B-tree для сравнения
CREATE INDEX idx_telemetry_date_btree
    ON fact_equipment_telemetry(date_id);

-- 10.4 Сравниваем размеры
SELECT
    'BRIN' AS type,
    pg_size_pretty(pg_relation_size('idx_telemetry_date_brin')) AS size
UNION ALL
SELECT
    'B-tree',
    pg_size_pretty(pg_relation_size('idx_telemetry_date_btree'));

-- 10.5 Сравниваем планы
EXPLAIN (ANALYZE, BUFFERS)
SELECT * FROM fact_equipment_telemetry WHERE date_id = 20240315;

-- Очистка
DROP INDEX idx_telemetry_date_brin;
DROP INDEX idx_telemetry_date_btree;


-- ============================================================
-- 11. УПРАВЛЕНИЕ ИНДЕКСАМИ
-- ============================================================

-- 11.1 CREATE INDEX CONCURRENTLY (без блокировки записи)
CREATE INDEX CONCURRENTLY idx_prod_date_concurrent
    ON fact_production(date_id, equipment_id);

-- 11.2 Проверка валидности индекса
SELECT
    indexrelid::regclass AS index_name,
    indisvalid AS is_valid,
    indisready AS is_ready
FROM pg_index
WHERE indexrelid = 'idx_prod_date_concurrent'::regclass;

-- 11.3 REINDEX — пересоздание раздувшегося индекса
REINDEX INDEX idx_prod_date_concurrent;

-- 11.4 REINDEX CONCURRENTLY (PostgreSQL 12+)
REINDEX INDEX CONCURRENTLY idx_prod_date_concurrent;

-- 11.5 Поиск невалидных индексов
SELECT indexrelid::regclass AS index_name, indisvalid
FROM pg_index
WHERE NOT indisvalid;

-- Очистка
DROP INDEX IF EXISTS idx_prod_date_concurrent;


-- ============================================================
-- 12. СТАТИСТИКА И КОМАНДА ANALYZE
-- ============================================================

-- 12.1 Просмотр статистики конкретного столбца
SELECT
    tablename,
    attname,
    null_frac,
    n_distinct,
    most_common_vals,
    most_common_freqs,
    correlation
FROM pg_stats
WHERE tablename = 'fact_production'
  AND attname = 'equipment_id';

-- 12.2 Обновление статистики
ANALYZE fact_production;
ANALYZE fact_equipment_telemetry(equipment_id, date_id, sensor_id);

-- 12.3 Увеличение детализации статистики
ALTER TABLE fact_equipment_telemetry
    ALTER COLUMN sensor_id SET STATISTICS 500;
ANALYZE fact_equipment_telemetry(sensor_id);

-- 12.4 Расширенная статистика для коррелированных столбцов
CREATE STATISTICS stat_prod_mine_shaft (dependencies)
    ON mine_id, shaft_id FROM fact_production;
ANALYZE fact_production;

-- Просмотр расширенных статистик
SELECT stxname, stxkeys, stxkind
FROM pg_statistic_ext
WHERE stxrelid = 'fact_production'::regclass;

-- Очистка
DROP STATISTICS IF EXISTS stat_prod_mine_shaft;


-- ============================================================
-- 13. КОМПЛЕКСНЫЙ ПРИМЕР: ОПТИМИЗАЦИЯ ОТЧЁТА OEE
-- ============================================================

-- 13.1 Исходный запрос (без оптимизации)
EXPLAIN (ANALYZE, BUFFERS)
WITH production_data AS (
    SELECT
        p.equipment_id,
        SUM(p.operating_hours) AS total_operating_hours,
        SUM(p.tons_mined) AS total_tons
    FROM fact_production p
    WHERE p.date_id BETWEEN 20240301 AND 20240331
    GROUP BY p.equipment_id
),
downtime_data AS (
    SELECT
        fd.equipment_id,
        SUM(fd.duration_min) / 60.0 AS total_downtime_hours,
        SUM(CASE WHEN fd.is_planned = FALSE THEN fd.duration_min ELSE 0 END) / 60.0 AS unplanned_hours
    FROM fact_equipment_downtime fd
    WHERE fd.date_id BETWEEN 20240301 AND 20240331
    GROUP BY fd.equipment_id
)
SELECT
    e.equipment_name,
    et.type_name,
    COALESCE(pd.total_operating_hours, 0) AS operating_hours,
    COALESCE(dd.total_downtime_hours, 0) AS downtime_hours,
    COALESCE(dd.unplanned_hours, 0) AS unplanned_downtime,
    COALESCE(pd.total_tons, 0) AS tons_mined
FROM dim_equipment e
JOIN dim_equipment_type et ON et.equipment_type_id = e.equipment_type_id
LEFT JOIN production_data pd ON pd.equipment_id = e.equipment_id
LEFT JOIN downtime_data dd ON dd.equipment_id = e.equipment_id
WHERE e.status = 'active'
ORDER BY e.equipment_name;

-- 13.2 Создаём оптимизирующие индексы
CREATE INDEX idx_prod_date_equip_cover
    ON fact_production(date_id, equipment_id)
    INCLUDE (operating_hours, tons_mined);

CREATE INDEX idx_downtime_date_equip_cover
    ON fact_equipment_downtime(date_id, equipment_id)
    INCLUDE (duration_min, is_planned);

-- 13.3 Повторяем запрос — сравниваем
EXPLAIN (ANALYZE, BUFFERS)
WITH production_data AS (
    SELECT
        p.equipment_id,
        SUM(p.operating_hours) AS total_operating_hours,
        SUM(p.tons_mined) AS total_tons
    FROM fact_production p
    WHERE p.date_id BETWEEN 20240301 AND 20240331
    GROUP BY p.equipment_id
),
downtime_data AS (
    SELECT
        fd.equipment_id,
        SUM(fd.duration_min) / 60.0 AS total_downtime_hours,
        SUM(CASE WHEN fd.is_planned = FALSE THEN fd.duration_min ELSE 0 END) / 60.0 AS unplanned_hours
    FROM fact_equipment_downtime fd
    WHERE fd.date_id BETWEEN 20240301 AND 20240331
    GROUP BY fd.equipment_id
)
SELECT
    e.equipment_name,
    et.type_name,
    COALESCE(pd.total_operating_hours, 0) AS operating_hours,
    COALESCE(dd.total_downtime_hours, 0) AS downtime_hours,
    COALESCE(dd.unplanned_hours, 0) AS unplanned_downtime,
    COALESCE(pd.total_tons, 0) AS tons_mined
FROM dim_equipment e
JOIN dim_equipment_type et ON et.equipment_type_id = e.equipment_type_id
LEFT JOIN production_data pd ON pd.equipment_id = e.equipment_id
LEFT JOIN downtime_data dd ON dd.equipment_id = e.equipment_id
WHERE e.status = 'active'
ORDER BY e.equipment_name;

-- 13.4 Очистка демонстрационных индексов
DROP INDEX IF EXISTS idx_prod_date_equip_cover;
DROP INDEX IF EXISTS idx_downtime_date_equip_cover;
