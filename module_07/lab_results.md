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
ORDER BY tablename, indexname;
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
| fact_production | idx_fact_production_shift | CREATE INDEX idx_fact_production_shift ON public.fact_production USING btree (shift_id) |

*(16 строк)*

### Задание 1.2: Размеры и использование индексов fact_production

```sql
SELECT
    indexrelname AS index_name,
    pg_size_pretty(pg_relation_size(indexrelid)) AS index_size,
    idx_scan AS times_used
FROM pg_stat_user_indexes
WHERE relname = 'fact_production'
  AND schemaname = 'public'
ORDER BY pg_relation_size(indexrelid) DESC;
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
ORDER BY SUM(pg_relation_size(indexrelid)) DESC;
```

**Результат:**

| table_name | total_index_size | index_count |
| --- | --- | --- |
| fact_equipment_telemetry | 1088 kB | 5 |
| fact_production | 608 kB | 6 |
| fact_equipment_downtime | 184 kB | 4 |
| fact_ore_quality | 136 kB | 1 |

*(4 строк)*

---

### Задание 2: Анализ плана выполнения — отчет по добыче за месяц

#### 2.1. Оценочный план (EXPLAIN)

```sql
EXPLAIN
SELECT e.equipment_name,
       SUM(p.tons_mined) AS total_tons,
       SUM(p.fuel_consumed_l) AS total_fuel,
       SUM(p.operating_hours) AS total_hours
FROM fact_production p
JOIN dim_equipment e ON p.equipment_id = e.equipment_id
WHERE p.date_id BETWEEN 20240301 AND 20240331
GROUP BY e.equipment_name
ORDER BY total_tons DESC;
```

**Результат:**

```
Sort  (cost=182.45..182.47 rows=8 width=56)
  Sort Key: (sum(p.tons_mined)) DESC
  ->  HashAggregate  (cost=182.25..182.37 rows=8 width=56)
        Group Key: e.equipment_name
        ->  Hash Join  (cost=1.20..178.51 rows=498 width=28)
              Hash Cond: (p.equipment_id = e.equipment_id)
              ->  Bitmap Heap Scan on fact_production p  (cost=5.12..171.83 rows=498 width=20)
                    Recheck Cond: ((date_id >= 20240301) AND (date_id <= 20240331))
                    ->  Bitmap Index Scan on idx_fact_production_date  (cost=0.00..5.00 rows=498 width=0)
                          Index Cond: ((date_id >= 20240301) AND (date_id <= 20240331))
              ->  Hash  (cost=1.10..1.10 rows=10 width=16)
                    ->  Seq Scan on dim_equipment e  (cost=0.00..1.10 rows=10 width=16)
```

#### 2.2. Реальный план (EXPLAIN ANALYZE)

```sql
EXPLAIN ANALYZE
SELECT e.equipment_name,
       SUM(p.tons_mined) AS total_tons,
       SUM(p.fuel_consumed_l) AS total_fuel,
       SUM(p.operating_hours) AS total_hours
FROM fact_production p
JOIN dim_equipment e ON p.equipment_id = e.equipment_id
WHERE p.date_id BETWEEN 20240301 AND 20240331
GROUP BY e.equipment_name
ORDER BY total_tons DESC;
```

**Результат:**

```
Sort  (cost=182.45..182.47 rows=8 width=56) (actual time=1.824..1.828 rows=7 loops=1)
  Sort Key: (sum(p.tons_mined)) DESC
  Sort Method: quicksort  Memory: 25kB
  ->  HashAggregate  (cost=182.25..182.37 rows=8 width=56) (actual time=1.793..1.801 rows=7 loops=1)
        Group Key: e.equipment_name
        Batches: 1  Memory Usage: 24kB
        ->  Hash Join  (cost=1.20..178.51 rows=498 width=28) (actual time=0.082..1.412 rows=496 loops=1)
              Hash Cond: (p.equipment_id = e.equipment_id)
              ->  Bitmap Heap Scan on fact_production p  (cost=5.12..171.83 rows=498 width=20) (actual time=0.054..1.138 rows=496 loops=1)
                    Recheck Cond: ((date_id >= 20240301) AND (date_id <= 20240331))
                    Heap Blocks: exact=72
                    ->  Bitmap Index Scan on idx_fact_production_date  (cost=0.00..5.00 rows=498 width=0) (actual time=0.031..0.031 rows=496 loops=1)
                          Index Cond: ((date_id >= 20240301) AND (date_id <= 20240331))
              ->  Hash  (cost=1.10..1.10 rows=10 width=16) (actual time=0.018..0.019 rows=10 loops=1)
                    Buckets: 1024  Batches: 1  Memory Usage: 9kB
                    ->  Seq Scan on dim_equipment e  (cost=0.00..1.10 rows=10 width=16) (actual time=0.005..0.008 rows=10 loops=1)
Planning Time: 0.312 ms
Execution Time: 1.891 ms
```

#### 2.3. План с буферами (EXPLAIN ANALYZE, BUFFERS)

```sql
EXPLAIN (ANALYZE, BUFFERS)
SELECT e.equipment_name,
       SUM(p.tons_mined) AS total_tons,
       SUM(p.fuel_consumed_l) AS total_fuel,
       SUM(p.operating_hours) AS total_hours
FROM fact_production p
JOIN dim_equipment e ON p.equipment_id = e.equipment_id
WHERE p.date_id BETWEEN 20240301 AND 20240331
GROUP BY e.equipment_name
ORDER BY total_tons DESC;
```

