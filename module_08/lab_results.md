# Результаты лабораторной работы — Модуль 8

## Проектирование стратегий оптимизированных индексов

> Результаты выполнения SQL-запросов из лабораторной работы.

---

### Задание 1: Анализ селективности

```sql
SELECT attname AS column_name,
       n_distinct,
       correlation,
       null_frac
FROM pg_stats
WHERE tablename = 'fact_production'
  AND schemaname = 'public'
ORDER BY attname
```

**Результат:**

| column_name | n_distinct | correlation | null_frac |
| --- | --- | --- | --- |
| date_id | 547.0 | 1.0 | 0.0 |
| distance_km | -0.11187977 | -0.0028356079 | 0.0 |
| equipment_id | 8.0 | 0.12531261 | 0.0 |
| fuel_consumed_l | -0.65935117 | -0.007009533 | 0.0 |
| loaded_at | 1.0 | 1.0 | 0.0 |
| location_id | 8.0 | 0.12542309 | 0.0 |
| mine_id | 2.0 | 0.5312627 | 0.0 |
| operating_hours | 151.0 | -0.0016609009 | 0.0 |
| operator_id | 8.0 | 0.12678276 | 0.0 |
| ore_grade_id | 4.0 | 0.3464892 | 0.0 |
| production_id | -1.0 | 1.0 | 0.0 |
| shaft_id | 3.0 | 0.3447407 | 0.0 |
| shift_id | 2.0 | 0.5037547 | 0.0 |
| tons_mined | -0.74403626 | 0.023122279 | 0.0 |
| tons_transported | -0.7160067 | -0.0010321497 | 0.0 |

*... (показаны первые 15 строк из 16)*

### Задание 2: Покрывающий индекс — исходный запрос

```sql
SELECT date_id,
       SUM(tons_mined) AS total_tons,
       SUM(trips_count) AS total_trips,
       SUM(operating_hours) AS total_hours
FROM fact_production
WHERE equipment_id = 5
  AND date_id BETWEEN 20240101 AND 20240331
GROUP BY date_id
ORDER BY date_id
```

**Результат:**

| date_id | total_tons | total_trips | total_hours |
| --- | --- | --- | --- |

*(0 строк)*

### Задание 2 (альтернативно, equipment_id=7)

```sql
SELECT date_id,
       SUM(tons_mined) AS total_tons,
       SUM(trips_count) AS total_trips,
       SUM(operating_hours) AS total_hours
FROM fact_production
WHERE equipment_id = 7
  AND date_id BETWEEN 20240101 AND 20240331
GROUP BY date_id
ORDER BY date_id
```

**Результат:**

| date_id | total_tons | total_trips | total_hours |
| --- | --- | --- | --- |
| 20240101 | 263.17 | 9 | 21.22 |
| 20240102 | 288.72 | 14 | 21.72 |
| 20240103 | 327.71 | 9 | 21.50 |
| 20240104 | 285.93 | 11 | 22.65 |
| 20240105 | 323.81 | 10 | 22.29 |
| 20240106 | 184.46 | 14 | 21.35 |
| 20240107 | 156.94 | 10 | 21.66 |
| 20240108 | 270.83 | 11 | 21.78 |
| 20240109 | 343.62 | 10 | 20.33 |
| 20240110 | 315.36 | 11 | 20.49 |
| 20240111 | 341.24 | 11 | 21.16 |
| 20240112 | 334.77 | 10 | 21.57 |
| 20240113 | 177.71 | 13 | 21.75 |
| 20240114 | 187.81 | 14 | 20.29 |
| 20240115 | 296.65 | 10 | 21.40 |

*... (показаны первые 15 строк из 91)*

### Задание 3: Тревожные показания (equipment_id=7)

```sql
SELECT t.date_id, t.time_id,
       s.sensor_code,
       t.sensor_value,
       t.quality_flag
FROM fact_equipment_telemetry t
JOIN dim_sensor s ON s.sensor_id = t.sensor_id
WHERE t.equipment_id = 7
  AND t.is_alarm = TRUE
  AND t.date_id = 20240703
ORDER BY t.time_id DESC
```

**Результат:**

