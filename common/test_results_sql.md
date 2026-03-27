# SQL Query Test Results

**Date:** 2026-03-19
**Database:** Yandex Managed Service for PostgreSQL

## Summary

| Metric | Count |
|--------|-------|
| PASS | 243 |
| FAIL (expected - depends on prior DDL) | 23 |
| SKIP (DML/DDL) | 120 |
| **Total** | **386** |

### Fixes Applied

| Module | Query | Issue | Fix |
|--------|-------|-------|-----|
| 3 | Q23 (4.5) | Alias mismatch: used `s.shaft_name` but table aliased as `sh` | Changed `s.shaft_name`, `s.shaft_type` to `sh.shaft_name`, `sh.shaft_type` |
| 6 | Q16 (2.7) | `ROUND(double precision, integer)` not supported in PostgreSQL | Added `::NUMERIC` cast to `STDDEV()` and `VARIANCE()` results |
| 6 | Q19 (3.3) | Russian month name in `TO_DATE()` not supported by PostgreSQL locale | Changed `TO_DATE('15 марта 2024', 'DD TMMonth YYYY')` to `TO_DATE('15 March 2024', 'DD Month YYYY')` |
| 9 | Q40 (4.3) | Column `d.month_number` does not exist in `dim_date` | Changed to `d.month` |
| 10 | Q4 (2.1) | `ORDER BY o.last_name` not in SELECT DISTINCT list | Added `o.last_name` to SELECT list |

### Remaining Failures (All Expected)

All 23 remaining FAIL results are **expected** -- they are SELECT queries that verify results of DDL/DML operations that precede them in the examples file:

- **Module 5** (11 failures): Queries reference `practice_*` tables which require running `scripts/create_practice_tables.sql` first
- **Module 8** (4 failures): Queries reference indexes created in prior CREATE INDEX statements (skipped as DDL)
- **Module 9** (8 failures): Queries reference `fact_telemetry_columnar`, `fact_telemetry_partitioned`, `fact_production_by_mine`, `columnar.options` -- tables created by preceding DDL statements

These queries will work correctly when the module examples are executed sequentially in order.

---

## Module 3

**File:** `C:\Users\dstrelnikov\Documents\SQL\module_03\examples.sql`

### Q1: 1.1 Выбрать все столбцы из таблицы оборудования

**Status:** PASS

```sql
SELECT *
FROM dim_equipment;
```

**Rows returned:** 18 (showing first 5)

| equipment_id | equipment_type_id | mine_id | equipment_name | inventory_number | manufacturer | model  | year_manufactured | commissioning_date | status      | has_video_recorder | has_navigation |
|--------------|-------------------|---------|----------------|------------------|--------------|--------|-------------------|--------------------|-------------|--------------------|----------------|
| 1            | 1                 | 1       | ПДМ-001        | INV-LHD-001      | Sandvik      | LH514  | 2019              | 2019-08-15         | active      | True               | True           |
| 2            | 1                 | 1       | ПДМ-002        | INV-LHD-002      | Sandvik      | LH514  | 2020              | 2020-03-10         | active      | True               | True           |
| 3            | 1                 | 1       | ПДМ-003        | INV-LHD-003      | Caterpillar  | R1700  | 2018              | 2018-11-20         | active      | True               | True           |
| 4            | 1                 | 2       | ПДМ-004        | INV-LHD-004      | Sandvik      | LH517i | 2021              | 2021-05-01         | active      | True               | True           |
| 5            | 1                 | 2       | ПДМ-005        | INV-LHD-005      | Caterpillar  | R1700  | 2017              | 2017-09-12         | maintenance | True               | True           |

### Q2: 1.2 Выбрать определённые столбцы

**Status:** PASS

```sql
SELECT equipment_name,
       inventory_number,
       manufacturer,
       model,
       status
FROM dim_equipment;
```

**Rows returned:** 18 (showing first 5)

| equipment_name | inventory_number | manufacturer | model  | status      |
|----------------|------------------|--------------|--------|-------------|
| ПДМ-001        | INV-LHD-001      | Sandvik      | LH514  | active      |
| ПДМ-002        | INV-LHD-002      | Sandvik      | LH514  | active      |
| ПДМ-003        | INV-LHD-003      | Caterpillar  | R1700  | active      |
| ПДМ-004        | INV-LHD-004      | Sandvik      | LH517i | active      |
| ПДМ-005        | INV-LHD-005      | Caterpillar  | R1700  | maintenance |

### Q3: 1.3 Выбрать уникальных производителей оборудования

**Status:** PASS

```sql
SELECT DISTINCT manufacturer
FROM dim_equipment;
```

**Rows returned:** 5 (showing first 5)

| manufacturer   |
|----------------|
| Sandvik        |
| Siemag Tecberg |
| Epiroc         |
| Caterpillar    |
| НКМЗ           |

### Q4: 1.4 Выбрать уникальные комбинации производитель + модель

**Status:** PASS

```sql
SELECT DISTINCT manufacturer, model
FROM dim_equipment;
```

**Rows returned:** 10 (showing first 5)

| manufacturer | model  |
|--------------|--------|
| НКМЗ         | ВГ-5.0 |
| НКМЗ         | СН-20  |
| Epiroc       | ST14   |
| Sandvik      | TH663i |
| Sandvik      | LH514  |

### Q5: 1.5 Подсчитать количество единиц оборудования

**Status:** PASS

```sql
SELECT COUNT(*) AS total_equipment
FROM dim_equipment;
```

**Rows returned:** 1 (showing first 1)

| total_equipment |
|-----------------|
| 18              |

### Q6: 2.1 Оборудование шахты «Северная» (mine_id = 1)

**Status:** PASS

```sql
SELECT equipment_name,
       inventory_number,
       manufacturer,
       model,
       status
FROM dim_equipment
WHERE mine_id = 1;
```

**Rows returned:** 10 (showing first 5)

| equipment_name | inventory_number | manufacturer | model  | status |
|----------------|------------------|--------------|--------|--------|
| ПДМ-001        | INV-LHD-001      | Sandvik      | LH514  | active |
| ПДМ-002        | INV-LHD-002      | Sandvik      | LH514  | active |
| ПДМ-003        | INV-LHD-003      | Caterpillar  | R1700  | active |
| Самосвал-001   | INV-TRK-001      | Sandvik      | TH663i | active |
| Самосвал-002   | INV-TRK-002      | Sandvik      | TH663i | active |

### Q7: 2.2 Активное оборудование

**Status:** PASS

```sql
SELECT equipment_name, manufacturer, model
FROM dim_equipment
WHERE status = 'active';
```

**Rows returned:** 17 (showing first 5)

| equipment_name | manufacturer | model  |
|----------------|--------------|--------|
| ПДМ-001        | Sandvik      | LH514  |
| ПДМ-002        | Sandvik      | LH514  |
| ПДМ-003        | Caterpillar  | R1700  |
| ПДМ-004        | Sandvik      | LH517i |
| ПДМ-006        | Epiroc       | ST14   |

### Q8: 2.3 ПДМ (equipment_type_id = 1) на шахте «Северная»

**Status:** PASS

```sql
SELECT equipment_name, manufacturer, model, year_manufactured
FROM dim_equipment
WHERE equipment_type_id = 1
  AND mine_id = 1;
```

**Rows returned:** 3 (showing first 3)

| equipment_name | manufacturer | model | year_manufactured |
|----------------|--------------|-------|-------------------|
| ПДМ-001        | Sandvik      | LH514 | 2019              |
| ПДМ-002        | Sandvik      | LH514 | 2020              |
| ПДМ-003        | Caterpillar  | R1700 | 2018              |

### Q9: 2.4 Оборудование выпуска после 2020 года

**Status:** PASS

```sql
SELECT equipment_name, manufacturer, model, year_manufactured
FROM dim_equipment
WHERE year_manufactured > 2020;
```

**Rows returned:** 3 (showing first 3)

| equipment_name | manufacturer | model  | year_manufactured |
|----------------|--------------|--------|-------------------|
| ПДМ-004        | Sandvik      | LH517i | 2021              |
| ПДМ-006        | Epiroc       | ST14   | 2022              |
| Самосвал-004   | Sandvik      | TH551i | 2021              |

### Q10: 2.5 Оборудование с видеорегистратором

**Status:** PASS

```sql
SELECT equipment_name, manufacturer, model
FROM dim_equipment
WHERE has_video_recorder = TRUE;
```

**Rows returned:** 13 (showing first 5)

| equipment_name | manufacturer | model  |
|----------------|--------------|--------|
| ПДМ-001        | Sandvik      | LH514  |
| ПДМ-002        | Sandvik      | LH514  |
| ПДМ-003        | Caterpillar  | R1700  |
| ПДМ-004        | Sandvik      | LH517i |
| ПДМ-005        | Caterpillar  | R1700  |

### Q11: 2.6 Добыча более 100 тонн за смену

**Status:** PASS

```sql
SELECT production_id, date_id, equipment_id, operator_id,
       tons_mined, tons_transported
FROM fact_production
WHERE tons_mined > 100;
```

**Rows returned:** 3194 (showing first 5)

| production_id | date_id  | equipment_id | operator_id | tons_mined | tons_transported |
|---------------|----------|--------------|-------------|------------|------------------|
| 6             | 20240101 | 7            | 3           | 135.07     | 195.51           |
| 7             | 20240101 | 8            | 4           | 154.57     | 150.66           |
| 8             | 20240101 | 10           | 7           | 151.82     | 153.89           |
| 14            | 20240101 | 7            | 3           | 128.10     | 147.88           |
| 15            | 20240101 | 8            | 4           | 148.58     | 159.44           |

### Q12: 2.7 Использование BETWEEN: добыча за январь 2024

**Status:** PASS

```sql
SELECT date_id, equipment_id, operator_id,
       tons_mined, trips_count
FROM fact_production
WHERE date_id BETWEEN 20240101 AND 20240131;
```

**Rows returned:** 482 (showing first 5)

| date_id  | equipment_id | operator_id | tons_mined | trips_count |
|----------|--------------|-------------|------------|-------------|
| 20240101 | 1            | 1           | 71.32      | 6           |
| 20240101 | 2            | 2           | 75.88      | 6           |
| 20240101 | 3            | 10          | 65.15      | 5           |
| 20240101 | 4            | 5           | 64.61      | 10          |
| 20240101 | 6            | 6           | 89.71      | 8           |

### Q13: 2.8 Использование IN: оборудование определённых производителей

**Status:** PASS

```sql
SELECT equipment_name, manufacturer, model
FROM dim_equipment
WHERE manufacturer IN ('Sandvik', 'Caterpillar');
```

**Rows returned:** 10 (showing first 5)

| equipment_name | manufacturer | model  |
|----------------|--------------|--------|
| ПДМ-001        | Sandvik      | LH514  |
| ПДМ-002        | Sandvik      | LH514  |
| ПДМ-003        | Caterpillar  | R1700  |
| ПДМ-004        | Sandvik      | LH517i |
| ПДМ-005        | Caterpillar  | R1700  |

### Q14: 2.9 Использование LIKE: поиск по названию

**Status:** PASS

```sql
SELECT equipment_name, inventory_number
FROM dim_equipment
WHERE equipment_name LIKE 'ПДМ%';
```

**Rows returned:** 6 (showing first 5)

| equipment_name | inventory_number |
|----------------|------------------|
| ПДМ-001        | INV-LHD-001      |
| ПДМ-002        | INV-LHD-002      |
| ПДМ-003        | INV-LHD-003      |
| ПДМ-004        | INV-LHD-004      |
| ПДМ-005        | INV-LHD-005      |

### Q15: 3.1 Оборудование, отсортированное по году выпуска (от нового к старому)

**Status:** PASS

```sql
SELECT equipment_name, manufacturer, model, year_manufactured
FROM dim_equipment
ORDER BY year_manufactured DESC;
```

**Rows returned:** 18 (showing first 5)

| equipment_name | manufacturer | model  | year_manufactured |
|----------------|--------------|--------|-------------------|
| ПДМ-006        | Epiroc       | ST14   | 2022              |
| Самосвал-004   | Sandvik      | TH551i | 2021              |
| ПДМ-004        | Sandvik      | LH517i | 2021              |
| Самосвал-001   | Sandvik      | TH663i | 2020              |
| ПДМ-002        | Sandvik      | LH514  | 2020              |

### Q16: 3.2 Добыча за январь 2024, сортировка по объёму (убывание)

**Status:** PASS

```sql
SELECT date_id, equipment_id, operator_id,
       tons_mined, trips_count
FROM fact_production
WHERE date_id BETWEEN 20240101 AND 20240131
ORDER BY tons_mined DESC;
```

**Rows returned:** 482 (showing first 5)

| date_id  | equipment_id | operator_id | tons_mined | trips_count |
|----------|--------------|-------------|------------|-------------|
| 20240112 | 7            | 3           | 181.18     | 5           |
| 20240103 | 7            | 3           | 180.76     | 4           |
| 20240109 | 7            | 3           | 180.54     | 5           |
| 20240130 | 7            | 3           | 178.83     | 7           |
| 20240116 | 8            | 4           | 178.50     | 7           |

### Q17: 3.3 Топ-5 записей добычи по объёму

**Status:** PASS

```sql
SELECT date_id, equipment_id, operator_id,
       tons_mined, trips_count
FROM fact_production
ORDER BY tons_mined DESC
LIMIT 5;
```

**Rows returned:** 5 (showing first 5)

| date_id  | equipment_id | operator_id | tons_mined | trips_count |
|----------|--------------|-------------|------------|-------------|
| 20240621 | 7            | 3           | 237.41     | 7           |
| 20240612 | 7            | 3           | 237.16     | 7           |
| 20250618 | 7            | 3           | 236.14     | 4           |
| 20250623 | 7            | 3           | 235.27     | 7           |
| 20250606 | 7            | 3           | 234.91     | 4           |

### Q18: 3.4 Сортировка по нескольким столбцам

**Status:** PASS

```sql
SELECT equipment_name, manufacturer, model, year_manufactured
FROM dim_equipment
ORDER BY manufacturer ASC, year_manufactured DESC;
```

**Rows returned:** 18 (showing first 5)

| equipment_name | manufacturer | model | year_manufactured |
|----------------|--------------|-------|-------------------|
| Самосвал-003   | Caterpillar  | AD30  | 2019              |
| ПДМ-003        | Caterpillar  | R1700 | 2018              |
| Самосвал-005   | Caterpillar  | AD30  | 2018              |
| ПДМ-005        | Caterpillar  | R1700 | 2017              |
| ПДМ-006        | Epiroc       | ST14  | 2022              |

### Q19: 4.1 Оборудование с названием типа и названием шахты

**Status:** PASS

```sql
SELECT e.equipment_name,
       et.type_name    AS equipment_type,
       m.mine_name
FROM dim_equipment e
INNER JOIN dim_equipment_type et ON e.equipment_type_id = et.equipment_type_id
INNER JOIN dim_mine m            ON e.mine_id = m.mine_id;
```

**Rows returned:** 18 (showing first 5)

| equipment_name | equipment_type                | mine_name        |
|----------------|-------------------------------|------------------|
| ПДМ-006        | Погрузочно-доставочная машина | Шахта "Южная"    |
| ПДМ-005        | Погрузочно-доставочная машина | Шахта "Южная"    |
| ПДМ-004        | Погрузочно-доставочная машина | Шахта "Южная"    |
| ПДМ-003        | Погрузочно-доставочная машина | Шахта "Северная" |
| ПДМ-002        | Погрузочно-доставочная машина | Шахта "Северная" |

### Q20: 4.2 Оборудование шахты «Северная» с типом

**Status:** PASS

```sql
SELECT e.equipment_name,
       et.type_name AS equipment_type,
       e.manufacturer,
       e.model
FROM dim_equipment e
INNER JOIN dim_equipment_type et ON e.equipment_type_id = et.equipment_type_id
INNER JOIN dim_mine m            ON e.mine_id = m.mine_id
WHERE m.mine_name = 'Шахта "Северная"';
```

**Rows returned:** 10 (showing first 5)

| equipment_name | equipment_type                | manufacturer | model  |
|----------------|-------------------------------|--------------|--------|
| ПДМ-001        | Погрузочно-доставочная машина | Sandvik      | LH514  |
| ПДМ-002        | Погрузочно-доставочная машина | Sandvik      | LH514  |
| ПДМ-003        | Погрузочно-доставочная машина | Caterpillar  | R1700  |
| Самосвал-001   | Шахтный самосвал              | Sandvik      | TH663i |
| Самосвал-002   | Шахтный самосвал              | Sandvik      | TH663i |

### Q21: 4.3 Добыча с расшифровкой оборудования, оператора и смены

**Status:** PASS

```sql
SELECT d.full_date,
       sh.shift_name,
       e.equipment_name,
       op.last_name || ' ' || op.first_name AS operator_name,
       fp.tons_mined,
       fp.trips_count
FROM fact_production fp
INNER JOIN dim_date d      ON fp.date_id = d.date_id
INNER JOIN dim_shift sh    ON fp.shift_id = sh.shift_id
INNER JOIN dim_equipment e ON fp.equipment_id = e.equipment_id
INNER JOIN dim_operator op ON fp.operator_id = op.operator_id
WHERE d.full_date = '2024-01-15'
ORDER BY fp.tons_mined DESC;
```

**Rows returned:** 16 (showing first 5)

| full_date  | shift_name    | equipment_name | operator_name   | tons_mined | trips_count |
|------------|---------------|----------------|-----------------|------------|-------------|
| 2024-01-15 | Ночная смена  | Самосвал-001   | Сидоров Дмитрий | 172.08     | 6           |
| 2024-01-15 | Ночная смена  | Самосвал-002   | Козлов Андрей   | 167.97     | 5           |
| 2024-01-15 | Дневная смена | Самосвал-002   | Козлов Андрей   | 160.75     | 7           |
| 2024-01-15 | Дневная смена | Самосвал-004   | Волков Николай  | 151.39     | 6           |
| 2024-01-15 | Дневная смена | Самосвал-001   | Сидоров Дмитрий | 124.57     | 4           |

### Q22: 4.4 Простои с причинами и названием оборудования

**Status:** PASS

```sql
SELECT e.equipment_name,
       dr.reason_name,
       dr.category,
       fd.duration_min,
       fd.is_planned,
       fd.comment
FROM fact_equipment_downtime fd
INNER JOIN dim_equipment e        ON fd.equipment_id = e.equipment_id
INNER JOIN dim_downtime_reason dr ON fd.reason_id = dr.reason_id
WHERE fd.date_id BETWEEN 20240101 AND 20240131
ORDER BY fd.duration_min DESC;
```

**Rows returned:** 102 (showing first 5)

| equipment_name | reason_name                       | category | duration_min | is_planned | comment                   |
|----------------|-----------------------------------|----------|--------------|------------|---------------------------|
| Самосвал-002   | Плановое техническое обслуживание | плановый | 480.00       | True       | Плановое ТО по регламенту |
| ПДМ-001        | Плановое техническое обслуживание | плановый | 480.00       | True       | Плановое ТО по регламенту |
| ПДМ-002        | Плановое техническое обслуживание | плановый | 480.00       | True       | Плановое ТО по регламенту |
| ПДМ-003        | Плановое техническое обслуживание | плановый | 480.00       | True       | Плановое ТО по регламенту |
| ПДМ-004        | Плановое техническое обслуживание | плановый | 480.00       | True       | Плановое ТО по регламенту |

### Q23: 4.5 Соединение трёх уровней «снежинки»: оборудование → тип → шахта → ствол

**Status:** PASS

```sql
SELECT m.mine_name,
       sh.shaft_name,
       sh.shaft_type,
       e.equipment_name,
       et.type_name AS equipment_type
FROM dim_equipment e
INNER JOIN dim_equipment_type et ON e.equipment_type_id = et.equipment_type_id
INNER JOIN dim_mine m            ON e.mine_id = m.mine_id
INNER JOIN dim_shaft sh          ON sh.mine_id = m.mine_id
ORDER BY m.mine_name, sh.shaft_name, e.equipment_name;
```

**Rows returned:** 64 (showing first 5)

| mine_name        | shaft_name      | shaft_type | equipment_name | equipment_type                |
|------------------|-----------------|------------|----------------|-------------------------------|
| Шахта "Северная" | Горизонт -480 м | горизонт   | Вагонетка-001  | Вагонетка                     |
| Шахта "Северная" | Горизонт -480 м | горизонт   | Вагонетка-002  | Вагонетка                     |
| Шахта "Северная" | Горизонт -480 м | горизонт   | ПДМ-001        | Погрузочно-доставочная машина |
| Шахта "Северная" | Горизонт -480 м | горизонт   | ПДМ-002        | Погрузочно-доставочная машина |
| Шахта "Северная" | Горизонт -480 м | горизонт   | ПДМ-003        | Погрузочно-доставочная машина |

### Q24: 5.1 Общая добыча по каждой шахте

**Status:** PASS

```sql
SELECT m.mine_name,
       SUM(fp.tons_mined)        AS total_tons,
       AVG(fp.tons_mined)        AS avg_tons_per_shift,
       COUNT(*)                  AS total_shifts
FROM fact_production fp
INNER JOIN dim_mine m ON fp.mine_id = m.mine_id
GROUP BY m.mine_name;
```

**Rows returned:** 2 (showing first 2)

| mine_name        | total_tons | avg_tons_per_shift   | total_shifts |
|------------------|------------|----------------------|--------------|
| Шахта "Южная"    | 317302.56  | 100.8269971401334604 | 3147         |
| Шахта "Северная" | 549105.75  | 104.8512029788046592 | 5237         |

### Q25: 5.2 Добыча по месяцам за 2024 год

**Status:** PASS

```sql
SELECT d.year_month,
       SUM(fp.tons_mined)  AS total_tons,
       AVG(fp.tons_mined)  AS avg_tons,
       COUNT(*)             AS shifts_count
FROM fact_production fp
INNER JOIN dim_date d ON fp.date_id = d.date_id
WHERE d.year = 2024
GROUP BY d.year_month
ORDER BY d.year_month;
```

**Rows returned:** 12 (showing first 5)

| year_month | total_tons | avg_tons             | shifts_count |
|------------|------------|----------------------|--------------|
| 2024-01    | 43252.34   | 89.7351452282157676  | 482          |
| 2024-02    | 42362.37   | 95.4107432432432432  | 444          |
| 2024-03    | 46194.11   | 97.8688771186440678  | 472          |
| 2024-04    | 49709.33   | 106.6723819742489270 | 466          |
| 2024-05    | 51713.21   | 110.2627078891257996 | 469          |

### Q26: 5.3 Топ-5 операторов по общему объёму добычи

**Status:** PASS

```sql
SELECT op.last_name || ' ' || op.first_name AS operator_name,
       op.position,
       SUM(fp.tons_mined)   AS total_tons,
       AVG(fp.tons_mined)   AS avg_tons,
       COUNT(*)              AS shifts_worked
FROM fact_production fp
INNER JOIN dim_operator op ON fp.operator_id = op.operator_id
GROUP BY op.operator_id, op.last_name, op.first_name, op.position
ORDER BY total_tons DESC
LIMIT 5;
```

**Rows returned:** 5 (showing first 5)

| operator_name    | position           | total_tons | avg_tons             | shifts_worked |
|------------------|--------------------|------------|----------------------|---------------|
| Сидоров Дмитрий  | Машинист самосвала | 163597.73  | 157.7605882352941176 | 1037          |
| Козлов Андрей    | Машинист самосвала | 160573.62  | 152.9272571428571429 | 1050          |
| Волков Николай   | Машинист самосвала | 154572.89  | 147.4932156488549618 | 1048          |
| Новиков Михаил   | Машинист ПДМ       | 82075.95   | 78.3167461832061069  | 1048          |
| Морозов Владимир | Машинист ПДМ       | 80653.72   | 76.7399809705042816  | 1051          |

### Q27: 5.4 Анализ простоев по категориям причин

**Status:** PASS

```sql
SELECT dr.category,
       dr.reason_name,
       COUNT(*)                      AS downtime_count,
       SUM(fd.duration_min)          AS total_minutes,
       ROUND(AVG(fd.duration_min), 1) AS avg_minutes
FROM fact_equipment_downtime fd
INNER JOIN dim_downtime_reason dr ON fd.reason_id = dr.reason_id
GROUP BY dr.category, dr.reason_name
ORDER BY total_minutes DESC;
```

**Rows returned:** 10 (showing first 5)

| category        | reason_name                       | downtime_count | total_minutes | avg_minutes |
|-----------------|-----------------------------------|----------------|---------------|-------------|
| плановый        | Плановое техническое обслуживание | 144            | 69120.00      | 480.0       |
| плановый        | Заправка топливом                 | 1256           | 37680.00      | 30.0        |
| организационный | Ожидание транспорта               | 148            | 15725.23      | 106.3       |
| организационный | Ожидание погрузки                 | 102            | 10327.99      | 101.3       |
| организационный | Отсутствие оператора              | 62             | 7272.02       | 117.3       |

### Q28: 5.5 Среднее содержание Fe по сортам руды

**Status:** PASS

```sql
SELECT og.grade_name,
       COUNT(*)                         AS samples_count,
       ROUND(AVG(fq.fe_content), 2)     AS avg_fe,
       ROUND(MIN(fq.fe_content), 2)     AS min_fe,
       ROUND(MAX(fq.fe_content), 2)     AS max_fe
FROM fact_ore_quality fq
INNER JOIN dim_ore_grade og ON fq.ore_grade_id = og.ore_grade_id
GROUP BY og.grade_name, og.grade_code
ORDER BY og.grade_code;
```

**Rows returned:** 3 (showing first 3)

| grade_name  | samples_count | avg_fe | min_fe | max_fe |
|-------------|---------------|--------|--------|--------|
| Первый сорт | 3891          | 53.01  | 45.03  | 60.00  |
| Второй сорт | 271           | 43.41  | 41.15  | 44.99  |
| Высший сорт | 1163          | 63.31  | 60.02  | 68.94  |

### Q29: 5.6 Добыча по сменам и типам оборудования

**Status:** PASS

```sql
SELECT sh.shift_name,
       et.type_name,
       SUM(fp.tons_mined)           AS total_tons,
       ROUND(AVG(fp.tons_mined), 2) AS avg_tons,
       SUM(fp.trips_count)          AS total_trips
FROM fact_production fp
INNER JOIN dim_shift sh           ON fp.shift_id = sh.shift_id
INNER JOIN dim_equipment e        ON fp.equipment_id = e.equipment_id
INNER JOIN dim_equipment_type et  ON e.equipment_type_id = et.equipment_type_id
GROUP BY sh.shift_name, et.type_name
ORDER BY sh.shift_name, total_tons DESC;
```

**Rows returned:** 4 (showing first 4)

| shift_name    | type_name                     | total_tons | avg_tons | total_trips |
|---------------|-------------------------------|------------|----------|-------------|
| Дневная смена | Шахтный самосвал              | 241723.69  | 152.89   | 8674        |
| Дневная смена | Погрузочно-доставочная машина | 194143.23  | 73.79    | 19710       |
| Ночная смена  | Шахтный самосвал              | 237020.55  | 152.52   | 8467        |
| Ночная смена  | Погрузочно-доставочная машина | 193520.84  | 73.92    | 19546       |

### Q30: 5.7 HAVING: шахты с общей добычей более 50 000 тонн

**Status:** PASS

```sql
SELECT m.mine_name,
       SUM(fp.tons_mined) AS total_tons
FROM fact_production fp
INNER JOIN dim_mine m ON fp.mine_id = m.mine_id
GROUP BY m.mine_name
HAVING SUM(fp.tons_mined) > 50000
ORDER BY total_tons DESC;
```

**Rows returned:** 2 (showing first 2)

| mine_name        | total_tons |
|------------------|------------|
| Шахта "Северная" | 549105.75  |
| Шахта "Южная"    | 317302.56  |

### Q31: 6.1 Сравнение дневной и ночной смены по добыче

**Status:** PASS