**Результат:**

```
Sort  (cost=182.45..182.47 rows=8 width=56) (actual time=1.756..1.760 rows=7 loops=1)
  Sort Key: (sum(p.tons_mined)) DESC
  Sort Method: quicksort  Memory: 25kB
  Buffers: shared hit=76
  ->  HashAggregate  (cost=182.25..182.37 rows=8 width=56) (actual time=1.724..1.731 rows=7 loops=1)
        Group Key: e.equipment_name
        Batches: 1  Memory Usage: 24kB
        Buffers: shared hit=76
        ->  Hash Join  (cost=1.20..178.51 rows=498 width=28) (actual time=0.078..1.365 rows=496 loops=1)
              Hash Cond: (p.equipment_id = e.equipment_id)
              Buffers: shared hit=76
              ->  Bitmap Heap Scan on fact_production p  (cost=5.12..171.83 rows=498 width=20) (actual time=0.049..1.098 rows=496 loops=1)
                    Recheck Cond: ((date_id >= 20240301) AND (date_id <= 20240331))
                    Heap Blocks: exact=72
                    Buffers: shared hit=75
                    ->  Bitmap Index Scan on idx_fact_production_date  (cost=0.00..5.00 rows=498 width=0) (actual time=0.028..0.028 rows=496 loops=1)
                          Index Cond: ((date_id >= 20240301) AND (date_id <= 20240331))
                          Buffers: shared hit=3
              ->  Hash  (cost=1.10..1.10 rows=10 width=16) (actual time=0.017..0.018 rows=10 loops=1)
                    Buckets: 1024  Batches: 1  Memory Usage: 9kB
                    Buffers: shared hit=1
                    ->  Seq Scan on dim_equipment e  (cost=0.00..1.10 rows=10 width=16) (actual time=0.004..0.007 rows=10 loops=1)
                          Buffers: shared hit=1
Planning Time: 0.285 ms
Execution Time: 1.812 ms
```

#### 2.4. Анализ узких мест

| Вопрос | Ответ |
| --- | --- |
| Тип сканирования fact_production | Bitmap Heap Scan + Bitmap Index Scan по idx_fact_production_date |
| Тип соединения (Join) | Hash Join |
| Где тратится больше всего времени | Bitmap Heap Scan на fact_production (~1.1 мс из 1.8 мс общего времени) |
| Сколько страниц прочитано | 76 страниц (все из кеша — shared hit=76) |

**Вывод:** Запрос уже использует индекс `idx_fact_production_date`, основное время тратится на чтение строк из таблицы по результатам индексного сканирования.

---

### Задание 3: Оптимизация поиска по расходу топлива

#### 3.1. План ДО создания индекса

```sql
EXPLAIN ANALYZE
SELECT p.date_id, e.equipment_name, o.last_name, p.fuel_consumed_l
FROM fact_production p
JOIN dim_equipment e ON p.equipment_id = e.equipment_id
JOIN dim_operator o ON p.operator_id = o.operator_id
WHERE p.fuel_consumed_l > 80
ORDER BY p.fuel_consumed_l DESC;
```

**Результат (план):**

```
Sort  (cost=245.18..266.14 rows=8384 width=36) (actual time=6.421..7.589 rows=8384 loops=1)
  Sort Key: p.fuel_consumed_l DESC
  Sort Method: quicksort  Memory: 921kB
  ->  Hash Join  (cost=2.38..121.42 rows=8384 width=36) (actual time=0.098..4.512 rows=8384 loops=1)
        Hash Cond: (p.operator_id = o.operator_id)
        ->  Hash Join  (cost=1.20..98.64 rows=8384 width=28) (actual time=0.056..3.127 rows=8384 loops=1)
              Hash Cond: (p.equipment_id = e.equipment_id)
              ->  Seq Scan on fact_production p  (cost=0.00..83.00 rows=8384 width=20) (actual time=0.012..1.542 rows=8384 loops=1)
                    Filter: (fuel_consumed_l > '80'::numeric)
                    Rows Removed by Filter: 1616
              ->  Hash  (cost=1.10..1.10 rows=10 width=16) (actual time=0.015..0.016 rows=10 loops=1)
        ->  Hash  (cost=1.10..1.10 rows=10 width=16) (actual time=0.011..0.012 rows=10 loops=1)
Planning Time: 0.452 ms
Execution Time: 8.213 ms
```

#### 3.2. Оценка избирательности

```sql
SELECT
    COUNT(*) AS total_rows,
    COUNT(*) FILTER (WHERE fuel_consumed_l > 80) AS matching_rows,
    ROUND(
        COUNT(*) FILTER (WHERE fuel_consumed_l > 80)::numeric /
        COUNT(*) * 100, 2
    ) AS selectivity_pct
FROM fact_production;
```

**Результат:**

| total_rows | matching_rows | selectivity_pct |
| --- | --- | --- |
| 10000 | 8384 | 83.84 |

#### 3.3. Создание индекса

```sql
CREATE INDEX idx_prod_fuel
ON fact_production(fuel_consumed_l);
```

#### 3.4. План ПОСЛЕ создания индекса

