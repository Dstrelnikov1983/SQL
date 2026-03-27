# Результаты лабораторной работы — Модуль 10

## Использование подзапросов

> Результаты выполнения SQL-запросов из лабораторной работы.

---

### Задание 1: Операторы с добычей выше средней (март 2024)

```sql
SELECT o.last_name || ' ' || LEFT(o.first_name, 1) || '.' AS operator_name,
       SUM(p.tons_mined) AS total_mined,
       (SELECT AVG(sub.total_tons)
        FROM (SELECT SUM(tons_mined) AS total_tons
              FROM fact_production
              WHERE date_id BETWEEN 20240301 AND 20240331
              GROUP BY operator_id) sub) AS avg_production
FROM fact_production p
JOIN dim_operator o ON p.operator_id = o.operator_id
WHERE p.date_id BETWEEN 20240301 AND 20240331
GROUP BY o.operator_id, o.last_name, o.first_name
HAVING SUM(p.tons_mined) > (
    SELECT AVG(sub.total_tons)
    FROM (SELECT SUM(tons_mined) AS total_tons
          FROM fact_production
          WHERE date_id BETWEEN 20240301 AND 20240331
          GROUP BY operator_id) sub
)
ORDER BY total_mined DESC
```

**Результат:**

| operator_name | total_mined | avg_production |
| --- | --- | --- |
| Сидоров Д. | 8796.23 | 5774.2637500000000000 |
| Козлов А. | 8744.12 | 5774.2637500000000000 |
| Волков Н. | 8203.19 | 5774.2637500000000000 |

*(3 строк)*

### Задание 2: Датчики на оборудовании, участвовавшем в добыче Q1 2024

```sql
SELECT s.sensor_code,
       st.type_name AS sensor_type,
       e.equipment_name,
       s.status
FROM dim_sensor s
JOIN dim_sensor_type st ON s.sensor_type_id = st.sensor_type_id
JOIN dim_equipment e ON s.equipment_id = e.equipment_id
WHERE s.equipment_id IN (
    SELECT DISTINCT equipment_id
    FROM fact_production
    WHERE date_id BETWEEN 20240101 AND 20240331
)
ORDER BY e.equipment_name, s.sensor_code
```

**Результат:**

| sensor_code | sensor_type | equipment_name | status |
| --- | --- | --- | --- |
| S-LHD001-FUEL | Датчик уровня топлива | ПДМ-001 | active |
| S-LHD001-LOAD | Датчик массы груза | ПДМ-001 | active |
| S-LHD001-SPD | Датчик скорости движения | ПДМ-001 | active |
| S-LHD001-TEMP | Датчик температуры двигателя | ПДМ-001 | active |
| S-LHD001-VIB | Датчик вибрации | ПДМ-001 | active |
| S-LHD002-FUEL | Датчик уровня топлива | ПДМ-002 | active |
| S-LHD002-LOAD | Датчик массы груза | ПДМ-002 | active |
| S-LHD002-SPD | Датчик скорости движения | ПДМ-002 | active |
| S-LHD002-TEMP | Датчик температуры двигателя | ПДМ-002 | active |
| S-LHD002-VIB | Датчик вибрации | ПДМ-002 | active |
| S-LHD003-FUEL | Датчик уровня топлива | ПДМ-003 | active |
| S-LHD003-LOAD | Датчик массы груза | ПДМ-003 | active |
| S-LHD003-TEMP | Датчик температуры двигателя | ПДМ-003 | active |
| S-LHD003-VIB | Датчик вибрации | ПДМ-003 | active |
| S-LHD004-FUEL | Датчик уровня топлива | ПДМ-004 | active |

*... (показаны первые 15 строк из 36)*

### Задание 3: Оборудование без записей о добыче (NOT IN)

```sql
SELECT e.equipment_name,
       et.type_name,
       m.mine_name,
       e.status
FROM dim_equipment e
JOIN dim_equipment_type et ON e.equipment_type_id = et.equipment_type_id
JOIN dim_mine m ON e.mine_id = m.mine_id
WHERE e.equipment_id NOT IN (
    SELECT equipment_id
    FROM fact_production
    WHERE equipment_id IS NOT NULL
)
ORDER BY e.equipment_name
```

**Результат:**

