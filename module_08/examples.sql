-- ============================================================
-- Модуль 8. Проектирование стратегий оптимизированных индексов
-- Примеры на языке SQL (PostgreSQL)
-- Предприятие «Руда+»
-- ============================================================
-- Структура модуля:
--   8.1. Общие подходы к проектированию индексов в реляционной СУБД
--   8.2. Обслуживание, мониторинг индексов
--        8.2.1. Коэффициент заполнения (fillfactor)
--        8.2.2. Индекс Pad
--        8.2.3. Задание коэффициента заполнения и PAD
--        8.2.4. Управление статистикой
--        8.2.5. Просмотр и анализ индексов
--   8.3. Оптимизация запросов «Руда+»
-- ============================================================


-- ============================================================
-- 1. АНАЛИЗ СУЩЕСТВУЮЩИХ ИНДЕКСОВ
-- ============================================================
-- Первый шаг при проектировании стратегии индексирования —
-- понять, какие индексы уже существуют и насколько они полезны.

-- 1.1 Список всех индексов в базе данных
-- Получаем полную картину: имя таблицы, индекса, определение и размер
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
-- Показывает, сколько раз каждый индекс реально использовался
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
-- Индексы с нулевым количеством сканирований занимают место
-- и замедляют операции INSERT/UPDATE/DELETE
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
-- Если размер индексов превышает размер таблицы — повод задуматься
SELECT
    relname AS table_name,
    pg_size_pretty(pg_total_relation_size(relid)) AS total_size,
    pg_size_pretty(pg_relation_size(relid)) AS table_size,
    pg_size_pretty(pg_total_relation_size(relid) - pg_relation_size(relid)) AS indexes_size,
    CASE
        WHEN pg_relation_size(relid) > 0
        THEN ROUND(
            100.0 * (pg_total_relation_size(relid) - pg_relation_size(relid))
            / pg_relation_size(relid), 1
        )
        ELSE 0
    END AS index_to_table_pct
FROM pg_catalog.pg_statio_user_tables
WHERE schemaname = 'public'
ORDER BY pg_total_relation_size(relid) DESC;


-- ============================================================
-- 2. СЕЛЕКТИВНОСТЬ И КАРДИНАЛЬНОСТЬ
-- ============================================================
-- Селективность столбца определяет, насколько эффективным
-- будет индекс. Высокая селективность = мало дублей = хороший индекс.

-- 2.1 Статистика столбцов таблицы fact_production из pg_stats
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

-- 2.2 Расчёт селективности вручную для ключевых столбцов
-- Селективность = COUNT(DISTINCT col) / COUNT(*)
-- Чем ближе к 1.0 — тем выше селективность
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

-- 2.3 Анализ распределения данных в столбце
-- Для оценки «перекоса» (data skew) — неравномерного распределения
SELECT
    equipment_id,
    COUNT(*) AS row_count,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) AS pct_of_total
FROM fact_production
GROUP BY equipment_id
ORDER BY row_count DESC
LIMIT 20;


-- ============================================================
-- 3. ДУБЛИРУЮЩИЕСЯ И ПЕРЕКРЫВАЮЩИЕСЯ ИНДЕКСЫ
-- ============================================================
-- Дублирующиеся и перекрывающиеся индексы — частая проблема.
-- Они расходуют дисковое пространство и замедляют запись.

-- 3.1 Поиск полностью дублирующихся индексов
-- Индексы с одинаковым определением (indexdef) на одной таблице
SELECT
    a.indexrelid::regclass AS index1,
    b.indexrelid::regclass AS index2,
    a.indrelid::regclass AS table_name,
    pg_size_pretty(pg_relation_size(a.indexrelid)) AS index1_size
FROM pg_index a
JOIN pg_index b
    ON a.indrelid = b.indrelid
   AND a.indexrelid < b.indexrelid
   AND a.indkey = b.indkey
   AND a.indclass = b.indclass
   AND a.indoption = b.indoption
WHERE a.indrelid::regclass::text LIKE '%fact_%'
   OR a.indrelid::regclass::text LIKE '%dim_%';

-- 3.2 Поиск перекрывающихся индексов (один является префиксом другого)
-- Например, idx(a) перекрывается idx(a, b) — первый можно удалить
SELECT
    pg_size_pretty(pg_relation_size(idx1.indexrelid)) AS idx1_size,
    idx1.indexrelid::regclass AS shorter_index,
    idx2.indexrelid::regclass AS longer_index,
    idx1.indrelid::regclass AS table_name
