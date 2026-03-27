-- ============================================================
-- Модуль 15: Хранимые процедуры и функции — Примеры SQL
-- СУБД: Yandex Managed Service for PostgreSQL
-- Предприятие «Руда+» — MES-система
-- ============================================================

-- ============================================================
-- 1. СКАЛЯРНЫЕ ФУНКЦИИ (CREATE FUNCTION ... RETURNS тип)
-- ============================================================

-- 1.1 Классификация руды по содержанию железа
CREATE OR REPLACE FUNCTION classify_ore_quality(
    p_fe_content NUMERIC
)
RETURNS VARCHAR
LANGUAGE plpgsql
IMMUTABLE
AS $$
BEGIN
    IF p_fe_content >= 65 THEN
        RETURN 'Высший сорт (богатая руда)';
    ELSIF p_fe_content >= 55 THEN
        RETURN 'Первый сорт';
    ELSIF p_fe_content >= 45 THEN
        RETURN 'Второй сорт';
    ELSIF p_fe_content >= 30 THEN
        RETURN 'Третий сорт (бедная руда)';
    ELSE
        RETURN 'Отходы (пустая порода)';
    END IF;
END;
$$;

-- Тестирование
SELECT classify_ore_quality(67.5);  -- Высший сорт
SELECT classify_ore_quality(52.0);  -- Второй сорт
SELECT classify_ore_quality(15.0);  -- Отходы

-- Использование в запросе
SELECT
    oq.sample_number,
    oq.fe_content,
    classify_ore_quality(oq.fe_content) AS quality_class,
    m.mine_name,
    d.full_date
FROM fact_ore_quality oq
JOIN dim_mine m ON oq.mine_id = m.mine_id
JOIN dim_date d ON oq.date_id = d.date_id
WHERE oq.date_id BETWEEN 20240101 AND 20240131
ORDER BY oq.fe_content DESC
LIMIT 20;

-- 1.2 Расчёт OEE (Overall Equipment Effectiveness)
CREATE OR REPLACE FUNCTION calc_oee(
    p_operating_hours NUMERIC,
    p_planned_hours   NUMERIC,
    p_actual_tons     NUMERIC,
    p_target_tons     NUMERIC
)
RETURNS NUMERIC
LANGUAGE plpgsql
IMMUTABLE
AS $$
BEGIN
    IF p_planned_hours = 0 OR p_target_tons = 0 THEN
        RETURN NULL;
    END IF;

    RETURN ROUND(
        (p_operating_hours / p_planned_hours)
        * (p_actual_tons / p_target_tons)
        * 100, 1
    );
END;
$$;

-- Тестирование
SELECT calc_oee(10, 12, 80, 100);  -- ~66.7
SELECT calc_oee(12, 12, 100, 100); -- 100.0
SELECT calc_oee(8, 0, 50, 100);    -- NULL

-- 1.3 Классификация длительности простоя
CREATE OR REPLACE FUNCTION classify_downtime(
    p_duration_min INT
)
RETURNS VARCHAR
LANGUAGE plpgsql
IMMUTABLE
AS $$
BEGIN
    CASE
        WHEN p_duration_min < 15 THEN RETURN 'Микропростой';
        WHEN p_duration_min <= 60 THEN RETURN 'Краткий простой';
        WHEN p_duration_min <= 240 THEN RETURN 'Средний простой';
        WHEN p_duration_min <= 480 THEN RETURN 'Длительный простой';
        ELSE RETURN 'Критический простой';
    END CASE;
END;
$$;

-- Применение: статистика простоев по категориям
SELECT
    classify_downtime(fd.duration_min) AS category,
    COUNT(*) AS cnt,
    ROUND(AVG(fd.duration_min), 0) AS avg_duration_min,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 1) AS pct
FROM fact_equipment_downtime fd
WHERE fd.date_id BETWEEN 20240101 AND 20240131
GROUP BY classify_downtime(fd.duration_min)
ORDER BY avg_duration_min;