| equipment_name | type_name | mine_name | status |
| --- | --- | --- | --- |
| Вагонетка-001 | Вагонетка | Шахта "Северная" | active |
| Вагонетка-002 | Вагонетка | Шахта "Северная" | active |
| Вагонетка-003 | Вагонетка | Шахта "Южная" | active |
| Вагонетка-004 | Вагонетка | Шахта "Южная" | active |
| ПДМ-005 | Погрузочно-доставочная машина | Шахта "Южная" | maintenance |
| Самосвал-003 | Шахтный самосвал | Шахта "Северная" | active |
| Самосвал-005 | Шахтный самосвал | Шахта "Южная" | active |
| Скип-001 | Скиповой подъёмник | Шахта "Северная" | active |
| Скип-002 | Скиповой подъёмник | Шахта "Северная" | active |
| Скип-003 | Скиповой подъёмник | Шахта "Южная" | active |

*(10 строк)*

### Задание 4: Смены с добычей ниже средней по шахте (Q1 2024, первые 15)

```sql
SELECT m.mine_name,
       d.full_date,
       e.equipment_name,
       fp.tons_mined,
       ROUND((SELECT AVG(fp2.tons_mined)
        FROM fact_production fp2
        WHERE fp2.mine_id = fp.mine_id
          AND fp2.date_id BETWEEN 20240101 AND 20240331)::numeric, 2) AS mine_avg
FROM fact_production fp
JOIN dim_mine m ON fp.mine_id = m.mine_id
JOIN dim_date d ON fp.date_id = d.date_id
JOIN dim_equipment e ON fp.equipment_id = e.equipment_id
WHERE fp.date_id BETWEEN 20240101 AND 20240331
  AND fp.tons_mined < (
    SELECT AVG(fp2.tons_mined)
    FROM fact_production fp2
    WHERE fp2.mine_id = fp.mine_id
      AND fp2.date_id BETWEEN 20240101 AND 20240331
  )
ORDER BY (fp.tons_mined - (
    SELECT AVG(fp2.tons_mined)
    FROM fact_production fp2
    WHERE fp2.mine_id = fp.mine_id
      AND fp2.date_id BETWEEN 20240101 AND 20240331
)) ASC
LIMIT 15
```

**Результат:**

| mine_name | full_date | equipment_name | tons_mined | mine_avg |
| --- | --- | --- | --- | --- |
| Шахта "Северная" | 2024-02-18 | ПДМ-003 | 33.77 | 95.45 |
| Шахта "Северная" | 2024-01-21 | ПДМ-002 | 34.00 | 95.45 |
| Шахта "Северная" | 2024-01-07 | ПДМ-002 | 34.05 | 95.45 |
| Шахта "Северная" | 2024-02-03 | ПДМ-003 | 35.13 | 95.45 |
| Шахта "Северная" | 2024-01-27 | ПДМ-002 | 35.48 | 95.45 |
| Шахта "Северная" | 2024-01-27 | ПДМ-003 | 35.52 | 95.45 |
| Шахта "Северная" | 2024-01-06 | ПДМ-002 | 35.63 | 95.45 |
| Шахта "Северная" | 2024-01-13 | ПДМ-003 | 35.74 | 95.45 |
| Шахта "Северная" | 2024-01-07 | ПДМ-001 | 35.78 | 95.45 |
| Шахта "Северная" | 2024-01-27 | ПДМ-003 | 35.90 | 95.45 |
| Шахта "Северная" | 2024-01-13 | ПДМ-003 | 36.04 | 95.45 |
| Шахта "Северная" | 2024-03-31 | ПДМ-003 | 36.21 | 95.45 |
| Шахта "Северная" | 2024-01-07 | ПДМ-003 | 36.35 | 95.45 |
| Шахта "Северная" | 2024-01-14 | ПДМ-003 | 36.73 | 95.45 |
| Шахта "Северная" | 2024-01-13 | ПДМ-001 | 36.76 | 95.45 |

*(15 строк)*

### Задание 5: Оборудование с тревожными показаниями (EXISTS)

