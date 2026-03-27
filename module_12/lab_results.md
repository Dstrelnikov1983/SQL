# Результаты лабораторной работы — Модуль 12

## Использование операторов набора

> Результаты выполнения SQL-запросов из лабораторной работы.

---

### Задание 1: UNION ALL — журнал событий за 15 марта 2024

```sql
SELECT 'Добыча' AS event_type,
       e.equipment_name,
       p.tons_mined AS value,
       'тонн' AS unit
FROM fact_production p
JOIN dim_equipment e ON p.equipment_id = e.equipment_id
WHERE p.date_id = 20240315

UNION ALL

SELECT 'Простой' AS event_type,
       e.equipment_name,
       dt.duration_min AS value,
       'мин.' AS unit
FROM fact_equipment_downtime dt
JOIN dim_equipment e ON dt.equipment_id = e.equipment_id
WHERE dt.date_id = 20240315

ORDER BY equipment_name, event_type
```

**Результат:**

| event_type | equipment_name | value | unit |
| --- | --- | --- | --- |
| Добыча | ПДМ-001 | 79.25 | тонн |
| Простой | ПДМ-001 | 240.00 | мин. |
| Простой | ПДМ-001 | 480.00 | мин. |
| Добыча | ПДМ-002 | 69.58 | тонн |
| Добыча | ПДМ-002 | 74.97 | тонн |
| Простой | ПДМ-002 | 480.00 | мин. |
| Добыча | ПДМ-003 | 79.01 | тонн |
| Добыча | ПДМ-003 | 68.13 | тонн |
| Простой | ПДМ-003 | 480.00 | мин. |
| Добыча | ПДМ-004 | 85.76 | тонн |
| Добыча | ПДМ-004 | 79.63 | тонн |
| Простой | ПДМ-004 | 480.00 | мин. |
| Добыча | ПДМ-006 | 99.25 | тонн |
| Простой | ПДМ-006 | 480.00 | мин. |
| Добыча | Самосвал-001 | 176.02 | тонн |

*... (показаны первые 15 строк из 23)*

### Задание 2: UNION — шахты с активностью (Q1 2024)

```sql
SELECT m.mine_name
FROM fact_production p
JOIN dim_mine m ON p.mine_id = m.mine_id
WHERE p.date_id BETWEEN 20240101 AND 20240331

UNION

SELECT m.mine_name
FROM fact_equipment_downtime dt
JOIN dim_equipment e ON dt.equipment_id = e.equipment_id
JOIN dim_mine m ON e.mine_id = m.mine_id
WHERE dt.date_id BETWEEN 20240101 AND 20240331
```

**Результат:**

| mine_name |
| --- |
| Шахта "Южная" |
| Шахта "Северная" |

*(2 строк)*

### Задание 3: EXCEPT — оборудование без данных о качестве (Q1 2024)

```sql
SELECT DISTINCT e.equipment_name, et.type_name
FROM (
    SELECT DISTINCT equipment_id
    FROM fact_production
    WHERE date_id BETWEEN 20240101 AND 20240331

    EXCEPT

    SELECT DISTINCT q.equipment_id
    FROM fact_ore_quality q
    WHERE q.date_id BETWEEN 20240101 AND 20240331
      AND q.equipment_id IS NOT NULL
) diff
JOIN dim_equipment e ON diff.equipment_id = e.equipment_id
JOIN dim_equipment_type et ON e.equipment_type_id = et.equipment_type_id
ORDER BY e.equipment_name
```

**Ошибка:** column q.equipment_id does not exist
LINE 10:     SELECT DISTINCT q.equipment_id
                             ^


### Задание 4: INTERSECT — операторы-универсалы (ПДМ и самосвалы)

```sql
SELECT o.last_name || ' ' || o.first_name AS operator_name,
       o.position,
       o.qualification
FROM dim_operator o
WHERE o.operator_id IN (
    SELECT fp.operator_id
    FROM fact_production fp
    JOIN dim_equipment e ON fp.equipment_id = e.equipment_id
    JOIN dim_equipment_type et ON e.equipment_type_id = et.equipment_type_id
    WHERE et.type_code = 'LHD'

    INTERSECT

    SELECT fp.operator_id
    FROM fact_production fp
    JOIN dim_equipment e ON fp.equipment_id = e.equipment_id
    JOIN dim_equipment_type et ON e.equipment_type_id = et.equipment_type_id
    WHERE et.type_code = 'TRUCK'
)
ORDER BY o.last_name
```