FROM pg_index idx1
JOIN pg_index idx2
    ON idx1.indrelid = idx2.indrelid
   AND idx1.indexrelid <> idx2.indexrelid
   AND idx1.indnatts < idx2.indnatts
WHERE (idx1.indkey::int2[])[1:idx1.indnatts] = (idx2.indkey::int2[])[1:idx1.indnatts]
  AND idx1.indisunique = FALSE
  AND (idx1.indrelid::regclass::text LIKE '%fact_%'
       OR idx1.indrelid::regclass::text LIKE '%dim_%')
ORDER BY table_name, shorter_index;


-- ============================================================
-- 4. КОЭФФИЦИЕНТ ЗАПОЛНЕНИЯ (FILLFACTOR)
-- ============================================================
-- Fillfactor определяет, какой процент страницы индекса (или таблицы)
-- заполняется данными при начальном построении.
-- Оставшееся место резервируется для будущих обновлений (HOT updates).
-- По умолчанию для B-tree индексов fillfactor = 90, для таблиц = 100.

-- 4.1 Создание индекса с пониженным fillfactor
-- Для часто обновляемых данных (например, телеметрия) полезно
-- оставить больше свободного места на страницах
CREATE INDEX idx_telemetry_ff70
    ON fact_equipment_telemetry(equipment_id, date_id)
    WITH (fillfactor = 70);

-- 4.2 Создание индекса со стандартным fillfactor для сравнения
CREATE INDEX idx_telemetry_ff100
    ON fact_equipment_telemetry(equipment_id, date_id)
    WITH (fillfactor = 100);

-- 4.3 Сравнение размеров индексов с разным fillfactor
SELECT
    indexname,
    pg_size_pretty(pg_relation_size(indexname::regclass)) AS index_size
FROM pg_indexes
WHERE indexname IN ('idx_telemetry_ff70', 'idx_telemetry_ff100')
ORDER BY indexname;

-- 4.4 Проверка текущего fillfactor индекса
SELECT
    c.relname AS index_name,
    COALESCE(
        (SELECT option_value
         FROM pg_options_to_table(c.reloptions)
         WHERE option_name = 'fillfactor'),
        '90'  -- значение по умолчанию для B-tree
    ) AS fillfactor
FROM pg_class c
JOIN pg_index i ON i.indexrelid = c.oid
WHERE c.relname IN ('idx_telemetry_ff70', 'idx_telemetry_ff100');

-- 4.5 Проверка заполненности страниц с помощью pgstattuple
-- (требуется расширение pgstattuple)
-- CREATE EXTENSION IF NOT EXISTS pgstattuple;
-- SELECT * FROM pgstatindex('idx_telemetry_ff70');
-- SELECT * FROM pgstatindex('idx_telemetry_ff100');

-- 4.6 Fillfactor для таблицы (влияет на HOT updates)
-- Для таблиц с частыми UPDATE полезно снизить fillfactor
ALTER TABLE fact_equipment_telemetry SET (fillfactor = 90);
-- Примечание: изменение вступит в силу при следующем VACUUM FULL или CLUSTER

-- Возвращаем fillfactor по умолчанию
ALTER TABLE fact_equipment_telemetry RESET (fillfactor);

-- Очистка
DROP INDEX IF EXISTS idx_telemetry_ff70;
DROP INDEX IF EXISTS idx_telemetry_ff100;


-- ============================================================
-- 5. УПРАВЛЕНИЕ СТАТИСТИКОЙ
-- ============================================================
-- PostgreSQL использует статистику для построения планов запросов.
-- Устаревшая или недостаточно детальная статистика приводит
-- к неоптимальным планам.

-- 5.1 Обновление статистики для таблицы
ANALYZE fact_production;

-- 5.2 Обновление статистики для конкретных столбцов
ANALYZE fact_equipment_telemetry(equipment_id, date_id, sensor_id);

-- 5.3 Просмотр статистики конкретного столбца
SELECT
    tablename,
    attname,
    null_frac,
    n_distinct,
    most_common_vals,
    most_common_freqs,
    histogram_bounds,
    correlation
FROM pg_stats
WHERE tablename = 'fact_production'
  AND attname = 'equipment_id';