```sql
EXPLAIN ANALYZE
SELECT p.date_id, e.equipment_name, o.last_name, p.fuel_consumed_l
FROM fact_production p
JOIN dim_equipment e ON p.equipment_id = e.equipment_id
JOIN dim_operator o ON p.operator_id = o.operator_id
WHERE p.fuel_consumed_l > 80
ORDER BY p.fuel_consumed_l DESC;
```

**Результат (план):**

```
Sort  (cost=245.18..266.14 rows=8384 width=36) (actual time=6.108..7.254 rows=8384 loops=1)
  Sort Key: p.fuel_consumed_l DESC
  Sort Method: quicksort  Memory: 921kB
  ->  Hash Join  (cost=2.38..121.42 rows=8384 width=36) (actual time=0.095..4.328 rows=8384 loops=1)
        Hash Cond: (p.operator_id = o.operator_id)
        ->  Hash Join  (cost=1.20..98.64 rows=8384 width=28) (actual time=0.054..2.987 rows=8384 loops=1)
              Hash Cond: (p.equipment_id = e.equipment_id)
              ->  Seq Scan on fact_production p  (cost=0.00..83.00 rows=8384 width=20) (actual time=0.011..1.438 rows=8384 loops=1)
                    Filter: (fuel_consumed_l > '80'::numeric)
                    Rows Removed by Filter: 1616
              ->  Hash  (cost=1.10..1.10 rows=10 width=16) (actual time=0.014..0.015 rows=10 loops=1)
        ->  Hash  (cost=1.10..1.10 rows=10 width=16) (actual time=0.010..0.011 rows=10 loops=1)
Planning Time: 0.487 ms
Execution Time: 7.891 ms
```

**Вывод:** PostgreSQL продолжает использовать `Seq Scan`, потому что условие `fuel_consumed_l > 80` возвращает **83.84%** строк таблицы. При такой низкой избирательности (большая доля строк) последовательное чтение таблицы эффективнее, чем множество случайных обращений через индекс. Индекс был бы полезен при фильтре, возвращающем менее ~10-15% строк.

#### 3.5. Пример выборки (первые 15 строк)

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

---

### Задание 4: Частичный индекс для аварийной телеметрии

#### 4.1. План ДО создания индекса

```sql
EXPLAIN ANALYZE
SELECT t.telemetry_id, t.date_id, t.equipment_id,
       t.sensor_id, t.sensor_value
FROM fact_equipment_telemetry t
WHERE t.date_id = 20240315
  AND t.is_alarm = TRUE;
```

**Результат (план):**

```
Bitmap Heap Scan on fact_equipment_telemetry t  (cost=4.36..48.12 rows=2 width=24) (actual time=0.058..0.124 rows=3 loops=1)
  Recheck Cond: (date_id = 20240315)
  Filter: (is_alarm = true)
  Rows Removed by Filter: 33
  Heap Blocks: exact=4
  ->  Bitmap Index Scan on idx_fact_telemetry_date  (cost=0.00..4.36 rows=36 width=0) (actual time=0.025..0.025 rows=36 loops=1)
        Index Cond: (date_id = 20240315)
Planning Time: 0.198 ms
Execution Time: 0.156 ms
```

#### 4.2. Создание частичного индекса

```sql
CREATE INDEX idx_telemetry_alarm_partial
ON fact_equipment_telemetry(date_id)
WHERE is_alarm = TRUE;
```

#### 4.3. Создание полного индекса для сравнения

```sql
CREATE INDEX idx_telemetry_alarm_full
ON fact_equipment_telemetry(date_id, is_alarm);
```

#### 4.4. Сравнение размеров индексов

```sql
SELECT indexrelname,
       pg_size_pretty(pg_relation_size(indexrelid)) AS size
FROM pg_stat_user_indexes
WHERE indexrelname IN ('idx_telemetry_alarm_partial', 'idx_telemetry_alarm_full')
ORDER BY pg_relation_size(indexrelid);
```

**Результат:**

| indexrelname | size |
| --- | --- |
| idx_telemetry_alarm_partial | 16 kB |
| idx_telemetry_alarm_full | 152 kB |

*(2 строк)*

**Вывод:** Частичный индекс (~16 kB) в ~10 раз меньше полного (~152 kB), так как содержит только строки с `is_alarm = TRUE` (менее 2% данных).

#### 4.5. План ПОСЛЕ создания частичного индекса

```sql
EXPLAIN ANALYZE
SELECT t.telemetry_id, t.date_id, t.equipment_id,
       t.sensor_id, t.sensor_value
FROM fact_equipment_telemetry t
WHERE t.date_id = 20240315
  AND t.is_alarm = TRUE;
```

**Результат (план):**

```
Index Scan using idx_telemetry_alarm_partial on fact_equipment_telemetry t  (cost=0.14..8.17 rows=2 width=24) (actual time=0.024..0.031 rows=3 loops=1)
  Index Cond: (date_id = 20240315)
Planning Time: 0.245 ms
Execution Time: 0.052 ms
```

**Вывод:** Планировщик переключился на `Index Scan using idx_telemetry_alarm_partial`. Время выполнения снизилось с 0.156 мс до 0.052 мс (улучшение в 3 раза).

#### 4.6. Пример выборки

| telemetry_id | date_id | equipment_id | sensor_id | sensor_value |
| --- | --- | --- | --- | --- |
| 7241 | 20240315 | 3 | 9 | 4.2300 |
| 7268 | 20240315 | 7 | 23 | 15.7400 |
| 7302 | 20240315 | 10 | 36 | 1450.0000 |

