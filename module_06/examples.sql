-- ============================================================
-- Модуль 6. Использование встроенных функций
-- Примеры на языке SQL (PostgreSQL)
-- Предприятие «Руда+»
-- ============================================================

-- ============================================================
-- 1. МАТЕМАТИЧЕСКИЕ ФУНКЦИИ
-- ============================================================

-- 1.1 ROUND — округление содержания Fe до 1 знака
SELECT
    sample_number,
    fe_content,
    ROUND(fe_content, 1) AS fe_round_1,
    ROUND(fe_content, 0) AS fe_round_0
FROM fact_ore_quality
WHERE date_id = 20240315
ORDER BY fe_content DESC
LIMIT 5;

-- 1.2 CEIL / FLOOR — округление вверх и вниз
SELECT
    sample_number,
    fe_content,
    CEIL(fe_content)  AS fe_ceil,
    FLOOR(fe_content) AS fe_floor
FROM fact_ore_quality
WHERE date_id = 20240315
LIMIT 5;

-- 1.3 TRUNC — отсечение (без округления)
SELECT
    sample_number,
    fe_content,
    TRUNC(fe_content, 1) AS fe_trunc_1,
    TRUNC(fe_content, 0) AS fe_trunc_0
FROM fact_ore_quality
WHERE date_id = 20240315
LIMIT 5;

-- 1.4 ABS — абсолютное отклонение от целевого Fe (60%)
SELECT
    sample_number,
    fe_content,
    fe_content - 60.0           AS deviation,
    ABS(fe_content - 60.0)      AS abs_deviation
FROM fact_ore_quality
WHERE date_id BETWEEN 20240301 AND 20240331
ORDER BY abs_deviation DESC
LIMIT 10;

-- 1.5 POWER и SQRT — квадрат отклонения и корень
SELECT
    sample_number,
    fe_content,
    POWER(fe_content - 60.0, 2)         AS squared_dev,
    SQRT(POWER(fe_content - 60.0, 2))   AS sqrt_squared_dev
FROM fact_ore_quality
WHERE date_id = 20240315;

-- 1.6 MOD — определение чётных/нечётных ID
SELECT
    production_id,
    MOD(production_id, 2) AS is_odd,
    CASE MOD(production_id, 2)
        WHEN 0 THEN 'Чётный'
        ELSE 'Нечётный'
    END AS parity
FROM fact_production
LIMIT 10;

-- 1.7 SIGN — направление отклонения от нормы
SELECT
    sample_number,
    fe_content,
    fe_content - 60.0 AS deviation,
    SIGN(fe_content - 60.0) AS direction,
    CASE SIGN(fe_content - 60.0)
        WHEN  1 THEN 'Выше нормы'
        WHEN  0 THEN 'Точно в норме'
        WHEN -1 THEN 'Ниже нормы'
    END AS status
FROM fact_ore_quality
WHERE date_id = 20240315;

-- 1.8 LN, LOG, PI — дополнительные функции
SELECT
    PI()           AS pi_value,
    LN(2.71828)    AS natural_log,
    LOG(100)       AS log_10_of_100,
    LOG(2, 8)      AS log_2_of_8;

-- 1.9 RANDOM — случайная выборка проб для контроля качества
SELECT
    sample_number,
    fe_content,
    sio2_content
FROM fact_ore_quality
WHERE date_id BETWEEN 20240301 AND 20240331
ORDER BY RANDOM()
LIMIT 5;


-- ============================================================
-- 2. АГРЕГАТНЫЕ ФУНКЦИИ — УГЛУБЛЁННЫЙ ОБЗОР
-- ============================================================

-- 2.1 Базовые агрегаты: сводка добычи за март 2024
SELECT
    COUNT(*)                        AS total_records,
    COUNT(DISTINCT equipment_id)    AS unique_equipment,
    COUNT(DISTINCT operator_id)     AS unique_operators,
    SUM(tons_mined)                 AS total_tons,
    ROUND(AVG(tons_mined), 2)       AS avg_tons,
    MIN(tons_mined)                 AS min_tons,
    MAX(tons_mined)                 AS max_tons,
    ROUND(AVG(operating_hours), 2)  AS avg_hours
