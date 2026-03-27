-- ============================================================
-- Модуль 1: Введение в язык SQL и СУБД PostgreSQL
-- Примеры SQL-запросов из презентации
-- СУБД: PostgreSQL (Yandex Managed Service for PostgreSQL)
-- База данных: ruda_plus (предприятие «Руда+»)
-- ============================================================

-- ============================================================
-- 1. EXPRESSION (ВЫРАЖЕНИЕ) — примеры
-- ============================================================

-- Литеральные выражения
SELECT
    42                    AS integer_literal,
    'Шахта Северная'      AS string_literal,
    TRUE                  AS boolean_literal,
    CURRENT_DATE          AS date_expression,
    CURRENT_TIMESTAMP     AS timestamp_expression;

-- Арифметические выражения на данных «Руда+»
SELECT
    equipment_name,
    year_manufactured,
    EXTRACT(YEAR FROM CURRENT_DATE) - year_manufactured AS equipment_age_years
FROM dim_equipment
ORDER BY equipment_age_years DESC;

-- Выражения с функциями
SELECT
    mine_name,
    max_depth_m,
    ROUND(max_depth_m * 3.281, 1) AS max_depth_ft,  -- перевод метров в футы
    UPPER(mine_code) AS mine_code_upper
FROM dim_mine;

-- Условное выражение CASE
SELECT
    equipment_name,
    status,
    CASE
        WHEN status = 'active'         THEN 'В работе'
        WHEN status = 'maintenance'    THEN 'На обслуживании'
        WHEN status = 'decommissioned' THEN 'Списано'
        ELSE 'Неизвестно'
    END AS status_rus
FROM dim_equipment
ORDER BY equipment_name;


-- ============================================================
-- 2. CLAUSE (ПРЕДЛОЖЕНИЕ) — каждое ключевое слово = секция
-- ============================================================

SELECT                                        -- Clause: SELECT (что выводить)
    m.mine_name,
    COUNT(e.equipment_id) AS equipment_count
FROM dim_mine m                               -- Clause: FROM (источник данных)
JOIN dim_equipment e                          -- Clause: JOIN (соединение)
    ON m.mine_id = e.mine_id                  -- Clause: ON (условие соединения)
WHERE m.status = 'active'                     -- Clause: WHERE (фильтрация строк)
GROUP BY m.mine_name                          -- Clause: GROUP BY (группировка)
HAVING COUNT(e.equipment_id) > 5              -- Clause: HAVING (фильтрация групп)
ORDER BY equipment_count DESC                 -- Clause: ORDER BY (сортировка)
LIMIT 10;                                     -- Clause: LIMIT (ограничение)


-- ============================================================
-- 3. STATEMENT (ИНСТРУКЦИЯ) — полная конструкция для выполнения
-- ============================================================

-- Statement 1: выборка шахт
SELECT mine_name, max_depth_m
FROM dim_mine
WHERE status = 'active'
ORDER BY max_depth_m DESC;

-- Statement 2: подсчёт оборудования по типам
SELECT
    et.type_name,
    COUNT(*) AS total
FROM dim_equipment e
JOIN dim_equipment_type et ON e.equipment_type_id = et.equipment_type_id
GROUP BY et.type_name
ORDER BY total DESC;


-- ============================================================
-- 4. COMMAND (КОМАНДА) — тип действия
-- ============================================================

-- DDL-команда: создание временной таблицы (для демонстрации)
CREATE TEMP TABLE temp_demo (
    id    SERIAL PRIMARY KEY,
    label VARCHAR(50) NOT NULL
);

-- DML-команда: вставка данных
INSERT INTO temp_demo (label) VALUES ('Тестовая запись 1'), ('Тестовая запись 2');

-- DML-команда: выборка
SELECT * FROM temp_demo;

-- DML-команда: обновление
UPDATE temp_demo SET label = 'Обновлённая запись' WHERE id = 1;

-- DML-команда: удаление
DELETE FROM temp_demo WHERE id = 2;

-- DDL-команда: удаление таблицы
DROP TABLE temp_demo;


-- ============================================================
-- 5. BATCH (ПАКЕТ) — несколько инструкций в одной транзакции
-- ============================================================

-- Пример пакета: проверка данных в нескольких таблицах
BEGIN;

