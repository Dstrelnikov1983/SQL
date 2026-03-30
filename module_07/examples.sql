-- ============================================================
-- Модуль 7. Введение в индексы
-- Примеры на языке SQL (PostgreSQL)
-- Предприятие «Руда+»
-- ============================================================
-- Структура модуля:
--   7.1  Планы выполнения запросов
--   7.2  Зачем нужны индексы? Избирательность, плотность, глубина
--   7.3  Как PostgreSQL хранит данные
--   7.4  Типы индексов в PostgreSQL
--   7.5  B-tree индекс (подробно)
--   7.6  Влияние индексов на INSERT/UPDATE/DELETE
-- ============================================================


-- ############################################################
-- 7.1  ПЛАНЫ ВЫПОЛНЕНИЯ ЗАПРОСОВ
-- ############################################################

-- ------------------------------------------------------------
-- 7.1.1  EXPLAIN — показать план без выполнения запроса
-- ------------------------------------------------------------
-- Просто покажет, какой план выбрал оптимизатор.
-- Запрос НЕ выполняется — безопасно для тяжёлых операций.

EXPLAIN
SELECT *
FROM fact_production
WHERE date_id = 20240315;

-- ------------------------------------------------------------
-- 7.1.2  EXPLAIN ANALYZE — план + реальная статистика
-- ------------------------------------------------------------
-- Запрос ДЕЙСТВИТЕЛЬНО выполняется!
-- Мы увидим: actual time, rows, loops.

EXPLAIN ANALYZE
SELECT *
FROM fact_production
WHERE date_id = 20240315;

-- ------------------------------------------------------------
-- 7.1.3  EXPLAIN (ANALYZE, BUFFERS) — план + буферы
-- ------------------------------------------------------------
-- Показывает количество страниц, прочитанных из кэша (shared hit)
-- и с диска (shared read). Помогает оценить I/O-нагрузку.

EXPLAIN (ANALYZE, BUFFERS)
SELECT *
FROM fact_production
WHERE equipment_id = 3
  AND date_id BETWEEN 20240301 AND 20240331;

-- ------------------------------------------------------------
-- 7.1.4  EXPLAIN в формате JSON — удобно для программного разбора
-- ------------------------------------------------------------

EXPLAIN (FORMAT JSON)
SELECT fp.date_id, de.equipment_name, fp.tons_mined
FROM fact_production fp
JOIN dim_equipment de ON fp.equipment_id = de.equipment_id
WHERE fp.mine_id = 1;

-- ------------------------------------------------------------
-- 7.1.5  EXPLAIN в формате YAML — человекочитаемый формат
-- ------------------------------------------------------------

EXPLAIN (FORMAT YAML)
SELECT date_id, SUM(tons_mined) AS total_tons
FROM fact_production
WHERE mine_id = 1
GROUP BY date_id
ORDER BY date_id;

-- ------------------------------------------------------------
-- 7.1.6  Безопасный EXPLAIN для DELETE (без реального удаления)
-- ------------------------------------------------------------
-- Оборачиваем в транзакцию и откатываем,
-- чтобы увидеть план DELETE, не удаляя данные.

BEGIN;

EXPLAIN ANALYZE
DELETE FROM fact_production
WHERE date_id < 20240101;

ROLLBACK;  -- данные остались на месте!

-- ------------------------------------------------------------
-- 7.1.7  EXPLAIN для сложного аналитического запроса
-- ------------------------------------------------------------
-- Суммарная добыча по шахтам за март 2024 — типичный отчёт MES

EXPLAIN (ANALYZE, BUFFERS, COSTS)
SELECT dm.mine_name,
       SUM(fp.tons_mined)        AS total_mined,
       SUM(fp.tons_transported)   AS total_transported,
       ROUND(AVG(fp.fuel_consumed_l), 2) AS avg_fuel
FROM fact_production fp
JOIN dim_mine dm ON fp.mine_id = dm.mine_id
WHERE fp.date_id BETWEEN 20240301 AND 20240331
GROUP BY dm.mine_name
ORDER BY total_mined DESC;


-- ############################################################
-- 7.2  ЗАЧЕМ НУЖНЫ ИНДЕКСЫ? ИЗБИРАТЕЛЬНОСТЬ, ПЛОТНОСТЬ, ГЛУБИНА
-- ############################################################

