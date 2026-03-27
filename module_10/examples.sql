-- ============================================================
-- Модуль 10. Использование подзапросов
-- Примеры на языке SQL (PostgreSQL)
-- Предприятие «Руда+»
-- ============================================================

-- ============================================================
-- 1. ЗАМКНУТЫЕ (САМОСТОЯТЕЛЬНЫЕ) ПОДЗАПРОСЫ — СКАЛЯРНЫЕ
-- ============================================================

-- 1.1 Скалярный подзапрос в WHERE
-- Оборудование с добычей выше средней по предприятию
SELECT
    e.equipment_name,
    et.type_name,
    ROUND(AVG(fp.tons_mined), 2) AS avg_tons_per_shift
FROM fact_production fp
JOIN dim_equipment e      ON fp.equipment_id = e.equipment_id
JOIN dim_equipment_type et ON e.equipment_type_id = et.equipment_type_id
GROUP BY e.equipment_name, et.type_name
HAVING AVG(fp.tons_mined) > (
    SELECT AVG(tons_mined) FROM fact_production
)
ORDER BY avg_tons_per_shift DESC;

-- 1.2 Скалярный подзапрос в SELECT — отклонение от средней
SELECT
    e.equipment_name,
    ROUND(AVG(fp.tons_mined), 2)  AS avg_tons,
    (SELECT ROUND(AVG(tons_mined), 2) FROM fact_production) AS overall_avg,
    ROUND(AVG(fp.tons_mined) -
        (SELECT AVG(tons_mined) FROM fact_production), 2) AS deviation
FROM fact_production fp
JOIN dim_equipment e ON fp.equipment_id = e.equipment_id
GROUP BY e.equipment_name
ORDER BY deviation DESC;

-- 1.3 Скалярный подзапрос в FROM — использование как константы
SELECT
    m.mine_name,
    ROUND(SUM(fp.tons_mined), 0) AS mine_total,
    overall.total AS enterprise_total,
    ROUND(SUM(fp.tons_mined) / overall.total * 100, 1) AS share_pct
FROM fact_production fp
JOIN dim_mine m ON fp.mine_id = m.mine_id
CROSS JOIN (
    SELECT SUM(tons_mined) AS total FROM fact_production
) overall
WHERE fp.date_id BETWEEN 20240101 AND 20240331
GROUP BY m.mine_name, overall.total
ORDER BY mine_total DESC;


-- ============================================================
-- 2. ЗАМКНУТЫЕ ПОДЗАПРОСЫ — МНОГОЗНАЧНЫЕ (IN / NOT IN)
-- ============================================================

-- 2.1 IN — операторы, работавшие на ПДМ
SELECT DISTINCT
    o.last_name,
    o.last_name || ' ' || LEFT(o.first_name, 1) || '.' AS operator_name,
    o.position,
    o.qualification
FROM fact_production fp
JOIN dim_operator o ON fp.operator_id = o.operator_id
WHERE fp.equipment_id IN (
    SELECT e.equipment_id
    FROM dim_equipment e
    JOIN dim_equipment_type et ON e.equipment_type_id = et.equipment_type_id
    WHERE et.type_code = 'LHD'
)
ORDER BY o.last_name;

-- 2.2 NOT IN — шахты без внеплановых простоев за месяц
SELECT m.mine_name, m.mine_code
FROM dim_mine m
WHERE m.mine_id NOT IN (
    SELECT DISTINCT e.mine_id
    FROM fact_equipment_downtime fd
    JOIN dim_equipment e ON fd.equipment_id = e.equipment_id
    WHERE fd.date_id BETWEEN 20240301 AND 20240331
      AND fd.is_planned = FALSE
      AND e.mine_id IS NOT NULL  -- защита от NULL!
)
AND m.status = 'active';

-- 2.3 IN с подзапросом, возвращающим вычисляемые значения
-- Даты с аномально высокой добычей (выше 2 стандартных отклонений)
SELECT
    d.full_date,
    d.day_of_week_name,
    daily.daily_tons
FROM (
    SELECT date_id, SUM(tons_mined) AS daily_tons
    FROM fact_production
    GROUP BY date_id
) daily
JOIN dim_date d ON daily.date_id = d.date_id
WHERE daily.daily_tons > (
    SELECT AVG(day_total) + 2 * STDDEV(day_total)
    FROM (
        SELECT SUM(tons_mined) AS day_total
        FROM fact_production
        GROUP BY date_id
    ) stats
)
ORDER BY daily.daily_tons DESC;


