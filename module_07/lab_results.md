# Результаты лабораторной работы — Модуль 7

## Введение в индексы

> Результаты выполнения SQL-запросов из лабораторной работы.
> **Примечание:** Задания связаны с созданием индексов и анализом планов выполнения (EXPLAIN ANALYZE).
> Результаты EXPLAIN ANALYZE зависят от текущего состояния БД и могут отличаться при повторном выполнении.

---

### Задание 1.1: Список всех индексов факт-таблиц

```sql
SELECT tablename, indexname, indexdef
FROM pg_indexes
WHERE tablename IN ('fact_production', 'fact_equipment_telemetry', 
                    'fact_equipment_downtime', 'fact_ore_quality')
  AND schemaname = 'public'
ORDER BY tablename, indexname
```

**Результат:**

| tablename | indexname | indexdef |
| --- | --- | --- |
| fact_equipment_downtime | fact_equipment_downtime_pkey | CREATE UNIQUE INDEX fact_equipment_downtime_pkey ON public.fact_equipment_downtime USING btree (downtime_id) |
| fact_equipment_downtime | idx_fact_downtime_date | CREATE INDEX idx_fact_downtime_date ON public.fact_equipment_downtime USING btree (date_id) |
| fact_equipment_downtime | idx_fact_downtime_equip | CREATE INDEX idx_fact_downtime_equip ON public.fact_equipment_downtime USING btree (equipment_id) |
| fact_equipment_downtime | idx_fact_downtime_reason | CREATE INDEX idx_fact_downtime_reason ON public.fact_equipment_downtime USING btree (reason_id) |
| fact_equipment_telemetry | fact_equipment_telemetry_pkey | CREATE UNIQUE INDEX fact_equipment_telemetry_pkey ON public.fact_equipment_telemetry USING btree (telemetry_id) |
| fact_equipment_telemetry | idx_fact_telemetry_date | CREATE INDEX idx_fact_telemetry_date ON public.fact_equipment_telemetry USING btree (date_id) |
| fact_equipment_telemetry | idx_fact_telemetry_equip | CREATE INDEX idx_fact_telemetry_equip ON public.fact_equipment_telemetry USING btree (equipment_id) |
| fact_equipment_telemetry | idx_fact_telemetry_sensor | CREATE INDEX idx_fact_telemetry_sensor ON public.fact_equipment_telemetry USING btree (sensor_id) |
| fact_equipment_telemetry | idx_fact_telemetry_time | CREATE INDEX idx_fact_telemetry_time ON public.fact_equipment_telemetry USING btree (time_id) |
| fact_ore_quality | fact_ore_quality_pkey | CREATE UNIQUE INDEX fact_ore_quality_pkey ON public.fact_ore_quality USING btree (quality_id) |
| fact_production | fact_production_pkey | CREATE UNIQUE INDEX fact_production_pkey ON public.fact_production USING btree (production_id) |
| fact_production | idx_fact_production_date | CREATE INDEX idx_fact_production_date ON public.fact_production USING btree (date_id) |
| fact_production | idx_fact_production_equip | CREATE INDEX idx_fact_production_equip ON public.fact_production USING btree (equipment_id) |
| fact_production | idx_fact_production_mine | CREATE INDEX idx_fact_production_mine ON public.fact_production USING btree (mine_id) |
| fact_production | idx_fact_production_operator | CREATE INDEX idx_fact_production_operator ON public.fact_production USING btree (operator_id) |

*... (показаны первые 15 строк из 16)*

### Задание 1.2: Размеры и использование индексов fact_production

```sql
SELECT
    indexrelname AS index_name,
    pg_size_pretty(pg_relation_size(indexrelid)) AS index_size,
    idx_scan AS times_used
FROM pg_stat_user_indexes
WHERE relname = 'fact_production'
  AND schemaname = 'public'
ORDER BY pg_relation_size(indexrelid) DESC
```

**Результат:**