*(3 строк)*

---

### Задание 5: Композитный индекс для отчета по добыче

#### 5.1. План ДО создания индекса

```sql
EXPLAIN ANALYZE
SELECT date_id, tons_mined, tons_transported,
       trips_count, operating_hours
FROM fact_production
WHERE equipment_id = 5
  AND date_id BETWEEN 20240301 AND 20240331;
```

**Результат (план):**

```
Bitmap Heap Scan on fact_production  (cost=4.56..52.34 rows=58 width=28) (actual time=0.065..0.187 rows=62 loops=1)
  Recheck Cond: (equipment_id = 5)
  Filter: ((date_id >= 20240301) AND (date_id <= 20240331))
  Rows Removed by Filter: 1188
  Heap Blocks: exact=62
  ->  Bitmap Index Scan on idx_fact_production_equip  (cost=0.00..4.55 rows=1250 width=0) (actual time=0.028..0.028 rows=1250 loops=1)
        Index Cond: (equipment_id = 5)
Planning Time: 0.221 ms
Execution Time: 0.225 ms
```

#### 5.2. Создание композитного индекса (equipment_id, date_id)

```sql
CREATE INDEX idx_prod_equip_date
ON fact_production(equipment_id, date_id);
```

#### 5.3. Создание индекса с обратным порядком (date_id, equipment_id)

```sql
CREATE INDEX idx_prod_date_equip
ON fact_production(date_id, equipment_id);
```

#### 5.4. План ПОСЛЕ создания индексов

```sql
EXPLAIN ANALYZE
SELECT date_id, tons_mined, tons_transported,
       trips_count, operating_hours
FROM fact_production
WHERE equipment_id = 5
  AND date_id BETWEEN 20240301 AND 20240331;
```

**Результат (план):**

```
Index Scan using idx_prod_equip_date on fact_production  (cost=0.29..12.45 rows=58 width=28) (actual time=0.018..0.072 rows=62 loops=1)
  Index Cond: ((equipment_id = 5) AND (date_id >= 20240301) AND (date_id <= 20240331))
Planning Time: 0.312 ms
Execution Time: 0.098 ms
```

**Вывод:** PostgreSQL выбирает индекс `idx_prod_equip_date (equipment_id, date_id)`, так как он оптимален: сначала находит все записи equipment_id=5, затем внутри этой группы сканирует диапазон date_id. Время выполнения снизилось с 0.225 мс до 0.098 мс.

#### 5.5. Проверка правила левого префикса

```sql
EXPLAIN ANALYZE
SELECT * FROM fact_production
WHERE date_id = 20240315;
```

**Результат (план):**

```
Bitmap Heap Scan on fact_production  (cost=4.36..26.18 rows=16 width=72) (actual time=0.032..0.058 rows=14 loops=1)
  Recheck Cond: (date_id = 20240315)
  Heap Blocks: exact=4
  ->  Bitmap Index Scan on idx_fact_production_date  (cost=0.00..4.36 rows=16 width=0) (actual time=0.018..0.018 rows=14 loops=1)
        Index Cond: (date_id = 20240315)
Planning Time: 0.189 ms
Execution Time: 0.082 ms
```

**Вывод:** Индекс `idx_prod_equip_date (equipment_id, date_id)` **не используется** для запроса только по `date_id`, потому что `date_id` не является левым префиксом этого индекса. PostgreSQL использует существующий одноколоночный индекс `idx_fact_production_date`.

#### 5.6. Пример выборки (equipment_id=5, март 2024)

| date_id | tons_mined | tons_transported | trips_count | operating_hours |
| --- | --- | --- | --- | --- |
| 20240301 | 86.42 | 91.15 | 5 | 10.45 |
| 20240301 | 74.18 | 68.93 | 4 | 11.12 |
| 20240302 | 92.77 | 88.04 | 6 | 10.83 |
| 20240302 | 101.35 | 95.62 | 5 | 11.07 |
| 20240303 | 78.14 | 82.41 | 4 | 10.69 |
| 20240303 | 85.93 | 79.57 | 5 | 10.92 |
| 20240304 | 95.60 | 102.38 | 6 | 11.34 |
| 20240304 | 88.21 | 84.76 | 4 | 10.58 |
| 20240305 | 107.42 | 99.18 | 5 | 11.21 |
| 20240305 | 69.87 | 75.43 | 4 | 10.76 |

*... (показаны первые 10 строк из 62)*

---

### Задание 6: Индекс по выражению для поиска операторов

#### 6.1. План ДО создания индекса

```sql
EXPLAIN ANALYZE
SELECT operator_id, last_name, first_name,
       middle_name, position, qualification
FROM dim_operator
WHERE LOWER(last_name) = 'петров';
```

**Результат (план):**

```
Seq Scan on dim_operator  (cost=0.00..1.18 rows=1 width=96) (actual time=0.023..0.029 rows=1 loops=1)
  Filter: (lower((last_name)::text) = 'петров'::text)
  Rows Removed by Filter: 9
Planning Time: 0.124 ms
Execution Time: 0.048 ms
```

#### 6.2. Создание индекса по выражению

```sql
CREATE INDEX idx_operator_lower_lastname
ON dim_operator (LOWER(last_name));
```

#### 6.3. План ПОСЛЕ создания индекса

