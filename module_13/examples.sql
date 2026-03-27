-- ============================================================
-- Модуль 13: Оконные функции — Примеры SQL
-- СУБД: Yandex Managed Service for PostgreSQL
-- Предприятие "Руда+" — MES-система
-- ============================================================

-- ============================================================
-- 1. ОСНОВЫ: OVER() и PARTITION BY
-- ============================================================

-- 1.1 Простейшая оконная функция: OVER() без параметров
-- Добавляет общую сумму добычи ко всем строкам
SELECT
    e.equipment_name,
    fp.tons_mined,
    SUM(fp.tons_mined) OVER () AS grand_total,
    ROUND(fp.tons_mined * 100.0 / SUM(fp.tons_mined) OVER (), 2)
        AS pct_of_total
FROM fact_production fp
JOIN dim_equipment e ON e.equipment_id = fp.equipment_id
WHERE fp.date_id = 20240115 AND fp.shift_id = 1;

-- 1.2 PARTITION BY: итого по шахтам
SELECT
    e.equipment_name,
    m.mine_name,
    fp.tons_mined,
    SUM(fp.tons_mined) OVER (PARTITION BY fp.mine_id)
        AS mine_total,
    ROUND(
        fp.tons_mined * 100.0
        / SUM(fp.tons_mined) OVER (PARTITION BY fp.mine_id),
        1
    ) AS pct_of_mine,
    COUNT(*) OVER (PARTITION BY fp.mine_id)
        AS equipment_count_in_mine
FROM fact_production fp
JOIN dim_equipment e ON e.equipment_id = fp.equipment_id
JOIN dim_mine m ON m.mine_id = fp.mine_id
WHERE fp.date_id = 20240115 AND fp.shift_id = 1;

-- 1.3 PARTITION BY с несколькими столбцами
SELECT
    m.mine_name,
    s.shift_name,
    e.equipment_name,
    fp.tons_mined,
    SUM(fp.tons_mined) OVER (
        PARTITION BY fp.mine_id, fp.shift_id
    ) AS mine_shift_total,
    AVG(fp.tons_mined) OVER (
        PARTITION BY fp.mine_id, fp.shift_id
    ) AS mine_shift_avg
FROM fact_production fp
JOIN dim_equipment e ON e.equipment_id = fp.equipment_id
JOIN dim_mine m ON m.mine_id = fp.mine_id
JOIN dim_shift s ON s.shift_id = fp.shift_id
WHERE fp.date_id = 20240115;


-- ============================================================
-- 2. ORDER BY В ОКНЕ И НАРАСТАЮЩИЙ ИТОГ
-- ============================================================

-- 2.1 Нарастающий итог добычи (running total)
SELECT
    d.full_date,
    SUM(fp.tons_mined) AS daily_tons,
    SUM(SUM(fp.tons_mined)) OVER (
        ORDER BY d.full_date
    ) AS running_total
FROM fact_production fp
JOIN dim_date d ON d.date_id = fp.date_id
WHERE fp.mine_id = 1
  AND d.year = 2024 AND d.month = 1
GROUP BY d.full_date
ORDER BY d.full_date;

-- 2.2 Нарастающий итог с разбивкой по шахтам
SELECT
    d.year_month,
    m.mine_name,
    SUM(fp.tons_mined) AS month_tons,
    SUM(SUM(fp.tons_mined)) OVER (
        PARTITION BY fp.mine_id
        ORDER BY d.year_month
    ) AS cumulative_tons
FROM fact_production fp
JOIN dim_date d ON d.date_id = fp.date_id
JOIN dim_mine m ON m.mine_id = fp.mine_id
WHERE d.year = 2024
GROUP BY d.year_month, fp.mine_id, m.mine_name
ORDER BY m.mine_name, d.year_month;

-- 2.3 Нарастающее количество рейсов
SELECT
    d.full_date,
    SUM(fp.trips_count) AS daily_trips,
    SUM(SUM(fp.trips_count)) OVER (
        ORDER BY d.full_date
    ) AS cumulative_trips,
    SUM(SUM(fp.distance_km)) OVER (
        ORDER BY d.full_date
    ) AS cumulative_distance_km
FROM fact_production fp
JOIN dim_date d ON d.date_id = fp.date_id
WHERE fp.mine_id = 1 AND d.year = 2024 AND d.month = 1
GROUP BY d.full_date
ORDER BY d.full_date;