**Результат:**

| operator_name | position | qualification |
| --- | --- | --- |

*(0 строк)*

### Задание 5: Диаграмма Венна — классификация операторов

```sql
WITH lhd_operators AS (
    SELECT DISTINCT fp.operator_id
    FROM fact_production fp
    JOIN dim_equipment e ON fp.equipment_id = e.equipment_id
    JOIN dim_equipment_type et ON e.equipment_type_id = et.equipment_type_id
    WHERE et.type_code = 'LHD'
),
truck_operators AS (
    SELECT DISTINCT fp.operator_id
    FROM fact_production fp
    JOIN dim_equipment e ON fp.equipment_id = e.equipment_id
    JOIN dim_equipment_type et ON e.equipment_type_id = et.equipment_type_id
    WHERE et.type_code = 'TRUCK'
),
both_types AS (
    SELECT operator_id FROM lhd_operators
    INTERSECT
    SELECT operator_id FROM truck_operators
),
only_lhd AS (
    SELECT operator_id FROM lhd_operators
    EXCEPT
    SELECT operator_id FROM truck_operators
),
only_truck AS (
    SELECT operator_id FROM truck_operators
    EXCEPT
    SELECT operator_id FROM lhd_operators
),
total AS (
    SELECT COUNT(DISTINCT operator_id) AS cnt FROM fact_production
)
SELECT 'Оба типа' AS category,
       (SELECT COUNT(*) FROM both_types) AS count,
       ROUND((SELECT COUNT(*) FROM both_types)::numeric / (SELECT cnt FROM total) * 100, 1) AS pct
UNION ALL
SELECT 'Только ПДМ',
       (SELECT COUNT(*) FROM only_lhd),
       ROUND((SELECT COUNT(*) FROM only_lhd)::numeric / (SELECT cnt FROM total) * 100, 1)
UNION ALL
SELECT 'Только самосвал',
       (SELECT COUNT(*) FROM only_truck),
       ROUND((SELECT COUNT(*) FROM only_truck)::numeric / (SELECT cnt FROM total) * 100, 1)
```

**Результат:**

| category | count | pct |
| --- | --- | --- |
| Оба типа | 0 | 0.0 |
| Только ПДМ | 5 | 62.5 |
| Только самосвал | 3 | 37.5 |

*(3 строк)*

### Задание 6: LATERAL — топ-5 простоев по шахтам (Q1 2024)

```sql
SELECT m.mine_name, top5.*
FROM dim_mine m
CROSS JOIN LATERAL (
    SELECT d.full_date,
           e.equipment_name,
           r.reason_name,
           fd.duration_min,
           ROUND(fd.duration_min / 60.0, 1) AS duration_hours
    FROM fact_equipment_downtime fd
    JOIN dim_equipment e ON fd.equipment_id = e.equipment_id
    JOIN dim_downtime_reason r ON fd.reason_id = r.reason_id
    JOIN dim_date d ON fd.date_id = d.date_id
    WHERE e.mine_id = m.mine_id
      AND fd.is_planned = FALSE
      AND fd.date_id BETWEEN 20240101 AND 20240331
    ORDER BY fd.duration_min DESC
    LIMIT 5
) top5
WHERE m.status = 'active'
ORDER BY m.mine_name, top5.duration_min DESC
```

**Результат:**

| mine_name | full_date | equipment_name | reason_name | duration_min | duration_hours |
| --- | --- | --- | --- | --- | --- |
| Шахта "Северная" | 2024-02-08 | ПДМ-001 | Аварийный ремонт | 480.00 | 8.0 |
| Шахта "Северная" | 2024-01-22 | ПДМ-002 | Аварийный ремонт | 240.00 | 4.0 |
| Шахта "Северная" | 2024-03-15 | ПДМ-001 | Перегрев двигателя | 240.00 | 4.0 |
| Шахта "Северная" | 2024-01-03 | Самосвал-001 | Ожидание транспорта | 173.18 | 2.9 |
| Шахта "Северная" | 2024-03-07 | ПДМ-001 | Отсутствие оператора | 173.11 | 2.9 |
| Шахта "Южная" | 2024-03-05 | ПДМ-004 | Аварийный ремонт | 240.00 | 4.0 |
| Шахта "Южная" | 2024-03-28 | ПДМ-004 | Ожидание транспорта | 179.97 | 3.0 |
| Шахта "Южная" | 2024-02-20 | ПДМ-004 | Ожидание транспорта | 174.51 | 2.9 |
| Шахта "Южная" | 2024-01-29 | Самосвал-004 | Ожидание транспорта | 173.69 | 2.9 |
| Шахта "Южная" | 2024-02-16 | ПДМ-004 | Ожидание транспорта | 152.55 | 2.5 |