FROM fact_production
WHERE date_id BETWEEN 20240301 AND 20240331;

-- 2.2 COUNT vs COUNT(*) vs COUNT(DISTINCT)
SELECT
    COUNT(*)                 AS all_rows,
    COUNT(sio2_content)      AS non_null_sio2,
    COUNT(DISTINCT ore_grade_id) AS unique_grades
FROM fact_ore_quality
WHERE date_id BETWEEN 20240301 AND 20240331;

-- 2.3 STRING_AGG — список оборудования по шахтам
SELECT
    m.mine_name,
    STRING_AGG(
        e.equipment_name, ', '
        ORDER BY e.equipment_name
    ) AS equipment_list,
    COUNT(*) AS total_equipment
FROM dim_equipment e
JOIN dim_mine m ON e.mine_id = m.mine_id
WHERE e.status = 'active'
GROUP BY m.mine_name;

-- 2.4 STRING_AGG — причины простоев за день
SELECT
    d.full_date,
    e.equipment_name,
    STRING_AGG(
        dr.reason_name, '; '
        ORDER BY fd.start_time
    ) AS downtime_reasons,
    SUM(fd.duration_min) AS total_downtime_min
FROM fact_equipment_downtime fd
JOIN dim_date d ON fd.date_id = d.date_id
JOIN dim_equipment e ON fd.equipment_id = e.equipment_id
JOIN dim_downtime_reason dr ON fd.reason_id = dr.reason_id
WHERE d.full_date = '2024-03-15'
GROUP BY d.full_date, e.equipment_name
ORDER BY total_downtime_min DESC;

-- 2.5 ARRAY_AGG — массив дат работы по операторам
SELECT
    o.last_name || ' ' || o.first_name AS operator_name,
    ARRAY_AGG(DISTINCT fp.date_id ORDER BY fp.date_id) AS work_dates,
    ARRAY_LENGTH(ARRAY_AGG(DISTINCT fp.date_id), 1) AS days_worked
FROM fact_production fp
JOIN dim_operator o ON fp.operator_id = o.operator_id
WHERE fp.date_id BETWEEN 20240301 AND 20240307
GROUP BY o.last_name, o.first_name
ORDER BY days_worked DESC;

-- 2.6 Агрегаты с FILTER (PostgreSQL 9.4+)
SELECT
    d.full_date,
    COUNT(*) FILTER (WHERE fp.shift_id = 1) AS shift_1_count,
    COUNT(*) FILTER (WHERE fp.shift_id = 2) AS shift_2_count,
    SUM(fp.tons_mined) FILTER (WHERE fp.shift_id = 1) AS tons_shift_1,
    SUM(fp.tons_mined) FILTER (WHERE fp.shift_id = 2) AS tons_shift_2,
    ROUND(AVG(fp.tons_mined) FILTER (WHERE fp.shift_id = 1), 2) AS avg_shift_1,
    ROUND(AVG(fp.tons_mined) FILTER (WHERE fp.shift_id = 2), 2) AS avg_shift_2
FROM fact_production fp
JOIN dim_date d ON fp.date_id = d.date_id
WHERE d.year = 2024 AND d.month = 3
GROUP BY d.full_date
ORDER BY d.full_date;

-- 2.7 Статистические функции
SELECT
    ROUND(STDDEV(fe_content)::NUMERIC, 3)        AS std_deviation,
    ROUND(VARIANCE(fe_content)::NUMERIC, 3)      AS variance_fe,
    ROUND(
        PERCENTILE_CONT(0.5)
        WITHIN GROUP (ORDER BY fe_content)::NUMERIC, 2
    ) AS median_fe,
    ROUND(
        PERCENTILE_CONT(0.9)
        WITHIN GROUP (ORDER BY fe_content)::NUMERIC, 2
    ) AS percentile_90,
    MODE() WITHIN GROUP (ORDER BY ore_grade_id) AS mode_grade