-- ============================================================
-- 3. СПЕЦИФИКАЦИЯ РАМКИ (FRAME)
-- ============================================================

-- 3.1 Скользящее среднее за 7 дней (ROWS)
SELECT
    d.full_date,
    SUM(fp.tons_mined) AS daily_tons,
    ROUND(
        AVG(SUM(fp.tons_mined)) OVER (
            ORDER BY d.full_date
            ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
        ), 2
    ) AS ma_7d,
    ROUND(
        AVG(SUM(fp.tons_mined)) OVER (
            ORDER BY d.full_date
            ROWS BETWEEN 14 PRECEDING AND CURRENT ROW
        ), 2
    ) AS ma_15d
FROM fact_production fp
JOIN dim_date d ON d.date_id = fp.date_id
WHERE fp.mine_id = 1
  AND d.year = 2024 AND d.quarter = 1
GROUP BY d.full_date
ORDER BY d.full_date;

-- 3.2 Скользящий максимум и минимум
SELECT
    d.full_date,
    SUM(fp.tons_mined) AS daily_tons,
    MIN(SUM(fp.tons_mined)) OVER (
        ORDER BY d.full_date
        ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
    ) AS min_7d,
    MAX(SUM(fp.tons_mined)) OVER (
        ORDER BY d.full_date
        ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
    ) AS max_7d,
    MAX(SUM(fp.tons_mined)) OVER (
        ORDER BY d.full_date
        ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
    ) - MIN(SUM(fp.tons_mined)) OVER (
        ORDER BY d.full_date
        ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
    ) AS range_7d
FROM fact_production fp
JOIN dim_date d ON d.date_id = fp.date_id
WHERE fp.mine_id = 1 AND d.year = 2024 AND d.month <= 2
GROUP BY d.full_date
ORDER BY d.full_date;

-- 3.3 Центрированное скользящее среднее
SELECT
    d.full_date,
    SUM(fp.tons_mined) AS daily_tons,
    ROUND(
        AVG(SUM(fp.tons_mined)) OVER (
            ORDER BY d.full_date
            ROWS BETWEEN 3 PRECEDING AND 3 FOLLOWING
        ), 2
    ) AS centered_ma_7d
FROM fact_production fp
JOIN dim_date d ON d.date_id = fp.date_id
WHERE fp.mine_id = 1 AND d.year = 2024 AND d.month = 1
GROUP BY d.full_date
ORDER BY d.full_date;