| index_name | index_size | times_used |
| --- | --- | --- |
| fact_production_pkey | 200 kB | 0 |
| idx_fact_production_date | 88 kB | 21584 |
| idx_fact_production_shift | 80 kB | 2 |
| idx_fact_production_mine | 80 kB | 5 |
| idx_fact_production_equip | 80 kB | 33634 |
| idx_fact_production_operator | 80 kB | 7 |

*(6 строк)*

### Задание 1.3: Суммарный размер индексов по факт-таблицам

```sql
SELECT
    relname AS table_name,
    pg_size_pretty(SUM(pg_relation_size(indexrelid))) AS total_index_size,
    COUNT(*) AS index_count
FROM pg_stat_user_indexes
WHERE relname IN ('fact_production', 'fact_equipment_telemetry', 
                  'fact_equipment_downtime', 'fact_ore_quality')
  AND schemaname = 'public'
GROUP BY relname
ORDER BY SUM(pg_relation_size(indexrelid)) DESC
```

**Результат:**

| table_name | total_index_size | index_count |
| --- | --- | --- |
| fact_equipment_telemetry | 1088 kB | 5 |
| fact_production | 608 kB | 6 |
| fact_equipment_downtime | 184 kB | 4 |
| fact_ore_quality | 136 kB | 1 |

*(4 строк)*

### Задание 2: Расход топлива > 80 литров

```sql
SELECT p.date_id, e.equipment_name, o.last_name, p.fuel_consumed_l
FROM fact_production p
JOIN dim_equipment e ON p.equipment_id = e.equipment_id
JOIN dim_operator o ON p.operator_id = o.operator_id
WHERE p.fuel_consumed_l > 80
ORDER BY p.fuel_consumed_l DESC
```

**Результат:**

| date_id | equipment_name | last_name | fuel_consumed_l |
| --- | --- | --- | --- |
| 20250428 | Самосвал-002 | Козлов | 241.31 |
| 20241206 | Самосвал-002 | Козлов | 241.31 |
| 20240911 | Самосвал-002 | Козлов | 241.24 |
| 20240824 | Самосвал-002 | Козлов | 241.21 |
| 20240827 | Самосвал-002 | Козлов | 241.17 |
| 20240323 | Самосвал-002 | Козлов | 241.07 |
| 20240908 | Самосвал-002 | Козлов | 241.05 |
| 20240507 | Самосвал-002 | Козлов | 241.04 |
| 20240906 | Самосвал-002 | Козлов | 240.97 |
| 20250128 | Самосвал-002 | Козлов | 240.97 |
| 20240326 | Самосвал-002 | Козлов | 240.95 |
| 20240403 | Самосвал-002 | Козлов | 240.89 |
| 20250404 | Самосвал-002 | Козлов | 240.89 |
| 20241208 | Самосвал-002 | Козлов | 240.80 |
| 20250413 | Самосвал-002 | Козлов | 240.74 |

*... (показаны первые 15 строк из 8384)*

### Задание 3: Аварийная телеметрия (is_alarm=TRUE, date_id=20240703)

```sql
SELECT t.telemetry_id, t.date_id, t.equipment_id,
       t.sensor_id, t.sensor_value
FROM fact_equipment_telemetry t
WHERE t.date_id = 20240703
  AND t.is_alarm = TRUE
```

**Результат:**

| telemetry_id | date_id | equipment_id | sensor_id | sensor_value |
| --- | --- | --- | --- | --- |
| 13612 | 20240703 | 4 | 15 | 87.2800 |
| 13675 | 20240703 | 1 | 3 | 5.6600 |
| 13677 | 20240703 | 1 | 5 | 71.8800 |
| 13701 | 20240703 | 4 | 16 | 12.5700 |
| 13868 | 20240703 | 10 | 34 | 11.6900 |
| 13934 | 20240703 | 10 | 34 | 0.1600 |
| 14027 | 20240703 | 1 | 3 | 2.0400 |
| 14046 | 20240703 | 10 | 36 | 1220.0000 |
| 14110 | 20240703 | 10 | 34 | 9.9900 |
| 14123 | 20240703 | 7 | 20 | 101.8600 |