-- 5.4 Просмотр гистограммы распределения значений
SELECT
    attname,
    array_length(histogram_bounds, 1) AS num_buckets,
    histogram_bounds
FROM pg_stats
WHERE tablename = 'fact_production'
  AND attname = 'date_id';

-- 5.5 Увеличение детализации статистики для столбца
-- По умолчанию default_statistics_target = 100
-- Для столбцов с неравномерным распределением полезно увеличить
ALTER TABLE fact_equipment_telemetry
    ALTER COLUMN sensor_id SET STATISTICS 500;

ALTER TABLE fact_production
    ALTER COLUMN equipment_id SET STATISTICS 300;

-- Пересобираем статистику с новым уровнем детализации
ANALYZE fact_equipment_telemetry(sensor_id);
ANALYZE fact_production(equipment_id);

-- 5.6 Проверка текущего значения statistics target
SELECT
    a.attname,
    a.attstattarget
FROM pg_attribute a
JOIN pg_class c ON c.oid = a.attrelid
WHERE c.relname = 'fact_equipment_telemetry'
  AND a.attname = 'sensor_id';
-- attstattarget = -1 означает default_statistics_target

-- 5.7 Расширенная статистика для коррелированных столбцов
-- Когда значения двух столбцов зависят друг от друга,
-- стандартная одноколоночная статистика даёт неточные оценки

-- Функциональные зависимости: mine_id -> shaft_id
CREATE STATISTICS stat_prod_mine_shaft (dependencies)
    ON mine_id, shaft_id FROM fact_production;

-- MCV (most common values) для комбинаций столбцов
CREATE STATISTICS stat_prod_equip_shift (mcv)
    ON equipment_id, shift_id FROM fact_production;

-- Обновляем статистику
ANALYZE fact_production;

-- 5.8 Просмотр расширенных статистик
SELECT
    stxname AS stat_name,
    stxrelid::regclass AS table_name,
    stxkeys,
    stxkind
FROM pg_statistic_ext
WHERE stxrelid = 'fact_production'::regclass;

-- 5.9 Просмотр данных расширенной статистики
SELECT
    stxname AS stat_name,
    stxdndistinct AS ndistinct,
    stxddependencies AS dependencies
FROM pg_statistic_ext
JOIN pg_statistic_ext_data ON pg_statistic_ext.oid = pg_statistic_ext_data.stxoid
WHERE stxrelid = 'fact_production'::regclass;

-- Возвращаем значения по умолчанию
ALTER TABLE fact_equipment_telemetry
    ALTER COLUMN sensor_id SET STATISTICS -1;
ALTER TABLE fact_production
    ALTER COLUMN equipment_id SET STATISTICS -1;
ANALYZE fact_equipment_telemetry(sensor_id);
ANALYZE fact_production(equipment_id);


-- ============================================================
-- 6. REINDEX И ОБСЛУЖИВАНИЕ
-- ============================================================
-- Со временем индексы «раздуваются» (bloat) из-за UPDATE и DELETE.
-- Регулярное обслуживание поддерживает их эффективность.

-- 6.1 Создаём тестовый индекс для демонстрации
CREATE INDEX idx_prod_date_equip_maint
    ON fact_production(date_id, equipment_id);

-- 6.2 REINDEX — пересоздание индекса (блокирует таблицу!)
REINDEX INDEX idx_prod_date_equip_maint;

-- 6.3 REINDEX CONCURRENTLY — пересоздание без блокировки (PostgreSQL 12+)
-- Создаёт новый индекс параллельно, затем подменяет старый
REINDEX INDEX CONCURRENTLY idx_prod_date_equip_maint;

-- 6.4 REINDEX всех индексов таблицы
REINDEX TABLE fact_production;

-- 6.5 REINDEX всех индексов таблицы без блокировки
REINDEX TABLE CONCURRENTLY fact_production;

-- 6.6 Оценка «раздувания» (bloat) индексов
-- Сравниваем реальный размер с ожидаемым
SELECT
    nspname || '.' || c.relname AS index_name,
    pg_size_pretty(pg_relation_size(c.oid)) AS actual_size,
    CASE
        WHEN pg_relation_size(c.oid) > 0 THEN
            ROUND(
                100.0 * (1 - (
                    (SELECT relpages FROM pg_class WHERE oid = c.oid)::numeric
                    / GREATEST(
                        CEIL(reltuples / NULLIF(
                            current_setting('block_size')::numeric / 30, 0
                        )), 1)
                )), 1
            )
        ELSE 0
    END AS estimated_bloat_pct