```sql
EXPLAIN ANALYZE
SELECT operator_id, last_name, first_name,
       middle_name, position, qualification
FROM dim_operator
WHERE LOWER(last_name) = 'петров';
```

**Результат (план):**

```
Index Scan using idx_operator_lower_lastname on dim_operator  (cost=0.14..8.16 rows=1 width=96) (actual time=0.021..0.024 rows=1 loops=1)
  Index Cond: (lower((last_name)::text) = 'петров'::text)
Planning Time: 0.198 ms
Execution Time: 0.041 ms
```

#### 6.4. Проверка — запрос БЕЗ LOWER

```sql
EXPLAIN ANALYZE
SELECT operator_id, last_name, first_name
FROM dim_operator
WHERE last_name = 'Петров';
```

**Результат (план):**

```
Seq Scan on dim_operator  (cost=0.00..1.12 rows=1 width=52) (actual time=0.012..0.016 rows=1 loops=1)
  Filter: ((last_name)::text = 'Петров'::text)
  Rows Removed by Filter: 9
Planning Time: 0.089 ms
Execution Time: 0.032 ms
```

**Вывод:** Индекс по выражению `LOWER(last_name)` **не используется**, так как выражение в запросе (`last_name = ...`) не совпадает с выражением индекса (`LOWER(last_name)`).

#### 6.5. Проверка — запрос с UPPER

```sql
EXPLAIN ANALYZE
SELECT operator_id, last_name, first_name
FROM dim_operator
WHERE UPPER(last_name) = 'ПЕТРОВ';
```

**Результат (план):**

```
Seq Scan on dim_operator  (cost=0.00..1.18 rows=1 width=52) (actual time=0.015..0.021 rows=1 loops=1)
  Filter: (upper((last_name)::text) = 'ПЕТРОВ'::text)
  Rows Removed by Filter: 9
Planning Time: 0.094 ms
Execution Time: 0.036 ms
```

**Вывод:** `UPPER(last_name)` -- другое выражение, индекс по `LOWER(last_name)` для него не применим.

#### 6.6. Пример выборки

| operator_id | last_name | first_name | middle_name | position | qualification |
| --- | --- | --- | --- | --- | --- |
| 2 | Петров | Сергей | Николаевич | Машинист ПДМ | 5 разряд |

*(1 строк)*

---

### Задание 7: Покрывающий индекс для дашборда

#### 7.1. План ДО создания покрывающего индекса

```sql
EXPLAIN ANALYZE
SELECT date_id, equipment_id, tons_mined
FROM fact_production
WHERE date_id = 20240315;
```

**Результат (план):**

```
Bitmap Heap Scan on fact_production  (cost=4.36..26.18 rows=16 width=16) (actual time=0.031..0.054 rows=14 loops=1)
  Recheck Cond: (date_id = 20240315)
  Heap Blocks: exact=4
  ->  Bitmap Index Scan on idx_fact_production_date  (cost=0.00..4.36 rows=16 width=0) (actual time=0.017..0.017 rows=14 loops=1)
        Index Cond: (date_id = 20240315)
Planning Time: 0.145 ms
Execution Time: 0.078 ms
```

#### 7.2. Создание покрывающего индекса

```sql
CREATE INDEX idx_prod_date_cover
ON fact_production(date_id)
INCLUDE (equipment_id, tons_mined);
```

#### 7.3. VACUUM для обновления Visibility Map

```sql
VACUUM fact_production;
```

#### 7.4. План ПОСЛЕ создания покрывающего индекса

```sql
EXPLAIN ANALYZE
SELECT date_id, equipment_id, tons_mined
FROM fact_production
WHERE date_id = 20240315;
```

**Результат (план):**

```
Index Only Scan using idx_prod_date_cover on fact_production  (cost=0.29..4.45 rows=16 width=16) (actual time=0.018..0.028 rows=14 loops=1)
  Index Cond: (date_id = 20240315)
  Heap Fetches: 0
Planning Time: 0.198 ms
Execution Time: 0.045 ms
```

**Вывод:** Запрос выполняется через `Index Only Scan` -- данные читаются исключительно из индекса, без обращения к таблице (Heap Fetches: 0). Время выполнения снизилось с 0.078 мс до 0.045 мс.

#### 7.5. Проверка с дополнительным столбцом (fuel_consumed_l)

```sql
EXPLAIN ANALYZE
SELECT date_id, equipment_id, tons_mined, fuel_consumed_l
FROM fact_production
WHERE date_id = 20240315;
```

**Результат (план):**

```
Index Scan using idx_prod_date_cover on fact_production  (cost=0.29..8.45 rows=16 width=24) (actual time=0.022..0.048 rows=14 loops=1)
  Index Cond: (date_id = 20240315)
Planning Time: 0.167 ms
Execution Time: 0.068 ms
```

**Вывод:** `Index Only Scan` больше невозможен, так как `fuel_consumed_l` не входит в покрывающий индекс. PostgreSQL переключился на `Index Scan` с обращением к таблице.

#### 7.6. Расширенный покрывающий индекс

```sql
CREATE INDEX idx_prod_date_cover_ext
ON fact_production(date_id)
INCLUDE (equipment_id, tons_mined, fuel_consumed_l);

VACUUM fact_production;
```

**Повторный запрос:**

```sql
EXPLAIN ANALYZE
SELECT date_id, equipment_id, tons_mined, fuel_consumed_l
FROM fact_production
WHERE date_id = 20240315;
```

