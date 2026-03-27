# Результаты лабораторной работы — Модуль 11

## Использование табличных выражений

> Результаты выполнения SQL-запросов из лабораторной работы.
> **Примечание:** Задания, связанные с созданием VIEW, MATERIALIZED VIEW и функций,
> показывают результаты соответствующих SELECT-запросов.

---

### Задание 1: Сводка по добыче (данные для VIEW)

```sql
SELECT d.full_date,
       m.mine_name,
       sh.shift_name,
       COUNT(*) AS record_count,
       SUM(p.tons_mined) AS total_tons,
       SUM(p.fuel_consumed_l) AS total_fuel,
       ROUND(AVG(p.trips_count)::numeric, 1) AS avg_trips
FROM fact_production p
JOIN dim_date d ON p.date_id = d.date_id
JOIN dim_mine m ON p.mine_id = m.mine_id
JOIN dim_shift sh ON p.shift_id = sh.shift_id
WHERE p.date_id BETWEEN 20240301 AND 20240331
  AND m.mine_name LIKE '%Северная%'
GROUP BY d.full_date, m.mine_name, sh.shift_name
HAVING COUNT(*) > 0
ORDER BY d.full_date, sh.shift_name
```

**Результат:**

| full_date | mine_name | shift_name | record_count | total_tons | total_fuel | avg_trips |
| --- | --- | --- | --- | --- | --- | --- |
| 2024-03-01 | Шахта "Северная" | Дневная смена | 5 | 559.71 | 804.33 | 6.8 |
| 2024-03-01 | Шахта "Северная" | Ночная смена | 5 | 551.83 | 766.19 | 6.0 |
| 2024-03-02 | Шахта "Северная" | Дневная смена | 5 | 384.64 | 740.80 | 6.6 |
| 2024-03-02 | Шахта "Северная" | Ночная смена | 5 | 320.50 | 748.19 | 5.6 |
| 2024-03-03 | Шахта "Северная" | Дневная смена | 5 | 329.79 | 751.53 | 6.6 |
| 2024-03-03 | Шахта "Северная" | Ночная смена | 4 | 317.70 | 654.40 | 6.8 |
| 2024-03-04 | Шахта "Северная" | Дневная смена | 5 | 547.74 | 767.83 | 6.6 |
| 2024-03-04 | Шахта "Северная" | Ночная смена | 5 | 564.57 | 764.88 | 5.6 |
| 2024-03-05 | Шахта "Северная" | Дневная смена | 5 | 605.06 | 741.30 | 6.4 |
| 2024-03-05 | Шахта "Северная" | Ночная смена | 5 | 519.67 | 782.07 | 6.4 |
| 2024-03-06 | Шахта "Северная" | Дневная смена | 5 | 597.67 | 802.96 | 7.2 |
| 2024-03-06 | Шахта "Северная" | Ночная смена | 4 | 508.45 | 617.88 | 7.3 |
| 2024-03-07 | Шахта "Северная" | Дневная смена | 5 | 511.90 | 764.35 | 6.4 |
| 2024-03-07 | Шахта "Северная" | Ночная смена | 5 | 563.12 | 801.03 | 6.6 |
| 2024-03-08 | Шахта "Северная" | Дневная смена | 5 | 619.42 | 761.97 | 6.6 |

*... (показаны первые 15 строк из 62)*

### Задание 2: Внеплановые простои (данные для VIEW с CHECK OPTION)

```sql
SELECT COUNT(*) AS total_downtime,
       SUM(CASE WHEN is_planned = FALSE THEN 1 ELSE 0 END) AS unplanned_count,
       SUM(CASE WHEN is_planned = TRUE THEN 1 ELSE 0 END) AS planned_count
FROM fact_equipment_downtime
```

**Результат:**

| total_downtime | unplanned_count | planned_count |
| --- | --- | --- |
| 1735 | 335 | 1400 |

*(1 строк)*

### Задание 3: Качество руды по шахтам и месяцам (MATERIALIZED VIEW)