*... (показаны первые 10 строк из 24)*

### Задание 4: Добыча equipment_id=7 за март 2024

```sql
SELECT date_id, tons_mined, tons_transported,
       trips_count, operating_hours
FROM fact_production
WHERE equipment_id = 7
  AND date_id BETWEEN 20240301 AND 20240331
```

**Результат:**

| date_id | tons_mined | tons_transported | trips_count | operating_hours |
| --- | --- | --- | --- | --- |
| 20240301 | 187.53 | 157.46 | 5 | 10.92 |
| 20240301 | 179.45 | 172.40 | 5 | 11.33 |
| 20240302 | 122.06 | 92.47 | 6 | 10.49 |
| 20240302 | 90.30 | 99.60 | 4 | 11.24 |
| 20240303 | 100.77 | 87.97 | 6 | 11.48 |
| 20240303 | 122.68 | 122.17 | 5 | 10.49 |
| 20240304 | 176.55 | 197.11 | 5 | 10.68 |
| 20240304 | 142.29 | 197.76 | 4 | 10.76 |
| 20240305 | 191.03 | 194.98 | 5 | 11.23 |
| 20240305 | 155.77 | 205.23 | 4 | 11.46 |
| 20240306 | 180.51 | 167.79 | 6 | 10.96 |
| 20240306 | 200.56 | 160.35 | 7 | 11.25 |
| 20240307 | 138.28 | 171.98 | 7 | 10.98 |
| 20240307 | 141.78 | 194.89 | 4 | 11.21 |
| 20240308 | 204.09 | 165.59 | 4 | 11.09 |

*... (показаны первые 15 строк из 59)*

### Задание 5: Поиск оператора по LOWER(last_name)

```sql
SELECT operator_id, last_name, first_name,
       middle_name, position, qualification
FROM dim_operator
WHERE LOWER(last_name) = 'петров'
```

**Результат:**

| operator_id | last_name | first_name | middle_name | position | qualification |
| --- | --- | --- | --- | --- | --- |
| 2 | Петров | Сергей | Николаевич | Машинист ПДМ | 5 разряд |

*(1 строк)*

### Задание 6: Покрывающий индекс — данные за date_id=20240315

```sql
SELECT date_id, equipment_id, tons_mined
FROM fact_production
WHERE date_id = 20240315
```

**Результат:**

| date_id | equipment_id | tons_mined |
| --- | --- | --- |
| 20240315 | 2 | 69.58 |
| 20240315 | 3 | 79.01 |
| 20240315 | 4 | 85.76 |
| 20240315 | 7 | 176.02 |
| 20240315 | 8 | 191.76 |
| 20240315 | 10 | 161.92 |
| 20240315 | 1 | 79.25 |
| 20240315 | 2 | 74.97 |
| 20240315 | 3 | 68.13 |
| 20240315 | 4 | 79.63 |
| 20240315 | 6 | 99.25 |
| 20240315 | 7 | 158.60 |
| 20240315 | 8 | 185.36 |
| 20240315 | 10 | 173.24 |

*(14 строк)*

### Задание 7: Размер B-tree индекса idx_fact_telemetry_date

```sql
SELECT indexrelname,
       pg_size_pretty(pg_relation_size(indexrelid)) AS size
FROM pg_stat_user_indexes
WHERE indexrelname = 'idx_fact_telemetry_date'
```

**Результат:**

| indexrelname | size |
| --- | --- |
| idx_fact_telemetry_date | 152 kB |

*(1 строк)*

### Задание 8: Простои оборудования (equipment_id=1, внеплановые, Q1 2024)