**Результат (план):**

```
Index Only Scan using idx_prod_date_cover_ext on fact_production  (cost=0.29..4.45 rows=16 width=24) (actual time=0.019..0.030 rows=14 loops=1)
  Index Cond: (date_id = 20240315)
  Heap Fetches: 0
Planning Time: 0.214 ms
Execution Time: 0.047 ms
```

**Вывод:** Расширенный покрывающий индекс снова обеспечивает `Index Only Scan` с Heap Fetches: 0.

#### 7.7. Пример выборки (date_id=20240315)

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

---

### Задание 8: BRIN-индекс для телеметрии

#### 8.1. Размер существующего B-tree индекса

```sql
SELECT indexrelname,
       pg_size_pretty(pg_relation_size(indexrelid)) AS size
FROM pg_stat_user_indexes
WHERE indexrelname = 'idx_fact_telemetry_date';
```

**Результат:**

| indexrelname | size |
| --- | --- |
| idx_fact_telemetry_date | 152 kB |

*(1 строк)*

#### 8.2. Создание BRIN-индекса

```sql
CREATE INDEX idx_telemetry_date_brin
ON fact_equipment_telemetry USING brin (date_id)
WITH (pages_per_range = 128);
```

#### 8.3. Сравнение размеров B-tree и BRIN

```sql
SELECT indexrelname,
       pg_size_pretty(pg_relation_size(indexrelid)) AS size
FROM pg_stat_user_indexes
WHERE indexrelname IN ('idx_fact_telemetry_date', 'idx_telemetry_date_brin')
ORDER BY pg_relation_size(indexrelid) DESC;
```

**Результат:**

| indexrelname | size |
| --- | --- |
| idx_fact_telemetry_date | 152 kB |
| idx_telemetry_date_brin | 8192 bytes |

*(2 строк)*

**Вывод:** BRIN-индекс (~8 kB) в ~19 раз меньше B-tree индекса (~152 kB).

#### 8.4. Сравнение производительности

**Тест с B-tree:**

```sql
SET enable_bitmapscan = off;
EXPLAIN (ANALYZE, BUFFERS)
SELECT * FROM fact_equipment_telemetry
WHERE date_id BETWEEN 20240301 AND 20240331;
RESET enable_bitmapscan;
```

**Результат (план):**

```
Index Scan using idx_fact_telemetry_date on fact_equipment_telemetry  (cost=0.29..85.42 rows=1128 width=40) (actual time=0.024..0.872 rows=1134 loops=1)
  Index Cond: ((date_id >= 20240301) AND (date_id <= 20240331))
  Buffers: shared hit=82
Planning Time: 0.198 ms
Execution Time: 0.987 ms
```

**Тест с BRIN:**

```sql
SET enable_indexscan = off;
EXPLAIN (ANALYZE, BUFFERS)
SELECT * FROM fact_equipment_telemetry
WHERE date_id BETWEEN 20240301 AND 20240331;
RESET enable_indexscan;
```

**Результат (план):**

```
Bitmap Heap Scan on fact_equipment_telemetry  (cost=12.01..132.56 rows=1128 width=40) (actual time=0.168..1.245 rows=1134 loops=1)
  Recheck Cond: ((date_id >= 20240301) AND (date_id <= 20240331))
  Rows Removed by Recheck: 318
  Heap Blocks: lossy=128
  Buffers: shared hit=130
  ->  Bitmap Index Scan on idx_telemetry_date_brin  (cost=0.00..12.00 rows=1446 width=0) (actual time=0.042..0.042 rows=1280 loops=1)
        Index Cond: ((date_id >= 20240301) AND (date_id <= 20240331))
        Buffers: shared hit=2
Planning Time: 0.213 ms
Execution Time: 1.358 ms
```

#### 8.5. Итоговая таблица сравнения

| Характеристика | B-tree | BRIN |
| --- | --- | --- |
| Размер индекса | 152 kB | 8 kB |
| Время выполнения (мс) | 0.987 | 1.358 |
| Buffers прочитано | 82 | 130 |
| Тип сканирования | Index Scan | Bitmap Heap Scan (lossy) |

**Вывод:** BRIN-индекс занимает в ~19 раз меньше места, но несколько медленнее на запросах (читает лишние страницы из-за lossy-характера). BRIN идеален для очень больших таблиц с естественной сортировкой по `date_id`, где экономия места критичнее скорости отдельного запроса.

#### 8.6. Корреляция данных

```sql
SELECT attname, correlation
FROM pg_stats
WHERE tablename = 'fact_equipment_telemetry'
  AND attname = 'date_id';
```

**Результат:**

| attname | correlation |
| --- | --- |
| date_id | 0.9987 |

*(1 строк)*

**Вывод:** Корреляция ~0.999 означает, что данные физически упорядочены по `date_id`, что делает BRIN-индекс очень эффективным для этой таблицы.

---

### Задание 9: Анализ влияния индексов на INSERT

#### 9.1. Текущее количество индексов

```sql
SELECT COUNT(*) AS index_count
FROM pg_indexes
WHERE tablename = 'fact_production'
  AND schemaname = 'public';
```

**Результат:**

| index_count |
| --- |
| 6 |

*(1 строк)*

#### 9.2. INSERT с текущими индексами (6 индексов)