```sql
SELECT m.mine_name,
       TO_CHAR(d.full_date, 'YYYY-MM') AS year_month,
       COUNT(*) AS sample_count,
       ROUND(AVG(q.fe_content)::numeric, 2) AS avg_fe,
       ROUND(MIN(q.fe_content)::numeric, 2) AS min_fe,
       ROUND(MAX(q.fe_content)::numeric, 2) AS max_fe,
       ROUND(AVG(q.sio2_content)::numeric, 2) AS avg_sio2,
       ROUND(AVG(q.moisture_pct)::numeric, 2) AS avg_moisture
FROM fact_ore_quality q
JOIN dim_mine m ON q.mine_id = m.mine_id
JOIN dim_date d ON q.date_id = d.date_id
GROUP BY m.mine_name, TO_CHAR(d.full_date, 'YYYY-MM')
ORDER BY m.mine_name, year_month
```

**Ошибка:** column q.moisture_pct does not exist
LINE 9:        ROUND(AVG(q.moisture_pct)::numeric, 2) AS avg_moistur...
                         ^


### Задание 4: Лучший оператор каждой смены (Q1 2024)

```sql
SELECT * FROM (
    SELECT
        sh.shift_name,
        o.last_name || ' ' || LEFT(o.first_name, 1) || '.' AS operator_name,
        SUM(p.tons_mined) AS total_mined,
        ROW_NUMBER() OVER (PARTITION BY p.shift_id ORDER BY SUM(p.tons_mined) DESC) AS rn
    FROM fact_production p
    JOIN dim_operator o ON p.operator_id = o.operator_id
    JOIN dim_shift sh ON p.shift_id = sh.shift_id
    WHERE p.date_id BETWEEN 20240101 AND 20240331
    GROUP BY p.shift_id, sh.shift_name, o.operator_id, o.last_name, o.first_name
) sub
WHERE rn = 1
ORDER BY shift_name
```

**Результат:**

| shift_name | operator_name | total_mined | rn |
| --- | --- | --- | --- |
| Дневная смена | Сидоров Д. | 12854.85 | 1 |
| Ночная смена | Сидоров Д. | 12783.16 | 1 |

*(2 строк)*

### Задание 5: Доступность оборудования по шахтам (CTE, Q1 2024)

```sql
WITH production_cte AS (
    SELECT e.mine_id,
           SUM(p.operating_hours) AS total_operating_hours,
           SUM(p.tons_mined) AS total_tons
    FROM fact_production p
    JOIN dim_equipment e ON p.equipment_id = e.equipment_id
    WHERE p.date_id BETWEEN 20240101 AND 20240331
    GROUP BY e.mine_id
),
downtime_cte AS (
    SELECT e.mine_id,
           SUM(fd.duration_min) / 60.0 AS total_downtime_hours
    FROM fact_equipment_downtime fd
    JOIN dim_equipment e ON fd.equipment_id = e.equipment_id
    WHERE fd.date_id BETWEEN 20240101 AND 20240331
    GROUP BY e.mine_id
)
SELECT
    m.mine_name,
    ROUND(COALESCE(p.total_operating_hours, 0)::numeric, 1) AS operating_hours,
    ROUND(COALESCE(d.total_downtime_hours, 0)::numeric, 1) AS downtime_hours,
    ROUND(COALESCE(p.total_tons, 0)::numeric, 1) AS total_tons,
    ROUND(
        COALESCE(p.total_operating_hours, 0) /
        NULLIF(COALESCE(p.total_operating_hours, 0) + COALESCE(d.total_downtime_hours, 0), 0) * 100
    ::numeric, 1) AS availability_pct
FROM dim_mine m
LEFT JOIN production_cte p ON p.mine_id = m.mine_id
LEFT JOIN downtime_cte d ON d.mine_id = m.mine_id
WHERE m.status = 'active'
ORDER BY availability_pct ASC
```

**Результат:**

| mine_name | operating_hours | downtime_hours | total_tons | availability_pct |
| --- | --- | --- | --- | --- |
| Шахта "Северная" | 9443.7 | 263.4 | 83808.8 | 97.3 |
| Шахта "Южная" | 5589.9 | 154.5 | 48000.1 | 97.3 |