-- 3.4 Рамка ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
-- (явный нарастающий итог)
SELECT
    d.full_date,
    SUM(fp.fuel_consumed_l) AS daily_fuel,
    SUM(SUM(fp.fuel_consumed_l)) OVER (
        ORDER BY d.full_date
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS cumulative_fuel
FROM fact_production fp
JOIN dim_date d ON d.date_id = fp.date_id
WHERE fp.mine_id = 1
  AND d.year = 2024 AND d.month = 1
GROUP BY d.full_date
ORDER BY d.full_date;

-- 3.5 Рамка ROWS BETWEEN CURRENT ROW AND UNBOUNDED FOLLOWING
-- (остаток до конца)
SELECT
    d.full_date,
    SUM(fp.tons_mined) AS daily_tons,
    SUM(SUM(fp.tons_mined)) OVER (
        ORDER BY d.full_date
        ROWS BETWEEN CURRENT ROW AND UNBOUNDED FOLLOWING
    ) AS remaining_total
FROM fact_production fp
JOIN dim_date d ON d.date_id = fp.date_id
WHERE fp.mine_id = 1
  AND d.year = 2024 AND d.month = 1
GROUP BY d.full_date
ORDER BY d.full_date;


-- ============================================================
-- 4. АГРЕГАТНЫЕ ФУНКЦИИ С ВЛОЖЕННЫМИ ОПЕРАТОРАМИ
-- ============================================================

-- 4.1 Доля оператора с накопительным процентом (Парето)
SELECT
    o.last_name || ' ' || LEFT(o.first_name, 1) || '.' AS operator,
    SUM(fp.tons_mined) AS total_tons,
    ROUND(
        SUM(fp.tons_mined) * 100.0
        / SUM(SUM(fp.tons_mined)) OVER (),
        1
    ) AS pct_total,
    ROUND(
        SUM(SUM(fp.tons_mined)) OVER (
            ORDER BY SUM(fp.tons_mined) DESC
        ) * 100.0
        / SUM(SUM(fp.tons_mined)) OVER (),
        1
    ) AS cumulative_pct
FROM fact_production fp
JOIN dim_operator o ON o.operator_id = fp.operator_id
WHERE fp.date_id BETWEEN 20240101 AND 20240131
GROUP BY o.operator_id, o.last_name, o.first_name
ORDER BY total_tons DESC;

-- 4.2 Сравнение с средним по группе
SELECT
    e.equipment_name,
    et.type_name,
    SUM(fp.tons_mined) AS total_tons,
    ROUND(AVG(SUM(fp.tons_mined)) OVER (
        PARTITION BY e.equipment_type_id
    ), 2) AS avg_for_type,
    ROUND(
        SUM(fp.tons_mined)
        - AVG(SUM(fp.tons_mined)) OVER (PARTITION BY e.equipment_type_id),
        2
    ) AS diff_from_avg,
    CASE
        WHEN SUM(fp.tons_mined) > AVG(SUM(fp.tons_mined))
            OVER (PARTITION BY e.equipment_type_id) THEN 'Выше среднего'
        ELSE 'Ниже среднего'
    END AS performance
FROM fact_production fp
JOIN dim_equipment e ON e.equipment_id = fp.equipment_id
JOIN dim_equipment_type et ON et.equipment_type_id = e.equipment_type_id
WHERE fp.date_id BETWEEN 20240101 AND 20240331
GROUP BY e.equipment_id, e.equipment_name,
         e.equipment_type_id, et.type_name
ORDER BY et.type_name, total_tons DESC;


-- ============================================================
-- 5. ФУНКЦИИ РАНЖИРОВАНИЯ
-- ============================================================

-- 5.1 Сравнение ROW_NUMBER, RANK, DENSE_RANK
SELECT
    o.last_name,
    SUM(fp.tons_mined) AS total_tons,
    ROW_NUMBER() OVER (ORDER BY SUM(fp.tons_mined) DESC)  AS row_num,
    RANK()       OVER (ORDER BY SUM(fp.tons_mined) DESC)  AS rank_val,
    DENSE_RANK() OVER (ORDER BY SUM(fp.tons_mined) DESC)  AS dense_rank_val,
    NTILE(3)     OVER (ORDER BY SUM(fp.tons_mined) DESC)  AS tercile
FROM fact_production fp
JOIN dim_operator o ON o.operator_id = fp.operator_id
WHERE fp.date_id BETWEEN 20240101 AND 20240131
GROUP BY o.operator_id, o.last_name
ORDER BY total_tons DESC;

-- 5.2 ТОП-3 дня по добыче для каждого оборудования
WITH daily AS (
    SELECT
        fp.equipment_id,
        e.equipment_name,
        d.full_date,
        SUM(fp.tons_mined) AS daily_tons,
        ROW_NUMBER() OVER (
            PARTITION BY fp.equipment_id
            ORDER BY SUM(fp.tons_mined) DESC
        ) AS rn
    FROM fact_production fp
    JOIN dim_equipment e ON e.equipment_id = fp.equipment_id
    JOIN dim_date d ON d.date_id = fp.date_id
    WHERE d.year = 2024
    GROUP BY fp.equipment_id, e.equipment_name, d.full_date
)
SELECT equipment_name, full_date, daily_tons
FROM daily
WHERE rn <= 3
ORDER BY equipment_name, rn;

-- 5.3 Ранжирование оборудования по надёжности
SELECT
    e.equipment_name,
    et.type_name,
    COUNT(*) AS downtime_events,
    ROUND(AVG(fd.duration_min), 0) AS avg_downtime_min,
    SUM(fd.duration_min) AS total_downtime_min,
    RANK() OVER (
        PARTITION BY e.equipment_type_id
        ORDER BY SUM(fd.duration_min) ASC
    ) AS reliability_rank
FROM fact_equipment_downtime fd
JOIN dim_equipment e ON e.equipment_id = fd.equipment_id
JOIN dim_equipment_type et ON et.equipment_type_id = e.equipment_type_id
WHERE NOT fd.is_planned
GROUP BY e.equipment_id, e.equipment_name,
         e.equipment_type_id, et.type_name
ORDER BY et.type_name, reliability_rank;

-- 5.4 NTILE: сегментация по эффективности
WITH equip_stats AS (
    SELECT
        e.equipment_id,
        e.equipment_name,
        et.type_name,
        ROUND(AVG(fp.tons_mined / NULLIF(fp.operating_hours, 0)), 2)
            AS tons_per_hour,
        NTILE(4) OVER (
            ORDER BY AVG(fp.tons_mined / NULLIF(fp.operating_hours, 0)) DESC
        ) AS efficiency_quartile
    FROM fact_production fp
    JOIN dim_equipment e ON e.equipment_id = fp.equipment_id
    JOIN dim_equipment_type et ON et.equipment_type_id = e.equipment_type_id
    WHERE fp.date_id BETWEEN 20240101 AND 20240630
    GROUP BY e.equipment_id, e.equipment_name, et.type_name
)
SELECT
    *,
    CASE efficiency_quartile
        WHEN 1 THEN 'Высокая эффективность'
        WHEN 2 THEN 'Выше среднего'
        WHEN 3 THEN 'Ниже среднего'
        WHEN 4 THEN 'Требует внимания'
    END AS efficiency_category
FROM equip_stats
ORDER BY efficiency_quartile, tons_per_hour DESC;

-- 5.5 Дедупликация: оставить последнюю запись с ROW_NUMBER
-- (если несколько записей за одну смену для одного оборудования)
WITH ranked AS (
    SELECT
        *,
        ROW_NUMBER() OVER (
            PARTITION BY date_id, shift_id, equipment_id
            ORDER BY production_id DESC
        ) AS rn
    FROM fact_production
)
SELECT *
FROM ranked
WHERE rn = 1;


-- ============================================================
-- 6. ФУНКЦИИ СМЕЩЕНИЯ
-- ============================================================

-- 6.1 LAG: сравнение с предыдущим днём
SELECT
    d.full_date,
    SUM(fp.tons_mined) AS today_tons,
    LAG(SUM(fp.tons_mined), 1) OVER (ORDER BY d.full_date)
        AS yesterday_tons,
    LAG(SUM(fp.tons_mined), 7) OVER (ORDER BY d.full_date)
        AS week_ago_tons,
    ROUND(
        (SUM(fp.tons_mined)
         - LAG(SUM(fp.tons_mined), 1) OVER (ORDER BY d.full_date))
        * 100.0
        / NULLIF(LAG(SUM(fp.tons_mined), 1) OVER (ORDER BY d.full_date), 0),
        1
    ) AS day_over_day_pct
FROM fact_production fp
JOIN dim_date d ON d.date_id = fp.date_id
WHERE fp.mine_id = 1 AND d.year = 2024 AND d.month = 1
GROUP BY d.full_date
ORDER BY d.full_date;

-- 6.2 LEAD: следующий простой
SELECT
    e.equipment_name,
    d.full_date AS downtime_date,
    dr.reason_name,
    fd.duration_min,
    LEAD(d.full_date, 1) OVER (
        PARTITION BY fd.equipment_id
        ORDER BY d.full_date
    ) AS next_downtime_date,
    LEAD(d.full_date, 1) OVER (
        PARTITION BY fd.equipment_id
        ORDER BY d.full_date
    ) - d.full_date AS days_between
FROM fact_equipment_downtime fd
JOIN dim_equipment e ON e.equipment_id = fd.equipment_id
JOIN dim_date d ON d.date_id = fd.date_id
JOIN dim_downtime_reason dr ON dr.reason_id = fd.reason_id
WHERE fd.is_planned AND dr.reason_code = 'MAINT_PLAN'
ORDER BY e.equipment_name, d.full_date;

-- 6.3 FIRST_VALUE и LAST_VALUE
SELECT
    d.full_date,
    SUM(fp.tons_mined) AS daily_tons,
    FIRST_VALUE(SUM(fp.tons_mined)) OVER (
        PARTITION BY d.month
        ORDER BY d.full_date
    ) AS first_day_tons,
    LAST_VALUE(SUM(fp.tons_mined)) OVER (
        PARTITION BY d.month
        ORDER BY d.full_date
        ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING
    ) AS last_day_tons,
    FIRST_VALUE(d.full_date) OVER (
        PARTITION BY d.month
        ORDER BY SUM(fp.tons_mined) DESC
        ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING
    ) AS best_day_date
FROM fact_production fp
JOIN dim_date d ON d.date_id = fp.date_id
WHERE fp.mine_id = 1 AND d.year = 2024 AND d.month <= 3
GROUP BY d.full_date, d.month
ORDER BY d.full_date;

-- 6.4 NTH_VALUE: второй и третий лучший день в месяце
SELECT DISTINCT
    d.year_month,
    FIRST_VALUE(daily_tons) OVER w AS best_day,
    NTH_VALUE(daily_tons, 2) OVER w AS second_best_day,
    NTH_VALUE(daily_tons, 3) OVER w AS third_best_day
FROM (
    SELECT fp.date_id, SUM(fp.tons_mined) AS daily_tons
    FROM fact_production fp WHERE fp.mine_id = 1
    GROUP BY fp.date_id
) sub
JOIN dim_date d ON d.date_id = sub.date_id
WHERE d.year = 2024
WINDOW w AS (
    PARTITION BY d.year_month
    ORDER BY daily_tons DESC
    ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING
)
ORDER BY d.year_month;

-- 6.5 LAG для определения скорости изменения температуры
SELECT
    d.full_date,
    t.hour_minute,
    ft.sensor_value AS temperature,
    LAG(ft.sensor_value, 1) OVER w AS prev_temp,
    ft.sensor_value - LAG(ft.sensor_value, 1) OVER w AS temp_delta,
    LAG(ft.sensor_value, 4) OVER w AS temp_1h_ago,
    ROUND(
        (ft.sensor_value - LAG(ft.sensor_value, 4) OVER w) / 4.0,
        2
    ) AS avg_delta_per_15min
FROM fact_equipment_telemetry ft
JOIN dim_date d ON d.date_id = ft.date_id
JOIN dim_time t ON t.time_id = ft.time_id
WHERE ft.sensor_id = 1  -- температура ПДМ-001
  AND ft.date_id = 20240102
WINDOW w AS (ORDER BY ft.date_id, ft.time_id)
ORDER BY t.hour_minute;


-- ============================================================
-- 7. СТАТИСТИЧЕСКИЕ И ПРОЦЕНТИЛЬНЫЕ ФУНКЦИИ
-- ============================================================

-- 7.1 PERCENT_RANK и CUME_DIST
SELECT
    o.last_name,
    et.type_name,
    ROUND(AVG(fp.tons_mined / NULLIF(fp.operating_hours, 0)), 2)
        AS tons_per_hour,
    ROUND(PERCENT_RANK() OVER (
        PARTITION BY e.equipment_type_id
        ORDER BY AVG(fp.tons_mined / NULLIF(fp.operating_hours, 0))
    )::NUMERIC, 3) AS pct_rank,
    ROUND(CUME_DIST() OVER (
        PARTITION BY e.equipment_type_id
        ORDER BY AVG(fp.tons_mined / NULLIF(fp.operating_hours, 0))
    )::NUMERIC, 3) AS cume_dist
FROM fact_production fp
JOIN dim_operator o ON o.operator_id = fp.operator_id
JOIN dim_equipment e ON e.equipment_id = fp.equipment_id
JOIN dim_equipment_type et ON et.equipment_type_id = e.equipment_type_id
WHERE fp.date_id BETWEEN 20240101 AND 20240630
GROUP BY o.operator_id, o.last_name,
         e.equipment_type_id, et.type_name;

-- 7.2 PERCENTILE_CONT: медиана и квартили
SELECT
    m.mine_name,
    COUNT(*) AS samples_count,
    ROUND(AVG(fq.fe_content), 2) AS avg_fe,
    ROUND(PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY fq.fe_content)::NUMERIC, 2) AS q1,
    ROUND(PERCENTILE_CONT(0.50) WITHIN GROUP (ORDER BY fq.fe_content)::NUMERIC, 2) AS median,
    ROUND(PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY fq.fe_content)::NUMERIC, 2) AS q3,
    ROUND(PERCENTILE_DISC(0.90) WITHIN GROUP (ORDER BY fq.fe_content)::NUMERIC, 2) AS p90