```sql
SELECT d.date_id, e.equipment_name,
       r.reason_name, r.category,
       dt.duration_min, dt.comment
FROM fact_equipment_downtime dt
JOIN dim_date d ON dt.date_id = d.date_id
JOIN dim_equipment e ON dt.equipment_id = e.equipment_id
JOIN dim_downtime_reason r ON dt.reason_id = r.reason_id
WHERE dt.equipment_id = 1
  AND dt.date_id BETWEEN 20240101 AND 20240331
  AND dt.is_planned = FALSE
ORDER BY dt.duration_min DESC
```

**Результат:**

| date_id | equipment_name | reason_name | category | duration_min | comment |
| --- | --- | --- | --- | --- | --- |
| 20240208 | ПДМ-001 | Аварийный ремонт | внеплановый | 480.00 | Разрыв гидрошланга |
| 20240315 | ПДМ-001 | Перегрев двигателя | внеплановый | 240.00 | Перегрев двигателя, замена термостата |
| 20240307 | ПДМ-001 | Отсутствие оператора | организационный | 173.11 | NULL |
| 20240207 | ПДМ-001 | Ожидание погрузки | организационный | 172.62 | NULL |
| 20240122 | ПДМ-001 | Отсутствие оператора | организационный | 170.43 | NULL |
| 20240108 | ПДМ-001 | Ожидание погрузки | организационный | 144.75 | NULL |
| 20240118 | ПДМ-001 | Ожидание транспорта | организационный | 125.99 | NULL |
| 20240103 | ПДМ-001 | Ожидание транспорта | организационный | 109.29 | NULL |
| 20240222 | ПДМ-001 | Отсутствие оператора | организационный | 79.51 | NULL |
| 20240311 | ПДМ-001 | Ожидание транспорта | организационный | 69.63 | NULL |
| 20240301 | ПДМ-001 | Ожидание транспорта | организационный | 56.82 | NULL |
| 20240201 | ПДМ-001 | Ожидание транспорта | организационный | 54.93 | NULL |

*(12 строк)*

### Задание 9: Количество индексов на fact_production

```sql
SELECT COUNT(*) AS index_count
FROM pg_indexes
WHERE tablename = 'fact_production'
  AND schemaname = 'public'
```

**Результат:**

| index_count |
| --- |
| 6 |

*(1 строк)*

### Задание 10.1: Суммарная добыча по шахте за март 2024

```sql
SELECT m.mine_name,
       SUM(p.tons_mined) AS total_tons,
       SUM(p.operating_hours) AS total_hours
FROM fact_production p
JOIN dim_mine m ON p.mine_id = m.mine_id
WHERE p.date_id BETWEEN 20240301 AND 20240331
GROUP BY m.mine_name
```

**Результат:**

| mine_name | total_tons | total_hours |
| --- | --- | --- |
| Шахта "Южная" | 16851.87 | 1900.90 |
| Шахта "Северная" | 29342.24 | 3175.88 |

*(2 строк)*

### Задание 10.2: Среднее качество руды по сорту за Q1 2024

```sql
SELECT g.grade_name,
       ROUND(AVG(q.fe_content), 2) AS avg_fe,
       ROUND(AVG(q.sio2_content), 2) AS avg_sio2,
       COUNT(*) AS samples
FROM fact_ore_quality q
JOIN dim_ore_grade g ON q.ore_grade_id = g.ore_grade_id
WHERE q.date_id BETWEEN 20240101 AND 20240331
GROUP BY g.grade_name
```

**Результат:**

| grade_name | avg_fe | avg_sio2 | samples |
| --- | --- | --- | --- |
| Высший сорт | 62.58 | 16.35 | 144 |
| Первый сорт | 52.94 | 15.30 | 701 |
| Второй сорт | 43.47 | 15.34 | 56 |

*(3 строк)*

### Задание 10.3: Топ-5 оборудования по внеплановым простоям