```sql
SELECT e.equipment_name,
       et.type_name,
       m.mine_name,
       (SELECT COUNT(*)
        FROM fact_equipment_telemetry t
        WHERE t.equipment_id = e.equipment_id
          AND t.is_alarm = TRUE
          AND t.date_id BETWEEN 20240301 AND 20240331) AS alarm_count
FROM dim_equipment e
JOIN dim_equipment_type et ON e.equipment_type_id = et.equipment_type_id
JOIN dim_mine m ON e.mine_id = m.mine_id
WHERE EXISTS (
    SELECT 1
    FROM fact_equipment_telemetry t
    WHERE t.equipment_id = e.equipment_id
      AND t.is_alarm = TRUE
      AND t.date_id BETWEEN 20240301 AND 20240331
)
ORDER BY alarm_count DESC
```

**Результат:**

| equipment_name | type_name | mine_name | alarm_count |
| --- | --- | --- | --- |

*(0 строк)*

### Задание 6: Даты без добычи для equipment_id=1 (март 2024)

```sql
SELECT d.full_date,
       d.day_of_week_name,
       d.is_weekend
FROM dim_date d
WHERE d.date_id BETWEEN 20240301 AND 20240331
  AND NOT EXISTS (
    SELECT 1
    FROM fact_production p
    WHERE p.equipment_id = 1
      AND p.date_id = d.date_id
  )
ORDER BY d.full_date
```

**Результат:**

| full_date | day_of_week_name | is_weekend |
| --- | --- | --- |

*(0 строк)*

### Задание 7: Добыча > ALL самосвалов

```sql
SELECT e.equipment_name,
       et.type_name,
       fp.date_id,
       fp.shift_id,
       fp.tons_mined
FROM fact_production fp
JOIN dim_equipment e ON fp.equipment_id = e.equipment_id
JOIN dim_equipment_type et ON e.equipment_type_id = et.equipment_type_id
WHERE fp.tons_mined > ALL (
    SELECT fp2.tons_mined
    FROM fact_production fp2
    JOIN dim_equipment e2 ON fp2.equipment_id = e2.equipment_id
    JOIN dim_equipment_type et2 ON e2.equipment_type_id = et2.equipment_type_id
    WHERE et2.type_code = 'TRUCK'
)
ORDER BY fp.tons_mined DESC
```

**Результат:**

| equipment_name | type_name | date_id | shift_id | tons_mined |
| --- | --- | --- | --- | --- |

*(0 строк)*

### Задание 8: Последняя запись добычи для каждого оборудования

```sql
SELECT e.equipment_name,
       et.type_name,
       d.full_date,
       fp.tons_mined,
       o.last_name || ' ' || LEFT(o.first_name, 1) || '.' AS operator_name
FROM fact_production fp
JOIN dim_equipment e ON fp.equipment_id = e.equipment_id
JOIN dim_equipment_type et ON e.equipment_type_id = et.equipment_type_id
JOIN dim_date d ON fp.date_id = d.date_id
JOIN dim_operator o ON fp.operator_id = o.operator_id
WHERE fp.date_id = (
    SELECT MAX(fp2.date_id)
    FROM fact_production fp2
    WHERE fp2.equipment_id = fp.equipment_id
)
ORDER BY d.full_date ASC
```

**Результат:**

| equipment_name | type_name | full_date | tons_mined | operator_name |
| --- | --- | --- | --- | --- |
| ПДМ-001 | Погрузочно-доставочная машина | 2025-06-30 | 77.52 | Иванов А. |
| ПДМ-002 | Погрузочно-доставочная машина | 2025-06-30 | 102.15 | Петров С. |
| ПДМ-003 | Погрузочно-доставочная машина | 2025-06-30 | 77.95 | Кузнецов И. |
| ПДМ-004 | Погрузочно-доставочная машина | 2025-06-30 | 90.68 | Новиков М. |
| ПДМ-006 | Погрузочно-доставочная машина | 2025-06-30 | 102.25 | Морозов В. |
| Самосвал-004 | Шахтный самосвал | 2025-06-30 | 196.29 | Волков Н. |
| ПДМ-001 | Погрузочно-доставочная машина | 2025-06-30 | 97.82 | Иванов А. |
| ПДМ-002 | Погрузочно-доставочная машина | 2025-06-30 | 72.45 | Петров С. |
| ПДМ-003 | Погрузочно-доставочная машина | 2025-06-30 | 75.77 | Кузнецов И. |
| ПДМ-004 | Погрузочно-доставочная машина | 2025-06-30 | 108.95 | Новиков М. |
| ПДМ-006 | Погрузочно-доставочная машина | 2025-06-30 | 97.32 | Морозов В. |
| Самосвал-001 | Шахтный самосвал | 2025-06-30 | 185.82 | Сидоров Д. |
| Самосвал-002 | Шахтный самосвал | 2025-06-30 | 225.95 | Козлов А. |
| Самосвал-004 | Шахтный самосвал | 2025-06-30 | 202.99 | Волков Н. |