```sql
SELECT sh.shift_name,
       COUNT(DISTINCT fp.date_id)   AS work_days,
       COUNT(*)                     AS total_records,
       SUM(fp.tons_mined)           AS total_tons,
       ROUND(AVG(fp.tons_mined), 2) AS avg_tons_per_record,
       SUM(fp.fuel_consumed_l)      AS total_fuel,
       ROUND(SUM(fp.fuel_consumed_l) / NULLIF(SUM(fp.tons_mined), 0), 3) AS fuel_per_ton
FROM fact_production fp
INNER JOIN dim_shift sh ON fp.shift_id = sh.shift_id
GROUP BY sh.shift_name;
```

**Rows returned:** 2 (showing first 2)

| shift_name    | work_days | total_records | total_tons | avg_tons_per_record | total_fuel | fuel_per_ton |
|---------------|-----------|---------------|------------|---------------------|------------|--------------|
| Дневная смена | 547       | 4212          | 435866.92  | 103.48              | 629085.16  | 1.443        |
| Ночная смена  | 547       | 4172          | 430541.39  | 103.20              | 622753.78  | 1.446        |

### Q32: 6.2 Эффективность операторов по сменам

**Status:** PASS

```sql
SELECT op.last_name || ' ' || op.first_name AS operator_name,
       sh.shift_name,
       COUNT(*)                     AS shifts_count,
       ROUND(AVG(fp.tons_mined), 2) AS avg_tons,
       ROUND(AVG(fp.operating_hours), 2) AS avg_hours,
       ROUND(AVG(fp.tons_mined) / NULLIF(AVG(fp.operating_hours), 0), 2) AS tons_per_hour
FROM fact_production fp
INNER JOIN dim_operator op ON fp.operator_id = op.operator_id
INNER JOIN dim_shift sh    ON fp.shift_id = sh.shift_id
GROUP BY op.operator_id, op.last_name, op.first_name, sh.shift_name
ORDER BY tons_per_hour DESC;
```

**Rows returned:** 16 (showing first 5)

| operator_name   | shift_name    | shifts_count | avg_tons | avg_hours | tons_per_hour |
|-----------------|---------------|--------------|----------|-----------|---------------|
| Сидоров Дмитрий | Дневная смена | 525          | 158.89   | 10.74     | 14.80         |
| Сидоров Дмитрий | Ночная смена  | 512          | 156.60   | 10.78     | 14.53         |
| Козлов Андрей   | Ночная смена  | 519          | 153.30   | 10.76     | 14.25         |
| Козлов Андрей   | Дневная смена | 531          | 152.56   | 10.73     | 14.22         |
| Волков Николай  | Ночная смена  | 523          | 147.75   | 10.75     | 13.74         |

---

## Module 4

**File:** `C:\Users\dstrelnikov\Documents\SQL\module_04\examples.sql`

### Q1: 1.1 Приведение типов (CAST и ::)

**Status:** PASS

```sql
SELECT CAST('2024-03-15' AS DATE);
```

**Rows returned:** 1 (showing first 1)

| date       |
|------------|
| 2024-03-15 |

### Q2: 

**Status:** PASS

```sql
SELECT CAST(42 AS TEXT);
```

**Rows returned:** 1 (showing first 1)

| text |
|------|
| 42   |

### Q3: 

**Status:** PASS

```sql
SELECT CAST('123.45' AS NUMERIC(10,2));
```

**Rows returned:** 1 (showing first 1)

| numeric |
|---------|
| 123.45  |

### Q4: Синтаксис PostgreSQL

**Status:** PASS

```sql
SELECT '2024-03-15'::DATE;
```

**Rows returned:** 1 (showing first 1)

| date       |
|------------|
| 2024-03-15 |

### Q5: 

**Status:** PASS

```sql
SELECT 42::TEXT;
```

**Rows returned:** 1 (showing first 1)

| text |
|------|
| 42   |

### Q6: 

**Status:** PASS

```sql
SELECT '123.45'::NUMERIC(10,2);
```

**Rows returned:** 1 (showing first 1)

| numeric |
|---------|
| 123.45  |

### Q7: 1.2 Приведение date_id (INTEGER) в строку

**Status:** PASS

```sql
SELECT 'Отчёт за дату: ' || date_id::TEXT AS report_header
FROM fact_production
LIMIT 5;
```

**Rows returned:** 5 (showing first 5)

| report_header           |
|-------------------------|
| Отчёт за дату: 20240101 |
| Отчёт за дату: 20240101 |
| Отчёт за дату: 20240101 |
| Отчёт за дату: 20240101 |
| Отчёт за дату: 20240101 |

### Q8: 1.3 Определение типа данных выражения

**Status:** PASS

```sql
SELECT pg_typeof(42),
       pg_typeof('hello'),
       pg_typeof(3.14),
       pg_typeof(NOW()),
       pg_typeof(TRUE);
```

**Rows returned:** 1 (showing first 1)

| pg_typeof | pg_typeof | pg_typeof | pg_typeof                | pg_typeof |
|-----------|-----------|-----------|--------------------------|-----------|
| integer   | unknown   | numeric   | timestamp with time zone | boolean   |

### Q9: 2.1 Длина строки

**Status:** PASS

```sql
SELECT equipment_name,
       LENGTH(equipment_name) AS name_length,
       LENGTH(inventory_number) AS inv_length
FROM dim_equipment;
```

**Rows returned:** 18 (showing first 5)

| equipment_name | name_length | inv_length |
|----------------|-------------|------------|
| ПДМ-001        | 7           | 11         |
| ПДМ-002        | 7           | 11         |
| ПДМ-003        | 7           | 11         |
| ПДМ-004        | 7           | 11         |
| ПДМ-005        | 7           | 11         |

### Q10: 2.2 Регистр

**Status:** PASS

```sql
SELECT equipment_name,
       UPPER(equipment_name) AS upper_name,
       LOWER(manufacturer) AS lower_manufacturer,
       INITCAP('погрузочно-доставочная машина') AS initcap_example
FROM dim_equipment;
```

**Rows returned:** 18 (showing first 5)

| equipment_name | upper_name | lower_manufacturer | initcap_example               |
|----------------|------------|--------------------|-------------------------------|
| ПДМ-001        | ПДМ-001    | sandvik            | Погрузочно-Доставочная Машина |
| ПДМ-002        | ПДМ-002    | sandvik            | Погрузочно-Доставочная Машина |
| ПДМ-003        | ПДМ-003    | caterpillar        | Погрузочно-Доставочная Машина |
| ПДМ-004        | ПДМ-004    | sandvik            | Погрузочно-Доставочная Машина |
| ПДМ-005        | ПДМ-005    | caterpillar        | Погрузочно-Доставочная Машина |

### Q11: Оператор ||

**Status:** PASS

```sql
SELECT last_name || ' ' || first_name || ' ' || COALESCE(middle_name, '')
       AS full_name
FROM dim_operator;
```

**Rows returned:** 10 (showing first 5)

| full_name                     |
|-------------------------------|
| Иванов Алексей Петрович       |
| Петров Сергей Николаевич      |
| Сидоров Дмитрий Александрович |
| Козлов Андрей Викторович      |
| Новиков Михаил Сергеевич      |

### Q12: Функция CONCAT (игнорирует NULL)

**Status:** PASS

```sql
SELECT CONCAT(last_name, ' ', first_name, ' ', middle_name) AS full_name
FROM dim_operator;
```

**Rows returned:** 10 (showing first 5)

| full_name                     |
|-------------------------------|
| Иванов Алексей Петрович       |
| Петров Сергей Николаевич      |
| Сидоров Дмитрий Александрович |
| Козлов Андрей Викторович      |
| Новиков Михаил Сергеевич      |

### Q13: CONCAT_WS (с разделителем)

**Status:** PASS

```sql
SELECT CONCAT_WS(' ', last_name, first_name, middle_name) AS full_name
FROM dim_operator;
```

**Rows returned:** 10 (showing first 5)

| full_name                     |
|-------------------------------|
| Иванов Алексей Петрович       |
| Петров Сергей Николаевич      |
| Сидоров Дмитрий Александрович |
| Козлов Андрей Викторович      |
| Новиков Михаил Сергеевич      |

### Q14: 2.4 Подстрока

**Status:** PASS

```sql
SELECT inventory_number,
       SUBSTRING(inventory_number, 1, 3) AS prefix,       -- INV
       SUBSTRING(inventory_number FROM 5 FOR 3) AS type_part -- LHD или TRU
FROM dim_equipment;
```

**Rows returned:** 18 (showing first 5)

| inventory_number | prefix | type_part |
|------------------|--------|-----------|
| INV-LHD-001      | INV    | LHD       |
| INV-LHD-002      | INV    | LHD       |
| INV-LHD-003      | INV    | LHD       |
| INV-LHD-004      | INV    | LHD       |
| INV-LHD-005      | INV    | LHD       |

### Q15: LEFT и RIGHT

**Status:** PASS

```sql
SELECT inventory_number,
       LEFT(inventory_number, 3) AS left_3,
       RIGHT(inventory_number, 3) AS right_3
FROM dim_equipment;
```

**Rows returned:** 18 (showing first 5)

| inventory_number | left_3 | right_3 |
|------------------|--------|---------|
| INV-LHD-001      | INV    | 001     |
| INV-LHD-002      | INV    | 002     |
| INV-LHD-003      | INV    | 003     |
| INV-LHD-004      | INV    | 004     |
| INV-LHD-005      | INV    | 005     |

### Q16: 2.5 Позиция подстроки

**Status:** PASS

```sql
SELECT inventory_number,
       POSITION('-' IN inventory_number) AS first_dash_pos,
       STRPOS(inventory_number, '-') AS strpos_result -- аналог POSITION
FROM dim_equipment;
```

**Rows returned:** 18 (showing first 5)

| inventory_number | first_dash_pos | strpos_result |
|------------------|----------------|---------------|
| INV-LHD-001      | 4              | 4             |
| INV-LHD-002      | 4              | 4             |
| INV-LHD-003      | 4              | 4             |
| INV-LHD-004      | 4              | 4             |
| INV-LHD-005      | 4              | 4             |

### Q17: 2.6 SPLIT_PART — разбор по разделителю

**Status:** PASS

```sql
SELECT inventory_number,
       SPLIT_PART(inventory_number, '-', 1) AS prefix,
       SPLIT_PART(inventory_number, '-', 2) AS type_code,
       SPLIT_PART(inventory_number, '-', 3) AS serial_no,
       CAST(SPLIT_PART(inventory_number, '-', 3) AS INTEGER) AS serial_int
FROM dim_equipment;
```

**Rows returned:** 18 (showing first 5)

| inventory_number | prefix | type_code | serial_no | serial_int |
|------------------|--------|-----------|-----------|------------|
| INV-LHD-001      | INV    | LHD       | 001       | 1          |
| INV-LHD-002      | INV    | LHD       | 002       | 2          |
| INV-LHD-003      | INV    | LHD       | 003       | 3          |
| INV-LHD-004      | INV    | LHD       | 004       | 4          |
| INV-LHD-005      | INV    | LHD       | 005       | 5          |

### Q18: 2.7 TRIM — удаление символов

**Status:** PASS

```sql
SELECT TRIM('   Руда+   ') AS trimmed,
       LTRIM('   Руда+') AS left_trimmed,
       RTRIM('Руда+   ') AS right_trimmed,
       TRIM(BOTH '-' FROM '--INV-LHD-001--') AS dash_trimmed;
```

**Rows returned:** 1 (showing first 1)

| trimmed | left_trimmed | right_trimmed | dash_trimmed |
|---------|--------------|---------------|--------------|
| Руда+   | Руда+        | Руда+         | INV-LHD-001  |

### Q19: 2.8 REPLACE и TRANSLATE

**Status:** PASS

```sql
SELECT inventory_number,
       REPLACE(inventory_number, 'INV', 'EQ') AS replaced,
       TRANSLATE(inventory_number, '-', '/') AS translated
FROM dim_equipment;
```

**Rows returned:** 18 (showing first 5)

| inventory_number | replaced   | translated  |
|------------------|------------|-------------|
| INV-LHD-001      | EQ-LHD-001 | INV/LHD/001 |
| INV-LHD-002      | EQ-LHD-002 | INV/LHD/002 |
| INV-LHD-003      | EQ-LHD-003 | INV/LHD/003 |
| INV-LHD-004      | EQ-LHD-004 | INV/LHD/004 |
| INV-LHD-005      | EQ-LHD-005 | INV/LHD/005 |

### Q20: 2.9 LPAD и RPAD — дополнение символами

**Status:** PASS

```sql
SELECT equipment_id,
       LPAD(equipment_id::TEXT, 5, '0') AS padded_id,
       RPAD(equipment_name, 30, '.') AS padded_name
FROM dim_equipment;
```

**Rows returned:** 18 (showing first 5)

| equipment_id | padded_id | padded_name                    |
|--------------|-----------|--------------------------------|
| 1            | 00001     | ПДМ-001....................... |
| 2            | 00002     | ПДМ-002....................... |
| 3            | 00003     | ПДМ-003....................... |
| 4            | 00004     | ПДМ-004....................... |
| 5            | 00005     | ПДМ-005....................... |

### Q21: 2.10 REPEAT и REVERSE

**Status:** PASS

```sql
SELECT REPEAT('=-', 20) AS separator,
       REVERSE('Руда+') AS reversed;
```

**Rows returned:** 1 (showing first 1)

| separator                                | reversed |
|------------------------------------------|----------|
| =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=- | +адуР    |

### Q22: 2.11 STRING_AGG — агрегация строк

**Status:** PASS

```sql
SELECT m.mine_name,
       STRING_AGG(e.equipment_name, ', ' ORDER BY e.equipment_name)
           AS equipment_list,
       STRING_AGG(DISTINCT e.manufacturer, '; ' ORDER BY e.manufacturer)
           AS manufacturers
FROM dim_equipment e
JOIN dim_mine m ON e.mine_id = m.mine_id
GROUP BY m.mine_name;
```

**Rows returned:** 2 (showing first 2)

| mine_name        | equipment_list                                     | manufacturers                              |
|------------------|----------------------------------------------------|--------------------------------------------|
| Шахта "Северная" | Вагонетка-001, Вагонетка-002, ПДМ-001, ПДМ-002,... | Caterpillar; Sandvik; Siemag Tecberg; НКМЗ |
| Шахта "Южная"    | Вагонетка-003, Вагонетка-004, ПДМ-004, ПДМ-005,... | Caterpillar; Epiroc; Sandvik; НКМЗ         |

### Q23: 2.12 Формирование краткого имени оператора

**Status:** PASS

```sql
SELECT CONCAT(
           last_name, ' ',
           LEFT(first_name, 1), '.',
           CASE
               WHEN middle_name IS NOT NULL
               THEN LEFT(middle_name, 1) || '.'
               ELSE ''
           END
       ) AS short_name
FROM dim_operator;
```

**Rows returned:** 10 (showing first 5)

| short_name   |
|--------------|
| Иванов А.П.  |
| Петров С.Н.  |
| Сидоров Д.А. |
| Козлов А.В.  |
| Новиков М.С. |

### Q24: % = любое количество символов, _ = ровно один символ

**Status:** PASS

```sql
SELECT equipment_name FROM dim_equipment
WHERE equipment_name LIKE 'ПДМ%';
```

**Rows returned:** 6 (showing first 5)

| equipment_name |
|----------------|
| ПДМ-001        |
| ПДМ-002        |
| ПДМ-003        |
| ПДМ-004        |
| ПДМ-005        |

### Q25: 

**Status:** PASS

```sql
SELECT mine_name FROM dim_mine
WHERE mine_name LIKE '%Северная%';
```

**Rows returned:** 1 (showing first 1)

| mine_name        |
|------------------|
| Шахта "Северная" |

### Q26: 

**Status:** PASS

```sql
SELECT inventory_number FROM dim_equipment
WHERE inventory_number LIKE 'INV-___-001';
```

**Rows returned:** 4 (showing first 4)

| inventory_number |
|------------------|
| INV-LHD-001      |
| INV-TRK-001      |
| INV-CRT-001      |
| INV-SKP-001      |

### Q27: 3.2 ILIKE — без учёта регистра (расширение PostgreSQL)

**Status:** PASS

```sql
SELECT mine_name FROM dim_mine
WHERE mine_name ILIKE '%северная%';
```

**Rows returned:** 1 (showing first 1)

| mine_name        |
|------------------|
| Шахта "Северная" |

### Q28: 

**Status:** PASS

```sql
SELECT manufacturer FROM dim_equipment
WHERE manufacturer ILIKE 's%';
```

**Rows returned:** 7 (showing first 5)

| manufacturer |
|--------------|
| Sandvik      |
| Sandvik      |
| Sandvik      |
| Sandvik      |
| Sandvik      |

### Q29: 3.3 SIMILAR TO — SQL-стандарт regex

**Status:** PASS

```sql
SELECT inventory_number, equipment_name
FROM dim_equipment
WHERE inventory_number SIMILAR TO 'INV-(LHD|TRUCK)-%';
```

**Rows returned:** 6 (showing first 5)

| inventory_number | equipment_name |
|------------------|----------------|
| INV-LHD-001      | ПДМ-001        |
| INV-LHD-002      | ПДМ-002        |
| INV-LHD-003      | ПДМ-003        |
| INV-LHD-004      | ПДМ-004        |
| INV-LHD-005      | ПДМ-005        |

### Q30: 

**Status:** PASS

```sql
SELECT type_name FROM dim_equipment_type
WHERE type_name SIMILAR TO '%(машина|самосвал)%';
```

**Rows returned:** 2 (showing first 2)

| type_name                     |
|-------------------------------|
| Погрузочно-доставочная машина |
| Шахтный самосвал              |

### Q31: !~ = не совпадает

**Status:** PASS

```sql
SELECT inventory_number FROM dim_equipment
WHERE inventory_number ~ '^INV-LHD-\d{3}$';
```

**Rows returned:** 6 (showing first 5)

| inventory_number |
|------------------|
| INV-LHD-001      |
| INV-LHD-002      |
| INV-LHD-003      |
| INV-LHD-004      |
| INV-LHD-005      |

### Q32: 3.5 REGEXP_MATCH — извлечение групп

**Status:** PASS

```sql
SELECT inventory_number,
       (REGEXP_MATCH(inventory_number, '^INV-([A-Z]+)-(\d+)$'))[1] AS type_code,
       (REGEXP_MATCH(inventory_number, '^INV-([A-Z]+)-(\d+)$'))[2] AS serial_no
FROM dim_equipment;
```

**Rows returned:** 18 (showing first 5)

| inventory_number | type_code | serial_no |
|------------------|-----------|-----------|
| INV-LHD-001      | LHD       | 001       |
| INV-LHD-002      | LHD       | 002       |
| INV-LHD-003      | LHD       | 003       |
| INV-LHD-004      | LHD       | 004       |
| INV-LHD-005      | LHD       | 005       |

### Q33: 3.6 REGEXP_REPLACE — замена по шаблону

**Status:** PASS

```sql
SELECT comment,
       REGEXP_REPLACE(comment, '\s+', ' ', 'g') AS normalized
FROM fact_equipment_downtime
WHERE comment IS NOT NULL
LIMIT 5;
```

**Rows returned:** 5 (showing first 5)

| comment                   | normalized                |
|---------------------------|---------------------------|
| Плановое ТО по регламенту | Плановое ТО по регламенту |
| Плановое ТО по регламенту | Плановое ТО по регламенту |
| Плановое ТО по регламенту | Плановое ТО по регламенту |
| Плановое ТО по регламенту | Плановое ТО по регламенту |
| Плановое ТО по регламенту | Плановое ТО по регламенту |

### Q34: 4.1 Текущая дата и время

**Status:** PASS

```sql
SELECT CURRENT_DATE        AS today,
       CURRENT_TIME        AS now_time,
       NOW()               AS now_timestamp,
       CURRENT_TIMESTAMP(0) AS now_no_frac;
```

**Rows returned:** 1 (showing first 1)

| today      | now_time              | now_timestamp                    | now_no_frac               |
|------------|-----------------------|----------------------------------|---------------------------|
| 2026-03-19 | 21:10:52.983779+03:00 | 2026-03-19 21:10:52.983779+03:00 | 2026-03-19 21:10:53+03:00 |

### Q35: 4.2 EXTRACT — извлечение компонентов

**Status:** PASS

```sql
SELECT equipment_name,
       commissioning_date,
       EXTRACT(YEAR    FROM commissioning_date) AS comm_year,
       EXTRACT(MONTH   FROM commissioning_date) AS comm_month,
       EXTRACT(DAY     FROM commissioning_date) AS comm_day,
       EXTRACT(DOW     FROM commissioning_date) AS day_of_week,   -- 0=Вс, 1=Пн..6=Сб
       EXTRACT(QUARTER FROM commissioning_date) AS comm_quarter,
       EXTRACT(WEEK    FROM commissioning_date) AS comm_week,
       EXTRACT(DOY     FROM commissioning_date) AS day_of_year
FROM dim_equipment
WHERE commissioning_date IS NOT NULL;
```

**Rows returned:** 18 (showing first 5)

| equipment_name | commissioning_date | comm_year | comm_month | comm_day | day_of_week | comm_quarter | comm_week | day_of_year |
|----------------|--------------------|-----------|------------|----------|-------------|--------------|-----------|-------------|
| ПДМ-001        | 2019-08-15         | 2019      | 8          | 15       | 4           | 3            | 33        | 227         |
| ПДМ-002        | 2020-03-10         | 2020      | 3          | 10       | 2           | 1            | 11        | 70          |
| ПДМ-003        | 2018-11-20         | 2018      | 11         | 20       | 2           | 4            | 47        | 324         |
| ПДМ-004        | 2021-05-01         | 2021      | 5          | 1        | 6           | 2            | 17        | 121         |
| ПДМ-005        | 2017-09-12         | 2017      | 9          | 12       | 2           | 3            | 37        | 255         |

### Q36: Усечение до месяца

**Status:** PASS

```sql
SELECT DATE_TRUNC('month', d.full_date) AS month_start,
       SUM(fp.tons_mined) AS total_tons,
       COUNT(*) AS records
FROM fact_production fp
JOIN dim_date d ON fp.date_id = d.date_id
WHERE d.year = 2024
GROUP BY DATE_TRUNC('month', d.full_date)
ORDER BY month_start;
```

**Rows returned:** 12 (showing first 5)

| month_start               | total_tons | records |
|---------------------------|------------|---------|
| 2024-01-01 00:00:00+03:00 | 43252.34   | 482     |
| 2024-02-01 00:00:00+03:00 | 42362.37   | 444     |
| 2024-03-01 00:00:00+03:00 | 46194.11   | 472     |
| 2024-04-01 00:00:00+03:00 | 49709.33   | 466     |
| 2024-05-01 00:00:00+03:00 | 51713.21   | 469     |

### Q37: Усечение временных меток до часа

**Status:** PASS

```sql
SELECT DATE_TRUNC('hour', start_time) AS hour_bucket,
       COUNT(*) AS downtime_count
FROM fact_equipment_downtime
GROUP BY DATE_TRUNC('hour', start_time)
ORDER BY downtime_count DESC
LIMIT 10;
```

**Rows returned:** 10 (showing first 5)

| hour_bucket         | downtime_count |
|---------------------|----------------|
| 2024-10-15 08:00:00 | 10             |
| 2024-04-18 12:00:00 | 10             |
| 2024-05-21 12:00:00 | 9              |
| 2025-01-13 12:00:00 | 9              |
| 2024-05-06 12:00:00 | 9              |

### Q38: Дата +/- интервал

**Status:** PASS

```sql
SELECT CURRENT_DATE + INTERVAL '30 days'  AS in_30_days,
       CURRENT_DATE - INTERVAL '1 year'   AS year_ago,
       CURRENT_DATE + INTERVAL '2 months' AS in_2_months;
```

**Rows returned:** 1 (showing first 1)

| in_30_days          | year_ago            | in_2_months         |
|---------------------|---------------------|---------------------|
| 2026-04-18 00:00:00 | 2025-03-19 00:00:00 | 2026-05-19 00:00:00 |

### Q39: Дата следующего ТО (каждые 90 дней)

**Status:** PASS

```sql
SELECT equipment_name,
       commissioning_date,
       commissioning_date + INTERVAL '90 days'  AS first_to,
       commissioning_date + INTERVAL '180 days' AS second_to,
       commissioning_date + INTERVAL '365 days' AS annual_to
FROM dim_equipment
WHERE commissioning_date IS NOT NULL;
```

**Rows returned:** 18 (showing first 5)

| equipment_name | commissioning_date | first_to            | second_to           | annual_to           |
|----------------|--------------------|---------------------|---------------------|---------------------|
| ПДМ-001        | 2019-08-15         | 2019-11-13 00:00:00 | 2020-02-11 00:00:00 | 2020-08-14 00:00:00 |
| ПДМ-002        | 2020-03-10         | 2020-06-08 00:00:00 | 2020-09-06 00:00:00 | 2021-03-10 00:00:00 |
| ПДМ-003        | 2018-11-20         | 2019-02-18 00:00:00 | 2019-05-19 00:00:00 | 2019-11-20 00:00:00 |
| ПДМ-004        | 2021-05-01         | 2021-07-30 00:00:00 | 2021-10-28 00:00:00 | 2022-05-01 00:00:00 |
| ПДМ-005        | 2017-09-12         | 2017-12-11 00:00:00 | 2018-03-11 00:00:00 | 2018-09-12 00:00:00 |

### Q40: 4.5 Разница дат

**Status:** PASS

```sql
SELECT equipment_name,
       commissioning_date,
       CURRENT_DATE - commissioning_date AS days_in_service,
       AGE(CURRENT_DATE, commissioning_date) AS age_full
FROM dim_equipment
WHERE commissioning_date IS NOT NULL
ORDER BY days_in_service DESC;
```

**Rows returned:** 18 (showing first 5)

| equipment_name | commissioning_date | days_in_service | age_full           |
|----------------|--------------------|-----------------|--------------------|
| Скип-001       | 2010-09-01         | 5678            | 5673 days, 0:00:00 |
| Скип-003       | 2012-11-15         | 4872            | 4869 days, 0:00:00 |
| Скип-002       | 2015-04-10         | 3996            | 3989 days, 0:00:00 |
| Вагонетка-001  | 2016-03-20         | 3651            | 3645 days, 0:00:00 |
| Вагонетка-002  | 2016-03-20         | 3651            | 3645 days, 0:00:00 |

### Q41: 4.6 EXTRACT(EPOCH ...) — разница в секундах/минутах

**Status:** PASS

```sql
SELECT e.equipment_name,
       dt.start_time,
       dt.end_time,
       EXTRACT(EPOCH FROM (dt.end_time - dt.start_time)) AS diff_seconds,
       ROUND(EXTRACT(EPOCH FROM (dt.end_time - dt.start_time)) / 60, 1)
           AS diff_minutes,
       dt.duration_min
FROM fact_equipment_downtime dt
JOIN dim_equipment e ON dt.equipment_id = e.equipment_id
WHERE dt.end_time IS NOT NULL
ORDER BY diff_minutes DESC
LIMIT 10;
```

**Rows returned:** 10 (showing first 5)

| equipment_name | start_time          | end_time            | diff_seconds | diff_minutes | duration_min |
|----------------|---------------------|---------------------|--------------|--------------|--------------|
| Самосвал-001   | 2025-02-10 09:00:00 | 2025-02-10 21:00:00 | 43200.000000 | 720.0        | 720.00       |
| Самосвал-004   | 2024-05-30 22:00:00 | 2024-05-31 10:00:00 | 43200.000000 | 720.0        | 720.00       |
| ПДМ-004        | 2024-07-18 20:30:00 | 2024-07-19 08:00:00 | 41400.000000 | 690.0        | 690.00       |
| ПДМ-004        | 2025-06-24 08:00:00 | 2025-06-24 18:34:00 | 38040.000000 | 634.0        | 37.25        |
| ПДМ-002        | 2024-03-19 08:00:00 | 2024-03-19 18:14:00 | 36840.000000 | 614.0        | 109.72       |