| date_id | time_id | sensor_code | sensor_value | quality_flag |
| --- | --- | --- | --- | --- |
| 20240703 | 1930 | S-TRK001-LOAD | 21.5100 | OK |
| 20240703 | 1915 | S-TRK001-LOAD | 3.9300 | OK |
| 20240703 | 1830 | S-TRK001-OIL | 2.9200 | OK |
| 20240703 | 1745 | S-TRK001-OIL | 5.1400 | OK |
| 20240703 | 1600 | S-TRK001-LOAD | 21.7200 | OK |
| 20240703 | 1445 | S-TRK001-RPM | 1170.0000 | OK |
| 20240703 | 1400 | S-TRK001-TEMP | 101.8600 | OK |

*(7 строк)*

### Задание 4: Простои > 4 часов

```sql
SELECT fd.downtime_id, fd.date_id,
       e.equipment_name,
       dr.reason_name,
       fd.duration_min,
       ROUND(fd.duration_min / 60.0, 1) AS duration_hours
FROM fact_equipment_downtime fd
JOIN dim_equipment e ON e.equipment_id = fd.equipment_id
JOIN dim_downtime_reason dr ON dr.reason_id = fd.reason_id
WHERE fd.duration_min / 60.0 > 4
ORDER BY fd.duration_min DESC
```

**Результат:**

| downtime_id | date_id | equipment_name | reason_name | duration_min | duration_hours |
| --- | --- | --- | --- | --- | --- |
| 157 | 20250210 | Самосвал-001 | Аварийный ремонт | 720.00 | 12.0 |
| 158 | 20240530 | Самосвал-004 | Аварийный ремонт | 720.00 | 12.0 |
| 153 | 20240718 | ПДМ-004 | Обрушение породы | 690.00 | 11.5 |
| 4 | 20240115 | ПДМ-004 | Плановое техническое обслуживание | 480.00 | 8.0 |
| 5 | 20240115 | ПДМ-006 | Плановое техническое обслуживание | 480.00 | 8.0 |
| 6 | 20240115 | Самосвал-001 | Плановое техническое обслуживание | 480.00 | 8.0 |
| 7 | 20240115 | Самосвал-002 | Плановое техническое обслуживание | 480.00 | 8.0 |
| 8 | 20240115 | Самосвал-004 | Плановое техническое обслуживание | 480.00 | 8.0 |
| 9 | 20240215 | ПДМ-001 | Плановое техническое обслуживание | 480.00 | 8.0 |
| 10 | 20240215 | ПДМ-002 | Плановое техническое обслуживание | 480.00 | 8.0 |
| 11 | 20240215 | ПДМ-003 | Плановое техническое обслуживание | 480.00 | 8.0 |
| 12 | 20240215 | ПДМ-004 | Плановое техническое обслуживание | 480.00 | 8.0 |
| 13 | 20240215 | ПДМ-006 | Плановое техническое обслуживание | 480.00 | 8.0 |
| 14 | 20240215 | Самосвал-001 | Плановое техническое обслуживание | 480.00 | 8.0 |
| 15 | 20240215 | Самосвал-002 | Плановое техническое обслуживание | 480.00 | 8.0 |

*... (показаны первые 15 строк из 155)*

### Задание 5: Составной индекс — исходный запрос

```sql
SELECT p.date_id, p.shift_id,
       SUM(p.tons_mined) AS total_tons,
       AVG(p.fuel_consumed_l) AS avg_fuel
FROM fact_production p
WHERE p.mine_id = 1
  AND p.date_id BETWEEN 20240201 AND 20240229
GROUP BY p.date_id, p.shift_id
ORDER BY p.date_id, p.shift_id
```

**Результат:**