SELECT 'Шахты' AS entity, COUNT(*) AS cnt FROM dim_mine;
SELECT 'Оборудование' AS entity, COUNT(*) AS cnt FROM dim_equipment;
SELECT 'Датчики' AS entity, COUNT(*) AS cnt FROM dim_sensor;
SELECT 'Операторы' AS entity, COUNT(*) AS cnt FROM dim_operator;

COMMIT;


-- ============================================================
-- 6. ОБЗОР СТРУКТУРЫ БД — системные запросы
-- ============================================================

-- Список всех таблиц
SELECT table_name, table_type
FROM information_schema.tables
WHERE table_schema = 'public'
ORDER BY table_name;

-- Столбцы конкретной таблицы
SELECT column_name, data_type, is_nullable, column_default
FROM information_schema.columns
WHERE table_name = 'dim_equipment'
ORDER BY ordinal_position;

-- Комментарии к таблицам
SELECT
    c.relname AS table_name,
    pg_catalog.obj_description(c.oid) AS description
FROM pg_catalog.pg_class c
JOIN pg_catalog.pg_namespace n ON n.oid = c.relnamespace
WHERE n.nspname = 'public'
  AND c.relkind = 'r'
  AND pg_catalog.obj_description(c.oid) IS NOT NULL
ORDER BY c.relname;


-- ============================================================
-- 7. ПЕРВЫЕ ЗАПРОСЫ К ДАННЫМ «РУДА+»
-- ============================================================

-- Какие шахты есть в системе?
SELECT mine_name, region, city, max_depth_m, status
FROM dim_mine;

-- Сколько оборудования на каждой шахте по типам?
SELECT
    m.mine_name,
    et.type_name,
    COUNT(*) AS equipment_count
FROM dim_equipment e
JOIN dim_mine m ON e.mine_id = m.mine_id
JOIN dim_equipment_type et ON e.equipment_type_id = et.equipment_type_id
GROUP BY m.mine_name, et.type_name
ORDER BY m.mine_name, et.type_name;

-- Причины простоев по категориям
SELECT reason_name, category
FROM dim_downtime_reason
ORDER BY category, reason_name;


-- ============================================================
-- 8. EXPLAIN — просмотр плана выполнения запроса
-- ============================================================

EXPLAIN
SELECT
    m.mine_name,
    COUNT(e.equipment_id) AS cnt
FROM dim_mine m
JOIN dim_equipment e ON m.mine_id = e.mine_id
WHERE m.status = 'active'
GROUP BY m.mine_name;

-- С подробной статистикой (ANALYZE выполняет запрос!)
EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
SELECT
    m.mine_name,
    COUNT(e.equipment_id) AS cnt
FROM dim_mine m
JOIN dim_equipment e ON m.mine_id = e.mine_id
WHERE m.status = 'active'
GROUP BY m.mine_name;


-- ============================================================
-- 9. СРАВНЕНИЕ SQL и DAX — подсчёт оборудования
-- ============================================================

-- SQL: подсчёт оборудования по шахтам
SELECT
    m.mine_name,
    COUNT(*) AS total_equipment
FROM dim_equipment e
JOIN dim_mine m ON e.mine_id = m.mine_id
GROUP BY m.mine_name;

-- Аналог в DAX (для справки, выполняется в Power BI / DAX Studio):
--
-- Total Equipment =
-- COUNTROWS(dim_equipment)
--
-- Equipment By Mine =
-- SUMMARIZE(
--     dim_equipment,
--     dim_mine[mine_name],
--     "Total Equipment", COUNTROWS(dim_equipment)
-- )


-- ============================================================
-- 10. ОБЪЁМ ДАННЫХ В ФАКТ-ТАБЛИЦАХ
-- ============================================================

SELECT
    'fact_production' AS table_name, COUNT(*) AS row_count FROM fact_production
UNION ALL
SELECT
    'fact_equipment_telemetry', COUNT(*) FROM fact_equipment_telemetry
UNION ALL
SELECT
    'fact_equipment_downtime', COUNT(*) FROM fact_equipment_downtime
UNION ALL
SELECT
    'fact_ore_quality', COUNT(*) FROM fact_ore_quality
ORDER BY table_name;