-- ------------------------------------------------------------
-- 7.2.1  Избирательность (Selectivity) столбца
-- ------------------------------------------------------------
-- Избирательность = количество уникальных значений / общее количество строк.
-- Чем ближе к 1 — тем выгоднее индексировать столбец.

-- Избирательность ключевых столбцов таблицы fact_production
SELECT
    'equipment_id' AS column_name,
    COUNT(DISTINCT equipment_id)::numeric / COUNT(*)::numeric AS selectivity
FROM fact_production
UNION ALL
SELECT
    'date_id',
    COUNT(DISTINCT date_id)::numeric / COUNT(*)::numeric
FROM fact_production
UNION ALL
SELECT
    'mine_id',
    COUNT(DISTINCT mine_id)::numeric / COUNT(*)::numeric
FROM fact_production
UNION ALL
SELECT
    'shift_id',
    COUNT(DISTINCT shift_id)::numeric / COUNT(*)::numeric
FROM fact_production
UNION ALL
SELECT
    'operator_id',
    COUNT(DISTINCT operator_id)::numeric / COUNT(*)::numeric
FROM fact_production
ORDER BY selectivity DESC;

-- ------------------------------------------------------------
-- 7.2.2  Плотность (Density) = 1 / количество уникальных значений
-- ------------------------------------------------------------
-- Показывает, какую долю таблицы в среднем вернёт фильтр по
-- конкретному значению столбца.

SELECT
    'equipment_id' AS column_name,
    COUNT(DISTINCT equipment_id) AS n_distinct,
    1.0 / COUNT(DISTINCT equipment_id) AS density,
    COUNT(*) AS total_rows,
    ROUND(COUNT(*)::numeric / COUNT(DISTINCT equipment_id), 0) AS avg_rows_per_value
FROM fact_production;

-- ------------------------------------------------------------
-- 7.2.3  Оценка глубины B-tree индекса
-- ------------------------------------------------------------
-- Формула: depth ≈ ceil(log(fan_out, num_rows))
-- Для типичного B-tree в PostgreSQL fan_out ≈ 300–500.
-- Демонстрируем расчёт для наших таблиц.

SELECT relname                             AS table_name,
       reltuples::bigint                   AS est_rows,
       CEIL(LOG(400, GREATEST(reltuples, 1))) AS est_btree_depth
FROM pg_class
WHERE relname IN ('fact_production', 'fact_equipment_telemetry',
                  'fact_equipment_downtime', 'fact_ore_quality',
                  'dim_equipment', 'dim_operator')
ORDER BY reltuples DESC;

-- ------------------------------------------------------------
-- 7.2.4  Статистика из pg_stats — что знает планировщик
-- ------------------------------------------------------------

SELECT attname        AS column_name,
       n_distinct,
       correlation,         -- физическая упорядоченность
       most_common_vals,
       most_common_freqs
FROM pg_stats
WHERE tablename = 'fact_production'
  AND attname IN ('date_id', 'equipment_id', 'mine_id', 'shift_id');


-- ############################################################
-- 7.3  КАК POSTGRESQL ХРАНИТ ДАННЫЕ
-- ############################################################

-- ------------------------------------------------------------
-- 7.3.1  Физический адрес строки — ctid (page, offset)
-- ------------------------------------------------------------
-- ctid = (номер_страницы, номер_строки_на_странице)
-- Каждая страница = 8 КБ

SELECT ctid, equipment_id, equipment_name
FROM dim_equipment
ORDER BY ctid
LIMIT 10;

-- ------------------------------------------------------------
-- 7.3.2  ctid в таблице фактов — видим распределение по страницам
-- ------------------------------------------------------------

SELECT ctid,
       date_id,
       equipment_id,
       tons_mined
FROM fact_production
ORDER BY ctid
LIMIT 20;

-- ------------------------------------------------------------
-- 7.3.3  Количество страниц и размер таблиц
-- ------------------------------------------------------------

SELECT relname                                      AS table_name,
       relpages                                     AS pages_8kb,
       pg_size_pretty(relpages::bigint * 8192)      AS table_size,
       reltuples::bigint                            AS est_rows
FROM pg_class
WHERE relname IN ('fact_production', 'fact_equipment_telemetry',
                  'fact_equipment_downtime', 'fact_ore_quality')
ORDER BY relpages DESC;

-- ------------------------------------------------------------
-- 7.3.4  Размер таблицы vs размер индексов
-- ------------------------------------------------------------