FROM pg_class c
JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE c.relkind = 'i'
  AND nspname = 'public'
ORDER BY pg_relation_size(c.oid) DESC
LIMIT 20;

-- 6.7 Более точная оценка bloat через pgstattuple (если доступно)
-- CREATE EXTENSION IF NOT EXISTS pgstattuple;
-- SELECT
--     indexrelid::regclass AS index_name,
--     (pgstatindex(indexrelid::regclass)).avg_leaf_density,
--     (pgstatindex(indexrelid::regclass)).leaf_fragmentation
-- FROM pg_index
-- WHERE indrelid = 'fact_production'::regclass;

-- 6.8 Поиск невалидных индексов
-- Невалидные индексы могут появиться после неудачного
-- CREATE INDEX CONCURRENTLY — их нужно пересоздать или удалить
SELECT
    indexrelid::regclass AS index_name,
    indrelid::regclass AS table_name,
    indisvalid AS is_valid,
    indisready AS is_ready
FROM pg_index
WHERE NOT indisvalid;

-- 6.9 Проверка валидности конкретного индекса
SELECT
    indexrelid::regclass AS index_name,
    indisvalid AS is_valid,
    indisready AS is_ready,
    indislive AS is_live
FROM pg_index
WHERE indexrelid = 'idx_prod_date_equip_maint'::regclass;

-- Очистка
DROP INDEX IF EXISTS idx_prod_date_equip_maint;


-- ============================================================
-- 7. МОНИТОРИНГ ИНДЕКСОВ
-- ============================================================
-- Регулярный мониторинг помогает выявить проблемы
-- и поддерживать систему в оптимальном состоянии.

-- 7.1 Неиспользуемые индексы (за период с последнего сброса статистики)
-- pg_stat_reset() сбрасывает счётчики — используйте осторожно!
SELECT
    s.indexrelname AS index_name,
    s.relname AS table_name,
    s.idx_scan AS scans_count,
    pg_size_pretty(pg_relation_size(s.indexrelid)) AS index_size,
    pg_size_pretty(pg_relation_size(s.relid)) AS table_size
FROM pg_stat_user_indexes s
WHERE s.idx_scan = 0
  AND s.schemaname = 'public'
  -- Исключаем уникальные индексы (нужны для целостности)
  AND NOT EXISTS (
      SELECT 1 FROM pg_index i
      WHERE i.indexrelid = s.indexrelid
        AND (i.indisunique OR i.indisprimary)
  )
ORDER BY pg_relation_size(s.indexrelid) DESC;

-- 7.2 Наиболее используемые индексы (Top-10)
SELECT
    s.indexrelname AS index_name,
    s.relname AS table_name,
    s.idx_scan AS scans_count,
    s.idx_tup_read AS tuples_read,
    s.idx_tup_fetch AS tuples_fetched,
    pg_size_pretty(pg_relation_size(s.indexrelid)) AS index_size
FROM pg_stat_user_indexes s
WHERE s.schemaname = 'public'
ORDER BY s.idx_scan DESC
LIMIT 10;

-- 7.3 Index Hit Ratio — процент обращений к индексам vs Seq Scan
-- Хороший показатель: > 95% для OLTP, > 80% для OLAP
SELECT
    relname AS table_name,
    seq_scan,
    idx_scan,
    CASE
        WHEN (seq_scan + idx_scan) > 0
        THEN ROUND(100.0 * idx_scan / (seq_scan + idx_scan), 2)
        ELSE 0
    END AS idx_hit_ratio_pct,
    seq_tup_read AS rows_by_seqscan,
    idx_tup_fetch AS rows_by_idxscan
FROM pg_stat_user_tables
WHERE schemaname = 'public'
ORDER BY (seq_scan + idx_scan) DESC;

-- 7.4 Cache Hit Ratio (буферный кэш)
-- Должен быть > 99% для нормальной работы
SELECT
    SUM(heap_blks_read) AS heap_blocks_read,
    SUM(heap_blks_hit) AS heap_blocks_hit,
    CASE
        WHEN SUM(heap_blks_read + heap_blks_hit) > 0
        THEN ROUND(
            100.0 * SUM(heap_blks_hit)
            / SUM(heap_blks_read + heap_blks_hit), 2
        )
        ELSE 0
    END AS cache_hit_ratio_pct