-- ============================================================
-- 2. ТАБЛИЧНЫЕ ФУНКЦИИ (RETURNS TABLE)
-- ============================================================

-- 2.1 Отчёт по добыче с параметрами
CREATE OR REPLACE FUNCTION get_production_report(
    p_date_from INT,
    p_date_to   INT,
    p_mine_id   INT DEFAULT NULL
)
RETURNS TABLE (
    mine_name      VARCHAR,
    shift_name     VARCHAR,
    total_tons     NUMERIC,
    total_trips    BIGINT,
    avg_tons_trip  NUMERIC,
    equipment_cnt  BIGINT
)
LANGUAGE plpgsql
STABLE
AS $$
BEGIN
    RETURN QUERY
    SELECT
        m.mine_name,
        s.shift_name,
        ROUND(SUM(fp.tons_mined), 2),
        SUM(fp.trips_count)::BIGINT,
        ROUND(SUM(fp.tons_mined) / NULLIF(SUM(fp.trips_count), 0), 2),
        COUNT(DISTINCT fp.equipment_id)
    FROM fact_production fp
    JOIN dim_mine m  ON fp.mine_id = m.mine_id
    JOIN dim_shift s ON fp.shift_id = s.shift_id
    WHERE fp.date_id BETWEEN p_date_from AND p_date_to
      AND (p_mine_id IS NULL OR fp.mine_id = p_mine_id)
    GROUP BY m.mine_name, s.shift_name
    ORDER BY m.mine_name, s.shift_name;
END;
$$;

-- Вызовы
SELECT * FROM get_production_report(20240101, 20240131);
SELECT * FROM get_production_report(20240101, 20240131, 2);
SELECT * FROM get_production_report(
    p_date_from := 20240101,
    p_date_to   := 20240131,
    p_mine_id   := 1
);

-- 2.2 Детальная сводка по оборудованию
CREATE OR REPLACE FUNCTION get_equipment_summary(
    p_equipment_id INT,
    p_date_from    INT,
    p_date_to      INT
)
RETURNS TABLE (
    report_date     DATE,
    tons_mined      NUMERIC,
    trips           INT,
    operating_hours NUMERIC,
    fuel_liters     NUMERIC,
    tons_per_hour   NUMERIC
)
LANGUAGE plpgsql
STABLE
AS $$
BEGIN
    RETURN QUERY
    SELECT
        d.full_date,
        ROUND(SUM(fp.tons_mined), 2),
        SUM(fp.trips_count)::INT,
        ROUND(SUM(fp.operating_hours), 2),
        ROUND(SUM(fp.fuel_consumed_l), 2),
        ROUND(SUM(fp.tons_mined) / NULLIF(SUM(fp.operating_hours), 0), 2)
    FROM fact_production fp
    JOIN dim_date d ON fp.date_id = d.date_id
    WHERE fp.equipment_id = p_equipment_id
      AND fp.date_id BETWEEN p_date_from AND p_date_to
    GROUP BY d.full_date
    ORDER BY d.full_date;
END;
$$;

-- Прямой вызов
SELECT * FROM get_equipment_summary(1, 20240101, 20240115);

-- Использование с LATERAL
SELECT
    e.equipment_name,
    s.*
FROM dim_equipment e
CROSS JOIN LATERAL get_equipment_summary(e.equipment_id, 20240101, 20240107) s
WHERE e.mine_id = 1
ORDER BY e.equipment_name, s.report_date;