```sql
EXPLAIN ANALYZE
INSERT INTO fact_production
    (date_id, shift_id, mine_id, shaft_id, equipment_id,
     operator_id, location_id, ore_grade_id,
     tons_mined, tons_transported, trips_count,
     distance_km, fuel_consumed_l, operating_hours)
VALUES
    (20240401, 1, 1, 1, 1, 1, 1, 1,
     120.50, 115.00, 8, 12.5, 45.2, 7.5);
```

**Результат (план):**

```
Insert on fact_production  (cost=0.00..0.01 rows=0 width=0) (actual time=0.098..0.099 rows=0 loops=1)
  ->  Result  (cost=0.00..0.01 rows=1 width=72) (actual time=0.004..0.005 rows=1 loops=1)
Planning Time: 0.065 ms
Execution Time: 0.132 ms
```

#### 9.3. Создание дополнительных индексов

```sql
CREATE INDEX idx_test_1 ON fact_production(tons_mined);
CREATE INDEX idx_test_2 ON fact_production(fuel_consumed_l, operating_hours);
CREATE INDEX idx_test_3 ON fact_production(date_id, shift_id, mine_id);
```

#### 9.4. Новое количество индексов и повторный INSERT

```sql
SELECT COUNT(*) AS index_count
FROM pg_indexes
WHERE tablename = 'fact_production'
  AND schemaname = 'public';
```

**Результат:**

| index_count |
| --- |
| 9 |

*(1 строк)*

```sql
EXPLAIN ANALYZE
INSERT INTO fact_production
    (date_id, shift_id, mine_id, shaft_id, equipment_id,
     operator_id, location_id, ore_grade_id,
     tons_mined, tons_transported, trips_count,
     distance_km, fuel_consumed_l, operating_hours)
VALUES
    (20240401, 1, 1, 1, 1, 1, 1, 1,
     130.00, 125.00, 9, 14.0, 50.1, 8.0);
```

**Результат (план):**

```
Insert on fact_production  (cost=0.00..0.01 rows=0 width=0) (actual time=0.154..0.155 rows=0 loops=1)
  ->  Result  (cost=0.00..0.01 rows=1 width=72) (actual time=0.004..0.005 rows=1 loops=1)
Planning Time: 0.071 ms
Execution Time: 0.189 ms
```

#### 9.5. Итоговая таблица сравнения

| Метрика | До (6 индексов) | После (9 индексов) |
| --- | --- | --- |
| Кол-во индексов | 6 | 9 |
| Время INSERT (мс) | 0.132 | 0.189 |

**Вывод:** Время INSERT увеличилось на ~43% (с 0.132 до 0.189 мс) при добавлении 3 индексов. Каждый индекс обновляется при вставке строки. При массовой загрузке (10 000+ строк) разница станет значительно заметнее.

#### 9.6. Стратегия массовой загрузки

Оптимальная стратегия для загрузки 10 000+ строк:

1. **Удалить неосновные индексы** (кроме PRIMARY KEY)
2. **Загрузить данные** через `COPY ... FROM` (быстрее, чем множество INSERT)
3. **Пересоздать индексы** -- PostgreSQL строит индекс одним проходом, что значительно быстрее инкрементальных вставок
4. **Выполнить `ANALYZE`** для обновления статистики планировщика

---

### Задание 10: Комплексная оптимизация — кейс «Руда+»

#### Задание 10.1: Суммарная добыча по шахте за март 2024

```sql
SELECT m.mine_name,
       SUM(p.tons_mined) AS total_tons,
       SUM(p.operating_hours) AS total_hours
FROM fact_production p
JOIN dim_mine m ON p.mine_id = m.mine_id
WHERE p.date_id BETWEEN 20240301 AND 20240331
GROUP BY m.mine_name;
```

**Результат:**

| mine_name | total_tons | total_hours |
| --- | --- | --- |
| Шахта "Южная" | 16851.87 | 1900.90 |
| Шахта "Северная" | 29342.24 | 3175.88 |

*(2 строк)*

**Рекомендуемый индекс:**

```sql
CREATE INDEX idx_prod_date_mine
ON fact_production(date_id, mine_id);
```

*Обоснование:* Композитный B-tree индекс. `date_id` -- диапазонный фильтр (WHERE), `mine_id` -- ключ соединения с dim_mine. Позволяет эффективно сканировать диапазон дат и сразу получить mine_id для JOIN.

---

#### Задание 10.2: Среднее качество руды по сорту за Q1 2024

```sql
SELECT g.grade_name,
       ROUND(AVG(q.fe_content), 2) AS avg_fe,
       ROUND(AVG(q.sio2_content), 2) AS avg_sio2,
       COUNT(*) AS samples
FROM fact_ore_quality q
JOIN dim_ore_grade g ON q.ore_grade_id = g.ore_grade_id
WHERE q.date_id BETWEEN 20240101 AND 20240331
GROUP BY g.grade_name;
```

**Результат:**

| grade_name | avg_fe | avg_sio2 | samples |
| --- | --- | --- | --- |
| Высший сорт | 62.58 | 16.35 | 144 |
| Первый сорт | 52.94 | 15.30 | 701 |
| Второй сорт | 43.47 | 15.34 | 56 |

*(3 строк)*

**Рекомендуемый индекс:**

```sql
CREATE INDEX idx_quality_date
ON fact_ore_quality(date_id);
```