SELECT pg_size_pretty(pg_table_size('fact_production'))          AS table_size,
       pg_size_pretty(pg_indexes_size('fact_production'))        AS indexes_size,
       pg_size_pretty(pg_total_relation_size('fact_production')) AS total_size;

-- ------------------------------------------------------------
-- 7.3.5  Sequential Scan — полное чтение таблицы
-- ------------------------------------------------------------
-- Без подходящего индекса PostgreSQL читает ВСЕ страницы.

EXPLAIN ANALYZE
SELECT *
FROM fact_production
WHERE tons_mined > 150;

-- Ещё пример: фильтрация по неиндексированному столбцу
EXPLAIN ANALYZE
SELECT *
FROM fact_production
WHERE fuel_consumed_l > 50;

-- Seq Scan по таблице телеметрии (большая таблица!)
EXPLAIN (ANALYZE, BUFFERS)
SELECT *
FROM fact_equipment_telemetry
WHERE sensor_value > 90;


-- ############################################################
-- 7.4  ТИПЫ ИНДЕКСОВ В POSTGRESQL
-- ############################################################

-- ============================================================
-- 7.4.1  HASH-индекс
-- ============================================================
-- Подходит ТОЛЬКО для точного равенства (=).
-- Не поддерживает: <, >, BETWEEN, ORDER BY, IS NULL.

CREATE INDEX idx_sensor_code_hash
ON dim_sensor USING hash (sensor_code);

-- Hash-индекс используется:
EXPLAIN ANALYZE
SELECT * FROM dim_sensor
WHERE sensor_code = 'SENS-T-LHD01';

-- Hash-индекс НЕ используется для диапазона:
EXPLAIN ANALYZE
SELECT * FROM dim_sensor
WHERE sensor_code > 'SENS-T';

-- ============================================================
-- 7.4.2  BRIN-индекс (Block Range INdex)
-- ============================================================
-- Очень компактный индекс, хранит MIN/MAX для блоков страниц.
-- Эффективен для столбцов с высокой корреляцией
-- (физический порядок данных совпадает с логическим).
-- Идеален для телеметрии (данные приходят хронологически).

CREATE INDEX idx_telemetry_date_brin
ON fact_equipment_telemetry USING brin (date_id)
WITH (pages_per_range = 128);

-- BRIN-индекс используется:
EXPLAIN ANALYZE
SELECT * FROM fact_equipment_telemetry
WHERE date_id BETWEEN 20240301 AND 20240331;

-- Сравнение размеров: B-tree vs BRIN
SELECT indexrelname                                        AS index_name,
       pg_size_pretty(pg_relation_size(indexrelid))        AS size
FROM pg_stat_user_indexes
WHERE relname = 'fact_equipment_telemetry'
  AND indexrelname IN ('idx_fact_telemetry_date', 'idx_telemetry_date_brin')
ORDER BY pg_relation_size(indexrelid) DESC;

-- ============================================================
-- 7.4.3  GiST-индекс (Generalized Search Tree) — краткий обзор
-- ============================================================
-- Используется для: геометрических данных, полнотекстового поиска,
-- range-типов, нечёткого поиска.
-- Пример: поиск зон в шахте по координатам (если бы хранили геометрию).

-- Допустим, у нас есть таблица зон шахты с координатами:
-- CREATE TABLE mine_zones (
--     zone_id     SERIAL PRIMARY KEY,
--     zone_name   TEXT,
--     zone_area   BOX   -- прямоугольная зона
-- );
-- CREATE INDEX idx_zones_area_gist ON mine_zones USING gist (zone_area);
-- SELECT * FROM mine_zones WHERE zone_area @> point(100, 200);

-- Реальный пример с range-типом для интервалов смен:
-- CREATE INDEX idx_shift_range_gist
-- ON dim_shift USING gist (tsrange(shift_start, shift_end));

-- ============================================================
-- 7.4.4  GIN-индекс (Generalized Inverted Index) — краткий обзор
-- ============================================================
-- Используется для: массивов, JSONB, полнотекстового поиска (tsvector).
-- Пример: поиск по тегам оборудования или по JSONB-полям.

-- Допустим, dim_equipment хранит теги в массиве:
-- ALTER TABLE dim_equipment ADD COLUMN tags TEXT[];
-- CREATE INDEX idx_equip_tags_gin ON dim_equipment USING gin (tags);
-- SELECT * FROM dim_equipment WHERE tags @> ARRAY['underground', 'LHD'];