-- 2.3 Функция с гибкой фильтрацией (DEFAULT параметры)
CREATE OR REPLACE FUNCTION get_production_filtered(
    p_date_from         INT,
    p_date_to           INT,
    p_mine_id           INT DEFAULT NULL,
    p_shift_id          INT DEFAULT NULL,
    p_equipment_type_id INT DEFAULT NULL
)
RETURNS TABLE (
    mine_name      VARCHAR,
    shift_name     VARCHAR,
    equipment_type VARCHAR,
    total_tons     NUMERIC,
    total_trips    BIGINT,
    equip_count    BIGINT
)
LANGUAGE plpgsql
STABLE
AS $$
BEGIN
    RETURN QUERY
    SELECT
        m.mine_name,
        s.shift_name,
        et.type_name,
        ROUND(SUM(fp.tons_mined), 2),
        SUM(fp.trips_count)::BIGINT,
        COUNT(DISTINCT fp.equipment_id)
    FROM fact_production fp
    JOIN dim_mine m ON fp.mine_id = m.mine_id
    JOIN dim_shift s ON fp.shift_id = s.shift_id
    JOIN dim_equipment e ON fp.equipment_id = e.equipment_id
    JOIN dim_equipment_type et ON e.equipment_type_id = et.equipment_type_id
    WHERE fp.date_id BETWEEN p_date_from AND p_date_to
      AND (p_mine_id IS NULL OR fp.mine_id = p_mine_id)
      AND (p_shift_id IS NULL OR fp.shift_id = p_shift_id)
      AND (p_equipment_type_id IS NULL OR e.equipment_type_id = p_equipment_type_id)
    GROUP BY m.mine_name, s.shift_name, et.type_name
    ORDER BY m.mine_name, s.shift_name, et.type_name;
END;
$$;

-- Вызовы с разными комбинациями параметров
SELECT * FROM get_production_filtered(20240101, 20240131);
SELECT * FROM get_production_filtered(20240101, 20240131, p_mine_id := 1);
SELECT * FROM get_production_filtered(20240101, 20240131, 1, 1);
SELECT * FROM get_production_filtered(20240101, 20240131, p_equipment_type_id := 1);


-- ============================================================
-- 3. ПРОЦЕДУРЫ (CREATE PROCEDURE) С ТРАНЗАКЦИЯМИ
-- ============================================================

-- 3.1 Подготовка staging-таблицы
CREATE TABLE IF NOT EXISTS staging_production (
    LIKE fact_production INCLUDING DEFAULTS
);

-- 3.2 Процедура загрузки данных с промежуточными COMMIT
CREATE OR REPLACE PROCEDURE load_daily_production(
    p_date_id   INT,
    OUT p_deleted  INT,
    OUT p_inserted INT
)
LANGUAGE plpgsql
AS $$
BEGIN
    -- Шаг 1: Удаляем старые данные за дату
    DELETE FROM staging_production WHERE date_id = p_date_id;
    GET DIAGNOSTICS p_deleted = ROW_COUNT;
    RAISE NOTICE 'Удалено из staging: % строк', p_deleted;
    COMMIT;

    -- Шаг 2: Копируем свежие данные
    INSERT INTO staging_production
    SELECT * FROM fact_production
    WHERE date_id = p_date_id;
    GET DIAGNOSTICS p_inserted = ROW_COUNT;
    RAISE NOTICE 'Загружено в staging: % строк', p_inserted;
    COMMIT;
END;
$$;

-- Вызов
CALL load_daily_production(20240115, NULL, NULL);

-- 3.3 Процедура архивации данных
CREATE TABLE IF NOT EXISTS archive_telemetry (
    LIKE fact_equipment_telemetry INCLUDING ALL
);

CREATE OR REPLACE PROCEDURE archive_old_telemetry(
    p_before_date_id INT,
    OUT p_archived     INT,
    OUT p_deleted      INT
)
LANGUAGE plpgsql
AS $$
BEGIN
    -- Шаг 1: Копируем в архив
    INSERT INTO archive_telemetry
    SELECT * FROM fact_equipment_telemetry
    WHERE date_id < p_before_date_id;
    GET DIAGNOSTICS p_archived = ROW_COUNT;
    RAISE NOTICE 'Архивировано: % записей', p_archived;
    COMMIT;

    -- Шаг 2: Удаляем из основной таблицы
    DELETE FROM fact_equipment_telemetry
    WHERE date_id < p_before_date_id;
    GET DIAGNOSTICS p_deleted = ROW_COUNT;
    RAISE NOTICE 'Удалено из основной таблицы: % записей', p_deleted;
    COMMIT;