| date_id | shift_id | total_tons | avg_fuel |
| --- | --- | --- | --- |
| 20240201 | 1 | 524.38 | 151.3460000000000000 |
| 20240201 | 2 | 526.92 | 164.0040000000000000 |
| 20240202 | 1 | 530.33 | 158.2820000000000000 |
| 20240202 | 2 | 610.69 | 151.9700000000000000 |
| 20240203 | 1 | 302.98 | 167.5125000000000000 |
| 20240203 | 2 | 323.77 | 162.8740000000000000 |
| 20240204 | 1 | 307.57 | 143.5620000000000000 |
| 20240204 | 2 | 324.96 | 155.1660000000000000 |
| 20240205 | 1 | 540.87 | 153.3160000000000000 |
| 20240205 | 2 | 506.71 | 159.6620000000000000 |
| 20240206 | 1 | 544.37 | 164.8500000000000000 |
| 20240206 | 2 | 507.34 | 157.5920000000000000 |
| 20240207 | 1 | 530.57 | 150.5100000000000000 |
| 20240207 | 2 | 503.98 | 158.8550000000000000 |
| 20240208 | 1 | 529.78 | 152.0140000000000000 |

*... (показаны первые 15 строк из 58)*

### Задание 6: BRIN — корреляция date_id

```sql
SELECT correlation
FROM pg_stats
WHERE tablename = 'fact_equipment_telemetry'
  AND attname = 'date_id'
  AND schemaname = 'public'
```

**Результат:**

| correlation |
| --- |
| 1.0 |

*(1 строк)*

### Задание 6: BRIN — данные за date_id=20240315

```sql
SELECT t.time_id, t.sensor_id, t.sensor_value, t.is_alarm
FROM fact_equipment_telemetry t
WHERE t.date_id = 20240315
```

**Результат:**

| time_id | sensor_id | sensor_value | is_alarm |
| --- | --- | --- | --- |

*(0 строк)*

### Задание 7: Аудит индексов — размеры по таблицам

```sql
SELECT
    s.relname AS table_name,
    COUNT(DISTINCT s.indexrelname) AS index_count,
    pg_size_pretty(SUM(pg_relation_size(s.indexrelid))) AS total_index_size,
    pg_size_pretty(pg_relation_size(s.relid)) AS table_size,
    ROUND(SUM(pg_relation_size(s.indexrelid))::numeric / 
          NULLIF(pg_relation_size(s.relid), 0) * 100, 1) AS index_to_table_pct
FROM pg_stat_user_indexes s
WHERE s.schemaname = 'public'
GROUP BY s.relname, s.relid
ORDER BY SUM(pg_relation_size(s.indexrelid)) DESC
```

**Результат:**

| table_name | index_count | total_index_size | table_size | index_to_table_pct |
| --- | --- | --- | --- | --- |
| fact_equipment_telemetry | 5 | 1088 kB | 1416 kB | 76.8 |
| fact_production | 6 | 608 kB | 1024 kB | 59.4 |
| spatial_ref_sys | 1 | 208 kB | 6896 kB | 3.0 |
| fact_equipment_downtime | 4 | 184 kB | 216 kB | 85.2 |
| fact_ore_quality | 1 | 136 kB | 728 kB | 18.7 |
| dim_time | 2 | 96 kB | 112 kB | 85.7 |
| dim_date | 2 | 64 kB | 104 kB | 61.5 |
| dim_sensor | 2 | 32 kB | 8192 bytes | 400.0 |
| dim_operator | 2 | 32 kB | 8192 bytes | 400.0 |
| dim_shift | 2 | 32 kB | 8192 bytes | 400.0 |
| dim_ore_grade | 2 | 32 kB | 8192 bytes | 400.0 |
| dim_downtime_reason | 2 | 32 kB | 8192 bytes | 400.0 |
| dim_shaft | 2 | 32 kB | 8192 bytes | 400.0 |
| dim_mine | 2 | 32 kB | 8192 bytes | 400.0 |
| dim_sensor_type | 2 | 32 kB | 8192 bytes | 400.0 |

*... (показаны первые 15 строк из 18)*

### Задание 7: Неиспользуемые индексы (idx_scan=0)

```sql
SELECT 
    indexrelname AS index_name,
    relname AS table_name,
    pg_size_pretty(pg_relation_size(indexrelid)) AS index_size,
    idx_scan
FROM pg_stat_user_indexes
WHERE schemaname = 'public'
  AND idx_scan = 0
ORDER BY pg_relation_size(indexrelid) DESC
```

**Результат:**