-- ============================================================
-- 3. ОПЕРАТОРЫ ANY / ALL
-- ============================================================

-- 3.1 > ALL — добыча превышает максимум всех самосвалов
SELECT DISTINCT
    e.equipment_name,
    et.type_name,
    fp.tons_mined
FROM fact_production fp
JOIN dim_equipment e      ON fp.equipment_id = e.equipment_id
JOIN dim_equipment_type et ON e.equipment_type_id = et.equipment_type_id
WHERE fp.tons_mined > ALL (
    SELECT fp2.tons_mined
    FROM fact_production fp2
    JOIN dim_equipment e2     ON fp2.equipment_id = e2.equipment_id
    JOIN dim_equipment_type et2 ON e2.equipment_type_id = et2.equipment_type_id
    WHERE et2.type_code = 'TRUCK'
)
ORDER BY fp.tons_mined DESC
LIMIT 10;

-- 3.2 > ANY — добыча превышает хотя бы одну запись самосвалов
-- (эквивалент > MIN)
SELECT COUNT(*)
FROM fact_production fp
JOIN dim_equipment e      ON fp.equipment_id = e.equipment_id
JOIN dim_equipment_type et ON e.equipment_type_id = et.equipment_type_id
WHERE et.type_code = 'LHD'
  AND fp.tons_mined > ANY (
    SELECT fp2.tons_mined
    FROM fact_production fp2
    JOIN dim_equipment e2     ON fp2.equipment_id = e2.equipment_id
    JOIN dim_equipment_type et2 ON e2.equipment_type_id = et2.equipment_type_id
    WHERE et2.type_code = 'TRUCK'
);

-- 3.3 = ANY — эквивалент IN
SELECT e.equipment_name
FROM dim_equipment e
WHERE e.mine_id = ANY (
    SELECT mine_id FROM dim_mine WHERE region = 'Курская область'
);


-- ============================================================
-- 4. КОРРЕЛИРОВАННЫЕ ПОДЗАПРОСЫ
-- ============================================================

-- 4.1 Для каждого оборудования — дата максимальной добычи
SELECT
    e.equipment_name,
    d.full_date,
    fp.tons_mined
FROM fact_production fp
JOIN dim_equipment e ON fp.equipment_id = e.equipment_id
JOIN dim_date d      ON fp.date_id = d.date_id
WHERE fp.tons_mined = (
    SELECT MAX(fp2.tons_mined)
    FROM fact_production fp2
    WHERE fp2.equipment_id = fp.equipment_id
)
ORDER BY fp.tons_mined DESC;

-- 4.2 Смены с добычей выше средней по данному оборудованию
SELECT
    e.equipment_name,
    d.full_date,
    s.shift_name,
    fp.tons_mined,
    ROUND((SELECT AVG(fp2.tons_mined)
           FROM fact_production fp2
           WHERE fp2.equipment_id = fp.equipment_id), 2) AS equip_avg
FROM fact_production fp
JOIN dim_equipment e ON fp.equipment_id = e.equipment_id
JOIN dim_date d      ON fp.date_id = d.date_id
JOIN dim_shift s     ON fp.shift_id = s.shift_id
WHERE fp.tons_mined > (
    SELECT AVG(fp2.tons_mined) * 1.2
    FROM fact_production fp2
    WHERE fp2.equipment_id = fp.equipment_id
)
ORDER BY fp.tons_mined DESC
LIMIT 15;

-- 4.3 Коррелированный подзапрос для подсчёта
-- Для каждой шахты — число уникальных операторов и единиц оборудования
SELECT
    m.mine_name,
    (SELECT COUNT(DISTINCT fp.operator_id)
     FROM fact_production fp
     WHERE fp.mine_id = m.mine_id
       AND fp.date_id BETWEEN 20240101 AND 20240331) AS operators_count,
    (SELECT COUNT(DISTINCT fp.equipment_id)
     FROM fact_production fp
     WHERE fp.mine_id = m.mine_id
       AND fp.date_id BETWEEN 20240101 AND 20240331) AS equipment_count,
    (SELECT ROUND(SUM(fp.tons_mined), 0)
     FROM fact_production fp
     WHERE fp.mine_id = m.mine_id
       AND fp.date_id BETWEEN 20240101 AND 20240331) AS total_tons