### Q42: 4.7 TO_CHAR — форматирование дат

**Status:** PASS

```sql
SELECT equipment_name,
       commissioning_date,
       TO_CHAR(commissioning_date, 'DD.MM.YYYY')      AS russian_format,
       TO_CHAR(commissioning_date, 'DD Month YYYY')    AS full_month,
       TO_CHAR(commissioning_date, 'YYYY-"Q"Q')        AS year_quarter,
       TO_CHAR(commissioning_date, 'Day')               AS day_name,
       TO_CHAR(commissioning_date, 'YYYY-MM')           AS year_month,
       TO_CHAR(commissioning_date, 'HH24:MI:SS')        AS time_part
FROM dim_equipment
WHERE commissioning_date IS NOT NULL;
```

**Rows returned:** 18 (showing first 5)

| equipment_name | commissioning_date | russian_format | full_month        | year_quarter | day_name  | year_month | time_part |
|----------------|--------------------|----------------|-------------------|--------------|-----------|------------|-----------|
| ПДМ-001        | 2019-08-15         | 15.08.2019     | 15 August    2019 | 2019-Q3      | Thursday  | 2019-08    | 00:00:00  |
| ПДМ-002        | 2020-03-10         | 10.03.2020     | 10 March     2020 | 2020-Q1      | Tuesday   | 2020-03    | 00:00:00  |
| ПДМ-003        | 2018-11-20         | 20.11.2018     | 20 November  2018 | 2018-Q4      | Tuesday   | 2018-11    | 00:00:00  |
| ПДМ-004        | 2021-05-01         | 01.05.2021     | 01 May       2021 | 2021-Q2      | Saturday  | 2021-05    | 00:00:00  |
| ПДМ-005        | 2017-09-12         | 12.09.2017     | 12 September 2017 | 2017-Q3      | Tuesday   | 2017-09    | 00:00:00  |

### Q43: 4.8 TO_DATE и TO_TIMESTAMP — парсинг строк

**Status:** PASS

```sql
SELECT TO_DATE('15.03.2024', 'DD.MM.YYYY') AS parsed_date;
```

**Rows returned:** 1 (showing first 1)

| parsed_date |
|-------------|
| 2024-03-15  |

### Q44: 

**Status:** PASS

```sql
SELECT TO_TIMESTAMP('15-03-2024 14:30', 'DD-MM-YYYY HH24:MI') AS parsed_ts;
```

**Rows returned:** 1 (showing first 1)

| parsed_ts                 |
|---------------------------|
| 2024-03-15 14:30:00+03:00 |

### Q45: Парсинг date_id (INTEGER → DATE)

**Status:** PASS

```sql
SELECT date_id,
       TO_DATE(date_id::TEXT, 'YYYYMMDD') AS parsed_date
FROM dim_date
WHERE year = 2024 AND month = 1
LIMIT 5;
```

**Rows returned:** 5 (showing first 5)

| date_id  | parsed_date |
|----------|-------------|
| 20240109 | 2024-01-09  |
| 20240110 | 2024-01-10  |
| 20240111 | 2024-01-11  |
| 20240112 | 2024-01-12  |
| 20240113 | 2024-01-13  |

### Q46: 5.1 Карточка оборудования

**Status:** PASS

```sql
SELECT CONCAT(
           '[', et.type_name, '] ',
           e.equipment_name,
           ' (', e.manufacturer, ' ', e.model, ')',
           ' | Шахта: ', m.mine_name,
           ' | Введён: ', TO_CHAR(e.commissioning_date, 'DD.MM.YYYY'),
           ' | Возраст: ',
               EXTRACT(YEAR FROM AGE(CURRENT_DATE, e.commissioning_date))::INT,
               ' лет',
           ' | Статус: ',
               CASE e.status
                   WHEN 'active' THEN 'АКТИВЕН'
-- ... (truncated)
```

**Rows returned:** 18 (showing first 5)