-- Пример для JSONB-параметров датчиков:
-- ALTER TABLE dim_sensor ADD COLUMN params JSONB;
-- CREATE INDEX idx_sensor_params_gin ON dim_sensor USING gin (params);
-- SELECT * FROM dim_sensor WHERE params @> '{"unit": "°C"}';


-- ############################################################
-- 7.5  B-TREE ИНДЕКС (ПОДРОБНО)
-- ############################################################

-- ============================================================
-- 7.5.1  Простой B-tree индекс
-- ============================================================

-- Индекс на тоннаж добычи — для быстрого поиска по объёму
CREATE INDEX idx_prod_tons_mined
ON fact_production(tons_mined);

-- Проверяем: теперь должен быть Index Scan (или Bitmap Index Scan)
EXPLAIN ANALYZE
SELECT * FROM fact_production
WHERE tons_mined > 150;

-- Индекс с направлением сортировки
CREATE INDEX idx_prod_date_desc
ON fact_production(date_id DESC NULLS LAST);

-- Используется для ORDER BY DESC
EXPLAIN ANALYZE
SELECT date_id, equipment_id, tons_mined
FROM fact_production
ORDER BY date_id DESC
LIMIT 20;

-- ============================================================
-- 7.5.2  UNIQUE индекс
-- ============================================================
-- Гарантирует уникальность значений в столбце.
-- Автоматически создаётся для PRIMARY KEY и UNIQUE constraints.

-- Демонстрация (закомментировано — уже создан через DDL):
-- CREATE UNIQUE INDEX idx_equip_inventory_unique
-- ON dim_equipment(inventory_number);

-- Попытка вставить дубликат (закомментировано — вызовет ошибку):
-- INSERT INTO dim_equipment (equipment_type_id, mine_id,
--     equipment_name, inventory_number, manufacturer)
-- VALUES (1, 1, 'ПДМ-тест', 'INV-LHD-001', 'Test');
-- Результат: ERROR: duplicate key value violates unique constraint

-- Просмотр ограничений и автоматически созданных индексов
SELECT conname AS constraint_name,
       contype AS type,
       pg_get_constraintdef(oid) AS definition
FROM pg_constraint
WHERE conrelid = 'dim_equipment'::regclass;

-- ============================================================
-- 7.5.3  Частичный индекс (Partial Index)
-- ============================================================
-- Индексирует только строки, удовлетворяющие условию WHERE.
-- Меньше размер, меньше накладных расходов на запись.

-- Индекс только по аварийным показаниям телеметрии
CREATE INDEX idx_telemetry_alarm
ON fact_equipment_telemetry(date_id, equipment_id)
WHERE is_alarm = TRUE;

-- Запрос использует частичный индекс (условие совпадает)
EXPLAIN ANALYZE
SELECT * FROM fact_equipment_telemetry
WHERE date_id = 20240315
  AND equipment_id = 3
  AND is_alarm = TRUE;

-- Запрос БЕЗ условия is_alarm — частичный индекс НЕ используется
EXPLAIN ANALYZE
SELECT * FROM fact_equipment_telemetry
WHERE date_id = 20240315
  AND equipment_id = 3;

-- Частичный индекс для внеплановых простоев
-- (внеплановые простои — самые критичные для MES)
CREATE INDEX idx_downtime_unplanned
ON fact_equipment_downtime(date_id, equipment_id)
WHERE is_planned = FALSE;

-- Поиск внеплановых простоев за дату — использует частичный индекс
EXPLAIN ANALYZE
SELECT *
FROM fact_equipment_downtime
WHERE date_id = 20240315
  AND is_planned = FALSE;

-- Сравнение размеров: полный индекс vs частичный
SELECT indexrelname                                 AS index_name,
       pg_size_pretty(pg_relation_size(indexrelid)) AS size
FROM pg_stat_user_indexes
WHERE relname = 'fact_equipment_telemetry'
ORDER BY indexrelname;

-- ============================================================
-- 7.5.4  Индекс по выражению (Expression Index)
-- ============================================================
-- Индексирует не значение столбца, а результат функции/выражения.
-- Условие в запросе должно ТОЧНО совпадать с выражением индекса.

-- Индекс по году-месяцу (извлечённому из date_id)
CREATE INDEX idx_prod_year_month
ON fact_production ((date_id / 100));

-- Используется: выражение в WHERE совпадает с индексом
EXPLAIN ANALYZE
SELECT * FROM fact_production
WHERE date_id / 100 = 202403;