```sql
SELECT e.equipment_name,
       SUM(dt.duration_min) AS total_downtime_min,
       COUNT(*) AS incidents
FROM fact_equipment_downtime dt
JOIN dim_equipment e ON dt.equipment_id = e.equipment_id
WHERE dt.is_planned = FALSE
  AND dt.date_id BETWEEN 20240301 AND 20240331
GROUP BY e.equipment_name
ORDER BY total_downtime_min DESC
LIMIT 5
```

**Результат:**

| equipment_name | total_downtime_min | incidents |
| --- | --- | --- |
| ПДМ-004 | 764.90 | 5 |
| ПДМ-001 | 539.56 | 4 |
| ПДМ-002 | 467.46 | 4 |
| Самосвал-001 | 283.94 | 2 |

*(4 строк)*

### Задание 10.4: Последние тревожные показания (equipment_id=7)

```sql
SELECT t.date_id, t.time_id, t.sensor_id,
       t.sensor_value, t.quality_flag
FROM fact_equipment_telemetry t
WHERE t.equipment_id = 7
  AND t.is_alarm = TRUE
ORDER BY t.date_id DESC, t.time_id DESC
LIMIT 20
```

**Результат:**

| date_id | time_id | sensor_id | sensor_value | quality_flag |
| --- | --- | --- | --- | --- |
| 20240707 | 1815 | 20 | 92.5700 | SUSPECT |
| 20240707 | 1730 | 21 | 5.6400 | OK |
| 20240707 | 1700 | 20 | 102.7800 | OK |
| 20240707 | 1645 | 20 | 86.3600 | OK |
| 20240707 | 1415 | 23 | 3.9300 | OK |
| 20240707 | 1345 | 25 | 2.7100 | OK |
| 20240707 | 1345 | 24 | 61.1700 | OK |
| 20240707 | 945 | 23 | 8.5400 | OK |
| 20240707 | 930 | 20 | 102.9300 | OK |
| 20240707 | 815 | 26 | 1241.0000 | OK |
| 20240707 | 815 | 20 | 102.4400 | OK |
| 20240706 | 1945 | 23 | 17.4000 | OK |
| 20240706 | 1615 | 21 | 7.3600 | OK |
| 20240706 | 1600 | 26 | 1818.0000 | OK |
| 20240706 | 1330 | 20 | 103.7500 | OK |

*... (показаны первые 15 строк из 20)*

### Задание 10.5: Добыча оператора (operator_id=3) за неделю

```sql
SELECT p.date_id, e.equipment_name,
       p.tons_mined, p.trips_count, p.operating_hours
FROM fact_production p
JOIN dim_equipment e ON p.equipment_id = e.equipment_id
WHERE p.operator_id = 3
  AND p.date_id BETWEEN 20240311 AND 20240317
ORDER BY p.date_id
```

**Результат:**

| date_id | equipment_name | tons_mined | trips_count | operating_hours |
| --- | --- | --- | --- | --- |
| 20240311 | Самосвал-001 | 158.94 | 6 | 10.58 |
| 20240311 | Самосвал-001 | 166.43 | 4 | 10.67 |
| 20240312 | Самосвал-001 | 161.07 | 4 | 10.37 |
| 20240312 | Самосвал-001 | 202.51 | 5 | 10.65 |
| 20240313 | Самосвал-001 | 199.97 | 5 | 10.29 |
| 20240313 | Самосвал-001 | 143.79 | 5 | 10.25 |
| 20240314 | Самосвал-001 | 160.57 | 6 | 10.77 |
| 20240315 | Самосвал-001 | 176.02 | 7 | 10.51 |
| 20240315 | Самосвал-001 | 158.60 | 5 | 10.18 |
| 20240316 | Самосвал-001 | 93.83 | 5 | 10.83 |
| 20240316 | Самосвал-001 | 106.44 | 4 | 10.30 |
| 20240317 | Самосвал-001 | 105.28 | 7 | 10.39 |
| 20240317 | Самосвал-001 | 107.33 | 6 | 11.23 |

*(13 строк)*