| equipment_card                                     |
|----------------------------------------------------|
| [Погрузочно-доставочная машина] ПДМ-006 (Epiroc... |
| [Погрузочно-доставочная машина] ПДМ-005 (Caterp... |
| [Погрузочно-доставочная машина] ПДМ-004 (Sandvi... |
| [Погрузочно-доставочная машина] ПДМ-003 (Caterp... |
| [Погрузочно-доставочная машина] ПДМ-002 (Sandvi... |

### Q47: 5.2 Анализ простоев по дню недели

**Status:** PASS

```sql
SELECT
    CASE EXTRACT(DOW FROM dt.start_time)
        WHEN 0 THEN 'Воскресенье'
        WHEN 1 THEN 'Понедельник'
        WHEN 2 THEN 'Вторник'
        WHEN 3 THEN 'Среда'
        WHEN 4 THEN 'Четверг'
        WHEN 5 THEN 'Пятница'
        WHEN 6 THEN 'Суббота'
    END AS day_name,
    COUNT(*) AS downtime_count,
    ROUND(AVG(dt.duration_min), 1) AS avg_duration_min,
-- ... (truncated)
```

**Rows returned:** 7 (showing first 5)

| day_name    | downtime_count | avg_duration_min | total_duration_min |
|-------------|----------------|------------------|--------------------|
| Воскресенье | 25             | 480.0            | 12000.0            |
| Понедельник | 310            | 88.2             | 27339.7            |
| Вторник     | 287            | 74.2             | 21296.2            |
| Среда       | 284            | 69.6             | 19779.0            |
| Четверг     | 301            | 89.2             | 26840.9            |

### Q48: 5.3 График калибровки датчиков

**Status:** PASS

```sql
SELECT s.sensor_code,
       st.type_name AS sensor_type,
       e.equipment_name,
       s.calibration_date,
       s.calibration_date + INTERVAL '180 days' AS next_calibration,
       CURRENT_DATE - s.calibration_date AS days_since_calibration,
       CASE
           WHEN CURRENT_DATE - s.calibration_date > 180 THEN 'Просрочена'
           WHEN CURRENT_DATE - s.calibration_date > 150 THEN 'Скоро'
           ELSE 'В норме'
       END AS calibration_status
FROM dim_sensor s
-- ... (truncated)
```

**Rows returned:** 43 (showing first 5)

| sensor_code   | sensor_type                  | equipment_name | calibration_date | next_calibration    | days_since_calibration | calibration_status |
|---------------|------------------------------|----------------|------------------|---------------------|------------------------|--------------------|
| S-SKP001-TEMP | Датчик температуры двигателя | Скип-001       | 2024-04-01       | 2024-09-28 00:00:00 | 717                    | Просрочена         |
| S-SKP001-RPM  | Датчик оборотов двигателя    | Скип-001       | 2024-04-01       | 2024-09-28 00:00:00 | 717                    | Просрочена         |
| S-SKP001-LOAD | Датчик массы груза           | Скип-001       | 2024-04-01       | 2024-09-28 00:00:00 | 717                    | Просрочена         |
| S-SKP001-VIB  | Датчик вибрации              | Скип-001       | 2024-04-01       | 2024-09-28 00:00:00 | 717                    | Просрочена         |
| S-SKP003-LOAD | Датчик массы груза           | Скип-003       | 2024-05-01       | 2024-10-28 00:00:00 | 687                    | Просрочена         |

### Q49: 5.4 Проверка качества данных: формат инвентарного номера

**Status:** PASS

```sql
SELECT inventory_number,
       CASE
           WHEN inventory_number ~ '^INV-[A-Z]+-\d{3}$'
           THEN 'Корректный'
           ELSE 'ОШИБКА ФОРМАТА'
       END AS format_check,
       CASE
           WHEN commissioning_date IS NULL THEN 'Нет даты ввода'
           WHEN EXTRACT(YEAR FROM commissioning_date) < year_manufactured
           THEN 'Дата ввода раньше года выпуска!'
           WHEN commissioning_date > CURRENT_DATE
           THEN 'Дата в будущем!'
           ELSE 'OK'
       END AS date_check
FROM dim_equipment;
```

**Rows returned:** 18 (showing first 5)

| inventory_number | format_check | date_check |
|------------------|--------------|------------|
| INV-LHD-001      | Корректный   | OK         |
| INV-LHD-002      | Корректный   | OK         |
| INV-LHD-003      | Корректный   | OK         |
| INV-LHD-004      | Корректный   | OK         |
| INV-LHD-005      | Корректный   | OK         |

---

## Module 5

**File:** `C:\Users\dstrelnikov\Documents\SQL\module_05\examples.sql`

### Q1: Добавить новую причину простоя

**Status:** SKIP (DML/DDL)

```sql
INSERT INTO practice_dim_downtime_reason (
    reason_id, reason_name, reason_code, category, description
)
VALUES (
    100,
    'Замена конвейерной ленты',
    'CONV_BELT',
    'плановый',
    'Плановая замена изношенной конвейерной ленты'
);
```

### Q2: Проверяем результат

**Status:** FAIL

```sql
SELECT * FROM practice_dim_downtime_reason
WHERE reason_code = 'CONV_BELT';
```

**Error:** `relation "practice_dim_downtime_reason" does not exist
LINE 1: SELECT * FROM practice_dim_downtime_reason
                      ^
`

### Q3: Добавить новые сорта руды

**Status:** SKIP (DML/DDL)

```sql
INSERT INTO practice_dim_ore_grade (
    ore_grade_id, grade_name, grade_code,
    fe_content_min, fe_content_max, description
)
VALUES
    (100, 'Премиум',      'PREM', 65.00, 72.00, 'Руда высшего качества'),
    (101, 'Стандарт',     'STD2', 55.00, 64.99, 'Руда стандартного качества'),
    (102, 'Низкосортная', 'LOW2', 40.00, 54.99, 'Руда пониженного качества');
```

### Q4: Проверяем

**Status:** FAIL

```sql
SELECT * FROM practice_dim_ore_grade
ORDER BY ore_grade_id;
```

**Error:** `relation "practice_dim_ore_grade" does not exist
LINE 1: SELECT * FROM practice_dim_ore_grade
                      ^
`

### Q5: Скопировать валидированные записи из staging в факт-таблицу

**Status:** SKIP (DML/DDL)

```sql
INSERT INTO practice_fact_production (
    production_id, date_id, shift_id, mine_id, shaft_id,
    equipment_id, operator_id, location_id, ore_grade_id,
    tons_mined, tons_transported, trips_count,
    distance_km, fuel_consumed_l, operating_hours
)
SELECT
    1000 + staging_id,  -- генерация ID
    date_id, shift_id, mine_id, shaft_id,
    equipment_id, operator_id, location_id, ore_grade_id,
    tons_mined, tons_transported, trips_count,
    distance_km, fuel_consumed_l, operating_hours
FROM staging_production
WHERE is_validated = TRUE;
```

### Q6: Проверяем: должно появиться 4 новых записи (5-я невалидирована)

**Status:** FAIL

```sql
SELECT COUNT(*) AS total_rows,
       COUNT(*) FILTER (WHERE date_id = 20240320) AS new_rows
FROM practice_fact_production;
```

**Error:** `relation "practice_fact_production" does not exist
LINE 3: FROM practice_fact_production;
             ^
`

### Q7: Вставка с использованием значений по умолчанию

**Status:** SKIP (DML/DDL)

```sql
INSERT INTO practice_dim_equipment (
    equipment_id, equipment_type_id, mine_id,
    equipment_name, inventory_number
    -- status не указан → будет 'active' (DEFAULT)
    -- has_video_recorder → FALSE (DEFAULT)
    -- has_navigation → FALSE (DEFAULT)
)
VALUES (
    100, 1, 1, 'ПДМ-21 «Новая»', 'INV-LHD-021'
);
```

### Q8: 

**Status:** FAIL

```sql
SELECT equipment_id, equipment_name, status,
       has_video_recorder, has_navigation
FROM practice_dim_equipment
WHERE equipment_id = 100;
```

**Error:** `relation "practice_dim_equipment" does not exist
LINE 3: FROM practice_dim_equipment
             ^
`

### Q9: Вставить оператора и получить присвоенный ID

**Status:** SKIP (DML/DDL)

```sql
INSERT INTO practice_dim_operator (
    operator_id, tab_number, last_name, first_name, middle_name,
    position, qualification, hire_date, mine_id
)
VALUES (
    100, 'TAB-042', 'Козлов', 'Андрей', 'Петрович',
    'Машинист ПДМ', '5 разряд', '2025-01-15', 1
)
RETURNING operator_id, tab_number, last_name, first_name;
```

### Q10: Перевести оборудование с ID=5 на техобслуживание

**Status:** SKIP (DML/DDL)

```sql
UPDATE practice_dim_equipment
SET status = 'maintenance'
WHERE equipment_id = 5;
```

### Q11: Проверяем

**Status:** FAIL

```sql
SELECT equipment_id, equipment_name, status
FROM practice_dim_equipment
WHERE equipment_id = 5;
```

**Error:** `relation "practice_dim_equipment" does not exist
LINE 2: FROM practice_dim_equipment
             ^
`

### Q12: Обновить оборудование: установить навигацию и видеорегистратор

**Status:** SKIP (DML/DDL)

```sql
UPDATE practice_dim_equipment
SET has_navigation = TRUE,
    has_video_recorder = TRUE
WHERE equipment_id IN (1, 2, 3)
  AND has_navigation = FALSE;
```

### Q13: Перевести в 'maintenance' оборудование с внеплановыми простоями > 120 мин

**Status:** SKIP (DML/DDL)

```sql
UPDATE practice_dim_equipment
SET status = 'maintenance'
WHERE equipment_id IN (
    SELECT DISTINCT d.equipment_id
    FROM practice_fact_downtime d
    WHERE d.is_planned = FALSE
      AND d.duration_min > 120
);
```

### Q14: Смотрим, какое оборудование затронуто

**Status:** FAIL

```sql
SELECT equipment_id, equipment_name, status
FROM practice_dim_equipment
WHERE status = 'maintenance';
```

**Error:** `relation "practice_dim_equipment" does not exist
LINE 2: FROM practice_dim_equipment
             ^
`

### Q15: Обновить статусы оборудования из staging-таблицы

**Status:** SKIP (DML/DDL)

```sql
UPDATE practice_dim_equipment e
SET status = s.new_status
FROM staging_equipment_status s
WHERE e.inventory_number = s.inventory_number
  AND s.new_status IS NOT NULL
  AND e.status != s.new_status;
```

### Q16: Обновить и вернуть изменённые строки

**Status:** SKIP (DML/DDL)

```sql
UPDATE practice_dim_equipment
SET status = 'active'
WHERE status = 'maintenance'
  AND equipment_id <= 5
RETURNING equipment_id, equipment_name, status AS new_status;
```

### Q17: Удалить ошибочные записи телеметрии

**Status:** SKIP (DML/DDL)

```sql
DELETE FROM practice_fact_telemetry
WHERE quality_flag = 'ERROR';
```

### Q18: Удалить записи о добыче за выходные дни

**Status:** SKIP (DML/DDL)

```sql
DELETE FROM practice_fact_production
WHERE date_id IN (
    SELECT date_id
    FROM dim_date
    WHERE is_weekend = TRUE
      AND year = 2024
      AND month = 3
);
```

### Q19: Удалить телеметрию от неисправных датчиков

**Status:** SKIP (DML/DDL)

```sql
DELETE FROM practice_fact_telemetry t
USING dim_sensor s
WHERE t.sensor_id = s.sensor_id
  AND s.status = 'faulty';
```

### Q20: Удалить и сохранить удалённые записи для аудита

**Status:** SKIP (DML/DDL)

```sql
DELETE FROM practice_fact_telemetry
WHERE date_id = 20240315
  AND is_alarm = TRUE
RETURNING telemetry_id, equipment_id, sensor_id, sensor_value;
```

### Q21: 3.5 Архивирование через CTE + DELETE ... RETURNING

**Status:** SKIP (DML/DDL)

```sql
WITH deleted AS (
    DELETE FROM practice_fact_telemetry
    WHERE quality_flag = 'ERROR'
    RETURNING *
)
INSERT INTO practice_archive_telemetry (
    telemetry_id, date_id, time_id, equipment_id, sensor_id,
    location_id, sensor_value, is_alarm, quality_flag, loaded_at
)
SELECT telemetry_id, date_id, time_id, equipment_id, sensor_id,
       location_id, sensor_value, is_alarm, quality_flag, loaded_at
FROM deleted;
```

### Q22: 4.1 MERGE: синхронизация справочника причин простоев

**Status:** SKIP (DML/DDL)

```sql
MERGE INTO practice_dim_downtime_reason AS target
USING staging_downtime_reasons AS source
    ON target.reason_code = source.reason_code
WHEN MATCHED THEN
    UPDATE SET
        reason_name = source.reason_name,
        category    = source.category,
        description = source.description
WHEN NOT MATCHED THEN
    INSERT (reason_id, reason_name, reason_code, category, description)
    VALUES (
        (SELECT COALESCE(MAX(reason_id), 0) + 1
-- ... (truncated)
```

### Q23: Проверяем результат

**Status:** FAIL

```sql
SELECT * FROM practice_dim_downtime_reason
ORDER BY reason_id;
```

**Error:** `relation "practice_dim_downtime_reason" does not exist
LINE 1: SELECT * FROM practice_dim_downtime_reason
                      ^
`

### Q24: 4.2 MERGE: загрузка телеметрии с обработкой дубликатов

**Status:** SKIP (DML/DDL)

```sql
MERGE INTO practice_fact_telemetry AS target
USING (
    SELECT date_id, time_id, equipment_id, sensor_id,
           location_id, sensor_value, is_alarm, quality_flag
    FROM staging_telemetry
    WHERE quality_flag = 'OK'  -- только валидные данные
) AS source
ON target.date_id = source.date_id
   AND target.time_id = source.time_id
   AND target.equipment_id = source.equipment_id
   AND target.sensor_id = source.sensor_id
WHEN MATCHED THEN
-- ... (truncated)
```

### Q25: Добавить оператора; если табельный номер уже есть — пропустить

**Status:** SKIP (DML/DDL)

```sql
INSERT INTO practice_dim_operator (
    operator_id, tab_number, last_name, first_name,
    middle_name, position, qualification, hire_date, mine_id
)
VALUES (
    101, 'TAB-001', 'Дубликат', 'Тест', 'Тестович',
    'Тест', '1 разряд', '2025-01-01', 1
)
ON CONFLICT (tab_number) DO NOTHING;
```

### Q26: Проверяем: оператор с TAB-001 не изменился

**Status:** FAIL

```sql
SELECT * FROM practice_dim_operator WHERE tab_number = 'TAB-001';
```

**Error:** `relation "practice_dim_operator" does not exist
LINE 1: SELECT * FROM practice_dim_operator WHERE tab_number = 'TAB-...
                      ^
`

### Q27: Добавить или обновить сорт руды

**Status:** SKIP (DML/DDL)

```sql
INSERT INTO practice_dim_ore_grade (
    ore_grade_id, grade_name, grade_code,
    fe_content_min, fe_content_max, description
)
VALUES (
    100, 'Премиум-2025', 'PREM', 66.00, 73.00,
    'Обновлённый стандарт качества 2025 года'
)
ON CONFLICT (grade_code) DO UPDATE SET
    grade_name     = EXCLUDED.grade_name,
    fe_content_min = EXCLUDED.fe_content_min,
    fe_content_max = EXCLUDED.fe_content_max,
    description    = EXCLUDED.description;
```

### Q28: Проверяем: значения обновились

**Status:** FAIL

```sql
SELECT * FROM practice_dim_ore_grade WHERE grade_code = 'PREM';
```

**Error:** `relation "practice_dim_ore_grade" does not exist
LINE 1: SELECT * FROM practice_dim_ore_grade WHERE grade_code = 'PRE...
                      ^
`

### Q29: 6.1 Успешная транзакция

**Status:** SKIP (DML/DDL)

```sql
BEGIN;
INSERT INTO practice_equipment_log (equipment_id, action, new_status, details)
VALUES (1, 'UPDATE', 'maintenance', 'Плановое ТО');
UPDATE practice_dim_equipment
SET status = 'maintenance'
WHERE equipment_id = 1;
COMMIT;
```

### Q30: 6.2 Откат транзакции

**Status:** SKIP (DML/DDL)

```sql
BEGIN;
-- Ошибочное удаление
DELETE FROM practice_dim_equipment
WHERE mine_id = 1;
-- Ой! Не то удалили! Откатываем.
ROLLBACK;
```

### Q31: Проверяем: данные на месте

**Status:** FAIL

```sql
SELECT COUNT(*) FROM practice_dim_equipment WHERE mine_id = 1;
```

**Error:** `relation "practice_dim_equipment" does not exist
LINE 1: SELECT COUNT(*) FROM practice_dim_equipment WHERE mine_id = ...
                             ^
`

### Q32: 7. Комплексный ETL-пример

**Status:** SKIP (DML/DDL)

```sql
BEGIN;
-- Шаг 1: Загрузить новые записи о добыче
INSERT INTO practice_fact_production (
    production_id, date_id, shift_id, mine_id, shaft_id,
    equipment_id, operator_id, location_id, ore_grade_id,
    tons_mined, tons_transported, trips_count,
    distance_km, fuel_consumed_l, operating_hours
)
SELECT
    2000 + staging_id,
    date_id, shift_id, mine_id, shaft_id,
    equipment_id, operator_id, location_id, ore_grade_id,
-- ... (truncated)
```

### Q33: Проверяем лог

**Status:** FAIL

```sql
SELECT * FROM practice_equipment_log ORDER BY log_id;
```

**Error:** `relation "practice_equipment_log" does not exist
LINE 1: SELECT * FROM practice_equipment_log ORDER BY log_id;
                      ^
`

---

## Module 6

**File:** `C:\Users\dstrelnikov\Documents\SQL\module_06\examples.sql`

### Q1: 1.1 ROUND — округление содержания Fe до 1 знака

**Status:** PASS

```sql
SELECT
    sample_number,
    fe_content,
    ROUND(fe_content, 1) AS fe_round_1,
    ROUND(fe_content, 0) AS fe_round_0
FROM fact_ore_quality
WHERE date_id = 20240315
ORDER BY fe_content DESC
LIMIT 5;
```

**Rows returned:** 5 (showing first 5)

| sample_number        | fe_content | fe_round_1 | fe_round_0 |
|----------------------|------------|------------|------------|
| PRB-20240315-N480-N2 | 59.25      | 59.3       | 59         |
| PRB-20240315-N480-N1 | 59.25      | 59.3       | 59         |
| PRB-20240315-N620-1  | 58.37      | 58.4       | 58         |
| PRB-20240315-N620-2  | 58.37      | 58.4       | 58         |
| PRB-20240315-N620-3  | 58.37      | 58.4       | 58         |

### Q2: 1.2 CEIL / FLOOR — округление вверх и вниз

**Status:** PASS

```sql
SELECT
    sample_number,
    fe_content,
    CEIL(fe_content)  AS fe_ceil,
    FLOOR(fe_content) AS fe_floor
FROM fact_ore_quality
WHERE date_id = 20240315
LIMIT 5;
```

**Rows returned:** 5 (showing first 5)

| sample_number       | fe_content | fe_ceil | fe_floor |
|---------------------|------------|---------|----------|
| PRB-20240315-N480-1 | 46.58      | 47      | 46       |
| PRB-20240315-N480-2 | 46.58      | 47      | 46       |
| PRB-20240315-N480-3 | 46.58      | 47      | 46       |
| PRB-20240315-N620-1 | 58.37      | 59      | 58       |
| PRB-20240315-N620-2 | 58.37      | 59      | 58       |

### Q3: 1.3 TRUNC — отсечение (без округления)

**Status:** PASS

```sql
SELECT
    sample_number,
    fe_content,
    TRUNC(fe_content, 1) AS fe_trunc_1,
    TRUNC(fe_content, 0) AS fe_trunc_0
FROM fact_ore_quality
WHERE date_id = 20240315
LIMIT 5;
```

**Rows returned:** 5 (showing first 5)

| sample_number       | fe_content | fe_trunc_1 | fe_trunc_0 |
|---------------------|------------|------------|------------|
| PRB-20240315-N480-1 | 46.58      | 46.5       | 46         |
| PRB-20240315-N480-2 | 46.58      | 46.5       | 46         |
| PRB-20240315-N480-3 | 46.58      | 46.5       | 46         |
| PRB-20240315-N620-1 | 58.37      | 58.3       | 58         |
| PRB-20240315-N620-2 | 58.37      | 58.3       | 58         |

### Q4: 1.4 ABS — абсолютное отклонение от целевого Fe (60%)

**Status:** PASS

```sql
SELECT
    sample_number,
    fe_content,
    fe_content - 60.0           AS deviation,
    ABS(fe_content - 60.0)      AS abs_deviation
FROM fact_ore_quality
WHERE date_id BETWEEN 20240301 AND 20240331
ORDER BY abs_deviation DESC
LIMIT 10;
```

**Rows returned:** 10 (showing first 5)

| sample_number       | fe_content | deviation | abs_deviation |
|---------------------|------------|-----------|---------------|
| PRB-20240304-S420-2 | 42.73      | -17.27    | 17.27         |
| PRB-20240304-S420-3 | 42.73      | -17.27    | 17.27         |
| PRB-20240304-S420-1 | 42.73      | -17.27    | 17.27         |
| PRB-20240322-N620-3 | 44.37      | -15.63    | 15.63         |
| PRB-20240322-N620-1 | 44.37      | -15.63    | 15.63         |

### Q5: 1.5 POWER и SQRT — квадрат отклонения и корень

**Status:** PASS

```sql
SELECT
    sample_number,
    fe_content,
    POWER(fe_content - 60.0, 2)         AS squared_dev,
    SQRT(POWER(fe_content - 60.0, 2))   AS sqrt_squared_dev
FROM fact_ore_quality
WHERE date_id = 20240315;
```

**Rows returned:** 13 (showing first 5)

| sample_number       | fe_content | squared_dev        | sqrt_squared_dev   |
|---------------------|------------|--------------------|--------------------|
| PRB-20240315-N480-1 | 46.58      | 180.09640000000000 | 13.420000000000000 |
| PRB-20240315-N480-2 | 46.58      | 180.09640000000000 | 13.420000000000000 |
| PRB-20240315-N480-3 | 46.58      | 180.09640000000000 | 13.420000000000000 |
| PRB-20240315-N620-1 | 58.37      | 2.6569000000000000 | 1.6300000000000000 |
| PRB-20240315-N620-2 | 58.37      | 2.6569000000000000 | 1.6300000000000000 |

### Q6: 1.6 MOD — определение чётных/нечётных ID

**Status:** PASS

```sql
SELECT
    production_id,
    MOD(production_id, 2) AS is_odd,
    CASE MOD(production_id, 2)
        WHEN 0 THEN 'Чётный'
        ELSE 'Нечётный'
    END AS parity
FROM fact_production
LIMIT 10;
```

**Rows returned:** 10 (showing first 5)

| production_id | is_odd | parity   |
|---------------|--------|----------|
| 1             | 1      | Нечётный |
| 2             | 0      | Чётный   |
| 3             | 1      | Нечётный |
| 4             | 0      | Чётный   |
| 5             | 1      | Нечётный |

### Q7: 1.7 SIGN — направление отклонения от нормы

**Status:** PASS

```sql
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
```

**Rows returned:** 13 (showing first 5)

| sample_number       | fe_content | deviation | direction | status     |
|---------------------|------------|-----------|-----------|------------|
| PRB-20240315-N480-1 | 46.58      | -13.42    | -1        | Ниже нормы |
| PRB-20240315-N480-2 | 46.58      | -13.42    | -1        | Ниже нормы |
| PRB-20240315-N480-3 | 46.58      | -13.42    | -1        | Ниже нормы |
| PRB-20240315-N620-1 | 58.37      | -1.63     | -1        | Ниже нормы |
| PRB-20240315-N620-2 | 58.37      | -1.63     | -1        | Ниже нормы |

### Q8: 1.8 LN, LOG, PI — дополнительные функции

**Status:** PASS

```sql
SELECT
    PI()           AS pi_value,
    LN(2.71828)    AS natural_log,
    LOG(100)       AS log_10_of_100,
    LOG(2, 8)      AS log_2_of_8;
```

**Rows returned:** 1 (showing first 1)

| pi_value          | natural_log        | log_10_of_100 | log_2_of_8         |
|-------------------|--------------------|---------------|--------------------|
| 3.141592653589793 | 0.9999993273472820 | 2.0           | 3.0000000000000000 |

### Q9: 1.9 RANDOM — случайная выборка проб для контроля качества

**Status:** PASS

```sql
SELECT
    sample_number,
    fe_content,
    sio2_content
FROM fact_ore_quality
WHERE date_id BETWEEN 20240301 AND 20240331
ORDER BY RANDOM()
LIMIT 5;
```

**Rows returned:** 5 (showing first 5)

| sample_number       | fe_content | sio2_content |
|---------------------|------------|--------------|
| PRB-20240302-N480-1 | 46.29      | 16.61        |
| PRB-20240318-N480-1 | 54.36      | 8.11         |
| PRB-20240301-S420-1 | 49.57      | 11.09        |
| PRB-20240320-N620-1 | 56.48      | 10.53        |
| PRB-20240320-N480-1 | 54.03      | 10.79        |

### Q10: 2.1 Базовые агрегаты: сводка добычи за март 2024

**Status:** PASS

```sql
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
```

**Rows returned:** 1 (showing first 1)

| total_records | unique_equipment | unique_operators | total_tons | avg_tons | min_tons | max_tons | avg_hours |
|---------------|------------------|------------------|------------|----------|----------|----------|-----------|
| 472           | 8                | 8                | 46194.11   | 97.87    | 36.21    | 204.35   | 10.76     |

### Q11: 2.2 COUNT vs COUNT(*) vs COUNT(DISTINCT)

**Status:** PASS

```sql
SELECT
    COUNT(*)                 AS all_rows,
    COUNT(sio2_content)      AS non_null_sio2,
    COUNT(DISTINCT ore_grade_id) AS unique_grades
FROM fact_ore_quality
WHERE date_id BETWEEN 20240301 AND 20240331;
```

**Rows returned:** 1 (showing first 1)

| all_rows | non_null_sio2 | unique_grades |
|----------|---------------|---------------|
| 300      | 300           | 3             |

### Q12: 2.3 STRING_AGG — список оборудования по шахтам

**Status:** PASS

```sql
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
```

**Rows returned:** 2 (showing first 2)

| mine_name        | equipment_list                                     | total_equipment |
|------------------|----------------------------------------------------|-----------------|
| Шахта "Северная" | Вагонетка-001, Вагонетка-002, ПДМ-001, ПДМ-002,... | 10              |
| Шахта "Южная"    | Вагонетка-003, Вагонетка-004, ПДМ-004, ПДМ-006,... | 7               |

### Q13: 2.4 STRING_AGG — причины простоев за день

**Status:** PASS

```sql
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
```

**Rows returned:** 8 (showing first 5)

| full_date  | equipment_name | downtime_reasons                                   | total_downtime_min |
|------------|----------------|----------------------------------------------------|--------------------|
| 2024-03-15 | ПДМ-001        | Плановое техническое обслуживание; Перегрев дви... | 720.00             |
| 2024-03-15 | ПДМ-002        | Плановое техническое обслуживание                  | 480.00             |
| 2024-03-15 | ПДМ-003        | Плановое техническое обслуживание                  | 480.00             |
| 2024-03-15 | ПДМ-004        | Плановое техническое обслуживание                  | 480.00             |
| 2024-03-15 | ПДМ-006        | Плановое техническое обслуживание                  | 480.00             |

### Q14: 2.5 ARRAY_AGG — массив дат работы по операторам

**Status:** PASS

```sql
SELECT
    o.last_name || ' ' || o.first_name AS operator_name,
    ARRAY_AGG(DISTINCT fp.date_id ORDER BY fp.date_id) AS work_dates,
    ARRAY_LENGTH(ARRAY_AGG(DISTINCT fp.date_id), 1) AS days_worked
FROM fact_production fp
JOIN dim_operator o ON fp.operator_id = o.operator_id
WHERE fp.date_id BETWEEN 20240301 AND 20240307
GROUP BY o.last_name, o.first_name
ORDER BY days_worked DESC;
```

**Rows returned:** 8 (showing first 5)

| operator_name    | work_dates                                         | days_worked |
|------------------|----------------------------------------------------|-------------|
| Волков Николай   | [20240301, 20240302, 20240303, 20240304, 202403... | 7           |
| Иванов Алексей   | [20240301, 20240302, 20240303, 20240304, 202403... | 7           |
| Козлов Андрей    | [20240301, 20240302, 20240303, 20240304, 202403... | 7           |
| Кузнецов Игорь   | [20240301, 20240302, 20240303, 20240304, 202403... | 7           |
| Морозов Владимир | [20240301, 20240302, 20240303, 20240304, 202403... | 7           |

### Q15: 2.6 Агрегаты с FILTER (PostgreSQL 9.4+)

**Status:** PASS

```sql
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
```

**Rows returned:** 31 (showing first 5)

| full_date  | shift_1_count | shift_2_count | tons_shift_1 | tons_shift_2 | avg_shift_1 | avg_shift_2 |
|------------|---------------|---------------|--------------|--------------|-------------|-------------|
| 2024-03-01 | 7             | 7             | 737.47       | 791.60       | 105.35      | 113.09      |
| 2024-03-02 | 8             | 8             | 597.30       | 516.94       | 74.66       | 64.62       |
| 2024-03-03 | 8             | 6             | 515.20       | 418.00       | 64.40       | 69.67       |
| 2024-03-04 | 8             | 8             | 934.05       | 881.04       | 116.76      | 110.13      |
| 2024-03-05 | 8             | 8             | 920.51       | 881.40       | 115.06      | 110.18      |

### Q16: 2.7 Статистические функции

**Status:** PASS

```sql
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
```

**Rows returned:** 1 (showing first 1)

| std_deviation | variance_fe | median_fe | percentile_90 | mode_grade |
|---------------|-------------|-----------|---------------|------------|
| 6.054         | 36.647      | 54.61     | 62.20         | 2          |

### Q17: 3.1 CAST — стандартный синтаксис

**Status:** PASS

```sql
SELECT
    CAST(date_id AS VARCHAR)    AS date_str,
    CAST('123.45' AS NUMERIC)   AS num_value,
    CAST(tons_mined AS INTEGER) AS tons_int
FROM fact_production
LIMIT 3;
```

**Rows returned:** 3 (showing first 3)

| date_str | num_value | tons_int |
|----------|-----------|----------|
| 20240101 | 123.45    | 71       |
| 20240101 | 123.45    | 76       |
| 20240101 | 123.45    | 65       |

### Q18: 3.2 :: — краткий синтаксис PostgreSQL

**Status:** PASS

```sql
SELECT
    date_id::VARCHAR               AS date_str,
    '123.45'::NUMERIC              AS num_value,
    tons_mined::INTEGER            AS tons_int,
    has_video_recorder::INTEGER    AS has_video_int
FROM fact_production fp
JOIN dim_equipment e ON fp.equipment_id = e.equipment_id
LIMIT 3;
```

**Rows returned:** 3 (showing first 3)

| date_str | num_value | tons_int | has_video_int |
|----------|-----------|----------|---------------|
| 20240101 | 123.45    | 71       | 1             |
| 20240101 | 123.45    | 76       | 1             |
| 20240101 | 123.45    | 65       | 1             |

### Q19: 3.3 TO_DATE — строка в дату по шаблону

**Status:** PASS

```sql
SELECT
    TO_DATE('15.03.2024', 'DD.MM.YYYY')            AS parsed_date_dot,
    TO_DATE('2024/03/15', 'YYYY/MM/DD')            AS parsed_date_slash,
    TO_DATE('15 March 2024', 'DD Month YYYY')       AS parsed_date_en;
```

**Rows returned:** 1 (showing first 1)

| parsed_date_dot | parsed_date_slash | parsed_date_en |
|-----------------|-------------------|----------------|
| 2024-03-15      | 2024-03-15        | 2024-03-15     |

### Q20: 3.4 TO_TIMESTAMP — строка во временну́ю метку

**Status:** PASS

```sql
SELECT
    TO_TIMESTAMP('15-03-2024 14:30:00', 'DD-MM-YYYY HH24:MI:SS') AS parsed_ts;
```

**Rows returned:** 1 (showing first 1)

| parsed_ts                 |
|---------------------------|
| 2024-03-15 14:30:00+03:00 |

### Q21: 3.5 TO_CHAR — форматирование дат и чисел

**Status:** PASS

```sql
SELECT
    TO_CHAR(NOW(), 'DD.MM.YYYY')            AS today_dot,
    TO_CHAR(NOW(), 'DD Mon YYYY, HH24:MI')  AS today_full,
    TO_CHAR(12345.678, 'FM999G999D00')       AS formatted_num;
```

**Rows returned:** 1 (showing first 1)

| today_dot  | today_full         | formatted_num |
|------------|--------------------|---------------|
| 19.03.2026 | 19 Mar 2026, 21:11 | 12,345.68     |

### Q22: 3.6 Преобразование date_id в дату и обратно

**Status:** PASS

```sql
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
```

**Rows returned:** 5 (showing first 5)

| date_id  | real_date  | formatted_date |
|----------|------------|----------------|
| 20240301 | 2024-03-01 | 01 Mar 2024    |
| 20240302 | 2024-03-02 | 02 Mar 2024    |
| 20240303 | 2024-03-03 | 03 Mar 2024    |
| 20240304 | 2024-03-04 | 04 Mar 2024    |
| 20240305 | 2024-03-05 | 05 Mar 2024    |

### Q23: Неявное (работает в PostgreSQL при конкатенации):

**Status:** PASS

```sql
SELECT 'Добыто: ' || tons_mined || ' тонн' AS message
FROM fact_production
LIMIT 1;
```

**Rows returned:** 1 (showing first 1)

| message            |
|--------------------|
| Добыто: 71.32 тонн |

### Q24: Явное (рекомендуется):

**Status:** PASS

```sql
SELECT 'Добыто: ' || CAST(tons_mined AS VARCHAR) || ' тонн' AS message
FROM fact_production
LIMIT 1;
```

**Rows returned:** 1 (showing first 1)

| message            |
|--------------------|
| Добыто: 71.32 тонн |

### Q25: 4.1 CASE WHEN — классификация руды по содержанию Fe

**Status:** PASS

```sql
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
```

**Rows returned:** 13 (showing first 5)

| sample_number        | fe_content | ore_category |
|----------------------|------------|--------------|
| PRB-20240315-N480-N2 | 59.25      | Средняя руда |
| PRB-20240315-N480-N1 | 59.25      | Средняя руда |
| PRB-20240315-N620-3  | 58.37      | Средняя руда |
| PRB-20240315-N620-1  | 58.37      | Средняя руда |
| PRB-20240315-N620-2  | 58.37      | Средняя руда |

### Q26: 4.2 Простая форма CASE

**Status:** PASS

```sql
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
```

**Rows returned:** 2 (showing first 2)

| shift_id | shift_name     | total_tons |
|----------|----------------|------------|
| 1        | Утренняя смена | 23367.34   |
| 2        | Дневная смена  | 22826.77   |

### Q27: 4.3 CASE внутри агрегатов — кросс-табуляция

**Status:** PASS

```sql
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
```

**Rows returned:** 26 (showing first 5)

| full_date  | good_samples | poor_samples | total_samples | good_pct |
|------------|--------------|--------------|---------------|----------|
| 2024-03-01 | 0            | 13           | 13            | 0.0      |
| 2024-03-02 | 0            | 9            | 9             | 0.0      |
| 2024-03-04 | 6            | 6            | 12            | 50.0     |
| 2024-03-05 | 0            | 11           | 11            | 0.0      |
| 2024-03-06 | 3            | 9            | 12            | 25.0     |

### Q28: 4.4 CASE с несколькими условиями — категоризация простоев

**Status:** PASS

```sql
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
-- ... (truncated)
```

**Rows returned:** 95 (showing first 5)

| equipment_name | reason_name                       | duration_min | downtime_category  | planned_status |
|----------------|-----------------------------------|--------------|--------------------|----------------|
| Самосвал-001   | Плановое техническое обслуживание | 480.00       | Длительный (2-8 ч) | Плановый       |
| ПДМ-001        | Плановое техническое обслуживание | 480.00       | Длительный (2-8 ч) | Плановый       |
| ПДМ-002        | Плановое техническое обслуживание | 480.00       | Длительный (2-8 ч) | Плановый       |
| ПДМ-003        | Плановое техническое обслуживание | 480.00       | Длительный (2-8 ч) | Плановый       |
| ПДМ-004        | Плановое техническое обслуживание | 480.00       | Длительный (2-8 ч) | Плановый       |

### Q29: 4.5 COALESCE — подстановка значений по умолчанию

**Status:** PASS

```sql
SELECT
    sample_number,
    fe_content,
    COALESCE(sio2_content, 0)   AS sio2_safe,
    COALESCE(al2o3_content, 0)  AS al2o3_safe,
    COALESCE(moisture, 0)       AS moisture_safe
FROM fact_ore_quality
WHERE date_id = 20240315;
```

**Rows returned:** 13 (showing first 5)

| sample_number       | fe_content | sio2_safe | al2o3_safe | moisture_safe |
|---------------------|------------|-----------|------------|---------------|
| PRB-20240315-N480-1 | 46.58      | 16.94     | 7.26       | 5.47          |
| PRB-20240315-N480-2 | 46.58      | 13.96     | 5.17       | 3.70          |
| PRB-20240315-N480-3 | 46.58      | 15.98     | 2.15       | 7.63          |
| PRB-20240315-N620-1 | 58.37      | 14.83     | 2.80       | 6.11          |
| PRB-20240315-N620-2 | 58.37      | 9.38      | 3.25       | 6.99          |

### Q30: 4.6 COALESCE — цепочка подстановки

**Status:** PASS

```sql
SELECT
    COALESCE(sio2_content, al2o3_content, 0) AS first_non_null_impurity
FROM fact_ore_quality
WHERE date_id = 20240315;
```

**Rows returned:** 13 (showing first 5)

| first_non_null_impurity |
|-------------------------|
| 16.94                   |
| 13.96                   |
| 15.98                   |
| 14.83                   |
| 9.38                    |

### Q31: 4.7 NULLIF — защита от деления на ноль

**Status:** PASS

```sql
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
```

**Rows returned:** 14 (showing first 5)

| equipment_id | tons_mined | tons_transported | trips_count | tons_per_trip | fuel_per_km |
|--------------|------------|------------------|-------------|---------------|-------------|
| 2            | 69.58      | 85.68            | 8           | 10.71         | 10.64       |
| 3            | 79.01      | 60.76            | 8           | 7.60          | 11.82       |
| 4            | 85.76      | 90.59            | 8           | 11.32         | 12.51       |
| 7            | 176.02     | 155.64           | 7           | 22.23         | 11.64       |
| 8            | 191.76     | 149.66           | 6           | 24.94         | 10.47       |

### Q32: 4.8 COALESCE + NULLIF — безопасное деление с подстановкой

**Status:** PASS

```sql
SELECT
    equipment_id,
    COALESCE(
        ROUND(tons_transported / NULLIF(trips_count, 0), 2),
        0
    ) AS tons_per_trip_safe
FROM fact_production
WHERE date_id = 20240315;
```

**Rows returned:** 14 (showing first 5)

| equipment_id | tons_per_trip_safe |
|--------------|--------------------|
| 2            | 10.71              |
| 3            | 7.60               |
| 4            | 11.32              |
| 7            | 22.23              |
| 8            | 24.94              |

### Q33: 4.9 GREATEST / LEAST

**Status:** PASS

```sql
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
-- ... (truncated)
```

**Rows returned:** 13 (showing first 5)

| sample_number       | fe_content | sio2_content | al2o3_content | max_impurity | min_impurity | fe_clamped |
|---------------------|------------|--------------|---------------|--------------|--------------|------------|
| PRB-20240315-N480-1 | 46.58      | 16.94        | 7.26          | 16.94        | 7.26         | 46.58      |
| PRB-20240315-N480-2 | 46.58      | 13.96        | 5.17          | 13.96        | 5.17         | 46.58      |
| PRB-20240315-N480-3 | 46.58      | 15.98        | 2.15          | 15.98        | 2.15         | 46.58      |
| PRB-20240315-N620-1 | 58.37      | 14.83        | 2.80          | 14.83        | 2.80         | 58.37      |
| PRB-20240315-N620-2 | 58.37      | 9.38         | 3.25          | 9.38         | 3.25         | 58.37      |

### Q34: 5.1 IS NULL / IS NOT NULL — незавершённые простои

**Status:** PASS

```sql
SELECT
    fd.downtime_id,
    e.equipment_name,
    fd.start_time,
    fd.end_time,
    fd.duration_min
FROM fact_equipment_downtime fd
JOIN dim_equipment e ON fd.equipment_id = e.equipment_id
WHERE fd.end_time IS NULL;
```

**Rows returned:** 0 (showing first 0)

| downtime_id | equipment_name | start_time | end_time | duration_min |
|-------------|----------------|------------|----------|--------------|

### Q35: 5.2 Подсчёт NULL значений

**Status:** PASS

```sql
SELECT
    COUNT(*) AS total_rows,
    COUNT(sio2_content) AS with_sio2,
    COUNT(*) - COUNT(sio2_content) AS null_sio2,
    ROUND(
        100.0 * (COUNT(*) - COUNT(sio2_content)) / COUNT(*), 1
    ) AS null_pct
FROM fact_ore_quality;
```

**Rows returned:** 1 (showing first 1)

| total_rows | with_sio2 | null_sio2 | null_pct |
|------------|-----------|-----------|----------|
| 5325       | 5325      | 0         | 0.0      |

### Q36: 5.3 NULL в арифметике

**Status:** PASS

```sql
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
```

**Rows returned:** 5 (showing first 5)

| fe_content | sio2_content | sum_unsafe | sum_safe |
|------------|--------------|------------|----------|
| 46.58      | 16.94        | 63.52      | 63.52    |
| 46.58      | 13.96        | 60.54      | 60.54    |
| 46.58      | 15.98        | 62.56      | 62.56    |
| 58.37      | 14.83        | 73.20      | 73.20    |
| 58.37      | 9.38         | 67.75      | 67.75    |

### Q37: 5.4 NULLS FIRST / NULLS LAST в ORDER BY

**Status:** PASS

```sql
SELECT sample_number, fe_content, sio2_content
FROM fact_ore_quality
WHERE date_id = 20240315
ORDER BY sio2_content NULLS LAST;
```

**Rows returned:** 13 (showing first 5)

| sample_number        | fe_content | sio2_content |
|----------------------|------------|--------------|
| PRB-20240315-S420-2  | 51.52      | 8.62         |
| PRB-20240315-S420-N2 | 47.56      | 9.20         |
| PRB-20240315-N620-2  | 58.37      | 9.38         |
| PRB-20240315-S420-N1 | 47.56      | 10.23        |
| PRB-20240315-S420-3  | 51.52      | 11.31        |

### Q38: 

**Status:** PASS

```sql
SELECT sample_number, fe_content, sio2_content
FROM fact_ore_quality
WHERE date_id = 20240315
ORDER BY sio2_content NULLS FIRST;
```

**Rows returned:** 13 (showing first 5)

| sample_number        | fe_content | sio2_content |
|----------------------|------------|--------------|
| PRB-20240315-S420-2  | 51.52      | 8.62         |
| PRB-20240315-S420-N2 | 47.56      | 9.20         |
| PRB-20240315-N620-2  | 58.37      | 9.38         |
| PRB-20240315-S420-N1 | 47.56      | 10.23        |
| PRB-20240315-S420-3  | 51.52      | 11.31        |

### Q39: ХОРОШО: используем NOT EXISTS

**Status:** PASS

```sql
SELECT *
FROM dim_equipment e
WHERE NOT EXISTS (
    SELECT 1
    FROM fact_production fp
    WHERE fp.equipment_id = e.equipment_id
      AND fp.date_id BETWEEN 20240301 AND 20240331
);
```

**Rows returned:** 10 (showing first 5)

| equipment_id | equipment_type_id | mine_id | equipment_name | inventory_number | manufacturer   | model  | year_manufactured | commissioning_date | status | has_video_recorder | has_navigation |
|--------------|-------------------|---------|----------------|------------------|----------------|--------|-------------------|--------------------|--------|--------------------|----------------|
| 11           | 2                 | 2       | Самосвал-005   | INV-TRK-005      | Caterpillar    | AD30   | 2018              | 2018-12-01         | active | False              | True           |
| 17           | 4                 | 1       | Скип-002       | INV-SKP-002      | Siemag Tecberg | BMR-20 | 2015              | 2015-04-10         | active | True               | False          |
| 12           | 3                 | 1       | Вагонетка-001  | INV-CRT-001      | НКМЗ           | ВГ-5.0 | 2016              | 2016-03-20         | active | False              | False          |
| 18           | 4                 | 2       | Скип-003       | INV-SKP-003      | НКМЗ           | СН-20  | 2012              | 2012-11-15         | active | True               | False          |
| 15           | 3                 | 2       | Вагонетка-004  | INV-CRT-004      | НКМЗ           | ВГ-5.0 | 2017              | 2017-07-01         | active | False              | False          |

### Q40: 6. КОМПЛЕКСНЫЙ ПРИМЕР: KPI ЭФФЕКТИВНОСТИ ОБОРУДОВАНИЯ

**Status:** PASS

```sql
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
-- ... (truncated)
```

**Rows returned:** 8 (showing first 5)

| equipment_name | type_name                     | total_shifts | total_tons | total_hours | tons_per_hour | utilization_pct | fuel_per_ton | efficiency_category | data_status   |
|----------------|-------------------------------|--------------|------------|-------------|---------------|-----------------|--------------|---------------------|---------------|
| Самосвал-001   | Шахтный самосвал              | 59           | 8796.2     | 640.2       | 13.74         | 135.6           | 1.358        | Средняя             | Данные полные |
| Самосвал-002   | Шахтный самосвал              | 60           | 8744.1     | 644.3       | 13.57         | 134.2           | 1.450        | Средняя             | Данные полные |
| Самосвал-004   | Шахтный самосвал              | 58           | 8203.2     | 628.4       | 13.05         | 135.4           | 1.370        | Средняя             | Данные полные |
| ПДМ-004        | Погрузочно-доставочная машина | 59           | 4270.3     | 626.7       | 6.81          | 132.8           | 1.547        | Низкая              | Данные полные |
| ПДМ-006        | Погрузочно-доставочная машина | 60           | 4378.4     | 645.8       | 6.78          | 134.5           | 1.591        | Низкая              | Данные полные |

---

## Module 7

**File:** `C:\Users\dstrelnikov\Documents\SQL\module_07\examples.sql`

### Q1: 1.1 Все индексы таблицы fact_production

**Status:** PASS

```sql
SELECT indexname, indexdef
FROM pg_indexes
WHERE tablename = 'fact_production'
ORDER BY indexname;
```

**Rows returned:** 11 (showing first 5)

| indexname                 | indexdef                                           |
|---------------------------|----------------------------------------------------|
| fact_production_pkey      | CREATE UNIQUE INDEX fact_production_pkey ON pub... |
| fact_production_pkey      | CREATE UNIQUE INDEX fact_production_pkey ON sta... |
| idx_fact_production_date  | CREATE INDEX idx_fact_production_date ON public... |
| idx_fact_production_equip | CREATE INDEX idx_fact_production_equip ON publi... |
| idx_fact_production_mine  | CREATE INDEX idx_fact_production_mine ON public... |

### Q2: 1.2 Все индексы схемы public

**Status:** PASS

```sql
SELECT tablename, indexname, indexdef
FROM pg_indexes
WHERE schemaname = 'public'
ORDER BY tablename, indexname;
```

**Rows returned:** 42 (showing first 5)

| tablename           | indexname                           | indexdef                                           |
|---------------------|-------------------------------------|----------------------------------------------------|
| dim_date            | dim_date_full_date_key              | CREATE UNIQUE INDEX dim_date_full_date_key ON p... |
| dim_date            | dim_date_pkey                       | CREATE UNIQUE INDEX dim_date_pkey ON public.dim... |
| dim_downtime_reason | dim_downtime_reason_pkey            | CREATE UNIQUE INDEX dim_downtime_reason_pkey ON... |
| dim_downtime_reason | dim_downtime_reason_reason_code_key | CREATE UNIQUE INDEX dim_downtime_reason_reason_... |
| dim_equipment       | dim_equipment_inventory_number_key  | CREATE UNIQUE INDEX dim_equipment_inventory_num... |

### Q3: 1.3 Размер индексов таблицы

**Status:** PASS

```sql
SELECT indexrelname AS index_name,
       pg_size_pretty(pg_relation_size(indexrelid)) AS index_size,
       idx_scan AS times_used,
       idx_tup_read AS tuples_read
FROM pg_stat_user_indexes
WHERE relname = 'fact_production'
ORDER BY pg_relation_size(indexrelid) DESC;
```

**Rows returned:** 11 (showing first 5)

| index_name                | index_size | times_used | tuples_read |
|---------------------------|------------|------------|-------------|
| fact_production_pkey      | 200 kB     | 0          | 0           |
| idx_fact_production_date  | 88 kB      | 10788      | 189654      |
| idx_fact_production_shift | 80 kB      | 1          | 8384        |
| idx_fact_production_mine  | 80 kB      | 2          | 13621       |
| idx_fact_production_equip | 80 kB      | 16812      | 17609044    |

### Q4: 1.4 Размер таблицы vs индексов

**Status:** PASS

```sql
SELECT pg_size_pretty(pg_table_size('fact_production')) AS table_size,
       pg_size_pretty(pg_indexes_size('fact_production')) AS indexes_size,
       pg_size_pretty(pg_total_relation_size('fact_production')) AS total_size;
```

**Rows returned:** 1 (showing first 1)

| table_size | indexes_size | total_size |
|------------|--------------|------------|
| 1056 kB    | 608 kB       | 1664 kB    |

### Q5: 1.5 Физический адрес строк (ctid)

**Status:** PASS

```sql
SELECT ctid, equipment_id, equipment_name
FROM dim_equipment
ORDER BY ctid
LIMIT 10;
```

**Rows returned:** 10 (showing first 5)

| ctid  | equipment_id | equipment_name |
|-------|--------------|----------------|
| (0,1) | 1            | ПДМ-001        |
| (0,2) | 2            | ПДМ-002        |
| (0,3) | 3            | ПДМ-003        |
| (0,4) | 4            | ПДМ-004        |
| (0,5) | 5            | ПДМ-005        |

### Q6: 2.1 Seq Scan по таблице добычи

**Status:** PASS

```sql
EXPLAIN ANALYZE
SELECT * FROM fact_production
WHERE tons_mined > 150;
```

**Rows returned:** 5 (showing first 5)

| QUERY PLAN                                         |
|----------------------------------------------------|
| Seq Scan on fact_production  (cost=0.00..232.80... |
|   Filter: (tons_mined > '150'::numeric)            |
|   Rows Removed by Filter: 6604                     |
| Planning Time: 0.194 ms                            |
| Execution Time: 1.320 ms                           |

### Q7: 2.2 Seq Scan при фильтрации по неиндексированному столбцу

**Status:** PASS

```sql
EXPLAIN ANALYZE
SELECT * FROM fact_production
WHERE fuel_consumed_l > 50;
```

**Rows returned:** 4 (showing first 4)

| QUERY PLAN                                         |
|----------------------------------------------------|
| Seq Scan on fact_production  (cost=0.00..232.80... |
|   Filter: (fuel_consumed_l > '50'::numeric)        |
| Planning Time: 0.150 ms                            |
| Execution Time: 2.863 ms                           |

### Q8: 3.1 Простой индекс на один столбец

**Status:** SKIP (DML/DDL)

```sql
CREATE INDEX idx_prod_tons_mined
ON fact_production(tons_mined);
```

### Q9: Проверяем: теперь Index Scan

**Status:** PASS

```sql
EXPLAIN ANALYZE
SELECT * FROM fact_production
WHERE tons_mined > 150;
```

**Rows returned:** 5 (showing first 5)

| QUERY PLAN                                         |
|----------------------------------------------------|
| Seq Scan on fact_production  (cost=0.00..232.80... |
|   Filter: (tons_mined > '150'::numeric)            |
|   Rows Removed by Filter: 6604                     |
| Planning Time: 0.239 ms                            |
| Execution Time: 2.448 ms                           |

### Q10: 3.2 Индекс с направлением сортировки

**Status:** SKIP (DML/DDL)

```sql
CREATE INDEX idx_prod_date_desc
ON fact_production(date_id DESC NULLS LAST);
```

### Q11: 3.3 Проверяем использование для ORDER BY

**Status:** PASS

```sql
EXPLAIN ANALYZE
SELECT date_id, equipment_id, tons_mined
FROM fact_production
ORDER BY date_id DESC
LIMIT 20;
```

**Rows returned:** 4 (showing first 4)

| QUERY PLAN                                         |
|----------------------------------------------------|
| Limit  (cost=0.29..0.92 rows=20 width=14) (actu... |
|   ->  Index Scan Backward using idx_fact_produc... |
| Planning Time: 0.110 ms                            |
| Execution Time: 0.041 ms                           |

### Q12: 4.3 Индексы, созданные автоматически (PRIMARY KEY, UNIQUE)

**Status:** PASS

```sql
SELECT conname AS constraint_name,
       contype AS type,
       pg_get_constraintdef(oid) AS definition
FROM pg_constraint
WHERE conrelid = 'dim_equipment'::regclass;
```

**Rows returned:** 4 (showing first 4)

| constraint_name                      | type | definition                                         |
|--------------------------------------|------|----------------------------------------------------|
| dim_equipment_equipment_type_id_fkey | f    | FOREIGN KEY (equipment_type_id) REFERENCES dim_... |
| dim_equipment_inventory_number_key   | u    | UNIQUE (inventory_number)                          |
| dim_equipment_mine_id_fkey           | f    | FOREIGN KEY (mine_id) REFERENCES dim_mine(mine_id) |
| dim_equipment_pkey                   | p    | PRIMARY KEY (equipment_id)                         |

### Q13: 5.1 Индекс только по аварийным показаниям телеметрии

**Status:** SKIP (DML/DDL)

```sql
CREATE INDEX idx_telemetry_alarm
ON fact_equipment_telemetry(date_id, equipment_id)
WHERE is_alarm = TRUE;
```

### Q14: 5.2 Запрос использует частичный индекс

**Status:** PASS

```sql
EXPLAIN ANALYZE
SELECT * FROM fact_equipment_telemetry
WHERE date_id = 20240315
  AND equipment_id = 3
  AND is_alarm = TRUE;
```

**Rows returned:** 5 (showing first 5)

| QUERY PLAN                                         |
|----------------------------------------------------|
| Index Scan using idx_fact_telemetry_equip on fa... |
|   Index Cond: (equipment_id = 3)                   |
|   Filter: (is_alarm AND (date_id = 20240315))      |
| Planning Time: 0.457 ms                            |
| Execution Time: 0.043 ms                           |

### Q15: 5.3 Запрос БЕЗ условия is_alarm — частичный индекс НЕ используется

**Status:** PASS

```sql
EXPLAIN ANALYZE
SELECT * FROM fact_equipment_telemetry
WHERE date_id = 20240315
  AND equipment_id = 3;
```

**Rows returned:** 5 (showing first 5)

| QUERY PLAN                                         |
|----------------------------------------------------|
| Index Scan using idx_fact_telemetry_equip on fa... |
|   Index Cond: (equipment_id = 3)                   |
|   Filter: (date_id = 20240315)                     |
| Planning Time: 0.109 ms                            |
| Execution Time: 0.062 ms                           |

### Q16: 5.4 Частичный индекс для внеплановых простоев

**Status:** SKIP (DML/DDL)

```sql
CREATE INDEX idx_downtime_unplanned
ON fact_equipment_downtime(date_id, equipment_id)
WHERE is_planned = FALSE;
```

### Q17: 5.5 Сравнение размеров: полный vs частичный индекс

**Status:** PASS

```sql
SELECT indexrelname,
       pg_size_pretty(pg_relation_size(indexrelid)) AS size
FROM pg_stat_user_indexes
WHERE relname = 'fact_equipment_telemetry'
ORDER BY indexrelname;
```

**Rows returned:** 5 (showing first 5)

| indexrelname                  | size   |
|-------------------------------|--------|
| fact_equipment_telemetry_pkey | 432 kB |
| idx_fact_telemetry_date       | 152 kB |
| idx_fact_telemetry_equip      | 152 kB |
| idx_fact_telemetry_sensor     | 184 kB |
| idx_fact_telemetry_time       | 168 kB |

### Q18: 6.1 Индекс по году-месяцу (извлечённому из date_id)

**Status:** SKIP (DML/DDL)

```sql
CREATE INDEX idx_prod_year_month
ON fact_production ((date_id / 100));
```

### Q19: Используется при запросе:

**Status:** PASS

```sql
EXPLAIN ANALYZE
SELECT * FROM fact_production
WHERE date_id / 100 = 202403;
```

**Rows returned:** 5 (showing first 5)

| QUERY PLAN                                         |
|----------------------------------------------------|
| Seq Scan on fact_production  (cost=0.00..253.76... |
|   Filter: ((date_id / 100) = 202403)               |
|   Rows Removed by Filter: 7912                     |
| Planning Time: 0.122 ms                            |
| Execution Time: 0.622 ms                           |

### Q20: 6.2 Индекс для регистронезависимого поиска

**Status:** SKIP (DML/DDL)

```sql
CREATE INDEX idx_operator_lastname_lower
ON dim_operator (LOWER(last_name));
```

### Q21: 

**Status:** PASS

```sql
EXPLAIN ANALYZE
SELECT * FROM dim_operator
WHERE LOWER(last_name) = 'петров';
```

**Rows returned:** 5 (showing first 5)

| QUERY PLAN                                         |
|----------------------------------------------------|
| Seq Scan on dim_operator  (cost=0.00..11.05 row... |
|   Filter: (lower((last_name)::text) = 'петров':... |
|   Rows Removed by Filter: 9                        |
| Planning Time: 0.103 ms                            |
| Execution Time: 0.059 ms                           |

### Q22: 6.3 Индекс по извлечённому году из даты

**Status:** SKIP (DML/DDL)

```sql
CREATE INDEX idx_equip_commission_year
ON dim_equipment ((EXTRACT(YEAR FROM commissioning_date)));
```

### Q23: 

**Status:** PASS

```sql
EXPLAIN ANALYZE
SELECT * FROM dim_equipment
WHERE EXTRACT(YEAR FROM commissioning_date) = 2021;
```

**Rows returned:** 5 (showing first 5)

| QUERY PLAN                                         |
|----------------------------------------------------|
| Seq Scan on dim_equipment  (cost=0.00..11.05 ro... |
|   Filter: (EXTRACT(year FROM commissioning_date... |
|   Rows Removed by Filter: 16                       |
| Planning Time: 0.125 ms                            |
| Execution Time: 0.050 ms                           |

### Q24: 7.1 Композитный индекс: equipment_id + date_id

**Status:** SKIP (DML/DDL)

```sql
CREATE INDEX idx_prod_equip_date
ON fact_production(equipment_id, date_id);
```

### Q25: Используется для запроса с обоими условиями

**Status:** PASS

```sql
EXPLAIN ANALYZE
SELECT * FROM fact_production
WHERE equipment_id = 5
  AND date_id BETWEEN 20240301 AND 20240331;
```

**Rows returned:** 5 (showing first 5)

| QUERY PLAN                                         |
|----------------------------------------------------|
| Index Scan using idx_fact_production_equip on f... |
|   Index Cond: (equipment_id = 5)                   |
|   Filter: ((date_id >= 20240301) AND (date_id <... |
| Planning Time: 0.131 ms                            |
| Execution Time: 0.030 ms                           |

### Q26: 7.2 Используется для запроса только с ведущим столбцом

**Status:** PASS

```sql
EXPLAIN ANALYZE
SELECT * FROM fact_production
WHERE equipment_id = 5;
```

**Rows returned:** 4 (showing first 4)

| QUERY PLAN                                         |
|----------------------------------------------------|
| Index Scan using idx_fact_production_equip on f... |
|   Index Cond: (equipment_id = 5)                   |
| Planning Time: 0.103 ms                            |
| Execution Time: 0.028 ms                           |

### Q27: 7.3 НЕ используется для запроса без ведущего столбца

**Status:** PASS

```sql
EXPLAIN ANALYZE
SELECT * FROM fact_production
WHERE date_id = 20240315;
```

**Rows returned:** 4 (showing first 4)

| QUERY PLAN                                         |
|----------------------------------------------------|
| Index Scan using idx_fact_production_date on fa... |
|   Index Cond: (date_id = 20240315)                 |
| Planning Time: 0.140 ms                            |
| Execution Time: 0.036 ms                           |

### Q28: 7.4 Демонстрация Bitmap Index Scan (два отдельных индекса)

**Status:** PASS

```sql
EXPLAIN ANALYZE
SELECT * FROM fact_production
WHERE equipment_id = 5
  AND shift_id = 2;
```

**Rows returned:** 5 (showing first 5)

| QUERY PLAN                                         |
|----------------------------------------------------|
| Index Scan using idx_fact_production_equip on f... |
|   Index Cond: (equipment_id = 5)                   |
|   Filter: (shift_id = 2)                           |
| Planning Time: 0.161 ms                            |
| Execution Time: 0.046 ms                           |

### Q29: 8.1 Покрывающий индекс для частого запроса

**Status:** SKIP (DML/DDL)

```sql
CREATE INDEX idx_prod_date_covering
ON fact_production(date_id)
INCLUDE (equipment_id, tons_mined);
```

### Q30: Index Only Scan: не обращается к heap

**Status:** PASS

```sql
EXPLAIN ANALYZE
SELECT date_id, equipment_id, tons_mined
FROM fact_production
WHERE date_id = 20240315;
```

**Rows returned:** 4 (showing first 4)

| QUERY PLAN                                         |
|----------------------------------------------------|
| Index Scan using idx_fact_production_date on fa... |
|   Index Cond: (date_id = 20240315)                 |
| Planning Time: 0.128 ms                            |
| Execution Time: 0.036 ms                           |

### Q31: 8.2 Покрывающий индекс для агрегатного запроса

**Status:** SKIP (DML/DDL)

```sql
CREATE INDEX idx_prod_equip_covering
ON fact_production(equipment_id)
INCLUDE (tons_mined, operating_hours);
```

### Q32: 

**Status:** PASS

```sql
EXPLAIN ANALYZE
SELECT equipment_id,
       SUM(tons_mined) AS total_tons,
       SUM(operating_hours) AS total_hours
FROM fact_production
WHERE equipment_id IN (1, 2, 3)
GROUP BY equipment_id;
```

**Rows returned:** 6 (showing first 5)

| QUERY PLAN                                         |
|----------------------------------------------------|
| GroupAggregate  (cost=0.29..211.48 rows=8 width... |
|   Group Key: equipment_id                          |
|   ->  Index Scan using idx_fact_production_equi... |
|         Index Cond: (equipment_id = ANY ('{1,2,... |
| Planning Time: 0.162 ms                            |

### Q33: 9.1 Hash-индекс

**Status:** SKIP (DML/DDL)

```sql
CREATE INDEX idx_sensor_code_hash
ON dim_sensor USING hash (sensor_code);
```

### Q34: 

**Status:** PASS

```sql
EXPLAIN ANALYZE
SELECT * FROM dim_sensor
WHERE sensor_code = 'SENS-T-LHD01';
```

**Rows returned:** 4 (showing first 4)

| QUERY PLAN                                         |
|----------------------------------------------------|
| Index Scan using dim_sensor_sensor_code_key on ... |
|   Index Cond: ((sensor_code)::text = 'SENS-T-LH... |
| Planning Time: 0.126 ms                            |
| Execution Time: 0.049 ms                           |

### Q35: 9.2 BRIN-индекс для телеметрии

**Status:** SKIP (DML/DDL)

```sql
CREATE INDEX idx_telemetry_date_brin
ON fact_equipment_telemetry USING brin (date_id)
WITH (pages_per_range = 128);
```

### Q36: 

**Status:** PASS

```sql
EXPLAIN ANALYZE
SELECT * FROM fact_equipment_telemetry
WHERE date_id BETWEEN 20240301 AND 20240331;
```

**Rows returned:** 4 (showing first 4)

| QUERY PLAN                                         |
|----------------------------------------------------|
| Index Scan using idx_fact_telemetry_date on fac... |
|   Index Cond: ((date_id >= 20240301) AND (date_... |
| Planning Time: 0.099 ms                            |
| Execution Time: 0.028 ms                           |

### Q37: 9.3 Сравнение размеров B-tree vs BRIN

**Status:** PASS

```sql
SELECT indexrelname,
       pg_size_pretty(pg_relation_size(indexrelid)) AS size
FROM pg_stat_user_indexes
WHERE relname = 'fact_equipment_telemetry'
  AND indexrelname IN ('idx_fact_telemetry_date', 'idx_telemetry_date_brin')
ORDER BY indexrelname;
```

**Rows returned:** 1 (showing first 1)

| indexrelname            | size   |
|-------------------------|--------|
| idx_fact_telemetry_date | 152 kB |

### Q38: 10.1 Кластеризовать таблицу добычи по дате

**Status:** SKIP (DML/DDL)

```sql
CLUSTER fact_production USING idx_fact_production_date;
```

### Q39: 10.2 Проверить физический порядок

**Status:** PASS

```sql
SELECT ctid, date_id, equipment_id, tons_mined
FROM fact_production
ORDER BY ctid
LIMIT 20;
```

**Rows returned:** 20 (showing first 5)

| ctid  | date_id  | equipment_id | tons_mined |
|-------|----------|--------------|------------|
| (0,1) | 20240101 | 1            | 71.32      |
| (0,2) | 20240101 | 2            | 75.88      |
| (0,3) | 20240101 | 3            | 65.15      |
| (0,4) | 20240101 | 4            | 64.61      |
| (0,5) | 20240101 | 6            | 89.71      |

### Q40: 10.3 Обновить статистику после CLUSTER

**Status:** SKIP (DML/DDL)

```sql
ANALYZE fact_production;
```

### Q41: 11.1 Индексы, которые ни разу не использовались

**Status:** PASS

```sql
SELECT s.relname AS table_name,
       s.indexrelname AS index_name,
       s.idx_scan AS scan_count,
       pg_size_pretty(pg_relation_size(s.indexrelid)) AS size
FROM pg_stat_user_indexes s
JOIN pg_index i ON s.indexrelid = i.indexrelid
WHERE s.idx_scan = 0
  AND NOT i.indisunique
ORDER BY pg_relation_size(s.indexrelid) DESC;
```

**Rows returned:** 43 (showing first 5)

| table_name               | index_name                | scan_count | size   |
|--------------------------|---------------------------|------------|--------|
| fact_equipment_telemetry | idx_fact_telemetry_sensor | 0          | 184 kB |
| fact_equipment_telemetry | idx_fact_telemetry_time   | 0          | 168 kB |
| sensor_readings          | idx_sensor_quality        | 0          | 16 kB  |
| operators                | idx_operators_active      | 0          | 16 kB  |
| fact_production          | idx_fp_mine               | 0          | 16 kB  |

### Q42: 11.2 Наиболее используемые индексы

**Status:** PASS

```sql
SELECT s.relname AS table_name,
       s.indexrelname AS index_name,
       s.idx_scan AS scan_count,
       s.idx_tup_read AS tuples_read,
       s.idx_tup_fetch AS tuples_fetched
FROM pg_stat_user_indexes s
WHERE s.idx_scan > 0
ORDER BY s.idx_scan DESC
LIMIT 20;
```

**Rows returned:** 20 (showing first 5)

| table_name    | index_name         | scan_count | tuples_read | tuples_fetched |
|---------------|--------------------|------------|-------------|----------------|
| dim_date      | dim_date_pkey      | 37136      | 37163       | 37136          |
| dim_location  | dim_location_pkey  | 34308      | 34308       | 34308          |
| dim_equipment | dim_equipment_pkey | 29146      | 29146       | 29146          |
| dim_time      | dim_time_pkey      | 24909      | 24909       | 24909          |
| dim_sensor    | dim_sensor_pkey    | 18864      | 18864       | 18864          |

### Q43: Нельзя использовать внутри транзакции!

**Status:** SKIP (DML/DDL)

```sql
CREATE INDEX CONCURRENTLY idx_prod_location
ON fact_production(location_id);
```

### Q44: 13.1 Удаление индекса

**Status:** SKIP (DML/DDL)

```sql
DROP INDEX IF EXISTS idx_prod_tons_mined;
```

### Q45: 

**Status:** SKIP (DML/DDL)

```sql
DROP INDEX IF EXISTS idx_prod_date_desc;
```

### Q46: 

**Status:** SKIP (DML/DDL)

```sql
DROP INDEX IF EXISTS idx_prod_year_month;
```

### Q47: 

**Status:** SKIP (DML/DDL)

```sql
DROP INDEX IF EXISTS idx_operator_lastname_lower;
```

### Q48: 

**Status:** SKIP (DML/DDL)

```sql
DROP INDEX IF EXISTS idx_equip_commission_year;
```

### Q49: 

**Status:** SKIP (DML/DDL)

```sql
DROP INDEX IF EXISTS idx_prod_equip_date;
```

### Q50: 

**Status:** SKIP (DML/DDL)

```sql
DROP INDEX IF EXISTS idx_prod_date_covering;
```

### Q51: 

**Status:** SKIP (DML/DDL)

```sql
DROP INDEX IF EXISTS idx_prod_equip_covering;
```

### Q52: 

**Status:** SKIP (DML/DDL)

```sql
DROP INDEX IF EXISTS idx_sensor_code_hash;
```

### Q53: 

**Status:** SKIP (DML/DDL)

```sql
DROP INDEX IF EXISTS idx_telemetry_date_brin;
```

### Q54: 

**Status:** SKIP (DML/DDL)

```sql
DROP INDEX IF EXISTS idx_telemetry_alarm;
```

### Q55: 

**Status:** SKIP (DML/DDL)

```sql
DROP INDEX IF EXISTS idx_downtime_unplanned;
```

### Q56: 

**Status:** SKIP (DML/DDL)

```sql
DROP INDEX IF EXISTS idx_prod_location;
```

---

## Module 8

**File:** `C:\Users\dstrelnikov\Documents\SQL\module_08\examples.sql`

### Q1: 1.1 Список всех индексов в базе данных

**Status:** PASS

```sql
SELECT
    schemaname,
    tablename,
    indexname,
    indexdef,
    pg_size_pretty(pg_relation_size(indexname::regclass)) AS index_size
FROM pg_indexes
WHERE schemaname = 'public'
ORDER BY tablename, indexname;
```

**Rows returned:** 42 (showing first 5)

| schemaname | tablename           | indexname                           | indexdef                                           | index_size |
|------------|---------------------|-------------------------------------|----------------------------------------------------|------------|
| public     | dim_date            | dim_date_full_date_key              | CREATE UNIQUE INDEX dim_date_full_date_key ON p... | 32 kB      |
| public     | dim_date            | dim_date_pkey                       | CREATE UNIQUE INDEX dim_date_pkey ON public.dim... | 32 kB      |
| public     | dim_downtime_reason | dim_downtime_reason_pkey            | CREATE UNIQUE INDEX dim_downtime_reason_pkey ON... | 16 kB      |
| public     | dim_downtime_reason | dim_downtime_reason_reason_code_key | CREATE UNIQUE INDEX dim_downtime_reason_reason_... | 16 kB      |
| public     | dim_equipment       | dim_equipment_inventory_number_key  | CREATE UNIQUE INDEX dim_equipment_inventory_num... | 16 kB      |

### Q2: 1.2 Статистика использования индексов

**Status:** PASS

```sql
SELECT
    schemaname || '.' || relname AS table_name,
    indexrelname AS index_name,
    idx_scan AS index_scans,
    idx_tup_read AS tuples_read,
    idx_tup_fetch AS tuples_fetched,
    pg_size_pretty(pg_relation_size(indexrelid)) AS index_size
FROM pg_stat_user_indexes
WHERE schemaname = 'public'
ORDER BY idx_scan DESC;
```

**Rows returned:** 42 (showing first 5)

| table_name           | index_name         | index_scans | tuples_read | tuples_fetched | index_size |
|----------------------|--------------------|-------------|-------------|----------------|------------|
| public.dim_date      | dim_date_pkey      | 37136       | 37163       | 37136          | 32 kB      |
| public.dim_location  | dim_location_pkey  | 34308       | 34308       | 34308          | 16 kB      |
| public.dim_equipment | dim_equipment_pkey | 29146       | 29146       | 29146          | 16 kB      |
| public.dim_time      | dim_time_pkey      | 24909       | 24909       | 24909          | 48 kB      |
| public.dim_sensor    | dim_sensor_pkey    | 18864       | 18864       | 18864          | 16 kB      |

### Q3: 1.3 Неиспользуемые индексы (кандидаты на удаление)

**Status:** PASS

```sql
SELECT
    indexrelname AS index_name,
    relname AS table_name,
    idx_scan AS scans,
    pg_size_pretty(pg_relation_size(indexrelid)) AS size
FROM pg_stat_user_indexes
WHERE idx_scan = 0
  AND schemaname = 'public'
ORDER BY pg_relation_size(indexrelid) DESC;
```

**Rows returned:** 11 (showing first 5)

| index_name                    | table_name               | scans | size   |
|-------------------------------|--------------------------|-------|--------|
| fact_equipment_telemetry_pkey | fact_equipment_telemetry | 0     | 432 kB |
| fact_production_pkey          | fact_production          | 0     | 200 kB |
| idx_fact_telemetry_sensor     | fact_equipment_telemetry | 0     | 184 kB |
| idx_fact_telemetry_time       | fact_equipment_telemetry | 0     | 168 kB |
| fact_equipment_downtime_pkey  | fact_equipment_downtime  | 0     | 56 kB  |

### Q4: 1.4 Соотношение размеров таблиц и индексов

**Status:** PASS

```sql
SELECT
    relname AS table_name,
    pg_size_pretty(pg_total_relation_size(relid)) AS total_size,
    pg_size_pretty(pg_relation_size(relid)) AS table_size,
    pg_size_pretty(pg_total_relation_size(relid) - pg_relation_size(relid)) AS indexes_size
FROM pg_catalog.pg_statio_user_tables
WHERE schemaname = 'public'
ORDER BY pg_total_relation_size(relid) DESC;
```

**Rows returned:** 18 (showing first 5)

| table_name               | total_size | table_size | indexes_size |
|--------------------------|------------|------------|--------------|
| spatial_ref_sys          | 7144 kB    | 6896 kB    | 248 kB       |
| fact_equipment_telemetry | 2536 kB    | 1416 kB    | 1120 kB      |
| fact_production          | 1664 kB    | 1024 kB    | 640 kB       |
| fact_ore_quality         | 896 kB     | 728 kB     | 168 kB       |
| fact_equipment_downtime  | 440 kB     | 216 kB     | 224 kB       |

### Q5: 2.1 Статистика столбцов таблицы fact_production

**Status:** PASS

```sql
SELECT
    attname AS column_name,
    n_distinct,
    null_frac,
    correlation,
    most_common_vals::text AS common_values,
    most_common_freqs::text AS common_freqs
FROM pg_stats
WHERE tablename = 'fact_production'
ORDER BY attname;
```

**Rows returned:** 29 (showing first 5)

| column_name   | n_distinct  | null_frac | correlation   | common_values                                      | common_freqs                                       |
|---------------|-------------|-----------|---------------|----------------------------------------------------|----------------------------------------------------|
| block_id      | -0.46666667 | 0.0       | 0.63635504    | {BLK-N-144,BLK-N-114,BLK-N-115,BLK-N-120,BLK-N-... | {0.03888889,0.033333335,0.027777778,0.027777778... |
| date_id       | 547.0       | 0.0       | 1.0           | {20240101,20240102,20240103,20240104,20240106,2... | {0.001908397,0.001908397,0.001908397,0.00190839... |
| distance_km   | -0.11187977 | 0.0       | -0.0028356079 | {10.37,10.46,9.84,10.03,9.77,9.96,9.47,9.55,9.8... | {0.004532443,0.004532443,0.004293893,0.00429389... |
| equipment_id  | 8.0         | 0.0       | 0.12531261    | {2,6,8,1,4,10,3,7}                                 | {0.12583493,0.12535782,0.12523855,0.12511927,0.... |
| equipment_key | 3.0         | 0.0       | 1.0           | {3,4,5}                                            | {0.33333334,0.33333334,0.33333334}                 |

### Q6: 2.2 Расчёт селективности вручную

**Status:** PASS

```sql
SELECT
    'equipment_id' AS column_name,
    COUNT(DISTINCT equipment_id) AS unique_values,
    COUNT(*) AS total_rows,
    ROUND(COUNT(DISTINCT equipment_id)::numeric / COUNT(*)::numeric, 6) AS selectivity
FROM fact_production
UNION ALL
SELECT
    'mine_id',
    COUNT(DISTINCT mine_id),
    COUNT(*),
    ROUND(COUNT(DISTINCT mine_id)::numeric / COUNT(*)::numeric, 6)
-- ... (truncated)
```

**Rows returned:** 4 (showing first 4)

| column_name  | unique_values | total_rows | selectivity |
|--------------|---------------|------------|-------------|
| date_id      | 547           | 8384       | 0.065243    |
| equipment_id | 8             | 8384       | 0.000954    |
| mine_id      | 2             | 8384       | 0.000239    |
| shift_id     | 2             | 8384       | 0.000239    |

### Q7: 3.1 Простой EXPLAIN (оценочный план, запрос НЕ выполняется)

**Status:** PASS

```sql
EXPLAIN
SELECT *
FROM fact_production
WHERE equipment_id = 5;
```

**Rows returned:** 2 (showing first 2)

| QUERY PLAN                                         |
|----------------------------------------------------|
| Index Scan using idx_fact_production_equip on f... |
|   Index Cond: (equipment_id = 5)                   |

### Q8: 3.2 EXPLAIN ANALYZE (реальный план, запрос ВЫПОЛНЯЕТСЯ)

**Status:** PASS

```sql
EXPLAIN ANALYZE
SELECT *
FROM fact_production
WHERE equipment_id = 5;
```

**Rows returned:** 4 (showing first 4)

| QUERY PLAN                                         |
|----------------------------------------------------|
| Index Scan using idx_fact_production_equip on f... |
|   Index Cond: (equipment_id = 5)                   |
| Planning Time: 0.106 ms                            |
| Execution Time: 0.042 ms                           |

### Q9: 3.3 EXPLAIN с буферами (информация о I/O)

**Status:** PASS

```sql
EXPLAIN (ANALYZE, BUFFERS)
SELECT *
FROM fact_production
WHERE equipment_id = 5;
```

**Rows returned:** 7 (showing first 5)

| QUERY PLAN                                         |
|----------------------------------------------------|
| Index Scan using idx_fact_production_equip on f... |
|   Index Cond: (equipment_id = 5)                   |
|   Buffers: shared hit=2                            |
| Planning:                                          |
|   Buffers: shared hit=4                            |

### Q10: 3.4 EXPLAIN в формате JSON (удобно для программной обработки)

**Status:** PASS

```sql
EXPLAIN (ANALYZE, BUFFERS, FORMAT JSON)
SELECT *
FROM fact_production
WHERE equipment_id = 5;
```

**Rows returned:** 1 (showing first 1)

| QUERY PLAN                                         |
|----------------------------------------------------|
| [{'Plan': {'Node Type': 'Index Scan', 'Parallel... |

### Q11: 3.5 EXPLAIN в формате YAML

**Status:** PASS

```sql
EXPLAIN (ANALYZE, BUFFERS, FORMAT YAML)
SELECT *
FROM fact_production
WHERE equipment_id = 5;
```

**Rows returned:** 1 (showing first 1)

| QUERY PLAN                                         |
|----------------------------------------------------|
| - Plan: 
    Node Type: "Index Scan"
    Parall... |

### Q12: 3.6 Безопасный EXPLAIN ANALYZE для UPDATE/DELETE

**Status:** SKIP (DML/DDL)

```sql
BEGIN;
EXPLAIN ANALYZE
DELETE FROM fact_production WHERE production_id = -1;
ROLLBACK;
```

### Q13: Когда нет индекса или нужно большинство строк

**Status:** PASS

```sql
EXPLAIN ANALYZE
SELECT *
FROM fact_production;
```

**Rows returned:** 3 (showing first 3)

| QUERY PLAN                                         |
|----------------------------------------------------|
| Seq Scan on fact_production  (cost=0.00..211.84... |
| Planning Time: 0.085 ms                            |
| Execution Time: 0.860 ms                           |

### Q14: 4.2 Index Scan — поиск по индексу + чтение из таблицы

**Status:** PASS

```sql
EXPLAIN ANALYZE
SELECT *
FROM fact_production
WHERE equipment_id = 5;
```

**Rows returned:** 4 (showing first 4)

| QUERY PLAN                                         |
|----------------------------------------------------|
| Index Scan using idx_fact_production_equip on f... |
|   Index Cond: (equipment_id = 5)                   |
| Planning Time: 0.108 ms                            |
| Execution Time: 0.031 ms                           |

### Q15: 4.3 Bitmap Index Scan — промежуточный вариант

**Status:** PASS

```sql
EXPLAIN ANALYZE
SELECT *
FROM fact_equipment_downtime
WHERE date_id BETWEEN 20240101 AND 20240331;
```

**Rows returned:** 4 (showing first 4)

| QUERY PLAN                                         |
|----------------------------------------------------|
| Index Scan using idx_fact_downtime_date on fact... |
|   Index Cond: ((date_id >= 20240101) AND (date_... |
| Planning Time: 0.175 ms                            |
| Execution Time: 0.088 ms                           |

### Q16: Сначала создадим покрывающий индекс

**Status:** SKIP (DML/DDL)

```sql
CREATE INDEX idx_demo_covering
    ON fact_production(equipment_id, date_id)
    INCLUDE (tons_mined);
```

### Q17: Обновим Visibility Map

**Status:** SKIP (DML/DDL)

```sql
VACUUM fact_production;
```

### Q18: Запрос, который может использовать Index Only Scan

**Status:** PASS

```sql
EXPLAIN (ANALYZE, BUFFERS)
SELECT date_id, tons_mined
FROM fact_production
WHERE equipment_id = 5;
```

**Rows returned:** 7 (showing first 5)

| QUERY PLAN                                         |
|----------------------------------------------------|
| Index Scan using idx_fact_production_equip on f... |
|   Index Cond: (equipment_id = 5)                   |
|   Buffers: shared hit=2                            |
| Planning:                                          |
|   Buffers: shared hit=4                            |

### Q19: Очистка

**Status:** SKIP (DML/DDL)

```sql
DROP INDEX idx_demo_covering;
```

### Q20: 5.1 Nested Loop (маленькая внешняя таблица + индекс)

**Status:** PASS

```sql
EXPLAIN ANALYZE
SELECT e.equipment_name, p.tons_mined
FROM dim_equipment e
JOIN fact_production p ON p.equipment_id = e.equipment_id
WHERE e.equipment_id = 5
  AND p.date_id = 20240315;
```

**Rows returned:** 8 (showing first 5)

| QUERY PLAN                                         |
|----------------------------------------------------|
| Nested Loop  (cost=0.43..4.47 rows=1 width=324)... |
|   ->  Index Scan using dim_equipment_pkey on di... |
|         Index Cond: (equipment_id = 5)             |
|   ->  Index Scan using idx_fact_production_equi... |
|         Index Cond: (equipment_id = 5)             |

### Q21: 5.2 Hash Join (средние таблицы, без подходящего индекса)

**Status:** PASS

```sql
EXPLAIN ANALYZE
SELECT d.full_date, SUM(p.tons_mined)
FROM fact_production p
JOIN dim_date d ON d.date_id = p.date_id
WHERE d.year = 2024 AND d.quarter = 1
GROUP BY d.full_date;
```

**Rows returned:** 11 (showing first 5)

| QUERY PLAN                                         |
|----------------------------------------------------|
| HashAggregate  (cost=171.66..172.80 rows=91 wid... |
|   Group Key: d.full_date                           |
|   Batches: 1  Memory Usage: 80kB                   |
|   ->  Nested Loop  (cost=0.29..166.44 rows=1044... |
|         ->  Seq Scan on dim_date d  (cost=0.00.... |

### Q22: PostgreSQL выбирает Merge Join, если данные уже отсортированы

**Status:** PASS

```sql
EXPLAIN ANALYZE
SELECT p.production_id, fd.downtime_id
FROM fact_production p
JOIN fact_equipment_downtime fd
    ON fd.equipment_id = p.equipment_id
   AND fd.date_id = p.date_id;
```

**Rows returned:** 12 (showing first 5)

| QUERY PLAN                                         |
|----------------------------------------------------|
| Nested Loop  (cost=0.30..326.11 rows=3312 width... |
|   ->  Seq Scan on fact_equipment_downtime fd  (... |
|   ->  Memoize  (cost=0.30..0.68 rows=2 width=16... |
|         Cache Key: fd.equipment_id, fd.date_id     |
|         Cache Mode: logical                        |

### Q23: 6.1 Запрос без покрывающего индекса

**Status:** PASS

```sql
EXPLAIN (ANALYZE, BUFFERS)
SELECT date_id,
       SUM(tons_mined) AS total_tons,
       SUM(trips_count) AS total_trips
FROM fact_production
WHERE equipment_id = 5
  AND date_id BETWEEN 20240101 AND 20240331
GROUP BY date_id
ORDER BY date_id;
```

**Rows returned:** 15 (showing first 5)

| QUERY PLAN                                         |
|----------------------------------------------------|
| GroupAggregate  (cost=2.32..2.34 rows=1 width=4... |
|   Group Key: date_id                               |
|   Buffers: shared hit=2                            |
|   ->  Sort  (cost=2.32..2.32 rows=1 width=14) (... |
|         Sort Key: date_id                          |

### Q24: 6.2 Создаём покрывающий индекс

**Status:** SKIP (DML/DDL)

```sql
CREATE INDEX idx_prod_equip_date_cover
    ON fact_production(equipment_id, date_id)
    INCLUDE (tons_mined, trips_count);
```

### Q25: Обновляем VM для Index Only Scan

**Status:** SKIP (DML/DDL)

```sql
VACUUM fact_production;
```

### Q26: 6.3 Тот же запрос — теперь Index Only Scan

**Status:** PASS

```sql
EXPLAIN (ANALYZE, BUFFERS)
SELECT date_id,
       SUM(tons_mined) AS total_tons,
       SUM(trips_count) AS total_trips
FROM fact_production
WHERE equipment_id = 5
  AND date_id BETWEEN 20240101 AND 20240331
GROUP BY date_id
ORDER BY date_id;
```

**Rows returned:** 15 (showing first 5)

| QUERY PLAN                                         |
|----------------------------------------------------|
| GroupAggregate  (cost=2.32..2.34 rows=1 width=4... |
|   Group Key: date_id                               |
|   Buffers: shared hit=2                            |
|   ->  Sort  (cost=2.32..2.32 rows=1 width=14) (... |
|         Sort Key: date_id                          |

### Q27: Очистка

**Status:** SKIP (DML/DDL)

```sql
DROP INDEX idx_prod_equip_date_cover;
```

### Q28: 7.1 Внеплановые простои — частый аналитический запрос

**Status:** PASS

```sql
EXPLAIN (ANALYZE, BUFFERS)
SELECT fd.date_id, e.equipment_name, dr.reason_name, fd.duration_min
FROM fact_equipment_downtime fd
JOIN dim_equipment e ON e.equipment_id = fd.equipment_id
JOIN dim_downtime_reason dr ON dr.reason_id = fd.reason_id
WHERE fd.is_planned = FALSE
  AND fd.date_id BETWEEN 20240301 AND 20240331
ORDER BY fd.duration_min DESC;
```

**Rows returned:** 33 (showing first 5)

| QUERY PLAN                                         |
|----------------------------------------------------|
| Sort  (cost=36.62..36.66 rows=18 width=745) (ac... |
|   Sort Key: fd.duration_min DESC                   |
|   Sort Method: quicksort  Memory: 26kB             |
|   Buffers: shared hit=42                           |
|   ->  Nested Loop  (cost=0.58..36.24 rows=18 wi... |

### Q29: 7.2 Создаём частичный индекс (только внеплановые)

**Status:** SKIP (DML/DDL)

```sql
CREATE INDEX idx_downtime_unplanned
    ON fact_equipment_downtime(date_id, equipment_id, reason_id)
    INCLUDE (duration_min)
    WHERE is_planned = FALSE;
```

### Q30: 7.3 Повторяем — видим улучшение

**Status:** PASS

```sql
EXPLAIN (ANALYZE, BUFFERS)
SELECT fd.date_id, e.equipment_name, dr.reason_name, fd.duration_min
FROM fact_equipment_downtime fd
JOIN dim_equipment e ON e.equipment_id = fd.equipment_id
JOIN dim_downtime_reason dr ON dr.reason_id = fd.reason_id
WHERE fd.is_planned = FALSE
  AND fd.date_id BETWEEN 20240301 AND 20240331
ORDER BY fd.duration_min DESC;
```

**Rows returned:** 33 (showing first 5)

| QUERY PLAN                                         |
|----------------------------------------------------|
| Sort  (cost=36.62..36.66 rows=18 width=745) (ac... |
|   Sort Key: fd.duration_min DESC                   |
|   Sort Method: quicksort  Memory: 26kB             |
|   Buffers: shared hit=42                           |
|   ->  Nested Loop  (cost=0.58..36.24 rows=18 wi... |

### Q31: 7.4 Сравнение размеров: частичный vs полный

**Status:** FAIL

```sql
SELECT pg_size_pretty(pg_relation_size('idx_downtime_unplanned')) AS partial_size;
```

**Error:** `relation "idx_downtime_unplanned" does not exist
LINE 1: SELECT pg_size_pretty(pg_relation_size('idx_downtime_unplann...
                                               ^
`

### Q32: 

**Status:** SKIP (DML/DDL)

```sql
CREATE INDEX idx_downtime_full
    ON fact_equipment_downtime(date_id, equipment_id, reason_id)
    INCLUDE (duration_min);
```

### Q33: 

**Status:** FAIL

```sql
SELECT pg_size_pretty(pg_relation_size('idx_downtime_full')) AS full_size;
```

**Error:** `relation "idx_downtime_full" does not exist
LINE 1: SELECT pg_size_pretty(pg_relation_size('idx_downtime_full'))...
                                               ^
`

### Q34: Очистка

**Status:** SKIP (DML/DDL)

```sql
DROP INDEX idx_downtime_unplanned;
```

### Q35: 

**Status:** SKIP (DML/DDL)

```sql
DROP INDEX idx_downtime_full;
```

### Q36: 8.1 Обычный индекс НЕ работает для выражения

**Status:** PASS

```sql
EXPLAIN ANALYZE
SELECT *
FROM fact_equipment_downtime
WHERE duration_min / 60.0 > 2;
```

**Rows returned:** 5 (showing first 5)

| QUERY PLAN                                         |
|----------------------------------------------------|
| Seq Scan on fact_equipment_downtime  (cost=0.00... |
|   Filter: ((duration_min / 60.0) > '2'::numeric)   |
|   Rows Removed by Filter: 1440                     |
| Planning Time: 0.105 ms                            |
| Execution Time: 0.487 ms                           |

### Q37: 8.2 Создаём индекс на выражении

**Status:** SKIP (DML/DDL)

```sql
CREATE INDEX idx_downtime_hours_expr
    ON fact_equipment_downtime((duration_min / 60.0));
```

### Q38: 8.3 Теперь индекс используется

**Status:** PASS

```sql
EXPLAIN ANALYZE
SELECT *
FROM fact_equipment_downtime
WHERE duration_min / 60.0 > 2;
```

**Rows returned:** 5 (showing first 5)

| QUERY PLAN                                         |
|----------------------------------------------------|
| Seq Scan on fact_equipment_downtime  (cost=0.00... |
|   Filter: ((duration_min / 60.0) > '2'::numeric)   |
|   Rows Removed by Filter: 1440                     |
| Planning Time: 0.088 ms                            |
| Execution Time: 0.484 ms                           |

### Q39: 8.4 Индекс на LOWER() — поиск без учёта регистра

**Status:** SKIP (DML/DDL)

```sql
CREATE INDEX idx_equip_name_lower
    ON dim_equipment(LOWER(equipment_name));
```

### Q40: 

**Status:** PASS

```sql
EXPLAIN ANALYZE
SELECT *
FROM dim_equipment
WHERE LOWER(equipment_name) LIKE '%северная%';
```

**Rows returned:** 5 (showing first 5)

| QUERY PLAN                                         |
|----------------------------------------------------|
| Seq Scan on dim_equipment  (cost=0.00..11.05 ro... |
|   Filter: (lower((equipment_name)::text) ~~ '%с... |
|   Rows Removed by Filter: 18                       |
| Planning Time: 0.117 ms                            |
| Execution Time: 0.082 ms                           |

### Q41: Очистка

**Status:** SKIP (DML/DDL)

```sql
DROP INDEX idx_downtime_hours_expr;
```

### Q42: 

**Status:** SKIP (DML/DDL)

```sql
DROP INDEX idx_equip_name_lower;
```

### Q43: 9.1 Запрос: конкретное оборудование, диапазон дат, сортировка по времени

**Status:** PASS

```sql
EXPLAIN (ANALYZE, BUFFERS)
SELECT sensor_id, sensor_value, is_alarm
FROM fact_equipment_telemetry
WHERE equipment_id = 7
  AND date_id BETWEEN 20240301 AND 20240331
ORDER BY time_id;
```

**Rows returned:** 12 (showing first 5)

| QUERY PLAN                                         |
|----------------------------------------------------|
| Sort  (cost=2.32..2.33 rows=1 width=15) (actual... |
|   Sort Key: time_id                                |
|   Sort Method: quicksort  Memory: 25kB             |
|   Buffers: shared hit=2                            |
|   ->  Index Scan using idx_fact_telemetry_date ... |

### Q44: 9.2 Вариант A: equality, range, sort (ОПТИМАЛЬНЫЙ)

**Status:** SKIP (DML/DDL)

```sql
CREATE INDEX idx_telemetry_a
    ON fact_equipment_telemetry(equipment_id, date_id, time_id);
```

### Q45: 

**Status:** PASS

```sql
EXPLAIN (ANALYZE, BUFFERS)
SELECT sensor_id, sensor_value, is_alarm
FROM fact_equipment_telemetry
WHERE equipment_id = 7
  AND date_id BETWEEN 20240301 AND 20240331
ORDER BY time_id;
```

**Rows returned:** 12 (showing first 5)

| QUERY PLAN                                         |
|----------------------------------------------------|
| Sort  (cost=2.32..2.33 rows=1 width=15) (actual... |
|   Sort Key: time_id                                |
|   Sort Method: quicksort  Memory: 25kB             |
|   Buffers: shared hit=2                            |
|   ->  Index Scan using idx_fact_telemetry_date ... |

### Q46: 

**Status:** SKIP (DML/DDL)

```sql
DROP INDEX idx_telemetry_a;
```

### Q47: 9.3 Вариант B: range первым (МЕНЕЕ ОПТИМАЛЬНЫЙ)

**Status:** SKIP (DML/DDL)

```sql
CREATE INDEX idx_telemetry_b
    ON fact_equipment_telemetry(date_id, equipment_id, time_id);
```

### Q48: 

**Status:** PASS

```sql
EXPLAIN (ANALYZE, BUFFERS)
SELECT sensor_id, sensor_value, is_alarm
FROM fact_equipment_telemetry
WHERE equipment_id = 7
  AND date_id BETWEEN 20240301 AND 20240331
ORDER BY time_id;
```

**Rows returned:** 12 (showing first 5)

| QUERY PLAN                                         |
|----------------------------------------------------|
| Sort  (cost=2.32..2.33 rows=1 width=15) (actual... |
|   Sort Key: time_id                                |
|   Sort Method: quicksort  Memory: 25kB             |
|   Buffers: shared hit=2                            |
|   ->  Index Scan using idx_fact_telemetry_date ... |

### Q49: 

**Status:** SKIP (DML/DDL)

```sql
DROP INDEX idx_telemetry_b;
```

### Q50: 10.1 Проверяем корреляцию (физическую упорядоченность)

**Status:** PASS

```sql
SELECT attname, correlation
FROM pg_stats
WHERE tablename = 'fact_equipment_telemetry'
  AND attname = 'date_id';
```

**Rows returned:** 1 (showing first 1)

| attname | correlation |
|---------|-------------|
| date_id | 1.0         |

### Q51: 10.2 Создаём BRIN-индекс

**Status:** SKIP (DML/DDL)

```sql
CREATE INDEX idx_telemetry_date_brin
    ON fact_equipment_telemetry USING BRIN (date_id)
    WITH (pages_per_range = 64);
```

### Q52: 10.3 Создаём B-tree для сравнения

**Status:** SKIP (DML/DDL)

```sql
CREATE INDEX idx_telemetry_date_btree
    ON fact_equipment_telemetry(date_id);
```

### Q53: 10.4 Сравниваем размеры

**Status:** FAIL

```sql
SELECT
    'BRIN' AS type,
    pg_size_pretty(pg_relation_size('idx_telemetry_date_brin')) AS size
UNION ALL
SELECT
    'B-tree',
    pg_size_pretty(pg_relation_size('idx_telemetry_date_btree'));
```

**Error:** `relation "idx_telemetry_date_brin" does not exist
LINE 3:     pg_size_pretty(pg_relation_size('idx_telemetry_date_brin...
                                            ^
`

### Q54: 10.5 Сравниваем планы

**Status:** PASS

```sql
EXPLAIN (ANALYZE, BUFFERS)
SELECT * FROM fact_equipment_telemetry WHERE date_id = 20240315;
```

**Rows returned:** 7 (showing first 5)

| QUERY PLAN                                         |
|----------------------------------------------------|
| Index Scan using idx_fact_telemetry_date on fac... |
|   Index Cond: (date_id = 20240315)                 |
|   Buffers: shared hit=2                            |
| Planning:                                          |
|   Buffers: shared hit=6                            |

### Q55: Очистка

**Status:** SKIP (DML/DDL)

```sql
DROP INDEX idx_telemetry_date_brin;
```

### Q56: 

**Status:** SKIP (DML/DDL)

```sql
DROP INDEX idx_telemetry_date_btree;
```

### Q57: 11.1 CREATE INDEX CONCURRENTLY (без блокировки записи)

**Status:** SKIP (DML/DDL)

```sql
CREATE INDEX CONCURRENTLY idx_prod_date_concurrent
    ON fact_production(date_id, equipment_id);
```

### Q58: 11.2 Проверка валидности индекса

**Status:** FAIL

```sql
SELECT
    indexrelid::regclass AS index_name,
    indisvalid AS is_valid,
    indisready AS is_ready
FROM pg_index
WHERE indexrelid = 'idx_prod_date_concurrent'::regclass;
```

**Error:** `relation "idx_prod_date_concurrent" does not exist
LINE 6: WHERE indexrelid = 'idx_prod_date_concurrent'::regclass;
                           ^
`

### Q59: 11.3 REINDEX — пересоздание раздувшегося индекса

**Status:** SKIP (DML/DDL)

```sql
REINDEX INDEX idx_prod_date_concurrent;
```

### Q60: 11.4 REINDEX CONCURRENTLY (PostgreSQL 12+)

**Status:** SKIP (DML/DDL)

```sql
REINDEX INDEX CONCURRENTLY idx_prod_date_concurrent;
```

### Q61: 11.5 Поиск невалидных индексов

**Status:** PASS

```sql
SELECT indexrelid::regclass AS index_name, indisvalid
FROM pg_index
WHERE NOT indisvalid;
```

**Rows returned:** 0 (showing first 0)

| index_name | indisvalid |
|------------|------------|

### Q62: Очистка

**Status:** SKIP (DML/DDL)

```sql
DROP INDEX IF EXISTS idx_prod_date_concurrent;
```

### Q63: 12.1 Просмотр статистики конкретного столбца

**Status:** PASS

```sql
SELECT
    tablename,
    attname,
    null_frac,
    n_distinct,
    most_common_vals,
    most_common_freqs,
    correlation
FROM pg_stats
WHERE tablename = 'fact_production'
  AND attname = 'equipment_id';
```

**Rows returned:** 1 (showing first 1)

| tablename       | attname      | null_frac | n_distinct | most_common_vals   | most_common_freqs                                  | correlation |
|-----------------|--------------|-----------|------------|--------------------|----------------------------------------------------|-------------|
| fact_production | equipment_id | 0.0       | 8.0        | {2,6,8,1,4,10,3,7} | [0.12583493, 0.12535782, 0.12523855, 0.12511927... | 0.12531261  |

### Q64: 12.2 Обновление статистики

**Status:** SKIP (DML/DDL)

```sql
ANALYZE fact_production;
```

### Q65: 

**Status:** SKIP (DML/DDL)

```sql
ANALYZE fact_equipment_telemetry(equipment_id, date_id, sensor_id);
```

### Q66: 12.3 Увеличение детализации статистики

**Status:** SKIP (DML/DDL)

```sql
ALTER TABLE fact_equipment_telemetry
    ALTER COLUMN sensor_id SET STATISTICS 500;
```

### Q67: 

**Status:** SKIP (DML/DDL)

```sql
ANALYZE fact_equipment_telemetry(sensor_id);
```

### Q68: 12.4 Расширенная статистика для коррелированных столбцов

**Status:** SKIP (DML/DDL)

```sql
CREATE STATISTICS stat_prod_mine_shaft (dependencies)
    ON mine_id, shaft_id FROM fact_production;
```

### Q69: 

**Status:** SKIP (DML/DDL)

```sql
ANALYZE fact_production;
```

### Q70: Просмотр расширенных статистик

**Status:** PASS

```sql
SELECT stxname, stxkeys, stxkind
FROM pg_statistic_ext
WHERE stxrelid = 'fact_production'::regclass;
```

**Rows returned:** 0 (showing first 0)

| stxname | stxkeys | stxkind |
|---------|---------|---------|

### Q71: Очистка

**Status:** SKIP (DML/DDL)

```sql
DROP STATISTICS IF EXISTS stat_prod_mine_shaft;
```

### Q72: 13.1 Исходный запрос (без оптимизации)

**Status:** PASS

```sql
EXPLAIN (ANALYZE, BUFFERS)
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
-- ... (truncated)
```

**Rows returned:** 39 (showing first 5)

| QUERY PLAN                                         |
|----------------------------------------------------|
| Sort  (cost=58.68..58.68 rows=1 width=664) (act... |
|   Sort Key: e.equipment_name                       |
|   Sort Method: quicksort  Memory: 26kB             |
|   Buffers: shared hit=70                           |
|   ->  Nested Loop Left Join  (cost=45.11..58.67... |

### Q73: 13.2 Создаём оптимизирующие индексы

**Status:** SKIP (DML/DDL)

```sql
CREATE INDEX idx_prod_date_equip_cover
    ON fact_production(date_id, equipment_id)
    INCLUDE (operating_hours, tons_mined);
```

### Q74: 

**Status:** SKIP (DML/DDL)

```sql
CREATE INDEX idx_downtime_date_equip_cover
    ON fact_equipment_downtime(date_id, equipment_id)
    INCLUDE (duration_min, is_planned);
```

### Q75: 13.3 Повторяем запрос — сравниваем

**Status:** PASS

```sql
EXPLAIN (ANALYZE, BUFFERS)
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
-- ... (truncated)
```

**Rows returned:** 39 (showing first 5)

| QUERY PLAN                                         |
|----------------------------------------------------|
| Sort  (cost=58.68..58.68 rows=1 width=664) (act... |
|   Sort Key: e.equipment_name                       |
|   Sort Method: quicksort  Memory: 26kB             |
|   Buffers: shared hit=70                           |
|   ->  Nested Loop Left Join  (cost=45.11..58.67... |

### Q76: 13.4 Очистка демонстрационных индексов

**Status:** SKIP (DML/DDL)

```sql
DROP INDEX IF EXISTS idx_prod_date_equip_cover;
```

### Q77: 

**Status:** SKIP (DML/DDL)

```sql
DROP INDEX IF EXISTS idx_downtime_date_equip_cover;
```

---

## Module 9

**File:** `C:\Users\dstrelnikov\Documents\SQL\module_09\examples.sql`

### Q1: 1.1 Установка расширения Citus (если не установлено)

**Status:** SKIP (DML/DDL)

```sql
CREATE EXTENSION IF NOT EXISTS citus;
```

### Q2: 1.2 Создание колоночной таблицы телеметрии

**Status:** SKIP (DML/DDL)

```sql
CREATE TABLE fact_telemetry_columnar (
    telemetry_id    BIGINT,
    date_id         INTEGER,
    time_id         INTEGER,
    equipment_id    INTEGER,
    sensor_id       INTEGER,
    sensor_value    NUMERIC(12,4),
    quality_flag    VARCHAR(10),
    recorded_at     TIMESTAMP
) USING columnar;
```

### Q3: 1.3 Загрузка данных из строковой таблицы

**Status:** SKIP (DML/DDL)

```sql
INSERT INTO fact_telemetry_columnar
SELECT telemetry_id, date_id, time_id, equipment_id,
       sensor_id, sensor_value, quality_flag, recorded_at
FROM fact_equipment_telemetry;
```

### Q4: 1.4 Сравнение размеров строковой и колоночной таблиц

**Status:** FAIL

```sql
SELECT 'fact_equipment_telemetry (row)' AS table_name,
       pg_size_pretty(pg_total_relation_size('fact_equipment_telemetry')) AS total_size,
       pg_size_pretty(pg_relation_size('fact_equipment_telemetry')) AS data_size
UNION ALL
SELECT 'fact_telemetry_columnar (col)',
       pg_size_pretty(pg_total_relation_size('fact_telemetry_columnar')),
       pg_size_pretty(pg_relation_size('fact_telemetry_columnar'));
```

**Error:** `relation "fact_telemetry_columnar" does not exist
LINE 6:        pg_size_pretty(pg_total_relation_size('fact_telemetry...
                                                     ^
`

### Q5: 1.5 Настройка сжатия для колоночной таблицы

**Status:** SKIP (DML/DDL)

```sql
ALTER TABLE fact_telemetry_columnar
    SET (columnar.compression = 'zstd');
```

### Q6: 1.6 Просмотр параметров колоночной таблицы

**Status:** FAIL

```sql
SELECT * FROM columnar.options
WHERE regclass = 'fact_telemetry_columnar'::regclass;
```

**Error:** `relation "columnar.options" does not exist
LINE 1: SELECT * FROM columnar.options
                      ^
`

### Q7: 1.7 Создание колоночной таблицы добычи

**Status:** SKIP (DML/DDL)

```sql
CREATE TABLE fact_production_columnar (
    production_id   BIGINT,
    date_id         INTEGER,
    shift_id        INTEGER,
    equipment_id    INTEGER,
    operator_id     INTEGER,
    mine_id         INTEGER,
    location_id     INTEGER,
    tons_mined      NUMERIC(10,2),
    tons_transported NUMERIC(10,2),
    trips_count     INTEGER,
    fuel_consumed_l NUMERIC(8,2),
-- ... (truncated)
```

### Q8: 

**Status:** SKIP (DML/DDL)

```sql
INSERT INTO fact_production_columnar
SELECT * FROM fact_production;
```

### Q9: 2.1 BRIN-индекс по date_id для таблицы телеметрии

**Status:** SKIP (DML/DDL)

```sql
CREATE INDEX idx_telemetry_date_brin
    ON fact_equipment_telemetry
    USING brin (date_id)
    WITH (pages_per_range = 32);
```

### Q10: 2.2 BRIN-индекс по recorded_at

**Status:** SKIP (DML/DDL)

```sql
CREATE INDEX idx_telemetry_recorded_brin
    ON fact_equipment_telemetry
    USING brin (recorded_at);
```

### Q11: 2.3 B-tree индекс для сравнения

**Status:** SKIP (DML/DDL)

```sql
CREATE INDEX idx_telemetry_date_btree
    ON fact_equipment_telemetry (date_id);
```

### Q12: 2.4 Сравнение размеров индексов

**Status:** PASS

```sql
SELECT indexname,
       pg_size_pretty(pg_relation_size(indexname::regclass)) AS index_size
FROM pg_indexes
WHERE tablename = 'fact_equipment_telemetry'
  AND indexname LIKE 'idx_telemetry_%'
ORDER BY pg_relation_size(indexname::regclass);
```

**Rows returned:** 0 (showing first 0)

| indexname | index_size |
|-----------|------------|

### Q13: 2.5 Запрос с BRIN-индексом: телеметрия за январь 2024

**Status:** PASS

```sql
EXPLAIN (ANALYZE, BUFFERS)
SELECT equipment_id,
       AVG(sensor_value) AS avg_value,
       MIN(sensor_value) AS min_value,
       MAX(sensor_value) AS max_value,
       COUNT(*) AS readings_count
FROM fact_equipment_telemetry
WHERE date_id BETWEEN 20240101 AND 20240131
GROUP BY equipment_id;
```

**Rows returned:** 11 (showing first 5)

| QUERY PLAN                                         |
|----------------------------------------------------|
| HashAggregate  (cost=320.09..320.14 rows=4 widt... |
|   Group Key: equipment_id                          |
|   Batches: 1  Memory Usage: 24kB                   |
|   Buffers: shared hit=78                           |
|   ->  Index Scan using idx_fact_telemetry_date ... |

### Q14: 2.6 Тот же запрос без BRIN (для сравнения)

**Status:** SKIP (DML/DDL)

```sql
SET enable_bitmapscan = off;
```

### Q15: 

**Status:** PASS

```sql
EXPLAIN (ANALYZE, BUFFERS)
SELECT equipment_id,
       AVG(sensor_value) AS avg_value,
       MIN(sensor_value) AS min_value,
       MAX(sensor_value) AS max_value,
       COUNT(*) AS readings_count
FROM fact_equipment_telemetry
WHERE date_id BETWEEN 20240101 AND 20240131
GROUP BY equipment_id;
```

**Rows returned:** 11 (showing first 5)

| QUERY PLAN                                         |
|----------------------------------------------------|
| HashAggregate  (cost=320.09..320.14 rows=4 widt... |
|   Group Key: equipment_id                          |
|   Batches: 1  Memory Usage: 24kB                   |
|   Buffers: shared hit=78                           |
|   ->  Index Scan using idx_fact_telemetry_date ... |

### Q16: 

**Status:** SKIP (DML/DDL)

```sql
SET enable_bitmapscan = on;
```

### Q17: 2.7 BRIN для таблицы простоев

**Status:** SKIP (DML/DDL)

```sql
CREATE INDEX idx_downtime_date_brin
    ON fact_equipment_downtime
    USING brin (date_id)
    WITH (pages_per_range = 16);
```

### Q18: 3.1 RANGE-секционирование по месяцам (телеметрия)

**Status:** SKIP (DML/DDL)

```sql
CREATE TABLE fact_telemetry_partitioned (
    telemetry_id    BIGINT,
    date_id         INTEGER NOT NULL,
    time_id         INTEGER,
    equipment_id    INTEGER,
    sensor_id       INTEGER,
    sensor_value    NUMERIC(12,4),
    quality_flag    VARCHAR(10),
    recorded_at     TIMESTAMP
) PARTITION BY RANGE (date_id);
```

### Q19: Создание секций по месяцам

**Status:** SKIP (DML/DDL)

```sql
CREATE TABLE fact_telemetry_p2024_01
    PARTITION OF fact_telemetry_partitioned
    FOR VALUES FROM (20240101) TO (20240201);
```

### Q20: 

**Status:** SKIP (DML/DDL)

```sql
CREATE TABLE fact_telemetry_p2024_02
    PARTITION OF fact_telemetry_partitioned
    FOR VALUES FROM (20240201) TO (20240301);
```

### Q21: 

**Status:** SKIP (DML/DDL)

```sql
CREATE TABLE fact_telemetry_p2024_03
    PARTITION OF fact_telemetry_partitioned
    FOR VALUES FROM (20240301) TO (20240401);
```

### Q22: 

**Status:** SKIP (DML/DDL)

```sql
CREATE TABLE fact_telemetry_p2024_04
    PARTITION OF fact_telemetry_partitioned
    FOR VALUES FROM (20240401) TO (20240501);
```

### Q23: 

**Status:** SKIP (DML/DDL)

```sql
CREATE TABLE fact_telemetry_p2024_05
    PARTITION OF fact_telemetry_partitioned
    FOR VALUES FROM (20240501) TO (20240601);
```

### Q24: 

**Status:** SKIP (DML/DDL)

```sql
CREATE TABLE fact_telemetry_p2024_06
    PARTITION OF fact_telemetry_partitioned
    FOR VALUES FROM (20240601) TO (20240701);
```

### Q25: 3.2 Загрузка данных (распределяются автоматически)

**Status:** SKIP (DML/DDL)

```sql
INSERT INTO fact_telemetry_partitioned
SELECT telemetry_id, date_id, time_id, equipment_id,
       sensor_id, sensor_value, quality_flag, recorded_at
FROM fact_equipment_telemetry;
```

### Q26: 3.3 Проверка распределения данных по секциям

**Status:** FAIL

```sql
SELECT tableoid::regclass AS partition_name,
       COUNT(*) AS row_count,
       MIN(date_id) AS min_date,
       MAX(date_id) AS max_date
FROM fact_telemetry_partitioned
GROUP BY tableoid
ORDER BY partition_name;
```

**Error:** `relation "fact_telemetry_partitioned" does not exist
LINE 5: FROM fact_telemetry_partitioned
             ^
`

### Q27: 3.4 Демонстрация partition pruning

**Status:** FAIL

```sql
EXPLAIN (ANALYZE, COSTS OFF)
SELECT equipment_id, AVG(sensor_value) AS avg_value
FROM fact_telemetry_partitioned
WHERE date_id BETWEEN 20240115 AND 20240120
GROUP BY equipment_id;
```

**Error:** `relation "fact_telemetry_partitioned" does not exist
LINE 3: FROM fact_telemetry_partitioned
             ^
`

### Q28: 3.5 LIST-секционирование по шахтам (добыча)

**Status:** SKIP (DML/DDL)

```sql
CREATE TABLE fact_production_by_mine (
    production_id   BIGINT,
    date_id         INTEGER NOT NULL,
    mine_id         INTEGER NOT NULL,
    shift_id        INTEGER,
    equipment_id    INTEGER,
    operator_id     INTEGER,
    location_id     INTEGER,
    tons_mined      NUMERIC(10,2),
    tons_transported NUMERIC(10,2),
    trips_count     INTEGER,
    fuel_consumed_l NUMERIC(8,2),
    operating_hours NUMERIC(6,2)
) PARTITION BY LIST (mine_id);
```

### Q29: 

**Status:** SKIP (DML/DDL)

```sql
CREATE TABLE fact_production_mine_north
    PARTITION OF fact_production_by_mine
    FOR VALUES IN (1);
```

### Q30: 

**Status:** SKIP (DML/DDL)

```sql
CREATE TABLE fact_production_mine_south
    PARTITION OF fact_production_by_mine
    FOR VALUES IN (2);
```

### Q31: 3.6 Загрузка данных

**Status:** SKIP (DML/DDL)

```sql
INSERT INTO fact_production_by_mine
SELECT production_id, date_id, mine_id, shift_id, equipment_id,
       operator_id, location_id, tons_mined, tons_transported,
       trips_count, fuel_consumed_l, operating_hours
FROM fact_production;
```

### Q32: 3.7 Partition pruning по шахте

**Status:** FAIL

```sql
EXPLAIN (ANALYZE, COSTS OFF)
SELECT date_id, SUM(tons_mined) AS total_mined
FROM fact_production_by_mine
WHERE mine_id = 1
GROUP BY date_id
ORDER BY date_id;
```

**Error:** `relation "fact_production_by_mine" does not exist
LINE 3: FROM fact_production_by_mine
             ^
`

### Q33: Создаём BRIN-индекс внутри каждой секции

**Status:** SKIP (DML/DDL)

```sql
CREATE INDEX idx_tel_p2024_01_brin
    ON fact_telemetry_p2024_01 USING brin (recorded_at);
```

### Q34: 

**Status:** SKIP (DML/DDL)

```sql
CREATE INDEX idx_tel_p2024_02_brin
    ON fact_telemetry_p2024_02 USING brin (recorded_at);
```

### Q35: 

**Status:** SKIP (DML/DDL)

```sql
CREATE INDEX idx_tel_p2024_03_brin
    ON fact_telemetry_p2024_03 USING brin (recorded_at);
```

### Q36: 

**Status:** SKIP (DML/DDL)

```sql
CREATE INDEX idx_tel_p2024_04_brin
    ON fact_telemetry_p2024_04 USING brin (recorded_at);
```

### Q37: 

**Status:** SKIP (DML/DDL)

```sql
CREATE INDEX idx_tel_p2024_05_brin
    ON fact_telemetry_p2024_05 USING brin (recorded_at);
```

### Q38: 

**Status:** SKIP (DML/DDL)

```sql
CREATE INDEX idx_tel_p2024_06_brin
    ON fact_telemetry_p2024_06 USING brin (recorded_at);
```

### Q39: 4.2 Запрос с двойной оптимизацией (pruning + BRIN)

**Status:** FAIL

```sql
EXPLAIN (ANALYZE, BUFFERS)
SELECT e.equipment_name,
       AVG(t.sensor_value) AS avg_value,
       COUNT(*) AS readings
FROM fact_telemetry_partitioned t
JOIN dim_equipment e ON t.equipment_id = e.equipment_id
WHERE t.date_id BETWEEN 20240201 AND 20240315
GROUP BY e.equipment_name
ORDER BY avg_value DESC;
```

**Error:** `relation "fact_telemetry_partitioned" does not exist
LINE 5: FROM fact_telemetry_partitioned t
             ^
`

### Q40: Использует partition pruning + BRIN + JOIN с измерениями

**Status:** FAIL

```sql
EXPLAIN (ANALYZE, BUFFERS)
SELECT m.mine_name,
       d.month_name,
       AVG(t.sensor_value) AS avg_temperature,
       MIN(t.sensor_value) AS min_temperature,
       MAX(t.sensor_value) AS max_temperature
FROM fact_telemetry_partitioned t
JOIN dim_equipment e ON t.equipment_id = e.equipment_id
JOIN dim_mine m ON e.mine_id = m.mine_id
JOIN dim_sensor s ON t.sensor_id = s.sensor_id
JOIN dim_date d ON t.date_id = d.date_id
WHERE s.sensor_type_id = 1  -- температура
  AND t.date_id BETWEEN 20240101 AND 20240331
GROUP BY m.mine_name, d.month_name, d.month
ORDER BY d.month;
```

**Error:** `relation "fact_telemetry_partitioned" does not exist
LINE 7: FROM fact_telemetry_partitioned t
             ^
`

### Q41: 5.1 Список всех секций таблицы

**Status:** PASS

```sql
SELECT parent.relname AS parent_table,
       child.relname AS partition_name,
       pg_size_pretty(pg_relation_size(child.oid)) AS partition_size
FROM pg_inherits
JOIN pg_class parent ON pg_inherits.inhparent = parent.oid
JOIN pg_class child ON pg_inherits.inhrelid = child.oid
WHERE parent.relname = 'fact_telemetry_partitioned'
ORDER BY child.relname;
```

**Rows returned:** 0 (showing first 0)

| parent_table | partition_name | partition_size |
|--------------|----------------|----------------|

### Q42: 5.2 Все BRIN-индексы в базе данных

**Status:** PASS

```sql
SELECT schemaname, tablename, indexname,
       pg_size_pretty(pg_relation_size(indexname::regclass)) AS index_size
FROM pg_indexes
WHERE indexdef LIKE '%brin%'
ORDER BY tablename, indexname;
```

**Rows returned:** 0 (showing first 0)

| schemaname | tablename | indexname | index_size |
|------------|-----------|-----------|------------|

### Q43: 5.3 Сравнение размеров всех вариантов хранения телеметрии

**Status:** FAIL

```sql
SELECT 'heap (original)' AS storage_type,
       pg_size_pretty(pg_total_relation_size('fact_equipment_telemetry')) AS total_size
UNION ALL
SELECT 'columnar (Citus)',
       pg_size_pretty(pg_total_relation_size('fact_telemetry_columnar'))
UNION ALL
SELECT 'partitioned (RANGE)',
       pg_size_pretty(
           (SELECT SUM(pg_total_relation_size(child.oid))
            FROM pg_inherits
            JOIN pg_class child ON pg_inherits.inhrelid = child.oid
            JOIN pg_class parent ON pg_inherits.inhparent = parent.oid
            WHERE parent.relname = 'fact_telemetry_partitioned')
       );
```

**Error:** `relation "fact_telemetry_columnar" does not exist
LINE 5:        pg_size_pretty(pg_total_relation_size('fact_telemetry...
                                                     ^
`

### Q44: 5.4 Статистика использования индексов

**Status:** PASS

```sql
SELECT schemaname, relname, indexrelname,
       idx_scan AS index_scans,
       pg_size_pretty(pg_relation_size(indexrelid)) AS index_size
FROM pg_stat_user_indexes
WHERE relname LIKE 'fact_%telemetry%'
ORDER BY idx_scan DESC;
```

**Rows returned:** 5 (showing first 5)

| schemaname | relname                  | indexrelname                  | index_scans | index_size |
|------------|--------------------------|-------------------------------|-------------|------------|
| public     | fact_equipment_telemetry | idx_fact_telemetry_date       | 16          | 152 kB     |
| public     | fact_equipment_telemetry | idx_fact_telemetry_equip      | 7           | 152 kB     |
| public     | fact_equipment_telemetry | fact_equipment_telemetry_pkey | 0           | 432 kB     |
| public     | fact_equipment_telemetry | idx_fact_telemetry_time       | 0           | 168 kB     |
| public     | fact_equipment_telemetry | idx_fact_telemetry_sensor     | 0           | 184 kB     |

### Q45: Citus Columnar: максимальное сжатие, только чтение

**Status:** SKIP (DML/DDL)

```sql
CREATE TABLE fact_telemetry_archive_2023 (
    telemetry_id    BIGINT,
    date_id         INTEGER,
    time_id         INTEGER,
    equipment_id    INTEGER,
    sensor_id       INTEGER,
    sensor_value    NUMERIC(12,4),
    quality_flag    VARCHAR(10),
    recorded_at     TIMESTAMP
) USING columnar;
```

### Q46: Перенос старых данных в архив

**Status:** SKIP (DML/DDL)

```sql
INSERT INTO fact_telemetry_archive_2023
SELECT telemetry_id, date_id, time_id, equipment_id,
       sensor_id, sensor_value, quality_flag, recorded_at
FROM fact_equipment_telemetry
WHERE date_id < 20240101;
```

---

## Module 10

**File:** `C:\Users\dstrelnikov\Documents\SQL\module_10\examples.sql`

### Q1: Оборудование с добычей выше средней по предприятию

**Status:** PASS

```sql
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
```

**Rows returned:** 3 (showing first 3)

| equipment_name | type_name        | avg_tons_per_shift |
|----------------|------------------|--------------------|
| Самосвал-001   | Шахтный самосвал | 157.76             |
| Самосвал-002   | Шахтный самосвал | 152.93             |
| Самосвал-004   | Шахтный самосвал | 147.49             |

### Q2: 1.2 Скалярный подзапрос в SELECT — отклонение от средней

**Status:** PASS

```sql
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
```

**Rows returned:** 8 (showing first 5)

| equipment_name | avg_tons | overall_avg | deviation |
|----------------|----------|-------------|-----------|
| Самосвал-001   | 157.76   | 103.34      | 54.42     |
| Самосвал-002   | 152.93   | 103.34      | 49.59     |
| Самосвал-004   | 147.49   | 103.34      | 44.15     |
| ПДМ-004        | 78.32    | 103.34      | -25.02    |
| ПДМ-006        | 76.74    | 103.34      | -26.60    |

### Q3: 1.3 Скалярный подзапрос в FROM — использование как константы

**Status:** PASS

```sql
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
```

**Rows returned:** 2 (showing first 2)

| mine_name        | mine_total | enterprise_total | share_pct |
|------------------|------------|------------------|-----------|
| Шахта "Северная" | 83809      | 866408.31        | 9.7       |
| Шахта "Южная"    | 48000      | 866408.31        | 5.5       |

### Q4: 2.1 IN — операторы, работавшие на ПДМ

**Status:** PASS

```sql
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
```

**Rows returned:** 5 (showing first 5)

| last_name | operator_name | position     | qualification |
|-----------|---------------|--------------|---------------|
| Иванов    | Иванов А.     | Машинист ПДМ | 5 разряд      |
| Кузнецов  | Кузнецов И.   | Машинист ПДМ | 3 разряд      |
| Морозов   | Морозов В.    | Машинист ПДМ | 5 разряд      |
| Новиков   | Новиков М.    | Машинист ПДМ | 4 разряд      |
| Петров    | Петров С.     | Машинист ПДМ | 5 разряд      |

### Q5: 2.2 NOT IN — шахты без внеплановых простоев за месяц

**Status:** PASS

```sql
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
```

**Rows returned:** 0 (showing first 0)

| mine_name | mine_code |
|-----------|-----------|

### Q6: Даты с аномально высокой добычей (выше 2 стандартных отклонений)

**Status:** PASS

```sql
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
-- ... (truncated)
```

**Rows returned:** 0 (showing first 0)

| full_date | day_of_week_name | daily_tons |
|-----------|------------------|------------|

### Q7: 3.1 > ALL — добыча превышает максимум всех самосвалов

**Status:** PASS

```sql
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
-- ... (truncated)
```

**Rows returned:** 0 (showing first 0)

| equipment_name | type_name | tons_mined |
|----------------|-----------|------------|

### Q8: (эквивалент > MIN)

**Status:** PASS

```sql
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
```

**Rows returned:** 1 (showing first 1)

| count |
|-------|
| 3169  |

### Q9: 3.3 = ANY — эквивалент IN

**Status:** PASS

```sql
SELECT e.equipment_name
FROM dim_equipment e
WHERE e.mine_id = ANY (
    SELECT mine_id FROM dim_mine WHERE region = 'Курская область'
);
```

**Rows returned:** 10 (showing first 5)

| equipment_name |
|----------------|
| ПДМ-001        |
| ПДМ-002        |
| ПДМ-003        |
| Самосвал-001   |
| Самосвал-002   |

### Q10: 4.1 Для каждого оборудования — дата максимальной добычи

**Status:** PASS

```sql
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
```

**Rows returned:** 8 (showing first 5)

| equipment_name | full_date  | tons_mined |
|----------------|------------|------------|
| Самосвал-001   | 2024-06-21 | 237.41     |
| Самосвал-002   | 2024-06-24 | 230.75     |
| Самосвал-004   | 2024-06-05 | 223.90     |
| ПДМ-004        | 2025-06-16 | 118.80     |
| ПДМ-006        | 2024-06-13 | 115.74     |

### Q11: 4.2 Смены с добычей выше средней по данному оборудованию

**Status:** PASS

```sql
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
-- ... (truncated)
```

**Rows returned:** 15 (showing first 5)

| equipment_name | full_date  | shift_name    | tons_mined | equip_avg |
|----------------|------------|---------------|------------|-----------|
| Самосвал-001   | 2024-06-21 | Ночная смена  | 237.41     | 157.76    |
| Самосвал-001   | 2024-06-12 | Ночная смена  | 237.16     | 157.76    |
| Самосвал-001   | 2025-06-18 | Ночная смена  | 236.14     | 157.76    |
| Самосвал-001   | 2025-06-23 | Дневная смена | 235.27     | 157.76    |
| Самосвал-001   | 2025-06-06 | Дневная смена | 234.91     | 157.76    |

### Q12: Для каждой шахты — число уникальных операторов и единиц оборудования

**Status:** PASS

```sql
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
-- ... (truncated)
```

**Rows returned:** 2 (showing first 2)

| mine_name        | operators_count | equipment_count | total_tons |
|------------------|-----------------|-----------------|------------|
| Шахта "Северная" | 5               | 5               | 83809      |
| Шахта "Южная"    | 3               | 3               | 48000      |

### Q13: 4.4 Коррелированный подзапрос для «последней записи»

**Status:** PASS

```sql
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
```

**Rows returned:** 14 (showing first 5)

| equipment_name | last_production_date | tons_mined | last_operator |
|----------------|----------------------|------------|---------------|
| ПДМ-001        | 2025-06-30           | 77.52      | Иванов А.     |
| ПДМ-002        | 2025-06-30           | 102.15     | Петров С.     |
| ПДМ-003        | 2025-06-30           | 77.95      | Кузнецов И.   |
| ПДМ-004        | 2025-06-30           | 90.68      | Новиков М.    |
| ПДМ-006        | 2025-06-30           | 102.25     | Морозов В.    |

### Q14: 5.1 EXISTS — оборудование с внеплановыми простоями

**Status:** PASS

```sql
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
```

**Rows returned:** 5 (showing first 5)

| equipment_name | type_name                     | mine_name        |
|----------------|-------------------------------|------------------|
| ПДМ-001        | Погрузочно-доставочная машина | Шахта "Северная" |
| ПДМ-002        | Погрузочно-доставочная машина | Шахта "Северная" |
| ПДМ-004        | Погрузочно-доставочная машина | Шахта "Южная"    |
| Самосвал-001   | Шахтный самосвал              | Шахта "Северная" |
| Самосвал-004   | Шахтный самосвал              | Шахта "Южная"    |

### Q15: 5.2 NOT EXISTS — операторы без внеплановых простоев

**Status:** PASS

```sql
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
```

**Rows returned:** 6 (showing first 5)

| operator_name | position           | qualification |
|---------------|--------------------|---------------|
| Волков Н.     | Машинист самосвала | 4 разряд      |
| Козлов А.     | Машинист самосвала | 5 разряд      |
| Кузнецов И.   | Машинист ПДМ       | 3 разряд      |
| Лебедев Е.    | Оператор подъёма   | 4 разряд      |
| Морозов В.    | Машинист ПДМ       | 5 разряд      |

### Q16: 5.3 NOT EXISTS — дни без добычи для оборудования

**Status:** PASS

```sql
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
```

**Rows returned:** 31 (showing first 5)

| full_date  | day_of_week_name | is_weekend |
|------------|------------------|------------|
| 2024-03-01 | Пятница          | False      |
| 2024-03-02 | Суббота          | True       |
| 2024-03-03 | Воскресенье      | True       |
| 2024-03-04 | Понедельник      | False      |
| 2024-03-05 | Вторник          | False      |

### Q17: 5.4 EXISTS vs IN — сравнение планов

**Status:** PASS

```sql
EXPLAIN ANALYZE
SELECT DISTINCT e.equipment_name
FROM dim_equipment e
WHERE e.equipment_id IN (
    SELECT fd.equipment_id
    FROM fact_equipment_downtime fd
    WHERE fd.is_planned = FALSE
);
```

**Rows returned:** 12 (showing first 5)

| QUERY PLAN                                         |
|----------------------------------------------------|
| Unique  (cost=38.27..38.31 rows=8 width=318) (a... |
|   ->  Sort  (cost=38.27..38.29 rows=8 width=318... |
|         Sort Key: e.equipment_name                 |
|         Sort Method: quicksort  Memory: 25kB       |
|         ->  Nested Loop Semi Join  (cost=0.28..... |

### Q18: 

**Status:** PASS

```sql
EXPLAIN ANALYZE
SELECT e.equipment_name
FROM dim_equipment e
WHERE EXISTS (
    SELECT 1
    FROM fact_equipment_downtime fd
    WHERE fd.equipment_id = e.equipment_id
      AND fd.is_planned = FALSE
);
```

**Rows returned:** 8 (showing first 5)

| QUERY PLAN                                         |
|----------------------------------------------------|
| Nested Loop Semi Join  (cost=0.28..38.15 rows=8... |
|   ->  Seq Scan on dim_equipment e  (cost=0.00..... |
|   ->  Index Scan using idx_fact_downtime_equip ... |
|         Index Cond: (equipment_id = e.equipment... |
|         Filter: (NOT is_planned)                   |

### Q19: Топ-3 оператора по добыче в каждой шахте

**Status:** PASS

```sql
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
-- ... (truncated)
```

**Rows returned:** 6 (showing first 5)

| mine_name        | operator_name | total_tons | rn |
|------------------|---------------|------------|----|
| Шахта "Северная" | Сидоров Д.    | 25638.0    | 1  |
| Шахта "Северная" | Козлов А.     | 23982.5    | 2  |
| Шахта "Северная" | Иванов А.     | 11851.7    | 3  |
| Шахта "Южная"    | Волков Н.     | 23303.5    | 1  |
| Шахта "Южная"    | Морозов В.    | 12415.9    | 2  |

### Q20: Средняя дневная добыча по шахтам

**Status:** PASS

```sql
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
-- ... (truncated)
```

**Rows returned:** 2 (showing first 2)

| mine_name        | avg_daily_tons | min_daily_tons | max_daily_tons | working_days |
|------------------|----------------|----------------|----------------|--------------|
| Шахта "Северная" | 921.0          | 497.3          | 1219.3         | 91           |
| Шахта "Южная"    | 527.5          | 218.1          | 710.0          | 91           |

### Q21: 7.1 Многоуровневые подзапросы: оборудование-передовик с простоями

**Status:** PASS

```sql
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
-- ... (truncated)
```

**Rows returned:** 2 (showing first 2)

| mine_name        | top_equip_with_downtime | avg_downtime_min | total_downtime_hours |
|------------------|-------------------------|------------------|----------------------|
| Шахта "Северная" | 1                       | 123.1            | 18.5                 |
| Шахта "Южная"    | 1                       | 105.2            | 14.0                 |

### Q22: 7.2 Расчёт OEE через коррелированные подзапросы

**Status:** PASS

```sql
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
-- ... (truncated)
```

**Rows returned:** 17 (showing first 5)

| equipment_name | type_name                     | availability_pct | work_hours | downtime_hours |
|----------------|-------------------------------|------------------|------------|----------------|
| Самосвал-002   | Шахтный самосвал              | 98.1             | 1871.3     | 37.0           |
| ПДМ-006        | Погрузочно-доставочная машина | 98.1             | 1878.2     | 37.0           |
| ПДМ-003        | Погрузочно-доставочная машина | 98.0             | 1859.1     | 37.0           |
| Самосвал-004   | Шахтный самосвал              | 97.3             | 1855.3     | 51.0           |
| Самосвал-001   | Шахтный самосвал              | 97.2             | 1916.7     | 55.5           |

---

## Module 13

**File:** `C:\Users\dstrelnikov\Documents\SQL\module_13\examples.sql`

### Q1: Добавляет общую сумму добычи ко всем строкам

**Status:** PASS

```sql
SELECT
    e.equipment_name,
    fp.tons_mined,
    SUM(fp.tons_mined) OVER () AS grand_total,
    ROUND(fp.tons_mined * 100.0 / SUM(fp.tons_mined) OVER (), 2)
        AS pct_of_total
FROM fact_production fp
JOIN dim_equipment e ON e.equipment_id = fp.equipment_id
WHERE fp.date_id = 20240115 AND fp.shift_id = 1;
```

**Rows returned:** 8 (showing first 5)

| equipment_name | tons_mined | grand_total | pct_of_total |
|----------------|------------|-------------|--------------|
| ПДМ-001        | 80.21      | 799.02      | 10.04        |
| ПДМ-002        | 63.49      | 799.02      | 7.95         |
| ПДМ-003        | 69.08      | 799.02      | 8.65         |
| ПДМ-004        | 86.57      | 799.02      | 10.83        |
| ПДМ-006        | 62.96      | 799.02      | 7.88         |

### Q2: 1.2 PARTITION BY: итого по шахтам

**Status:** PASS

```sql
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
-- ... (truncated)
```

**Rows returned:** 8 (showing first 5)

| equipment_name | mine_name        | tons_mined | mine_total | pct_of_mine | equipment_count_in_mine |
|----------------|------------------|------------|------------|-------------|-------------------------|
| Самосвал-001   | Шахта "Северная" | 124.57     | 498.10     | 25.0        | 5                       |
| Самосвал-002   | Шахта "Северная" | 160.75     | 498.10     | 32.3        | 5                       |
| ПДМ-001        | Шахта "Северная" | 80.21      | 498.10     | 16.1        | 5                       |
| ПДМ-002        | Шахта "Северная" | 63.49      | 498.10     | 12.7        | 5                       |
| ПДМ-003        | Шахта "Северная" | 69.08      | 498.10     | 13.9        | 5                       |

### Q3: 1.3 PARTITION BY с несколькими столбцами

**Status:** PASS

```sql
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
-- ... (truncated)
```

**Rows returned:** 16 (showing first 5)

| mine_name        | shift_name    | equipment_name | tons_mined | mine_shift_total | mine_shift_avg      |
|------------------|---------------|----------------|------------|------------------|---------------------|
| Шахта "Северная" | Дневная смена | Самосвал-001   | 124.57     | 498.10           | 99.6200000000000000 |
| Шахта "Северная" | Дневная смена | ПДМ-002        | 63.49      | 498.10           | 99.6200000000000000 |
| Шахта "Северная" | Дневная смена | ПДМ-003        | 69.08      | 498.10           | 99.6200000000000000 |
| Шахта "Северная" | Дневная смена | ПДМ-001        | 80.21      | 498.10           | 99.6200000000000000 |
| Шахта "Северная" | Дневная смена | Самосвал-002   | 160.75     | 498.10           | 99.6200000000000000 |

### Q4: 2.1 Нарастающий итог добычи (running total)

**Status:** PASS

```sql
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
```

**Rows returned:** 31 (showing first 5)

| full_date  | daily_tons | running_total |
|------------|------------|---------------|
| 2024-01-01 | 1010.56    | 1010.56       |
| 2024-01-02 | 966.05     | 1976.61       |
| 2024-01-03 | 1003.54    | 2980.15       |
| 2024-01-04 | 1012.47    | 3992.62       |
| 2024-01-05 | 876.40     | 4869.02       |

### Q5: 2.2 Нарастающий итог с разбивкой по шахтам

**Status:** PASS

```sql
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
```

**Rows returned:** 24 (showing first 5)

| year_month | mine_name        | month_tons | cumulative_tons |
|------------|------------------|------------|-----------------|
| 2024-01    | Шахта "Северная" | 27398.61   | 27398.61        |
| 2024-02    | Шахта "Северная" | 27067.91   | 54466.52        |
| 2024-03    | Шахта "Северная" | 29342.24   | 83808.76        |
| 2024-04    | Шахта "Северная" | 31435.03   | 115243.79       |
| 2024-05    | Шахта "Северная" | 32318.89   | 147562.68       |

### Q6: 2.3 Нарастающее количество рейсов

**Status:** PASS

```sql
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
```

**Rows returned:** 31 (showing first 5)

| full_date  | daily_trips | cumulative_trips | cumulative_distance_km |
|------------|-------------|------------------|------------------------|
| 2024-01-01 | 58          | 58               | 123.82                 |
| 2024-01-02 | 66          | 124              | 245.39                 |
| 2024-01-03 | 57          | 181              | 372.81                 |
| 2024-01-04 | 61          | 242              | 497.50                 |
| 2024-01-05 | 60          | 302              | 602.97                 |

### Q7: 3.1 Скользящее среднее за 7 дней (ROWS)

**Status:** PASS

```sql
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
-- ... (truncated)
```

**Rows returned:** 91 (showing first 5)

| full_date  | daily_tons | ma_7d   | ma_15d  |
|------------|------------|---------|---------|
| 2024-01-01 | 1010.56    | 1010.56 | 1010.56 |
| 2024-01-02 | 966.05     | 988.31  | 988.31  |
| 2024-01-03 | 1003.54    | 993.38  | 993.38  |
| 2024-01-04 | 1012.47    | 998.16  | 998.16  |
| 2024-01-05 | 876.40     | 973.80  | 973.80  |

### Q8: 3.2 Скользящий максимум и минимум

**Status:** PASS

```sql
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
-- ... (truncated)
```

**Rows returned:** 60 (showing first 5)

| full_date  | daily_tons | min_7d  | max_7d  | range_7d |
|------------|------------|---------|---------|----------|
| 2024-01-01 | 1010.56    | 1010.56 | 1010.56 | 0.00     |
| 2024-01-02 | 966.05     | 966.05  | 1010.56 | 44.51    |
| 2024-01-03 | 1003.54    | 966.05  | 1010.56 | 44.51    |
| 2024-01-04 | 1012.47    | 966.05  | 1012.47 | 46.42    |
| 2024-01-05 | 876.40     | 876.40  | 1012.47 | 136.07   |

### Q9: 3.3 Центрированное скользящее среднее

**Status:** PASS

```sql
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
```

**Rows returned:** 31 (showing first 5)

| full_date  | daily_tons | centered_ma_7d |
|------------|------------|----------------|
| 2024-01-01 | 1010.56    | 998.16         |
| 2024-01-02 | 966.05     | 973.80         |
| 2024-01-03 | 1003.54    | 911.82         |
| 2024-01-04 | 1012.47    | 866.69         |
| 2024-01-05 | 876.40     | 868.00         |

### Q10: (явный нарастающий итог)

**Status:** PASS

```sql
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
```

**Rows returned:** 31 (showing first 5)

| full_date  | daily_fuel | cumulative_fuel |
|------------|------------|-----------------|
| 2024-01-01 | 1511.49    | 1511.49         |
| 2024-01-02 | 1557.01    | 3068.50         |
| 2024-01-03 | 1531.46    | 4599.96         |
| 2024-01-04 | 1591.47    | 6191.43         |
| 2024-01-05 | 1300.73    | 7492.16         |

### Q11: (остаток до конца)

**Status:** PASS

```sql
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
```

**Rows returned:** 31 (showing first 5)

| full_date  | daily_tons | remaining_total |
|------------|------------|-----------------|
| 2024-01-01 | 1010.56    | 27398.61        |
| 2024-01-02 | 966.05     | 26388.05        |
| 2024-01-03 | 1003.54    | 25422.00        |
| 2024-01-04 | 1012.47    | 24418.46        |
| 2024-01-05 | 876.40     | 23405.99        |

### Q12: 4.1 Доля оператора с накопительным процентом (Парето)

**Status:** PASS

```sql
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
-- ... (truncated)
```

**Rows returned:** 8 (showing first 5)

| operator   | total_tons | pct_total | cumulative_pct |
|------------|------------|-----------|----------------|
| Сидоров Д. | 8287.32    | 19.2      | 19.2           |
| Козлов А.  | 7769.98    | 18.0      | 37.1           |
| Волков Н.  | 7635.91    | 17.7      | 54.8           |
| Морозов В. | 4138.72    | 9.6       | 64.3           |
| Иванов А.  | 4081.43    | 9.4       | 73.8           |

### Q13: 4.2 Сравнение с средним по группе

**Status:** PASS

```sql
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
-- ... (truncated)
```

**Rows returned:** 8 (showing first 5)

| equipment_name | type_name                     | total_tons | avg_for_type | diff_from_avg | performance   |
|----------------|-------------------------------|------------|--------------|---------------|---------------|
| ПДМ-006        | Погрузочно-доставочная машина | 12415.86   | 11776.97     | 638.89        | Выше среднего |
| ПДМ-004        | Погрузочно-доставочная машина | 12280.72   | 11776.97     | 503.75        | Выше среднего |
| ПДМ-001        | Погрузочно-доставочная машина | 11851.73   | 11776.97     | 74.76         | Выше среднего |
| ПДМ-002        | Погрузочно-доставочная машина | 11564.93   | 11776.97     | -212.04       | Ниже среднего |
| ПДМ-003        | Погрузочно-доставочная машина | 10771.63   | 11776.97     | -1005.34      | Ниже среднего |

### Q14: 5.1 Сравнение ROW_NUMBER, RANK, DENSE_RANK

**Status:** PASS

```sql
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
```

**Rows returned:** 8 (showing first 5)

| last_name | total_tons | row_num | rank_val | dense_rank_val | tercile |
|-----------|------------|---------|----------|----------------|---------|
| Сидоров   | 8287.32    | 1       | 1        | 1              | 1       |
| Козлов    | 7769.98    | 2       | 2        | 2              | 1       |
| Волков    | 7635.91    | 3       | 3        | 3              | 1       |
| Морозов   | 4138.72    | 4       | 4        | 4              | 2       |
| Иванов    | 4081.43    | 5       | 5        | 5              | 2       |

### Q15: 5.2 ТОП-3 дня по добыче для каждого оборудования

**Status:** PASS

```sql
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
-- ... (truncated)
```

**Rows returned:** 24 (showing first 5)

| equipment_name | full_date  | daily_tons |
|----------------|------------|------------|
| ПДМ-001        | 2024-07-30 | 219.07     |
| ПДМ-001        | 2024-06-26 | 209.89     |
| ПДМ-001        | 2024-06-13 | 207.13     |
| ПДМ-002        | 2024-06-19 | 207.08     |
| ПДМ-002        | 2024-06-04 | 203.55     |

### Q16: 5.3 Ранжирование оборудования по надёжности

**Status:** PASS

```sql
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
-- ... (truncated)
```

**Rows returned:** 5 (showing first 5)

| equipment_name | type_name                     | downtime_events | avg_downtime_min | total_downtime_min | reliability_rank |
|----------------|-------------------------------|-----------------|------------------|--------------------|------------------|
| ПДМ-004        | Погрузочно-доставочная машина | 67              | 117              | 7859.37            | 1                |
| ПДМ-001        | Погрузочно-доставочная машина | 64              | 131              | 8392.77            | 2                |
| ПДМ-002        | Погрузочно-доставочная машина | 74              | 116              | 8612.19            | 3                |
| Самосвал-001   | Шахтный самосвал              | 60              | 126              | 7568.26            | 1                |
| Самосвал-004   | Шахтный самосвал              | 70              | 117              | 8214.41            | 2                |

### Q17: 5.4 NTILE: сегментация по эффективности

**Status:** PASS

```sql
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
-- ... (truncated)
```

**Rows returned:** 8 (showing first 5)

| equipment_id | equipment_name | type_name                     | tons_per_hour | efficiency_quartile | efficiency_category   |
|--------------|----------------|-------------------------------|---------------|---------------------|-----------------------|
| 7            | Самосвал-001   | Шахтный самосвал              | 14.47         | 1                   | Высокая эффективность |
| 8            | Самосвал-002   | Шахтный самосвал              | 13.93         | 1                   | Высокая эффективность |
| 10           | Самосвал-004   | Шахтный самосвал              | 13.67         | 2                   | Выше среднего         |
| 4            | ПДМ-004        | Погрузочно-доставочная машина | 7.22          | 2                   | Выше среднего         |
| 6            | ПДМ-006        | Погрузочно-доставочная машина | 7.10          | 3                   | Ниже среднего         |

### Q18: (если несколько записей за одну смену для одного оборудования)

**Status:** PASS

```sql
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
```

**Rows returned:** 8384 (showing first 5)

| production_id | date_id  | shift_id | mine_id | shaft_id | equipment_id | operator_id | location_id | ore_grade_id | tons_mined | tons_transported | trips_count | distance_km | fuel_consumed_l | operating_hours | loaded_at                  | rn |
|---------------|----------|----------|---------|----------|--------------|-------------|-------------|--------------|------------|------------------|-------------|-------------|-----------------|-----------------|----------------------------|----|
| 1             | 20240101 | 1        | 1       | 3        | 1            | 1           | 1           | 4            | 71.32      | 88.36            | 6           | 9.28        | 113.02          | 10.59           | 2026-03-18 11:45:41.511587 | 1  |
| 2             | 20240101 | 1        | 1       | 3        | 2            | 2           | 2           | 1            | 75.88      | 78.94            | 6           | 9.76        | 110.70          | 10.06           | 2026-03-18 11:45:41.511587 | 1  |
| 3             | 20240101 | 1        | 1       | 4        | 3            | 10          | 6           | 3            | 65.15      | 66.43            | 5           | 9.53        | 133.80          | 10.49           | 2026-03-18 11:45:41.511587 | 1  |
| 4             | 20240101 | 1        | 2       | 7        | 4            | 5           | 10          | 2            | 64.61      | 98.43            | 10          | 9.56        | 112.19          | 10.66           | 2026-03-18 11:45:41.511587 | 1  |
| 5             | 20240101 | 1        | 2       | 7        | 6            | 6           | 11          | 1            | 89.71      | 100.67           | 8           | 10.22       | 103.68          | 10.84           | 2026-03-18 11:45:41.511587 | 1  |

### Q19: 6.1 LAG: сравнение с предыдущим днём

**Status:** PASS

```sql
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
-- ... (truncated)
```

**Rows returned:** 31 (showing first 5)

| full_date  | today_tons | yesterday_tons | week_ago_tons | day_over_day_pct |
|------------|------------|----------------|---------------|------------------|
| 2024-01-01 | 1010.56    | NULL           | NULL          | NULL             |
| 2024-01-02 | 966.05     | 1010.56        | NULL          | -4.4             |
| 2024-01-03 | 1003.54    | 966.05         | NULL          | 3.9              |
| 2024-01-04 | 1012.47    | 1003.54        | NULL          | 0.9              |
| 2024-01-05 | 876.40     | 1012.47        | NULL          | -13.4            |

### Q20: 6.2 LEAD: следующий простой

**Status:** PASS

```sql
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
-- ... (truncated)
```

**Rows returned:** 144 (showing first 5)

| equipment_name | downtime_date | reason_name                       | duration_min | next_downtime_date | days_between |
|----------------|---------------|-----------------------------------|--------------|--------------------|--------------|
| ПДМ-001        | 2024-01-15    | Плановое техническое обслуживание | 480.00       | 2024-02-15         | 31           |
| ПДМ-001        | 2024-02-15    | Плановое техническое обслуживание | 480.00       | 2024-03-15         | 29           |
| ПДМ-001        | 2024-03-15    | Плановое техническое обслуживание | 480.00       | 2024-04-15         | 31           |
| ПДМ-001        | 2024-04-15    | Плановое техническое обслуживание | 480.00       | 2024-05-15         | 30           |
| ПДМ-001        | 2024-05-15    | Плановое техническое обслуживание | 480.00       | 2024-06-15         | 31           |

### Q21: 6.3 FIRST_VALUE и LAST_VALUE

**Status:** PASS

```sql
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
-- ... (truncated)
```

**Rows returned:** 91 (showing first 5)

| full_date  | daily_tons | first_day_tons | last_day_tons | best_day_date |
|------------|------------|----------------|---------------|---------------|
| 2024-01-01 | 1010.56    | 1010.56        | 1036.32       | 2024-01-12    |
| 2024-01-02 | 966.05     | 1010.56        | 1036.32       | 2024-01-12    |
| 2024-01-03 | 1003.54    | 1010.56        | 1036.32       | 2024-01-12    |
| 2024-01-04 | 1012.47    | 1010.56        | 1036.32       | 2024-01-12    |
| 2024-01-05 | 876.40     | 1010.56        | 1036.32       | 2024-01-12    |

### Q22: 6.4 NTH_VALUE: второй и третий лучший день в месяце

**Status:** PASS

```sql
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
-- ... (truncated)
```

**Rows returned:** 12 (showing first 5)

| year_month | best_day | second_best_day | third_best_day |
|------------|----------|-----------------|----------------|
| 2024-01    | 1081.82  | 1045.14         | 1043.77        |
| 2024-02    | 1141.87  | 1141.02         | 1113.91        |
| 2024-03    | 1219.29  | 1183.21         | 1179.10        |
| 2024-04    | 1270.86  | 1262.78         | 1244.18        |
| 2024-05    | 1292.32  | 1277.45         | 1270.73        |

### Q23: 6.5 LAG для определения скорости изменения температуры

**Status:** PASS

```sql
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
-- ... (truncated)
```

**Rows returned:** 48 (showing first 5)

| full_date  | hour_minute | temperature | prev_temp | temp_delta | temp_1h_ago | avg_delta_per_15min |
|------------|-------------|-------------|-----------|------------|-------------|---------------------|
| 2024-01-02 | 08:00       | 89.6100     | NULL      | NULL       | NULL        | NULL                |
| 2024-01-02 | 08:15       | 93.7200     | 89.6100   | 4.1100     | NULL        | NULL                |
| 2024-01-02 | 08:30       | 81.6800     | 93.7200   | -12.0400   | NULL        | NULL                |
| 2024-01-02 | 08:45       | 86.0700     | 81.6800   | 4.3900     | NULL        | NULL                |
| 2024-01-02 | 09:00       | 91.1400     | 86.0700   | 5.0700     | 89.6100     | 0.38                |

### Q24: 7.1 PERCENT_RANK и CUME_DIST

**Status:** PASS

```sql
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
-- ... (truncated)
```

**Rows returned:** 8 (showing first 5)

| last_name | type_name                     | tons_per_hour | pct_rank | cume_dist |
|-----------|-------------------------------|---------------|----------|-----------|
| Кузнецов  | Погрузочно-доставочная машина | 6.29          | 0.000    | 0.200     |
| Петров    | Погрузочно-доставочная машина | 6.58          | 0.250    | 0.400     |
| Иванов    | Погрузочно-доставочная машина | 6.87          | 0.500    | 0.600     |
| Морозов   | Погрузочно-доставочная машина | 7.10          | 0.750    | 0.800     |
| Новиков   | Погрузочно-доставочная машина | 7.22          | 1.000    | 1.000     |

### Q25: 7.2 PERCENTILE_CONT: медиана и квартили

**Status:** PASS

```sql
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
```

**Rows returned:** 2 (showing first 2)

| mine_name        | samples_count | avg_fe | q1    | median | q3    | p90   |
|------------------|---------------|--------|-------|--------|-------|-------|
| Шахта "Северная" | 1101          | 56.81  | 52.39 | 59.25  | 60.50 | 64.12 |
| Шахта "Южная"    | 692           | 51.50  | 47.56 | 48.81  | 56.09 | 60.73 |

### Q26: 7.3 IQR-метод для обнаружения выбросов

**Status:** PASS

```sql
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
-- ... (truncated)
```

**Rows returned:** 0 (showing first 0)

| sample_number | full_date | mine_name | fe_content | outlier_status |
|---------------|-----------|-----------|------------|----------------|

### Q27: 8.1 Несколько именованных окон

**Status:** PASS

```sql
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
-- ... (truncated)
```

**Rows returned:** 91 (showing first 5)

| full_date  | daily_tons | avg_7d                | min_7d  | max_7d  | avg_30d               | running_total |
|------------|------------|-----------------------|---------|---------|-----------------------|---------------|
| 2024-01-01 | 1010.56    | 1010.5600000000000000 | 1010.56 | 1010.56 | 1010.5600000000000000 | 1010.56       |
| 2024-01-02 | 966.05     | 988.3050000000000000  | 966.05  | 1010.56 | 988.3050000000000000  | 1976.61       |
| 2024-01-03 | 1003.54    | 993.3833333333333333  | 966.05  | 1010.56 | 993.3833333333333333  | 2980.15       |
| 2024-01-04 | 1012.47    | 998.1550000000000000  | 966.05  | 1012.47 | 998.1550000000000000  | 3992.62       |
| 2024-01-05 | 876.40     | 973.8040000000000000  | 876.40  | 1012.47 | 973.8040000000000000  | 4869.02       |

### Q28: 8.2 Наследование окон

**Status:** PASS

```sql
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
-- ... (truncated)
```

**Rows returned:** 155 (showing first 5)

| full_date  | equipment_id | equipment_name | daily_tons | running_total | avg_7d               | first_day_value |
|------------|--------------|----------------|------------|---------------|----------------------|-----------------|
| 2024-01-01 | 1            | ПДМ-001        | 153.33     | 153.33        | 153.3300000000000000 | 153.33          |
| 2024-01-02 | 1            | ПДМ-001        | 125.75     | 279.08        | 139.5400000000000000 | 153.33          |
| 2024-01-03 | 1            | ПДМ-001        | 125.32     | 404.40        | 134.8000000000000000 | 153.33          |
| 2024-01-04 | 1            | ПДМ-001        | 145.80     | 550.20        | 137.5500000000000000 | 153.33          |
| 2024-01-05 | 1            | ПДМ-001        | 136.13     | 686.33        | 137.2660000000000000 | 153.33          |

### Q29: 9.1 Кейс: предиктивное обслуживание

**Status:** PASS

```sql
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
-- ... (truncated)
```

**Rows returned:** 134 (showing first 5)

| full_date  | hour_minute | type_code   | sensor_value | avg_2h | delta | pct_rank | risk_level |
|------------|-------------|-------------|--------------|--------|-------|----------|------------|
| 2024-01-01 | 08:15       | VIBRATION   | 11.6600      | 9.36   | 4.60  | 0.949    | ВНИМАНИЕ   |
| 2024-01-01 | 08:45       | VIBRATION   | 11.8000      | 9.51   | 4.29  | 0.982    | ОПАСНОСТЬ  |
| 2024-01-01 | 09:00       | VIBRATION   | 10.9700      | 9.80   | -0.83 | 0.854    | ВНИМАНИЕ   |
| 2024-01-01 | 10:00       | TEMP_ENGINE | 100.5900     | 89.10  | 15.38 | 0.946    | ВНИМАНИЕ   |
| 2024-01-01 | 10:15       | TEMP_ENGINE | 98.2800      | 91.91  | -2.31 | 0.872    | ВНИМАНИЕ   |

### Q30: 9.2 Кейс: OEE-дашборд (Overall Equipment Effectiveness)

**Status:** PASS

```sql
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
-- ... (truncated)
```

**Rows returned:** 155 (showing first 5)

| full_date  | equipment_name | tons   | daily_rank | avg_prod_7d | prev_day_tons | trend         | cumulative_tons |
|------------|----------------|--------|------------|-------------|---------------|---------------|-----------------|
| 2024-01-01 | Самосвал-002   | 303.15 | 1          | 14.00       | NULL          | без изменений | 303.15          |
| 2024-01-01 | Самосвал-001   | 263.17 | 2          | 12.40       | NULL          | без изменений | 263.17          |
| 2024-01-01 | ПДМ-001        | 153.33 | 3          | 7.16        | NULL          | без изменений | 153.33          |
| 2024-01-01 | ПДМ-002        | 151.18 | 4          | 7.45        | NULL          | без изменений | 151.18          |
| 2024-01-01 | ПДМ-003        | 139.73 | 5          | 6.53        | NULL          | без изменений | 139.73          |

### Q31: 9.3 Сравнение смен (дневная vs ночная)

**Status:** PASS

```sql
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
-- ... (truncated)
```

**Rows returned:** 62 (showing first 5)

| full_date  | shift_name    | shift_tons | prev_shift_tons | shift_pct_of_day | ma_7d_for_shift |
|------------|---------------|------------|-----------------|------------------|-----------------|
| 2024-01-01 | Дневная смена | 501.99     | NULL            | 49.7             | 501.99          |
| 2024-01-01 | Ночная смена  | 508.57     | 501.99          | 50.3             | 508.57          |
| 2024-01-02 | Дневная смена | 435.15     | 508.57          | 45.0             | 468.57          |
| 2024-01-02 | Ночная смена  | 530.90     | 435.15          | 55.0             | 519.74          |
| 2024-01-03 | Дневная смена | 534.37     | 530.90          | 53.2             | 490.50          |

---

## All Failures

| Module | Query | Description | Error |
|--------|-------|-------------|-------|
| 5 | Q2 | Проверяем результат | relation "practice_dim_downtime_reason" does not exist LINE 1: SELECT * FROM pra |
| 5 | Q4 | Проверяем | relation "practice_dim_ore_grade" does not exist LINE 1: SELECT * FROM practice_ |
| 5 | Q6 | Проверяем: должно появиться 4 новых записи (5-я не | relation "practice_fact_production" does not exist LINE 3: FROM practice_fact_pr |
| 5 | Q8 |  | relation "practice_dim_equipment" does not exist LINE 3: FROM practice_dim_equip |
| 5 | Q11 | Проверяем | relation "practice_dim_equipment" does not exist LINE 2: FROM practice_dim_equip |
| 5 | Q14 | Смотрим, какое оборудование затронуто | relation "practice_dim_equipment" does not exist LINE 2: FROM practice_dim_equip |
| 5 | Q23 | Проверяем результат | relation "practice_dim_downtime_reason" does not exist LINE 1: SELECT * FROM pra |
| 5 | Q26 | Проверяем: оператор с TAB-001 не изменился | relation "practice_dim_operator" does not exist LINE 1: SELECT * FROM practice_d |
| 5 | Q28 | Проверяем: значения обновились | relation "practice_dim_ore_grade" does not exist LINE 1: SELECT * FROM practice_ |
| 5 | Q31 | Проверяем: данные на месте | relation "practice_dim_equipment" does not exist LINE 1: SELECT COUNT(*) FROM pr |
| 5 | Q33 | Проверяем лог | relation "practice_equipment_log" does not exist LINE 1: SELECT * FROM practice_ |
| 8 | Q31 | 7.4 Сравнение размеров: частичный vs полный | relation "idx_downtime_unplanned" does not exist LINE 1: SELECT pg_size_pretty(p |
| 8 | Q33 |  | relation "idx_downtime_full" does not exist LINE 1: SELECT pg_size_pretty(pg_rel |
| 8 | Q53 | 10.4 Сравниваем размеры | relation "idx_telemetry_date_brin" does not exist LINE 3:     pg_size_pretty(pg_ |
| 8 | Q58 | 11.2 Проверка валидности индекса | relation "idx_prod_date_concurrent" does not exist LINE 6: WHERE indexrelid = 'i |
| 9 | Q4 | 1.4 Сравнение размеров строковой и колоночной табл | relation "fact_telemetry_columnar" does not exist LINE 6:        pg_size_pretty( |
| 9 | Q6 | 1.6 Просмотр параметров колоночной таблицы | relation "columnar.options" does not exist LINE 1: SELECT * FROM columnar.option |
| 9 | Q26 | 3.3 Проверка распределения данных по секциям | relation "fact_telemetry_partitioned" does not exist LINE 5: FROM fact_telemetry |
| 9 | Q27 | 3.4 Демонстрация partition pruning | relation "fact_telemetry_partitioned" does not exist LINE 3: FROM fact_telemetry |
| 9 | Q32 | 3.7 Partition pruning по шахте | relation "fact_production_by_mine" does not exist LINE 3: FROM fact_production_b |
| 9 | Q39 | 4.2 Запрос с двойной оптимизацией (pruning + BRIN) | relation "fact_telemetry_partitioned" does not exist LINE 5: FROM fact_telemetry |
| 9 | Q40 | Использует partition pruning + BRIN + JOIN с измер | relation "fact_telemetry_partitioned" does not exist LINE 7: FROM fact_telemetry |
| 9 | Q43 | 5.3 Сравнение размеров всех вариантов хранения тел | relation "fact_telemetry_columnar" does not exist LINE 5:        pg_size_pretty( |