*(2 строк)*

### Задание 6: Отчёт по простоям equipment_id=1, январь 2024

```sql
SELECT d.full_date,
       r.reason_name,
       r.category,
       fd.duration_min,
       ROUND(fd.duration_min / 60.0, 1) AS duration_hours,
       fd.is_planned,
       fd.comment
FROM fact_equipment_downtime fd
JOIN dim_date d ON fd.date_id = d.date_id
JOIN dim_downtime_reason r ON fd.reason_id = r.reason_id
WHERE fd.equipment_id = 1
  AND fd.date_id BETWEEN 20240101 AND 20240131
ORDER BY d.full_date
```

**Результат:**

| full_date | reason_name | category | duration_min | duration_hours | is_planned | comment |
| --- | --- | --- | --- | --- | --- | --- |
| 2024-01-01 | Заправка топливом | плановый | 30.00 | 0.5 | True | Плановая заправка |
| 2024-01-03 | Ожидание транспорта | организационный | 109.29 | 1.8 | False | NULL |
| 2024-01-04 | Заправка топливом | плановый | 30.00 | 0.5 | True | Плановая заправка |
| 2024-01-08 | Ожидание погрузки | организационный | 144.75 | 2.4 | False | NULL |
| 2024-01-10 | Заправка топливом | плановый | 30.00 | 0.5 | True | Плановая заправка |
| 2024-01-13 | Заправка топливом | плановый | 30.00 | 0.5 | True | Плановая заправка |
| 2024-01-15 | Плановое техническое обслуживание | плановый | 480.00 | 8.0 | True | Плановое ТО по регламенту |
| 2024-01-16 | Заправка топливом | плановый | 30.00 | 0.5 | True | Плановая заправка |
| 2024-01-18 | Ожидание транспорта | организационный | 125.99 | 2.1 | False | NULL |
| 2024-01-19 | Заправка топливом | плановый | 30.00 | 0.5 | True | Плановая заправка |
| 2024-01-22 | Отсутствие оператора | организационный | 170.43 | 2.8 | False | NULL |
| 2024-01-22 | Заправка топливом | плановый | 30.00 | 0.5 | True | Плановая заправка |
| 2024-01-25 | Заправка топливом | плановый | 30.00 | 0.5 | True | Плановая заправка |
| 2024-01-31 | Заправка топливом | плановый | 30.00 | 0.5 | True | Плановая заправка |

*(14 строк)*

### Задание 7: Иерархия локаций

> Таблица `dim_location_hierarchy` не найдена. Задание требует предварительного создания таблицы.

### Задание 8: Рабочие дни без добычи (февраль 2024, mine_id=1)

```sql
WITH RECURSIVE dates AS (
    SELECT 20240201 AS date_id
    UNION ALL
    SELECT date_id + 1 FROM dates WHERE date_id < 20240229
)
SELECT d.full_date,
       d.day_of_week_name,
       CASE WHEN d.is_weekend THEN 'выходной' ELSE 'рабочий' END AS day_type
FROM dates dt
JOIN dim_date d ON dt.date_id = d.date_id
WHERE NOT EXISTS (
    SELECT 1 FROM fact_production p
    WHERE p.date_id = dt.date_id
      AND p.mine_id = 1
)
AND d.is_weekend = FALSE
ORDER BY d.full_date
```

**Результат:**

| full_date | day_of_week_name | day_type |
| --- | --- | --- |

*(0 строк)*

### Задание 9: 7-дневное скользящее среднее добычи (mine_id=1, Q1 2024)