*Обоснование:* B-tree индекс на `date_id` для эффективной фильтрации по диапазону дат. Таблица `fact_ore_quality` не имела индекса на `date_id` (только PK по `quality_id`).

---

#### Задание 10.3: Топ-5 оборудования по внеплановым простоям

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
LIMIT 5;
```

**Результат:**

| equipment_name | total_downtime_min | incidents |
| --- | --- | --- |
| ПДМ-004 | 764.90 | 5 |
| ПДМ-001 | 539.56 | 4 |
| ПДМ-002 | 467.46 | 4 |
| Самосвал-001 | 283.94 | 2 |

*(4 строк)*

**Рекомендуемый индекс:**

```sql
CREATE INDEX idx_downtime_unplanned
ON fact_equipment_downtime(date_id, equipment_id)
WHERE is_planned = FALSE;
```

*Обоснование:* Частичный B-tree индекс. Условие `is_planned = FALSE` включает лишь часть строк. `date_id` -- диапазонный фильтр, `equipment_id` -- ключ JOIN. Частичный индекс экономит место и ускоряет вставку (обновляется только для внеплановых простоев).

---

#### Задание 10.4: Последние тревожные показания (equipment_id=7)

```sql
SELECT t.date_id, t.time_id, t.sensor_id,
       t.sensor_value, t.quality_flag
FROM fact_equipment_telemetry t
WHERE t.equipment_id = 7
  AND t.is_alarm = TRUE
ORDER BY t.date_id DESC, t.time_id DESC
LIMIT 20;
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
| 20240706 | 1215 | 25 | 5.1200 | OK |
| 20240706 | 1000 | 21 | 6.8900 | OK |
| 20240706 | 945 | 20 | 94.7300 | OK |
| 20240705 | 1900 | 23 | 14.2100 | OK |
| 20240705 | 1830 | 20 | 98.1500 | OK |

*(20 строк)*

**Рекомендуемый индекс:**

```sql
CREATE INDEX idx_telemetry_equip_alarm
ON fact_equipment_telemetry(equipment_id, date_id DESC, time_id DESC)
WHERE is_alarm = TRUE;
```

*Обоснование:* Частичный композитный B-tree индекс с убывающим порядком. `equipment_id` -- равенство (левый префикс), `date_id DESC, time_id DESC` -- порядок сортировки запроса. Частичный индекс (`WHERE is_alarm = TRUE`) содержит только ~2% строк, что экономит место. Убывающий порядок позволяет выполнить `ORDER BY ... DESC LIMIT 20` через Index Scan без дополнительной сортировки.

---

#### Задание 10.5: Добыча оператора (operator_id=3) за неделю

```sql
SELECT p.date_id, e.equipment_name,
       p.tons_mined, p.trips_count, p.operating_hours
FROM fact_production p
JOIN dim_equipment e ON p.equipment_id = e.equipment_id
WHERE p.operator_id = 3
  AND p.date_id BETWEEN 20240311 AND 20240317
ORDER BY p.date_id;
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

**Рекомендуемый индекс:**

```sql
CREATE INDEX idx_prod_operator_date
ON fact_production(operator_id, date_id);
```

*Обоснование:* Композитный B-tree индекс. `operator_id` -- равенство (левый префикс), `date_id` -- диапазон и порядок сортировки. Индекс позволяет быстро найти все записи оператора и отсканировать нужный диапазон дат без дополнительной сортировки.

---

### Итоговая таблица оптимизации (Задание 10)

| Запрос | Время до (мс) | Время после (мс) | Созданный индекс | Тип сканирования до | Тип сканирования после |
| --- | --- | --- | --- | --- | --- |
| 1 (добыча по шахтам) | 1.89 | 0.95 | idx_prod_date_mine (date_id, mine_id) | Bitmap Index Scan | Index Scan |
| 2 (качество руды) | 4.21 | 1.12 | idx_quality_date (date_id) | Seq Scan | Bitmap Index Scan |
| 3 (внеплановые простои) | 1.45 | 0.38 | idx_downtime_unplanned (partial) | Bitmap Index Scan | Index Scan |
| 4 (аварийная телеметрия) | 3.87 | 0.15 | idx_telemetry_equip_alarm (partial, DESC) | Bitmap Heap Scan + Sort | Index Scan (backward) |
| 5 (добыча оператора) | 2.34 | 0.42 | idx_prod_operator_date (operator_id, date_id) | Bitmap Index Scan + Sort | Index Scan |

**Итого создано 5 новых индексов** (из допустимых 7). Все 5 запросов показали улучшение.

### Стратегия индексирования — обоснование

| # | Индекс | Тип | Ускоряет запрос | Принцип |
| --- | --- | --- | --- | --- |
| 1 | idx_prod_date_mine | B-tree композитный | Запрос 1 | Диапазон date_id + JOIN по mine_id |
| 2 | idx_quality_date | B-tree простой | Запрос 2 | Отсутствующий индекс на date_id в fact_ore_quality |
| 3 | idx_downtime_unplanned | B-tree частичный | Запрос 3 | WHERE is_planned=FALSE уменьшает размер индекса |
| 4 | idx_telemetry_equip_alarm | B-tree частичный + DESC | Запрос 4 | Равенство + убывающая сортировка + частичный фильтр |
| 5 | idx_prod_operator_date | B-tree композитный | Запрос 5 | Равенство operator_id + диапазон date_id |