FROM fact_ore_quality fq
JOIN dim_mine m ON m.mine_id = fq.mine_id
WHERE fq.date_id BETWEEN 20240101 AND 20240630
GROUP BY m.mine_id, m.mine_name;

-- 7.3 IQR-метод для обнаружения выбросов
WITH quartiles AS (
    SELECT
        mine_id,
        PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY fe_content) AS q1,
        PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY fe_content) AS q3
    FROM fact_ore_quality
    WHERE date_id BETWEEN 20240101 AND 20240630
    GROUP BY mine_id
)
SELECT
    fq.sample_number,
    d.full_date,
    m.mine_name,
    fq.fe_content,
    CASE
        WHEN fq.fe_content < q.q1 - 1.5 * (q.q3 - q.q1) THEN 'Выброс (низ)'
        WHEN fq.fe_content > q.q3 + 1.5 * (q.q3 - q.q1) THEN 'Выброс (верх)'
        ELSE 'Норма'
    END AS outlier_status
FROM fact_ore_quality fq
JOIN quartiles q ON q.mine_id = fq.mine_id
JOIN dim_date d ON d.date_id = fq.date_id
JOIN dim_mine m ON m.mine_id = fq.mine_id
WHERE fq.fe_content < q.q1 - 1.5 * (q.q3 - q.q1)
   OR fq.fe_content > q.q3 + 1.5 * (q.q3 - q.q1)