FROM pg_statio_user_tables
WHERE schemaname = 'public';

-- 7.5 Cache Hit Ratio для индексов
SELECT
    indexrelname AS index_name,
    relname AS table_name,
    idx_blks_read,
    idx_blks_hit,
    CASE
        WHEN (idx_blks_read + idx_blks_hit) > 0
        THEN ROUND(
            100.0 * idx_blks_hit / (idx_blks_read + idx_blks_hit), 2
        )
        ELSE 0
    END AS idx_cache_hit_pct
FROM pg_statio_user_indexes
WHERE schemaname = 'public'
  AND (idx_blks_read + idx_blks_hit) > 0
ORDER BY idx_cache_hit_pct ASC
LIMIT 10;

-- 7.6 Таблицы, которым больше всего не хватает индексов
-- (много Seq Scan + много строк)
SELECT
    relname AS table_name,
    seq_scan,
    seq_tup_read,
    n_live_tup AS live_rows,
    CASE
        WHEN seq_scan > 0
        THEN seq_tup_read / seq_scan
        ELSE 0
    END AS avg_rows_per_seqscan
FROM pg_stat_user_tables
WHERE schemaname = 'public'
  AND seq_scan > 0
  AND n_live_tup > 1000
ORDER BY seq_tup_read DESC
LIMIT 10;

-- 7.7 Время с последнего сброса статистики
SELECT
    stats_reset
FROM pg_stat_bgwriter;


-- ============================================================
-- 8. КОМПЛЕКСНЫЙ ПРИМЕР: ОПТИМИЗАЦИЯ ОТЧЁТА OEE
-- ============================================================
-- OEE (Overall Equipment Effectiveness) — ключевой KPI для «Руда+».
-- Покажем полный цикл: анализ запроса, создание индексов, сравнение.

-- 8.1 Исходный запрос (без оптимизации) — засекаем время
EXPLAIN (ANALYZE, BUFFERS, TIMING)
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
),
quality_data AS (
    SELECT
        q.equipment_id,
        AVG(q.fe_content) AS avg_fe_content,
        AVG(q.sio2_content) AS avg_sio2_content
    FROM fact_ore_quality q
    WHERE q.date_id BETWEEN 20240301 AND 20240331
    GROUP BY q.equipment_id
)
SELECT
    e.equipment_name,
    et.type_name,
    COALESCE(pd.total_operating_hours, 0) AS operating_hours,
    COALESCE(dd.total_downtime_hours, 0) AS downtime_hours,
    COALESCE(dd.unplanned_hours, 0) AS unplanned_downtime,
    COALESCE(pd.total_tons, 0) AS tons_mined,
    COALESCE(qd.avg_fe_content, 0) AS avg_fe_content,
    -- Расчёт компонентов OEE
    CASE
        WHEN COALESCE(pd.total_operating_hours, 0) + COALESCE(dd.total_downtime_hours, 0) > 0
        THEN ROUND(
            100.0 * COALESCE(pd.total_operating_hours, 0)
            / (COALESCE(pd.total_operating_hours, 0) + COALESCE(dd.total_downtime_hours, 0)),
            1
        )
        ELSE 0
    END AS availability_pct
FROM dim_equipment e
JOIN dim_equipment_type et ON et.equipment_type_id = e.equipment_type_id
LEFT JOIN production_data pd ON pd.equipment_id = e.equipment_id
LEFT JOIN downtime_data dd ON dd.equipment_id = e.equipment_id
LEFT JOIN quality_data qd ON qd.equipment_id = e.equipment_id
WHERE e.status = 'active'
ORDER BY e.equipment_name;

-- 8.2 Анализ: какие индексы помогут?
-- Проверяем, есть ли подходящие индексы для каждого CTE

-- Для fact_production: фильтр по date_id, группировка по equipment_id
EXPLAIN
SELECT p.equipment_id, SUM(p.operating_hours), SUM(p.tons_mined)
FROM fact_production p
WHERE p.date_id BETWEEN 20240301 AND 20240331
GROUP BY p.equipment_id;