-- Индекс для регистронезависимого поиска операторов
CREATE INDEX idx_operator_lastname_lower
ON dim_operator (LOWER(last_name));

EXPLAIN ANALYZE
SELECT * FROM dim_operator
WHERE LOWER(last_name) = 'петров';

-- Индекс по году ввода оборудования в эксплуатацию
CREATE INDEX idx_equip_commission_year
ON dim_equipment ((EXTRACT(YEAR FROM commissioning_date)));

EXPLAIN ANALYZE
SELECT * FROM dim_equipment
WHERE EXTRACT(YEAR FROM commissioning_date) = 2021;

-- ============================================================
-- 7.5.5  Покрывающий индекс (INCLUDE) — Index Only Scan
-- ============================================================
-- Дополнительные столбцы хранятся в листьях B-tree,
-- но НЕ участвуют в поиске. Позволяет получить
-- Index Only Scan — без обращения к таблице (heap).

-- Покрывающий индекс для ежедневного отчёта по добыче
CREATE INDEX idx_prod_date_covering
ON fact_production(date_id)
INCLUDE (equipment_id, tons_mined);

-- Index Only Scan: все нужные столбцы в индексе
EXPLAIN ANALYZE
SELECT date_id, equipment_id, tons_mined
FROM fact_production
WHERE date_id = 20240315;

-- Покрывающий индекс для агрегатного запроса
CREATE INDEX idx_prod_equip_covering
ON fact_production(equipment_id)
INCLUDE (tons_mined, operating_hours);

EXPLAIN ANALYZE
SELECT equipment_id,
       SUM(tons_mined)      AS total_tons,
       SUM(operating_hours)  AS total_hours
FROM fact_production
WHERE equipment_id IN (1, 2, 3)
GROUP BY equipment_id;

-- ============================================================
-- 7.5.6  Index Scan vs Index Only Scan — демонстрация разницы
-- ============================================================

-- Index Scan — обращается к таблице за «невидимыми» столбцами
EXPLAIN (ANALYZE, BUFFERS)
SELECT *
FROM fact_production
WHERE date_id = 20240315;

-- Index Only Scan — все данные из индекса, heap не читается
-- (при условии, что VACUUM отработал и Visibility Map актуальна)
EXPLAIN (ANALYZE, BUFFERS)
SELECT date_id, equipment_id, tons_mined
FROM fact_production
WHERE date_id = 20240315;

-- Подсказка: для чистоты эксперимента выполните VACUUM перед тестом
-- VACUUM fact_production;

-- ============================================================
-- 7.5.7  CREATE INDEX CONCURRENTLY — без блокировки таблицы
-- ============================================================
-- Обычный CREATE INDEX блокирует таблицу на запись.
-- CONCURRENTLY строит индекс в фоне, не мешая INSERT/UPDATE/DELETE.
-- Нельзя выполнять внутри транзакции (BEGIN...COMMIT).

CREATE INDEX CONCURRENTLY idx_prod_location
ON fact_production(location_id);

-- Проверяем, что индекс создан и валиден
SELECT indexrelname, idx_scan
FROM pg_stat_user_indexes
WHERE relname = 'fact_production'
  AND indexrelname = 'idx_prod_location';

-- Для удаления тоже есть CONCURRENTLY:
-- DROP INDEX CONCURRENTLY IF EXISTS idx_prod_location;

-- ============================================================
-- 7.5.8  Композитный (составной) индекс — порядок столбцов
-- ============================================================
-- Правило «левого префикса»: композитный индекс (A, B, C)
-- эффективен для запросов с фильтром по A, по (A, B), по (A, B, C).
-- НЕ эффективен для запросов только по B или только по C.

-- Вариант 1: (equipment_id, date_id)
CREATE INDEX idx_prod_equip_date
ON fact_production(equipment_id, date_id);

-- Запрос по обоим столбцам — индекс используется
EXPLAIN ANALYZE
SELECT * FROM fact_production
WHERE equipment_id = 5
  AND date_id BETWEEN 20240301 AND 20240331;

-- Запрос только по ведущему столбцу — индекс используется
EXPLAIN ANALYZE
SELECT * FROM fact_production
WHERE equipment_id = 5;

-- Запрос только по второму столбцу — композитный индекс НЕ используется
-- (будет использован одноколоночный idx_fact_production_date)
EXPLAIN ANALYZE
SELECT * FROM fact_production
WHERE date_id = 20240315;