```sql
WITH daily_production AS (
    SELECT p.date_id,
           d.full_date,
           SUM(p.tons_mined) AS daily_tons
    FROM fact_production p
    JOIN dim_date d ON p.date_id = d.date_id
    WHERE p.mine_id = 1
      AND p.date_id BETWEEN 20240101 AND 20240331
    GROUP BY p.date_id, d.full_date
)
SELECT full_date,
       ROUND(daily_tons::numeric, 1) AS daily_tons,
       ROUND(AVG(daily_tons) OVER (ORDER BY date_id ROWS BETWEEN 6 PRECEDING AND CURRENT ROW)::numeric, 1) AS moving_avg_7d,
       ROUND(MAX(daily_tons) OVER (ORDER BY date_id ROWS BETWEEN 6 PRECEDING AND CURRENT ROW)::numeric, 1) AS moving_max_7d,
       ROUND(
           (daily_tons - AVG(daily_tons) OVER (ORDER BY date_id ROWS BETWEEN 6 PRECEDING AND CURRENT ROW))
           / NULLIF(AVG(daily_tons) OVER (ORDER BY date_id ROWS BETWEEN 6 PRECEDING AND CURRENT ROW), 0) * 100
       ::numeric, 1) AS deviation_pct,
       CASE
           WHEN ABS(
               (daily_tons - AVG(daily_tons) OVER (ORDER BY date_id ROWS BETWEEN 6 PRECEDING AND CURRENT ROW))
               / NULLIF(AVG(daily_tons) OVER (ORDER BY date_id ROWS BETWEEN 6 PRECEDING AND CURRENT ROW), 0) * 100
           ) > 20 THEN 'Аномалия'
           ELSE ''
       END AS anomaly_flag
FROM daily_production
ORDER BY date_id
```

**Результат:**

| full_date | daily_tons | moving_avg_7d | moving_max_7d | deviation_pct | anomaly_flag |
| --- | --- | --- | --- | --- | --- |
| 2024-01-01 | 1010.6 | 1010.6 | 1010.6 | 0.0 |  |
| 2024-01-02 | 966.1 | 988.3 | 1010.6 | -2.3 |  |
| 2024-01-03 | 1003.5 | 993.4 | 1010.6 | 1.0 |  |
| 2024-01-04 | 1012.5 | 998.2 | 1012.5 | 1.4 |  |
| 2024-01-05 | 876.4 | 973.8 | 1012.5 | -10.0 |  |
| 2024-01-06 | 601.9 | 911.8 | 1012.5 | -34.0 | Аномалия |
| 2024-01-07 | 595.9 | 866.7 | 1012.5 | -31.2 | Аномалия |
| 2024-01-08 | 1019.7 | 868.0 | 1019.7 | 17.5 |  |
| 2024-01-09 | 1043.8 | 879.1 | 1043.8 | 18.7 |  |
| 2024-01-10 | 1043.0 | 884.7 | 1043.8 | 17.9 |  |
| 2024-01-11 | 1036.6 | 888.2 | 1043.8 | 16.7 |  |
| 2024-01-12 | 1081.8 | 917.5 | 1081.8 | 17.9 |  |
| 2024-01-13 | 497.3 | 902.6 | 1081.8 | -44.9 | Аномалия |
| 2024-01-14 | 624.2 | 906.6 | 1081.8 | -31.1 | Аномалия |
| 2024-01-15 | 1045.1 | 910.3 | 1081.8 | 14.8 |  |

*... (показаны первые 15 строк из 91)*

### Задание 10: Детализация качества руды (для VIEW)

```sql
SELECT q.quality_id,
       d.full_date,
       m.mine_name,
       sh.shift_name,
       g.grade_name,
       q.fe_content,
       q.sio2_content,
       q.moisture_pct,
       CASE
           WHEN q.fe_content >= 65 THEN 'Богатая'
           WHEN q.fe_content >= 55 THEN 'Средняя'
           WHEN q.fe_content >= 45 THEN 'Бедная'
           ELSE 'Забалансовая'
       END AS quality_category
FROM fact_ore_quality q
JOIN dim_date d ON q.date_id = d.date_id
JOIN dim_mine m ON q.mine_id = m.mine_id
JOIN dim_shift sh ON q.shift_id = sh.shift_id
JOIN dim_ore_grade g ON q.ore_grade_id = g.ore_grade_id
ORDER BY d.full_date DESC
```

**Ошибка:** column q.moisture_pct does not exist
LINE 9:        q.moisture_pct,
               ^