END;
$$;

-- 3.4 Демонстрация: COMMIT в функции — ОШИБКА
-- (для понимания ключевого отличия функции от процедуры)
CREATE OR REPLACE FUNCTION test_commit_in_function()
RETURNS VOID LANGUAGE plpgsql AS $$
BEGIN
    INSERT INTO staging_production
    SELECT * FROM fact_production LIMIT 1;
    COMMIT;  -- ОШИБКА!
END;
$$;

-- Попытка вызова вызовет ошибку:
-- SELECT test_commit_in_function();
-- ERROR: invalid transaction termination


-- ============================================================
-- 4. ДИНАМИЧЕСКИЙ SQL (EXECUTE, format())
-- ============================================================

-- 4.1 Подсчёт строк в произвольной таблице (безопасный)
CREATE OR REPLACE FUNCTION count_rows(p_table_name TEXT)
RETURNS BIGINT
LANGUAGE plpgsql
AS $$
DECLARE
    v_count BIGINT;
BEGIN
    -- %I — безопасная подстановка идентификатора (экранирование)
    EXECUTE format('SELECT COUNT(*) FROM %I', p_table_name)
    INTO v_count;
    RETURN v_count;
END;
$$;

-- Тесты
SELECT count_rows('fact_production');
SELECT count_rows('dim_mine');
SELECT count_rows('fact_equipment_telemetry');

-- 4.2 Подсчёт с валидацией имени таблицы
CREATE OR REPLACE FUNCTION count_fact_records(
    p_table_name TEXT,
    p_date_from  INT,
    p_date_to    INT
)
RETURNS BIGINT
LANGUAGE plpgsql
AS $$
DECLARE
    v_count BIGINT;
BEGIN
    -- Валидация: только таблицы фактов
    IF NOT p_table_name LIKE 'fact_%' THEN
        RAISE EXCEPTION 'Допустимы только таблицы фактов (fact_*). Получено: %', p_table_name;
    END IF;

    EXECUTE format(
        'SELECT COUNT(*) FROM %I WHERE date_id BETWEEN $1 AND $2',
        p_table_name
    ) INTO v_count USING p_date_from, p_date_to;

    RETURN v_count;
END;
$$;

-- Тесты
SELECT count_fact_records('fact_production', 20240101, 20240131);
SELECT count_fact_records('fact_equipment_downtime', 20240101, 20240131);
-- SELECT count_fact_records('dim_mine', 20240101, 20240131);  -- ОШИБКА!

-- 4.3 Универсальная группировка по измерению
CREATE OR REPLACE FUNCTION production_by_dimension(
    p_dimension VARCHAR,
    p_date_from INT,
    p_date_to   INT
)
RETURNS TABLE (dimension_value VARCHAR, total_tons NUMERIC, avg_trips NUMERIC)
LANGUAGE plpgsql
AS $$
DECLARE
    v_join  TEXT;
    v_field TEXT;