FROM fact_ore_quality
WHERE date_id BETWEEN 20240301 AND 20240331;


-- ============================================================
-- 3. ФУНКЦИИ ПРЕОБРАЗОВАНИЯ ТИПОВ
-- ============================================================

-- 3.1 CAST — стандартный синтаксис
SELECT
    CAST(date_id AS VARCHAR)    AS date_str,
    CAST('123.45' AS NUMERIC)   AS num_value,
    CAST(tons_mined AS INTEGER) AS tons_int
FROM fact_production
LIMIT 3;

-- 3.2 :: — краткий синтаксис PostgreSQL
SELECT
    date_id::VARCHAR               AS date_str,
    '123.45'::NUMERIC              AS num_value,
    tons_mined::INTEGER            AS tons_int,
    has_video_recorder::INTEGER    AS has_video_int
FROM fact_production fp
JOIN dim_equipment e ON fp.equipment_id = e.equipment_id
LIMIT 3;

-- 3.3 TO_DATE — строка в дату по шаблону
SELECT
    TO_DATE('15.03.2024', 'DD.MM.YYYY')            AS parsed_date_dot,
    TO_DATE('2024/03/15', 'YYYY/MM/DD')            AS parsed_date_slash,
    TO_DATE('15 March 2024', 'DD Month YYYY')       AS parsed_date_en;

-- 3.4 TO_TIMESTAMP — строка во временну́ю метку
SELECT
    TO_TIMESTAMP('15-03-2024 14:30:00', 'DD-MM-YYYY HH24:MI:SS') AS parsed_ts;

-- 3.5 TO_CHAR — форматирование дат и чисел
SELECT
    TO_CHAR(NOW(), 'DD.MM.YYYY')            AS today_dot,
    TO_CHAR(NOW(), 'DD Mon YYYY, HH24:MI')  AS today_full,
    TO_CHAR(12345.678, 'FM999G999D00')       AS formatted_num;

-- 3.6 Преобразование date_id в дату и обратно
SELECT
    date_id,
    TO_DATE(date_id::VARCHAR, 'YYYYMMDD') AS real_date,
    TO_CHAR(
        TO_DATE(date_id::VARCHAR, 'YYYYMMDD'),
        'DD Mon YYYY'
    ) AS formatted_date
FROM fact_production
WHERE date_id BETWEEN 20240301 AND 20240305
GROUP BY date_id
ORDER BY date_id;

-- 3.7 Неявное vs явное преобразование
-- Неявное (работает в PostgreSQL при конкатенации):
SELECT 'Добыто: ' || tons_mined || ' тонн' AS message
FROM fact_production
LIMIT 1;

-- Явное (рекомендуется):
SELECT 'Добыто: ' || CAST(tons_mined AS VARCHAR) || ' тонн' AS message
FROM fact_production
LIMIT 1;


-- ============================================================
-- 4. УСЛОВНАЯ ЛОГИКА
-- ============================================================

-- 4.1 CASE WHEN — классификация руды по содержанию Fe
SELECT
    sample_number,
    fe_content,
    CASE
        WHEN fe_content >= 65 THEN 'Богатая руда'
        WHEN fe_content >= 55 THEN 'Средняя руда'
        WHEN fe_content >= 45 THEN 'Бедная руда'
        ELSE 'Забалансовая'
    END AS ore_category
FROM fact_ore_quality
WHERE date_id = 20240315
ORDER BY fe_content DESC;

-- 4.2 Простая форма CASE
SELECT
    shift_id,
    CASE shift_id
        WHEN 1 THEN 'Утренняя смена'
        WHEN 2 THEN 'Дневная смена'
        WHEN 3 THEN 'Ночная смена'
        ELSE 'Неизвестная смена'
    END AS shift_name,
    SUM(tons_mined) AS total_tons
FROM fact_production
WHERE date_id BETWEEN 20240301 AND 20240331
GROUP BY shift_id
ORDER BY shift_id;