-- Эксперимент: меняем порядок столбцов
CREATE INDEX idx_prod_date_equip
ON fact_production(date_id, equipment_id);

-- Теперь запрос по date_id может выбрать этот индекс
EXPLAIN ANALYZE
SELECT * FROM fact_production
WHERE date_id = 20240315
  AND equipment_id = 5;

-- Bitmap Index Scan — PostgreSQL объединяет два индекса
EXPLAIN ANALYZE
SELECT * FROM fact_production
WHERE equipment_id = 5
  AND shift_id = 2;
-- Планировщик может объединить idx_fact_production_equip
-- и idx_fact_production_shift через BitmapAnd

-- Тройной композитный индекс для детального отчёта MES
CREATE INDEX idx_prod_mine_date_equip
ON fact_production(mine_id, date_id, equipment_id);

EXPLAIN ANALYZE
SELECT * FROM fact_production
WHERE mine_id = 1
  AND date_id BETWEEN 20240301 AND 20240331
  AND equipment_id = 3;

-- ============================================================
-- 7.5.9  CLUSTER — физическая упорядоченность данных
-- ============================================================
-- CLUSTER перестраивает таблицу в порядке указанного индекса.
-- После кластеризации range-запросы читают последовательные страницы
-- вместо случайных, что значительно ускоряет I/O.
-- ВНИМАНИЕ: CLUSTER блокирует таблицу на время выполнения.

-- Кластеризовать таблицу добычи по дате
CLUSTER fact_production USING idx_fact_production_date;

-- Проверяем физический порядок после кластеризации
SELECT ctid, date_id, equipment_id, tons_mined
FROM fact_production
ORDER BY ctid
LIMIT 20;

-- Обновляем статистику после CLUSTER
ANALYZE fact_production;

-- Проверяем корреляцию — должна быть близка к 1.0 для date_id
SELECT attname, correlation
FROM pg_stats
WHERE tablename = 'fact_production'
  AND attname IN ('date_id', 'equipment_id', 'mine_id');

-- Повторная кластеризация (PostgreSQL запоминает индекс):
-- CLUSTER fact_production;


-- ############################################################
-- 7.6  ВЛИЯНИЕ ИНДЕКСОВ НА INSERT / UPDATE / DELETE
-- ############################################################

-- ============================================================
-- 7.6.1  Влияние индексов на INSERT — эксперимент
-- ============================================================
-- Каждый индекс замедляет INSERT, потому что нужно обновить
-- все B-tree деревья. Чем больше индексов — тем дороже вставка.

-- Шаг 1: Создадим тестовую таблицу без индексов
CREATE TABLE test_insert_perf (
    id           SERIAL PRIMARY KEY,
    date_id      INT,
    equipment_id INT,
    sensor_value NUMERIC(10,2),
    note         TEXT
);

-- Шаг 2: Вставка 10 000 строк БЕЗ дополнительных индексов
EXPLAIN ANALYZE
INSERT INTO test_insert_perf (date_id, equipment_id, sensor_value, note)
SELECT
    20240301 + (g % 31),
    (g % 15) + 1,
    ROUND((RANDOM() * 100)::numeric, 2),
    'Тестовая запись #' || g
FROM generate_series(1, 10000) AS g;

-- Запоминаем время выполнения!

-- Шаг 3: Добавляем 3 индекса
CREATE INDEX idx_test_date ON test_insert_perf(date_id);
CREATE INDEX idx_test_equip ON test_insert_perf(equipment_id);
CREATE INDEX idx_test_sensor ON test_insert_perf(sensor_value);

-- Шаг 4: Очищаем таблицу
TRUNCATE test_insert_perf;

-- Шаг 5: Вставка 10 000 строк С индексами
EXPLAIN ANALYZE
INSERT INTO test_insert_perf (date_id, equipment_id, sensor_value, note)
SELECT
    20240301 + (g % 31),
    (g % 15) + 1,
    ROUND((RANDOM() * 100)::numeric, 2),
    'Тестовая запись #' || g
FROM generate_series(1, 10000) AS g;

-- Сравниваем время: вставка с индексами медленнее!

-- ============================================================
-- 7.6.2  Просмотр «стоимости» индексов для записи
-- ============================================================
-- Сколько индексов обслуживает каждая таблица?