FROM dim_mine m
WHERE m.status = 'active'
ORDER BY total_tons DESC NULLS LAST;

-- 4.4 Коррелированный подзапрос для «последней записи»
SELECT
    e.equipment_name,
    d.full_date AS last_production_date,
    fp.tons_mined,
    o.last_name || ' ' || LEFT(o.first_name, 1) || '.' AS last_operator
FROM fact_production fp
JOIN dim_equipment e ON fp.equipment_id = e.equipment_id
JOIN dim_date d      ON fp.date_id = d.date_id
JOIN dim_operator o  ON fp.operator_id = o.operator_id
WHERE fp.date_id = (
    SELECT MAX(fp2.date_id)
    FROM fact_production fp2
    WHERE fp2.equipment_id = fp.equipment_id
)
ORDER BY d.full_date;


-- ============================================================
-- 5. ПРЕДИКАТ EXISTS
-- ============================================================

-- 5.1 EXISTS — оборудование с внеплановыми простоями
SELECT
    e.equipment_name,
    et.type_name,
    m.mine_name
FROM dim_equipment e
JOIN dim_equipment_type et ON e.equipment_type_id = et.equipment_type_id
JOIN dim_mine m            ON e.mine_id = m.mine_id
WHERE EXISTS (
    SELECT 1
    FROM fact_equipment_downtime fd
    WHERE fd.equipment_id = e.equipment_id
      AND fd.date_id BETWEEN 20240101 AND 20240331
      AND fd.is_planned = FALSE
)
ORDER BY e.equipment_name;

-- 5.2 NOT EXISTS — операторы без внеплановых простоев
SELECT
    o.last_name || ' ' || LEFT(o.first_name, 1) || '.' AS operator_name,
    o.position,
    o.qualification
FROM dim_operator o
WHERE o.status = 'active'
  AND NOT EXISTS (
    SELECT 1
    FROM fact_equipment_downtime fd
    WHERE fd.operator_id = o.operator_id
      AND fd.date_id BETWEEN 20240301 AND 20240331
      AND fd.is_planned = FALSE
)
ORDER BY o.last_name;

-- 5.3 NOT EXISTS — дни без добычи для оборудования
SELECT d.full_date, d.day_of_week_name, d.is_weekend
FROM dim_date d
WHERE d.full_date BETWEEN '2024-03-01' AND '2024-03-31'
  AND NOT EXISTS (
    SELECT 1
    FROM fact_production fp
    WHERE fp.date_id = d.date_id
      AND fp.equipment_id = 5
)
ORDER BY d.full_date;

-- 5.4 EXISTS vs IN — сравнение планов
EXPLAIN ANALYZE
SELECT DISTINCT e.equipment_name
FROM dim_equipment e
WHERE e.equipment_id IN (
    SELECT fd.equipment_id
    FROM fact_equipment_downtime fd
    WHERE fd.is_planned = FALSE
);

EXPLAIN ANALYZE
SELECT e.equipment_name
FROM dim_equipment e
WHERE EXISTS (
    SELECT 1
    FROM fact_equipment_downtime fd
    WHERE fd.equipment_id = e.equipment_id
      AND fd.is_planned = FALSE
);


-- ============================================================
-- 6. ПОДЗАПРОСЫ В FROM (ПРОИЗВОДНЫЕ ТАБЛИЦЫ)
-- ============================================================

-- 6.1 Производная таблица для ранжирования
-- Топ-3 оператора по добыче в каждой шахте
SELECT ranked.*
FROM (
    SELECT
        m.mine_name,
        o.last_name || ' ' || LEFT(o.first_name, 1) || '.' AS operator_name,
        ROUND(SUM(fp.tons_mined), 1) AS total_tons,
        ROW_NUMBER() OVER (
            PARTITION BY fp.mine_id
            ORDER BY SUM(fp.tons_mined) DESC
        ) AS rn
    FROM fact_production fp
    JOIN dim_operator o ON fp.operator_id = o.operator_id
    JOIN dim_mine m     ON fp.mine_id = m.mine_id
    WHERE fp.date_id BETWEEN 20240101 AND 20240331
    GROUP BY fp.mine_id, m.mine_name, o.last_name, o.first_name
) ranked
WHERE ranked.rn <= 3
ORDER BY ranked.mine_name, ranked.rn;