*(10 строк)*

### Задание 7: LEFT JOIN LATERAL — последнее показание датчиков

```sql
SELECT s.sensor_code,
       st.type_name AS sensor_type,
       e.equipment_name,
       latest.date_id,
       latest.time_id,
       latest.sensor_value,
       latest.is_alarm
FROM dim_sensor s
JOIN dim_sensor_type st ON s.sensor_type_id = st.sensor_type_id
JOIN dim_equipment e ON s.equipment_id = e.equipment_id
LEFT JOIN LATERAL (
    SELECT t.date_id, t.time_id, t.sensor_value, t.is_alarm
    FROM fact_equipment_telemetry t
    WHERE t.sensor_id = s.sensor_id
    ORDER BY t.date_id DESC, t.time_id DESC
    LIMIT 1
) latest ON TRUE
WHERE s.status = 'active'
ORDER BY latest.date_id ASC NULLS FIRST, latest.time_id ASC NULLS FIRST
```

**Результат:**

| sensor_code | sensor_type | equipment_name | date_id | time_id | sensor_value | is_alarm |
| --- | --- | --- | --- | --- | --- | --- |
| S-LHD003-TEMP | Датчик температуры двигателя | ПДМ-003 | NULL | NULL | NULL | NULL |
| S-LHD002-TEMP | Датчик температуры двигателя | ПДМ-002 | NULL | NULL | NULL | NULL |
| S-LHD002-VIB | Датчик вибрации | ПДМ-002 | NULL | NULL | NULL | NULL |
| S-LHD002-SPD | Датчик скорости движения | ПДМ-002 | NULL | NULL | NULL | NULL |
| S-LHD002-LOAD | Датчик массы груза | ПДМ-002 | NULL | NULL | NULL | NULL |
| S-LHD002-FUEL | Датчик уровня топлива | ПДМ-002 | NULL | NULL | NULL | NULL |
| S-LHD003-VIB | Датчик вибрации | ПДМ-003 | NULL | NULL | NULL | NULL |
| S-LHD003-LOAD | Датчик массы груза | ПДМ-003 | NULL | NULL | NULL | NULL |
| S-LHD003-FUEL | Датчик уровня топлива | ПДМ-003 | NULL | NULL | NULL | NULL |
| S-TRK002-TEMP | Датчик температуры двигателя | Самосвал-002 | NULL | NULL | NULL | NULL |
| S-TRK002-VIB | Датчик вибрации | Самосвал-002 | NULL | NULL | NULL | NULL |
| S-TRK002-SPD | Датчик скорости движения | Самосвал-002 | NULL | NULL | NULL | NULL |
| S-TRK002-LOAD | Датчик массы груза | Самосвал-002 | NULL | NULL | NULL | NULL |
| S-TRK002-FUEL | Датчик уровня топлива | Самосвал-002 | NULL | NULL | NULL | NULL |
| S-SKP001-TEMP | Датчик температуры двигателя | Скип-001 | NULL | NULL | NULL | NULL |

*... (показаны первые 15 строк из 43)*

### Задание 8: Сводный KPI-отчёт по шахтам (март 2024)