-- Для fact_equipment_downtime: фильтр по date_id, группировка по equipment_id
EXPLAIN
SELECT fd.equipment_id, SUM(fd.duration_min)
FROM fact_equipment_downtime fd
WHERE fd.date_id BETWEEN 20240301 AND 20240331
GROUP BY fd.equipment_id;

-- Для fact_ore_quality: фильтр по date_id, группировка по equipment_id
EXPLAIN
SELECT q.equipment_id, AVG(q.fe_content)
FROM fact_ore_quality q
WHERE q.date_id BETWEEN 20240301 AND 20240331
GROUP BY q.equipment_id;

-- 8.3 Создаём оптимизирующие индексы

-- Покрывающий индекс для fact_production
-- date_id первым (фильтр по диапазону), equipment_id в INCLUDE
CREATE INDEX idx_oee_production
    ON fact_production(date_id)
    INCLUDE (equipment_id, operating_hours, tons_mined)
    WITH (fillfactor = 90);

-- Покрывающий индекс для fact_equipment_downtime
CREATE INDEX idx_oee_downtime
    ON fact_equipment_downtime(date_id)
    INCLUDE (equipment_id, duration_min, is_planned)
    WITH (fillfactor = 90);

-- Покрывающий индекс для fact_ore_quality
CREATE INDEX idx_oee_quality
    ON fact_ore_quality(date_id)
    INCLUDE (equipment_id, fe_content, sio2_content)
    WITH (fillfactor = 90);

-- Обновляем статистику и Visibility Map
ANALYZE fact_production;
ANALYZE fact_equipment_downtime;
ANALYZE fact_ore_quality;
VACUUM fact_production;
VACUUM fact_equipment_downtime;
VACUUM fact_ore_quality;

-- 8.4 Повторяем тот же запрос — сравниваем план
EXPLAIN (ANALYZE, BUFFERS, TIMING)
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
),
quality_data AS (
    SELECT
        q.equipment_id,
        AVG(q.fe_content) AS avg_fe_content,
        AVG(q.sio2_content) AS avg_sio2_content
    FROM fact_ore_quality q
    WHERE q.date_id BETWEEN 20240301 AND 20240331
    GROUP BY q.equipment_id
)
SELECT
    e.equipment_name,
    et.type_name,
    COALESCE(pd.total_operating_hours, 0) AS operating_hours,
    COALESCE(dd.total_downtime_hours, 0) AS downtime_hours,
    COALESCE(dd.unplanned_hours, 0) AS unplanned_downtime,
    COALESCE(pd.total_tons, 0) AS tons_mined,
    COALESCE(qd.avg_fe_content, 0) AS avg_fe_content,
    CASE
        WHEN COALESCE(pd.total_operating_hours, 0) + COALESCE(dd.total_downtime_hours, 0) > 0
        THEN ROUND(
            100.0 * COALESCE(pd.total_operating_hours, 0)
            / (COALESCE(pd.total_operating_hours, 0) + COALESCE(dd.total_downtime_hours, 0)),
            1
        )
        ELSE 0
    END AS availability_pct
FROM dim_equipment e
JOIN dim_equipment_type et ON et.equipment_type_id = e.equipment_type_id
LEFT JOIN production_data pd ON pd.equipment_id = e.equipment_id
LEFT JOIN downtime_data dd ON dd.equipment_id = e.equipment_id
LEFT JOIN quality_data qd ON qd.equipment_id = e.equipment_id
WHERE e.status = 'active'
ORDER BY e.equipment_name;

-- 8.5 Сводка: размеры созданных индексов
SELECT
    indexname,
    pg_size_pretty(pg_relation_size(indexname::regclass)) AS index_size
FROM pg_indexes
WHERE indexname IN ('idx_oee_production', 'idx_oee_downtime', 'idx_oee_quality')
ORDER BY indexname;


-- ============================================================
-- 9. ОЧИСТКА
-- ============================================================
-- Удаляем все индексы и статистики, созданные в ходе демонстрации

-- Индексы из раздела 8 (OEE)
DROP INDEX IF EXISTS idx_oee_production;
DROP INDEX IF EXISTS idx_oee_downtime;
DROP INDEX IF EXISTS idx_oee_quality;

-- Расширенные статистики из раздела 5
DROP STATISTICS IF EXISTS stat_prod_mine_shaft;
DROP STATISTICS IF EXISTS stat_prod_equip_shift;

-- ============================================================
-- Конец примеров модуля 8
-- ============================================================