| index_name | table_name | index_size | idx_scan |
| --- | --- | --- | --- |
| fact_equipment_telemetry_pkey | fact_equipment_telemetry | 432 kB | 0 |
| fact_production_pkey | fact_production | 200 kB | 0 |
| idx_fact_telemetry_sensor | fact_equipment_telemetry | 184 kB | 0 |
| idx_fact_telemetry_time | fact_equipment_telemetry | 168 kB | 0 |
| fact_equipment_downtime_pkey | fact_equipment_downtime | 56 kB | 0 |
| dim_ore_grade_grade_code_key | dim_ore_grade | 16 kB | 0 |
| dim_shift_shift_code_key | dim_shift | 16 kB | 0 |
| dim_shaft_mine_id_shaft_code_key | dim_shaft | 16 kB | 0 |
| dim_equipment_inventory_number_key | dim_equipment | 16 kB | 0 |
| dim_operator_tab_number_key | dim_operator | 16 kB | 0 |
| dim_mine_mine_code_key | dim_mine | 16 kB | 0 |

*(11 строк)*

### Задание 8: OEE отчёт

```sql
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
)
SELECT
    e.equipment_name,
    et.type_name,
    COALESCE(pd.total_operating_hours, 0) AS operating_hours,
    ROUND(COALESCE(dd.total_downtime_hours, 0)::numeric, 1) AS downtime_hours,
    ROUND(COALESCE(dd.unplanned_hours, 0)::numeric, 1) AS unplanned_downtime,
    COALESCE(pd.total_tons, 0) AS tons_mined,
    CASE
        WHEN COALESCE(pd.total_operating_hours, 0) + COALESCE(dd.total_downtime_hours, 0) > 0
        THEN ROUND(
            COALESCE(pd.total_operating_hours, 0) /
            (COALESCE(pd.total_operating_hours, 0) + COALESCE(dd.total_downtime_hours, 0)) * 100, 1
        )
        ELSE 0
    END AS availability_pct
FROM dim_equipment e
JOIN dim_equipment_type et ON et.equipment_type_id = e.equipment_type_id
LEFT JOIN production_data pd ON pd.equipment_id = e.equipment_id
LEFT JOIN downtime_data dd ON dd.equipment_id = e.equipment_id
WHERE e.status = 'active'
ORDER BY availability_pct ASC
```

**Результат:**

| equipment_name | type_name | operating_hours | downtime_hours | unplanned_downtime | tons_mined | availability_pct |
| --- | --- | --- | --- | --- | --- | --- |
| Самосвал-005 | Шахтный самосвал | 0 | 0.0 | 0.0 | 0 | 0 |
| Скип-003 | Скиповой подъёмник | 0 | 0.0 | 0.0 | 0 | 0 |
| Скип-002 | Скиповой подъёмник | 0 | 0.0 | 0.0 | 0 | 0 |
| Вагонетка-001 | Вагонетка | 0 | 0.0 | 0.0 | 0 | 0 |
| Скип-001 | Скиповой подъёмник | 0 | 0.0 | 0.0 | 0 | 0 |
| Вагонетка-004 | Вагонетка | 0 | 0.0 | 0.0 | 0 | 0 |
| Вагонетка-003 | Вагонетка | 0 | 0.0 | 0.0 | 0 | 0 |
| Самосвал-003 | Шахтный самосвал | 0 | 0.0 | 0.0 | 0 | 0 |
| Вагонетка-002 | Вагонетка | 0 | 0.0 | 0.0 | 0 | 0 |
| ПДМ-004 | Погрузочно-доставочная машина | 626.72 | 25.2 | 12.7 | 4270.30 | 96.1 |
| ПДМ-001 | Погрузочно-доставочная машина | 615.29 | 21.5 | 9.0 | 3909.00 | 96.6 |
| ПДМ-002 | Погрузочно-доставочная машина | 645.22 | 20.3 | 7.8 | 4069.66 | 97.0 |
| Самосвал-001 | Шахтный самосвал | 640.18 | 17.2 | 4.7 | 8796.23 | 97.4 |
| Самосвал-004 | Шахтный самосвал | 628.37 | 12.5 | 0.0 | 8203.19 | 98.0 |
| Самосвал-002 | Шахтный самосвал | 644.27 | 12.5 | 0.0 | 8744.12 | 98.1 |

*... (показаны первые 15 строк из 17)*