ORDER BY d.full_date
LIMIT 20;


-- ============================================================
-- 8. ИМЕНОВАННЫЕ ОКНА (WINDOW)
-- ============================================================

-- 8.1 Несколько именованных окон
SELECT
    d.full_date,
    SUM(fp.tons_mined) AS daily_tons,
    AVG(SUM(fp.tons_mined)) OVER w7   AS avg_7d,
    MIN(SUM(fp.tons_mined)) OVER w7   AS min_7d,
    MAX(SUM(fp.tons_mined)) OVER w7   AS max_7d,
    AVG(SUM(fp.tons_mined)) OVER w30  AS avg_30d,
    SUM(SUM(fp.tons_mined)) OVER w_cum AS running_total
FROM fact_production fp
JOIN dim_date d ON d.date_id = fp.date_id
WHERE fp.mine_id = 1 AND d.year = 2024 AND d.quarter = 1
GROUP BY d.full_date
WINDOW
    w7    AS (ORDER BY d.full_date ROWS BETWEEN 6 PRECEDING AND CURRENT ROW),
    w30   AS (ORDER BY d.full_date ROWS BETWEEN 29 PRECEDING AND CURRENT ROW),
    w_cum AS (ORDER BY d.full_date)
ORDER BY d.full_date;

-- 8.2 Наследование окон
SELECT
    d.full_date,
    fp.equipment_id,
    e.equipment_name,
    SUM(fp.tons_mined) AS daily_tons,
    SUM(SUM(fp.tons_mined)) OVER (
        base_w ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS running_total,
    AVG(SUM(fp.tons_mined)) OVER (
        base_w ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
    ) AS avg_7d,
    FIRST_VALUE(SUM(fp.tons_mined)) OVER (
        base_w ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING
    ) AS first_day_value
FROM fact_production fp
JOIN dim_date d ON d.date_id = fp.date_id
JOIN dim_equipment e ON e.equipment_id = fp.equipment_id
WHERE fp.mine_id = 1 AND d.year = 2024 AND d.month = 1
GROUP BY d.full_date, fp.equipment_id, e.equipment_name
WINDOW base_w AS (
    PARTITION BY fp.equipment_id
    ORDER BY d.full_date
)
ORDER BY fp.equipment_id, d.full_date;


-- ============================================================
-- 9. КОМПЛЕКСНЫЕ ПРИМЕРЫ
-- ============================================================

-- 9.1 Кейс: предиктивное обслуживание
WITH telemetry_enriched AS (
    SELECT
        ft.telemetry_id,
        d.full_date,
        t.hour_minute,
        st.type_code,
        ft.sensor_value,
        AVG(ft.sensor_value) OVER w8 AS avg_2h,
        STDDEV(ft.sensor_value) OVER w8 AS stddev_2h,
        ft.sensor_value - LAG(ft.sensor_value) OVER w_seq AS delta,
        PERCENT_RANK() OVER (
            PARTITION BY ft.sensor_id
            ORDER BY ft.sensor_value
        ) AS pct_rank
    FROM fact_equipment_telemetry ft
    JOIN dim_date d ON d.date_id = ft.date_id
    JOIN dim_time t ON t.time_id = ft.time_id
    JOIN dim_sensor s ON s.sensor_id = ft.sensor_id
    JOIN dim_sensor_type st ON st.sensor_type_id = s.sensor_type_id
    WHERE ft.equipment_id = 1
      AND st.type_code IN ('TEMP_ENGINE', 'VIBRATION')
      AND ft.date_id BETWEEN 20240101 AND 20240107
    WINDOW
        w8 AS (PARTITION BY ft.sensor_id
               ORDER BY ft.date_id, ft.time_id
               ROWS BETWEEN 7 PRECEDING AND CURRENT ROW),
        w_seq AS (PARTITION BY ft.sensor_id
                  ORDER BY ft.date_id, ft.time_id)
)
SELECT
    full_date, hour_minute, type_code, sensor_value,
    ROUND(avg_2h::NUMERIC, 2) AS avg_2h,
    ROUND(delta::NUMERIC, 2) AS delta,
    ROUND(pct_rank::NUMERIC, 3) AS pct_rank,
    CASE
        WHEN pct_rank > 0.95 THEN 'ОПАСНОСТЬ'
        WHEN pct_rank > 0.85 THEN 'ВНИМАНИЕ'
        ELSE 'Норма'
    END AS risk_level
FROM telemetry_enriched
WHERE pct_rank > 0.80
ORDER BY full_date, hour_minute;

-- 9.2 Кейс: OEE-дашборд (Overall Equipment Effectiveness)
WITH daily_stats AS (
    SELECT
        d.full_date,
        fp.equipment_id,
        e.equipment_name,
        SUM(fp.operating_hours) AS work_hours,
        SUM(fp.tons_mined) AS tons,
        SUM(fp.fuel_consumed_l) AS fuel
    FROM fact_production fp
    JOIN dim_date d ON d.date_id = fp.date_id
    JOIN dim_equipment e ON e.equipment_id = fp.equipment_id
    WHERE d.year = 2024 AND d.month = 1 AND fp.mine_id = 1
    GROUP BY d.full_date, fp.equipment_id, e.equipment_name
),
enriched AS (
    SELECT
        *,
        -- Скользящая производительность
        ROUND(AVG(tons / NULLIF(work_hours, 0)) OVER w7, 2) AS avg_productivity_7d,
        -- Ранг по производительности за день
        RANK() OVER (
            PARTITION BY full_date
            ORDER BY tons DESC
        ) AS daily_rank,
        -- Сравнение с предыдущим днём
        LAG(tons) OVER (
            PARTITION BY equipment_id
            ORDER BY full_date
        ) AS prev_day_tons,
        -- Нарастающий итог
        SUM(tons) OVER (
            PARTITION BY equipment_id
            ORDER BY full_date
        ) AS cumulative_tons
    FROM daily_stats
    WINDOW w7 AS (
        PARTITION BY equipment_id
        ORDER BY full_date
        ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
    )
)
SELECT
    full_date,
    equipment_name,
    tons,
    daily_rank,
    ROUND(avg_productivity_7d, 2) AS avg_prod_7d,
    prev_day_tons,
    CASE
        WHEN tons > prev_day_tons THEN 'рост'
        WHEN tons < prev_day_tons THEN 'снижение'
        ELSE 'без изменений'
    END AS trend,
    cumulative_tons
FROM enriched
ORDER BY full_date, daily_rank;

-- 9.3 Сравнение смен (дневная vs ночная)
SELECT
    d.full_date,
    s.shift_name,
    SUM(fp.tons_mined) AS shift_tons,
    LAG(SUM(fp.tons_mined)) OVER (
        PARTITION BY fp.mine_id
        ORDER BY d.full_date, s.shift_id
    ) AS prev_shift_tons,
    ROUND(
        SUM(fp.tons_mined) * 100.0
        / SUM(SUM(fp.tons_mined)) OVER (
            PARTITION BY d.full_date
        ), 1
    ) AS shift_pct_of_day,
    ROUND(
        AVG(SUM(fp.tons_mined)) OVER (
            PARTITION BY s.shift_id
            ORDER BY d.full_date
            ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
        ), 2
    ) AS ma_7d_for_shift
FROM fact_production fp
JOIN dim_date d ON d.date_id = fp.date_id
JOIN dim_shift s ON s.shift_id = fp.shift_id
WHERE fp.mine_id = 1 AND d.year = 2024 AND d.month = 1
GROUP BY d.full_date, s.shift_id, s.shift_name, fp.mine_id
ORDER BY d.full_date, s.shift_id;