BEGIN
    CASE p_dimension
        WHEN 'mine' THEN
            v_join  := 'JOIN dim_mine d ON fp.mine_id = d.mine_id';
            v_field := 'd.mine_name';
        WHEN 'shift' THEN
            v_join  := 'JOIN dim_shift d ON fp.shift_id = d.shift_id';
            v_field := 'd.shift_name';
        WHEN 'operator' THEN
            v_join  := 'JOIN dim_operator d ON fp.operator_id = d.operator_id';
            v_field := 'd.last_name || '' '' || d.first_name';
        WHEN 'equipment' THEN
            v_join  := 'JOIN dim_equipment d ON fp.equipment_id = d.equipment_id';
            v_field := 'd.equipment_name';
        WHEN 'equipment_type' THEN
            v_join  := 'JOIN dim_equipment d ON fp.equipment_id = d.equipment_id '
                     || 'JOIN dim_equipment_type dt ON d.equipment_type_id = dt.equipment_type_id';
            v_field := 'dt.type_name';
        ELSE
            RAISE EXCEPTION 'Неизвестное измерение: %. Допустимые: mine, shift, operator, equipment, equipment_type',
                            p_dimension;
    END CASE;

    RETURN QUERY EXECUTE format(
        'SELECT %s::VARCHAR AS dimension_value,
                ROUND(SUM(fp.tons_mined), 2) AS total_tons,
                ROUND(AVG(fp.trips_count), 2) AS avg_trips
         FROM fact_production fp %s
         WHERE fp.date_id BETWEEN $1 AND $2
         GROUP BY 1 ORDER BY 2 DESC',
        v_field, v_join
    ) USING p_date_from, p_date_to;
END;
$$;

-- Тесты
SELECT * FROM production_by_dimension('mine', 20240101, 20240131);
SELECT * FROM production_by_dimension('shift', 20240101, 20240131);
SELECT * FROM production_by_dimension('operator', 20240101, 20240131);
SELECT * FROM production_by_dimension('equipment', 20240101, 20240131);
SELECT * FROM production_by_dimension('equipment_type', 20240101, 20240131);

-- 4.4 Динамическая сортировка (безопасная)
CREATE OR REPLACE FUNCTION get_top_equipment(
    p_date_from  INT,
    p_date_to    INT,
    p_order_by   TEXT DEFAULT 'total_tons',
    p_direction  TEXT DEFAULT 'DESC',
    p_limit      INT DEFAULT 10
)
RETURNS TABLE (
    equipment_name VARCHAR,
    total_tons     NUMERIC,
    total_trips    BIGINT,
    avg_productivity NUMERIC
)
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
    v_order_col TEXT;
    v_dir TEXT;
BEGIN
    -- Белый список для ORDER BY (защита от инъекций)
    v_order_col := CASE p_order_by
        WHEN 'total_tons'       THEN 'total_tons'
        WHEN 'total_trips'      THEN 'total_trips'
        WHEN 'avg_productivity' THEN 'avg_productivity'
        WHEN 'equipment_name'   THEN 'equipment_name'
        ELSE 'total_tons'
    END;

    v_dir := CASE UPPER(p_direction)
        WHEN 'ASC' THEN 'ASC'
        ELSE 'DESC'
    END;

    RETURN QUERY EXECUTE format(
        'SELECT
            e.equipment_name::VARCHAR,
            ROUND(SUM(fp.tons_mined), 2),
            SUM(fp.trips_count)::BIGINT,
            ROUND(SUM(fp.tons_mined) / NULLIF(SUM(fp.operating_hours), 0), 2)
         FROM fact_production fp
         JOIN dim_equipment e ON fp.equipment_id = e.equipment_id
         WHERE fp.date_id BETWEEN $1 AND $2
         GROUP BY e.equipment_id, e.equipment_name
         ORDER BY %I %s
         LIMIT $3',
        v_order_col, v_dir
    ) USING p_date_from, p_date_to, p_limit;
END;
$$;

-- Тесты
SELECT * FROM get_top_equipment(20240101, 20240331);
SELECT * FROM get_top_equipment(20240101, 20240331, 'avg_productivity', 'DESC', 5);
SELECT * FROM get_top_equipment(20240101, 20240331, 'equipment_name', 'ASC');


-- ============================================================
-- 5. ДЕМОНСТРАЦИЯ SQL-ИНЪЕКЦИИ
-- ============================================================