SELECT relname                                       AS table_name,
       COUNT(*)                                      AS index_count,
       pg_size_pretty(pg_table_size(relid))          AS table_size,
       pg_size_pretty(pg_indexes_size(relid))        AS indexes_size,
       ROUND(pg_indexes_size(relid)::numeric
           / NULLIF(pg_table_size(relid), 0) * 100, 1) AS idx_to_table_pct
FROM pg_stat_user_tables
JOIN pg_stat_user_indexes USING (relid)
GROUP BY relname, relid
ORDER BY index_count DESC;

-- Удаляем тестовую таблицу
DROP TABLE IF EXISTS test_insert_perf;


-- ############################################################
-- ПРОСМОТР И АНАЛИЗ ИНДЕКСОВ
-- ############################################################

-- ============================================================
-- Все индексы таблицы fact_production
-- ============================================================

SELECT indexname, indexdef
FROM pg_indexes
WHERE tablename = 'fact_production'
ORDER BY indexname;

-- ============================================================
-- Все индексы схемы public
-- ============================================================

SELECT tablename, indexname, indexdef
FROM pg_indexes
WHERE schemaname = 'public'
ORDER BY tablename, indexname;

-- ============================================================
-- Размер индексов с количеством использований
-- ============================================================

SELECT indexrelname                                        AS index_name,
       pg_size_pretty(pg_relation_size(indexrelid))        AS index_size,
       idx_scan                                            AS times_used,
       idx_tup_read                                        AS tuples_read
FROM pg_stat_user_indexes
WHERE relname = 'fact_production'
ORDER BY pg_relation_size(indexrelid) DESC;

-- ============================================================
-- Неиспользуемые индексы — кандидаты на удаление
-- ============================================================
-- Если индекс ни разу не использовался, он только замедляет запись.

SELECT s.relname     AS table_name,
       s.indexrelname AS index_name,
       s.idx_scan    AS scan_count,
       pg_size_pretty(pg_relation_size(s.indexrelid)) AS size
FROM pg_stat_user_indexes s
JOIN pg_index i ON s.indexrelid = i.indexrelid
WHERE s.idx_scan = 0
  AND NOT i.indisunique    -- не удаляем уникальные (нужны для целостности)
ORDER BY pg_relation_size(s.indexrelid) DESC;

-- ============================================================
-- Наиболее используемые индексы — самые ценные
-- ============================================================

SELECT s.relname      AS table_name,
       s.indexrelname  AS index_name,
       s.idx_scan     AS scan_count,
       s.idx_tup_read  AS tuples_read,
       s.idx_tup_fetch AS tuples_fetched
FROM pg_stat_user_indexes s
WHERE s.idx_scan > 0
ORDER BY s.idx_scan DESC
LIMIT 20;

-- ============================================================
-- Дублирующиеся индексы (индексы на одни и те же столбцы)
-- ============================================================

SELECT a.indexrelid::regclass AS index_1,
       b.indexrelid::regclass AS index_2,
       a.indrelid::regclass   AS table_name
FROM pg_index a
JOIN pg_index b ON a.indrelid = b.indrelid
                AND a.indexrelid < b.indexrelid
                AND a.indkey = b.indkey;


-- ############################################################
-- ОЧИСТКА: удаление всех созданных в примерах индексов
-- ############################################################

DROP INDEX IF EXISTS idx_prod_tons_mined;
DROP INDEX IF EXISTS idx_prod_date_desc;
DROP INDEX IF EXISTS idx_prod_year_month;
DROP INDEX IF EXISTS idx_operator_lastname_lower;
DROP INDEX IF EXISTS idx_equip_commission_year;
DROP INDEX IF EXISTS idx_prod_equip_date;
DROP INDEX IF EXISTS idx_prod_date_equip;
DROP INDEX IF EXISTS idx_prod_mine_date_equip;
DROP INDEX IF EXISTS idx_prod_date_covering;
DROP INDEX IF EXISTS idx_prod_equip_covering;
DROP INDEX IF EXISTS idx_sensor_code_hash;
DROP INDEX IF EXISTS idx_telemetry_date_brin;
DROP INDEX IF EXISTS idx_telemetry_alarm;
DROP INDEX IF EXISTS idx_downtime_unplanned;
DROP INDEX IF EXISTS idx_prod_location;

-- Удаление тестовой таблицы (на случай, если не удалили ранее)
DROP TABLE IF EXISTS test_insert_perf;

-- ============================================================
-- Конец примеров Модуля 7
-- ============================================================