-- 6.2 Производная таблица для агрегации агрегатов
-- Средняя дневная добыча по шахтам
SELECT
    daily_data.mine_name,
    ROUND(AVG(daily_data.daily_tons), 1) AS avg_daily_tons,
    ROUND(MIN(daily_data.daily_tons), 1) AS min_daily_tons,
    ROUND(MAX(daily_data.daily_tons), 1) AS max_daily_tons,
    COUNT(*) AS working_days
FROM (
    SELECT
        m.mine_name,
        fp.date_id,
        SUM(fp.tons_mined) AS daily_tons
    FROM fact_production fp
    JOIN dim_mine m ON fp.mine_id = m.mine_id
    WHERE fp.date_id BETWEEN 20240101 AND 20240331
    GROUP BY m.mine_name, fp.date_id
) daily_data
GROUP BY daily_data.mine_name
ORDER BY avg_daily_tons DESC;


-- ============================================================
-- 7. КОМПЛЕКСНЫЕ ПРИМЕРЫ С ПОДЗАПРОСАМИ
-- ============================================================

-- 7.1 Многоуровневые подзапросы: оборудование-передовик с простоями
SELECT
    m.mine_name,
    COUNT(DISTINCT fd.equipment_id) AS top_equip_with_downtime,
    ROUND(AVG(fd.duration_min), 1)  AS avg_downtime_min,
    ROUND(SUM(fd.duration_min) / 60.0, 1) AS total_downtime_hours
FROM fact_equipment_downtime fd
JOIN dim_equipment e ON fd.equipment_id = e.equipment_id
JOIN dim_mine m      ON e.mine_id = m.mine_id
WHERE fd.is_planned = FALSE
  AND fd.date_id BETWEEN 20240101 AND 20240331
  AND fd.equipment_id IN (
    -- Оборудование с суммарной добычей выше средней
    SELECT fp.equipment_id
    FROM fact_production fp
    WHERE fp.date_id BETWEEN 20240101 AND 20240331
    GROUP BY fp.equipment_id
    HAVING SUM(fp.tons_mined) > (
        -- Средняя суммарная добыча на единицу оборудования
        SELECT AVG(eq_total)
        FROM (
            SELECT SUM(tons_mined) AS eq_total
            FROM fact_production
            WHERE date_id BETWEEN 20240101 AND 20240331
            GROUP BY equipment_id
        ) sub
    )
)
GROUP BY m.mine_name
ORDER BY total_downtime_hours DESC;

-- 7.2 Расчёт OEE через коррелированные подзапросы
SELECT
    e.equipment_name,
    et.type_name,
    -- Доступность
    ROUND(
        COALESCE(
            (SELECT SUM(fp.operating_hours)
             FROM fact_production fp
             WHERE fp.equipment_id = e.equipment_id
               AND fp.date_id BETWEEN 20240101 AND 20240331)
            /
            NULLIF(
                (SELECT SUM(fp.operating_hours)
                 FROM fact_production fp
                 WHERE fp.equipment_id = e.equipment_id
                   AND fp.date_id BETWEEN 20240101 AND 20240331)
                +
                (SELECT COALESCE(SUM(fd.duration_min) / 60.0, 0)
                 FROM fact_equipment_downtime fd
                 WHERE fd.equipment_id = e.equipment_id
                   AND fd.date_id BETWEEN 20240101 AND 20240331)
            , 0)
        , 0) * 100
    , 1) AS availability_pct,
    -- Рабочие часы
    ROUND(COALESCE(
        (SELECT SUM(fp.operating_hours)
         FROM fact_production fp
         WHERE fp.equipment_id = e.equipment_id
           AND fp.date_id BETWEEN 20240101 AND 20240331)
    , 0), 1) AS work_hours,
    -- Простои (часы)
    ROUND(COALESCE(
        (SELECT SUM(fd.duration_min) / 60.0
         FROM fact_equipment_downtime fd
         WHERE fd.equipment_id = e.equipment_id
           AND fd.date_id BETWEEN 20240101 AND 20240331)
    , 0), 1) AS downtime_hours
FROM dim_equipment e
JOIN dim_equipment_type et ON e.equipment_type_id = et.equipment_type_id
WHERE e.status = 'active'
ORDER BY availability_pct DESC;