-- 5.1 ОПАСНЫЙ пример (для обучения):
CREATE OR REPLACE FUNCTION unsafe_count(p_table TEXT)
RETURNS BIGINT LANGUAGE plpgsql AS $$
DECLARE v_count BIGINT;
BEGIN
    -- НЕ ДЕЛАЙТЕ ТАК! Прямая конкатенация
    EXECUTE 'SELECT COUNT(*) FROM ' || p_table INTO v_count;
    RETURN v_count;
END;
$$;

-- Нормальный вызов
SELECT unsafe_count('dim_mine');

-- Попытка инъекции (НЕ ВЫПОЛНЯЙТЕ на реальных данных!):
-- SELECT unsafe_count('dim_mine; DROP TABLE staging_production; --');

-- 5.2 БЕЗОПАСНЫЙ аналог
CREATE OR REPLACE FUNCTION safe_count(p_table TEXT)
RETURNS BIGINT LANGUAGE plpgsql AS $$
DECLARE v_count BIGINT;
BEGIN
    -- Безопасно: %I экранирует идентификатор
    EXECUTE format('SELECT COUNT(*) FROM %I', p_table) INTO v_count;
    RETURN v_count;
END;
$$;

-- Попытка инъекции провалится:
-- SELECT safe_count('dim_mine; DROP TABLE staging_production; --');
-- ERROR: relation "dim_mine; DROP TABLE staging_production; --" does not exist


-- ============================================================
-- 6. ВСПОМОГАТЕЛЬНЫЕ ВОЗМОЖНОСТИ
-- ============================================================

-- 6.1 Волатильность функций: IMMUTABLE, STABLE, VOLATILE
-- IMMUTABLE — результат зависит ТОЛЬКО от аргументов (можно кэшировать)
-- STABLE    — результат может меняться между транзакциями, но стабилен внутри одной
-- VOLATILE  — результат может меняться при каждом вызове (по умолчанию)

-- 6.2 Перегрузка функций
CREATE OR REPLACE FUNCTION get_mine_info(p_mine_id INT)
RETURNS TABLE (mine_name VARCHAR, status VARCHAR)
LANGUAGE sql STABLE AS $$
    SELECT mine_name, status FROM dim_mine WHERE mine_id = p_mine_id;
$$;

CREATE OR REPLACE FUNCTION get_mine_info(p_mine_name VARCHAR)
RETURNS TABLE (mine_id INT, status VARCHAR)
LANGUAGE sql STABLE AS $$
    SELECT mine_id, status FROM dim_mine WHERE mine_name = p_mine_name;
$$;

-- PostgreSQL выбирает нужную перегрузку по типу аргумента
SELECT * FROM get_mine_info(1);
SELECT * FROM get_mine_info('Шахта Северная');

-- 6.3 Функция на чистом SQL (без plpgsql)
CREATE OR REPLACE FUNCTION get_daily_production_sql(
    p_mine_id   INT,
    p_date_from INT,
    p_date_to   INT
)
RETURNS TABLE (report_date DATE, total_tons NUMERIC)
LANGUAGE sql
STABLE
AS $$
    SELECT d.full_date, ROUND(SUM(fp.tons_mined), 2)
    FROM fact_production fp
    JOIN dim_date d ON fp.date_id = d.date_id
    WHERE fp.mine_id = p_mine_id
      AND fp.date_id BETWEEN p_date_from AND p_date_to
    GROUP BY d.full_date
    ORDER BY d.full_date;
$$;

SELECT * FROM get_daily_production_sql(1, 20240101, 20240115);


-- ============================================================
-- ОЧИСТКА (при необходимости)
-- ============================================================
-- DROP TABLE IF EXISTS staging_production;
-- DROP TABLE IF EXISTS archive_telemetry;
-- DROP FUNCTION IF EXISTS unsafe_count(TEXT);
-- DROP FUNCTION IF EXISTS safe_count(TEXT);
-- DROP FUNCTION IF EXISTS test_commit_in_function();
-- DROP FUNCTION IF EXISTS get_mine_info(INT);
-- DROP FUNCTION IF EXISTS get_mine_info(VARCHAR);