-- 4.3 CASE внутри агрегатов — кросс-табуляция
SELECT
    d.full_date,
    SUM(CASE WHEN oq.fe_content >= 60 THEN 1 ELSE 0 END) AS good_samples,
    SUM(CASE WHEN oq.fe_content < 60  THEN 1 ELSE 0 END) AS poor_samples,
    COUNT(*) AS total_samples,
    ROUND(
        100.0 * SUM(CASE WHEN oq.fe_content >= 60 THEN 1 ELSE 0 END)
        / NULLIF(COUNT(*), 0), 1
    ) AS good_pct
FROM fact_ore_quality oq
JOIN dim_date d ON oq.date_id = d.date_id
WHERE d.year = 2024 AND d.month = 3
GROUP BY d.full_date
ORDER BY d.full_date;

-- 4.4 CASE с несколькими условиями — категоризация простоев
SELECT
    e.equipment_name,
    dr.reason_name,
    fd.duration_min,
    CASE
        WHEN fd.duration_min > 480 THEN 'Критический (> 8 ч)'
        WHEN fd.duration_min > 120 THEN 'Длительный (2-8 ч)'
        WHEN fd.duration_min > 30  THEN 'Средний (30 мин - 2 ч)'
        ELSE 'Короткий (< 30 мин)'
    END AS downtime_category,
    CASE
        WHEN fd.is_planned THEN 'Плановый'
        ELSE 'Внеплановый'
    END AS planned_status
FROM fact_equipment_downtime fd
JOIN dim_equipment e ON fd.equipment_id = e.equipment_id
JOIN dim_downtime_reason dr ON fd.reason_id = dr.reason_id
WHERE fd.date_id BETWEEN 20240301 AND 20240331
ORDER BY fd.duration_min DESC;

-- 4.5 COALESCE — подстановка значений по умолчанию
SELECT
    sample_number,
    fe_content,
    COALESCE(sio2_content, 0)   AS sio2_safe,
    COALESCE(al2o3_content, 0)  AS al2o3_safe,
    COALESCE(moisture, 0)       AS moisture_safe
FROM fact_ore_quality
WHERE date_id = 20240315;

-- 4.6 COALESCE — цепочка подстановки
SELECT
    COALESCE(sio2_content, al2o3_content, 0) AS first_non_null_impurity
FROM fact_ore_quality
WHERE date_id = 20240315;

-- 4.7 NULLIF — защита от деления на ноль
SELECT
    equipment_id,
    tons_mined,
    tons_transported,
    trips_count,
    ROUND(
        tons_transported / NULLIF(trips_count, 0), 2
    ) AS tons_per_trip,
    ROUND(
        fuel_consumed_l / NULLIF(distance_km, 0), 2
    ) AS fuel_per_km
FROM fact_production
WHERE date_id = 20240315;

-- 4.8 COALESCE + NULLIF — безопасное деление с подстановкой
SELECT
    equipment_id,
    COALESCE(
        ROUND(tons_transported / NULLIF(trips_count, 0), 2),
        0
    ) AS tons_per_trip_safe
FROM fact_production
WHERE date_id = 20240315;

-- 4.9 GREATEST / LEAST
SELECT
    sample_number,
    fe_content,
    sio2_content,
    al2o3_content,
    GREATEST(
        COALESCE(sio2_content, 0),
        COALESCE(al2o3_content, 0)
    ) AS max_impurity,
    LEAST(
        COALESCE(sio2_content, 999),
        COALESCE(al2o3_content, 999)
    ) AS min_impurity,
    -- Ограничение Fe в диапазоне [40, 70] (clamp)
    GREATEST(LEAST(fe_content, 70.0), 40.0) AS fe_clamped
FROM fact_ore_quality
WHERE date_id = 20240315;


-- ============================================================
-- 5. РАБОТА С NULL
-- ============================================================

-- 5.1 IS NULL / IS NOT NULL — незавершённые простои
SELECT
    fd.downtime_id,
    e.equipment_name,
    fd.start_time,
    fd.end_time,
    fd.duration_min