*(14 строк)*

### Задание 9: Среднее время простоев оборудования-передовиков

```sql
SELECT m.mine_name,
       COUNT(DISTINCT fd.equipment_id) AS top_equipment_count,
       ROUND(AVG(fd.duration_min)::numeric, 1) AS avg_downtime_min,
       ROUND(SUM(fd.duration_min)::numeric / 60, 1) AS total_downtime_hours
FROM fact_equipment_downtime fd
JOIN dim_equipment e ON fd.equipment_id = e.equipment_id
JOIN dim_mine m ON e.mine_id = m.mine_id
WHERE fd.is_planned = FALSE
  AND fd.equipment_id IN (
    SELECT fp.equipment_id
    FROM fact_production fp
    WHERE fp.date_id BETWEEN 20240101 AND 20240331
    GROUP BY fp.equipment_id
    HAVING SUM(fp.tons_mined) > (
        SELECT AVG(total_tons)
        FROM (
            SELECT SUM(tons_mined) AS total_tons
            FROM fact_production
            WHERE date_id BETWEEN 20240101 AND 20240331
            GROUP BY equipment_id
        ) sub
    )
  )
GROUP BY m.mine_name
ORDER BY total_downtime_hours DESC
```

**Результат:**

| mine_name | top_equipment_count | avg_downtime_min | total_downtime_hours |
| --- | --- | --- | --- |
| Шахта "Южная" | 1 | 117.3 | 136.9 |
| Шахта "Северная" | 1 | 126.1 | 126.1 |

*(2 строк)*

### Задание 10: OEE по оборудованию (Q1 2024)

```sql
SELECT
    e.equipment_name,
    et.type_name,
    ROUND(
        COALESCE(
            (SELECT SUM(fp.operating_hours) FROM fact_production fp
             WHERE fp.equipment_id = e.equipment_id AND fp.date_id BETWEEN 20240101 AND 20240331)
            / NULLIF(
                (SELECT SUM(fp.operating_hours) FROM fact_production fp
                 WHERE fp.equipment_id = e.equipment_id AND fp.date_id BETWEEN 20240101 AND 20240331)
                + (SELECT COALESCE(SUM(fd.duration_min) / 60.0, 0) FROM fact_equipment_downtime fd
                   WHERE fd.equipment_id = e.equipment_id AND fd.date_id BETWEEN 20240101 AND 20240331)
            , 0) * 100
        , 0)::numeric, 1
    ) AS availability_pct,
    ROUND(
        COALESCE(
            (SELECT SUM(fp.tons_mined) FROM fact_production fp
             WHERE fp.equipment_id = e.equipment_id AND fp.date_id BETWEEN 20240101 AND 20240331)
            / NULLIF(
                (SELECT SUM(fp.operating_hours) FROM fact_production fp
                 WHERE fp.equipment_id = e.equipment_id AND fp.date_id BETWEEN 20240101 AND 20240331)
                * et.max_payload_tons
            , 0) * 100
        , 0)::numeric, 1
    ) AS performance_pct,
    ROUND(
        COALESCE(
            (SELECT COUNT(*) FILTER (WHERE q.fe_content >= 55)::numeric / NULLIF(COUNT(*)::numeric, 0)
             FROM fact_ore_quality q
             WHERE q.equipment_id = e.equipment_id AND q.date_id BETWEEN 20240101 AND 20240331)
            * 100
        , 0)::numeric, 1
    ) AS quality_pct
FROM dim_equipment e
JOIN dim_equipment_type et ON e.equipment_type_id = et.equipment_type_id
WHERE e.status = 'active'
ORDER BY availability_pct DESC
```

**Ошибка:** column q.equipment_id does not exist
LINE 32:              WHERE q.equipment_id = e.equipment_id AND q.dat...
                            ^
HINT:  Perhaps you meant to reference the column "e.equipment_id".