```sql
WITH kpi_data AS (
    SELECT m.mine_name, 'Добыча (тонн)' AS kpi_name,
           ROUND(SUM(p.tons_mined)::numeric, 1) AS kpi_value
    FROM fact_production p
    JOIN dim_mine m ON p.mine_id = m.mine_id
    WHERE p.date_id BETWEEN 20240301 AND 20240331
    GROUP BY m.mine_name

    UNION ALL

    SELECT m.mine_name, 'Простои (часы)',
           ROUND(SUM(dt.duration_min)::numeric / 60, 1)
    FROM fact_equipment_downtime dt
    JOIN dim_equipment e ON dt.equipment_id = e.equipment_id
    JOIN dim_mine m ON e.mine_id = m.mine_id
    WHERE dt.date_id BETWEEN 20240301 AND 20240331
    GROUP BY m.mine_name

    UNION ALL

    SELECT m.mine_name, 'Среднее Fe (%)',
           ROUND(AVG(q.fe_content)::numeric, 2)
    FROM fact_ore_quality q
    JOIN dim_mine m ON q.mine_id = m.mine_id
    WHERE q.date_id BETWEEN 20240301 AND 20240331
    GROUP BY m.mine_name

    UNION ALL

    SELECT m.mine_name, 'Тревожные показания',
           COUNT(*)::numeric
    FROM fact_equipment_telemetry t
    JOIN dim_equipment e ON t.equipment_id = e.equipment_id
    JOIN dim_mine m ON e.mine_id = m.mine_id
    WHERE t.is_alarm = TRUE
      AND t.date_id BETWEEN 20240301 AND 20240331
    GROUP BY m.mine_name
)
SELECT mine_name, kpi_name, kpi_value
FROM kpi_data
ORDER BY mine_name, kpi_name
```

**Результат:**

| mine_name | kpi_name | kpi_value |
| --- | --- | --- |
| Шахта "Северная" | Добыча (тонн) | 29342.2 |
| Шахта "Северная" | Простои (часы) | 84.0 |
| Шахта "Северная" | Среднее Fe (%) | 55.48 |
| Шахта "Южная" | Добыча (тонн) | 16851.9 |
| Шахта "Южная" | Простои (часы) | 50.2 |
| Шахта "Южная" | Среднее Fe (%) | 51.98 |

*(6 строк)*

### Задание 8 (широкая таблица): Сводный KPI-отчёт

```sql
WITH kpi_data AS (
    SELECT m.mine_name, 'Добыча (тонн)' AS kpi_name,
           ROUND(SUM(p.tons_mined)::numeric, 1) AS kpi_value
    FROM fact_production p
    JOIN dim_mine m ON p.mine_id = m.mine_id
    WHERE p.date_id BETWEEN 20240301 AND 20240331
    GROUP BY m.mine_name

    UNION ALL

    SELECT m.mine_name, 'Простои (часы)',
           ROUND(SUM(dt.duration_min)::numeric / 60, 1)
    FROM fact_equipment_downtime dt
    JOIN dim_equipment e ON dt.equipment_id = e.equipment_id
    JOIN dim_mine m ON e.mine_id = m.mine_id
    WHERE dt.date_id BETWEEN 20240301 AND 20240331
    GROUP BY m.mine_name

    UNION ALL

    SELECT m.mine_name, 'Среднее Fe (%)',
           ROUND(AVG(q.fe_content)::numeric, 2)
    FROM fact_ore_quality q
    JOIN dim_mine m ON q.mine_id = m.mine_id
    WHERE q.date_id BETWEEN 20240301 AND 20240331
    GROUP BY m.mine_name

    UNION ALL

    SELECT m.mine_name, 'Тревожные показания',
           COUNT(*)::numeric
    FROM fact_equipment_telemetry t
    JOIN dim_equipment e ON t.equipment_id = e.equipment_id
    JOIN dim_mine m ON e.mine_id = m.mine_id
    WHERE t.is_alarm = TRUE
      AND t.date_id BETWEEN 20240301 AND 20240331
    GROUP BY m.mine_name
)
SELECT
    mine_name,
    MAX(CASE WHEN kpi_name = 'Добыча (тонн)' THEN kpi_value END) AS production_tons,
    MAX(CASE WHEN kpi_name = 'Простои (часы)' THEN kpi_value END) AS downtime_hours,
    MAX(CASE WHEN kpi_name = 'Среднее Fe (%)' THEN kpi_value END) AS avg_fe_pct,
    MAX(CASE WHEN kpi_name = 'Тревожные показания' THEN kpi_value END) AS alarm_count
FROM kpi_data
GROUP BY mine_name
ORDER BY mine_name
```

**Результат:**

| mine_name | production_tons | downtime_hours | avg_fe_pct | alarm_count |
| --- | --- | --- | --- | --- |
| Шахта "Северная" | 29342.2 | 84.0 | 55.48 | NULL |
| Шахта "Южная" | 16851.9 | 50.2 | 51.98 | NULL |

*(2 строк)*