FROM fact_equipment_downtime fd
JOIN dim_equipment e ON fd.equipment_id = e.equipment_id
WHERE fd.end_time IS NULL;

-- 5.2 Подсчёт NULL значений
SELECT
    COUNT(*) AS total_rows,
    COUNT(sio2_content) AS with_sio2,
    COUNT(*) - COUNT(sio2_content) AS null_sio2,
    ROUND(
        100.0 * (COUNT(*) - COUNT(sio2_content)) / COUNT(*), 1
    ) AS null_pct
FROM fact_ore_quality;

-- 5.3 NULL в арифметике
SELECT
    fe_content,
    sio2_content,
    -- Если sio2_content NULL, то и результат NULL:
    fe_content + sio2_content AS sum_unsafe,
    -- Безопасный вариант:
    fe_content + COALESCE(sio2_content, 0) AS sum_safe
FROM fact_ore_quality
WHERE date_id = 20240315
LIMIT 5;

-- 5.4 NULLS FIRST / NULLS LAST в ORDER BY
SELECT sample_number, fe_content, sio2_content
FROM fact_ore_quality
WHERE date_id = 20240315
ORDER BY sio2_content NULLS LAST;

SELECT sample_number, fe_content, sio2_content
FROM fact_ore_quality
WHERE date_id = 20240315
ORDER BY sio2_content NULLS FIRST;

-- 5.5 NOT IN с NULL — опасная ловушка
-- ПЛОХО: если подзапрос вернёт NULL, NOT IN вернёт 0 строк
-- SELECT * FROM dim_equipment
-- WHERE equipment_id NOT IN (SELECT operator_id FROM dim_operator);

-- ХОРОШО: используем NOT EXISTS
SELECT *
FROM dim_equipment e
WHERE NOT EXISTS (
    SELECT 1
    FROM fact_production fp
    WHERE fp.equipment_id = e.equipment_id
      AND fp.date_id BETWEEN 20240301 AND 20240331
);


-- ============================================================
-- 6. КОМПЛЕКСНЫЙ ПРИМЕР: KPI ЭФФЕКТИВНОСТИ ОБОРУДОВАНИЯ
-- ============================================================

SELECT
    e.equipment_name,
    et.type_name,
    COUNT(fp.production_id) AS total_shifts,
    ROUND(SUM(fp.tons_mined), 1) AS total_tons,
    ROUND(SUM(fp.operating_hours), 1) AS total_hours,
    -- KPI: производительность (тонн/час)
    ROUND(
        SUM(fp.tons_mined)
        / NULLIF(SUM(fp.operating_hours), 0), 2
    ) AS tons_per_hour,
    -- KPI: коэффициент использования (%)
    ROUND(
        100.0 * SUM(fp.operating_hours)
        / NULLIF(COUNT(fp.production_id) * 8.0, 0), 1
    ) AS utilization_pct,
    -- KPI: расход топлива на тонну
    ROUND(
        SUM(fp.fuel_consumed_l)
        / NULLIF(SUM(fp.tons_mined), 0), 3
    ) AS fuel_per_ton,
    -- Категория эффективности
    CASE
        WHEN SUM(fp.tons_mined) / NULLIF(SUM(fp.operating_hours), 0) > 20
            THEN 'Высокая'
        WHEN SUM(fp.tons_mined) / NULLIF(SUM(fp.operating_hours), 0) > 12
            THEN 'Средняя'
        ELSE 'Низкая'
    END AS efficiency_category,
    -- Статус данных
    CASE
        WHEN COUNT(fp.fuel_consumed_l) < COUNT(*) THEN 'Неполные данные'
        ELSE 'Данные полные'
    END AS data_status
FROM fact_production fp
JOIN dim_equipment e ON fp.equipment_id = e.equipment_id
JOIN dim_equipment_type et ON e.equipment_type_id = et.equipment_type_id
WHERE fp.date_id BETWEEN 20240301 AND 20240331
GROUP BY e.equipment_name, et.type_name
ORDER BY tons_per_hour DESC;
