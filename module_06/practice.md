# Практическая работа — Модуль 6

## Использование встроенных функций

**Продолжительность:** 45 минут
**Инструменты:** Yandex Managed Service for PostgreSQL (SQL) | Power BI + DAX Studio (DAX)
**Предприятие:** «Руда+» — добыча железной руды

---

## Предварительные требования

1. База данных «Руда+» развёрнута на PostgreSQL (скрипты `01_create_schema.sql`, `02_insert_dimensions.sql`, `03_insert_facts.sql` из каталога `common/scripts/`)
2. Модель данных импортирована в Power BI и опубликована (или открыта локально)
3. DAX Studio установлен и подключён к модели Power BI
4. Клиент SQL (DBeaver, pgAdmin или psql) подключён к PostgreSQL

---

## Часть 1. Математические функции (10 мин)

### Шаг 1.1. Округление содержания Fe в пробах

**SQL (PostgreSQL):**

```sql
SELECT
    sample_number,
    fe_content,
    ROUND(fe_content, 1)  AS fe_round_1,
    CEIL(fe_content)      AS fe_ceil,
    FLOOR(fe_content)     AS fe_floor,
    TRUNC(fe_content, 0)  AS fe_trunc
FROM fact_ore_quality
WHERE date_id = 20240315
ORDER BY fe_content DESC
LIMIT 5;
```

**DAX (DAX Studio):**

```dax
EVALUATE
TOPN(5,
    ADDCOLUMNS(
        FILTER(fact_ore_quality,
            fact_ore_quality[date_id] = 20240315),
        "Fe округл.", ROUND(fact_ore_quality[fe_content], 1),
        "Fe вверх",   CEILING(fact_ore_quality[fe_content], 1),
        "Fe вниз",    FLOOR(fact_ore_quality[fe_content], 1)
    ),
    fact_ore_quality[fe_content], DESC
)
```

**Что наблюдаем:**
- ROUND округляет по математическим правилам
- CEIL всегда вверх, FLOOR всегда вниз
- TRUNC просто отбрасывает дробную часть (не округляет)

> **Обратите внимание:** В DAX функции CEILING и FLOOR принимают второй параметр — значимость (significance). Для целых чисел используйте 1.

### Шаг 1.2. Абсолютное отклонение от целевого содержания Fe

Целевое содержание Fe = 60%. Рассчитаем отклонение каждой пробы.

**SQL:**

```sql
SELECT
    sample_number,
    fe_content,
    fe_content - 60.0           AS deviation,
    ABS(fe_content - 60.0)      AS abs_deviation,
    SIGN(fe_content - 60.0)     AS direction,
    CASE SIGN(fe_content - 60.0)
        WHEN  1 THEN 'Выше нормы'
        WHEN  0 THEN 'В норме'
        WHEN -1 THEN 'Ниже нормы'
    END AS status
FROM fact_ore_quality
WHERE date_id BETWEEN 20240301 AND 20240331
ORDER BY abs_deviation DESC
LIMIT 10;
```

**DAX:**

```dax
EVALUATE
TOPN(10,
    ADDCOLUMNS(
        FILTER(fact_ore_quality,
            fact_ore_quality[date_id] >= 20240301
            && fact_ore_quality[date_id] <= 20240331),
        "Отклонение",  fact_ore_quality[fe_content] - 60,
        "Абс. откл.",  ABS(fact_ore_quality[fe_content] - 60),
        "Направление", SIGN(fact_ore_quality[fe_content] - 60),
        "Статус",
            SWITCH(SIGN(fact_ore_quality[fe_content] - 60),
                1,  "Выше нормы",
                0,  "В норме",
                -1, "Ниже нормы")
    ),
    ABS(fact_ore_quality[fe_content] - 60), DESC
)
```

**Что наблюдаем:**
- ABS возвращает модуль числа — убирает знак
- SIGN возвращает -1, 0 или 1 — удобно для классификации
- Комбинация ABS + SIGN позволяет и измерить, и классифицировать отклонение

### Шаг 1.3. POWER и SQRT — компоненты среднеквадратичного отклонения

**SQL:**

```sql
SELECT
    sample_number,
    fe_content,
    POWER(fe_content - 60.0, 2) AS squared_deviation,
    ROUND(SQRT(POWER(fe_content - 60.0, 2)), 2) AS root_squared
FROM fact_ore_quality
WHERE date_id = 20240315;
```

> **Примечание:** SQRT(POWER(x, 2)) = ABS(x). Это демонстрация компонентов, из которых складывается расчёт RMSE (Root Mean Square Error).

---

## Часть 2. Агрегатные функции — углублённый обзор (10 мин)

### Шаг 2.1. Базовая сводка добычи

**SQL:**

```sql
SELECT
    COUNT(*)                        AS total_records,
    COUNT(DISTINCT equipment_id)    AS unique_equipment,
    SUM(tons_mined)                 AS total_tons,
    ROUND(AVG(tons_mined), 2)       AS avg_tons,
    MIN(tons_mined)                 AS min_tons,
    MAX(tons_mined)                 AS max_tons
FROM fact_production
WHERE date_id BETWEEN 20240301 AND 20240331;
```

**DAX:**

```dax
EVALUATE
VAR _march =
    FILTER(fact_production,
        fact_production[date_id] >= 20240301
        && fact_production[date_id] <= 20240331)
RETURN
ROW(
    "Записей",       COUNTROWS(_march),
    "Уник. оборуд.", CALCULATE(DISTINCTCOUNT(fact_production[equipment_id]), _march),
    "Всего тонн",    CALCULATE(SUM(fact_production[tons_mined]), _march),
    "Ср. тонн",      ROUND(CALCULATE(AVERAGE(fact_production[tons_mined]), _march), 2),
    "Мин.",          CALCULATE(MIN(fact_production[tons_mined]), _march),
    "Макс.",         CALCULATE(MAX(fact_production[tons_mined]), _march)
)
```

**Что наблюдаем:**
- COUNT(*) в SQL = COUNTROWS в DAX
- AVG в SQL = AVERAGE в DAX
- COUNT(DISTINCT ...) = DISTINCTCOUNT в DAX

### Шаг 2.2. STRING_AGG / CONCATENATEX — конкатенация строк

**SQL:**

```sql
SELECT
    m.mine_name,
    STRING_AGG(e.equipment_name, ', ' ORDER BY e.equipment_name)
        AS equipment_list,
    COUNT(*) AS total
FROM dim_equipment e
JOIN dim_mine m ON e.mine_id = m.mine_id
WHERE e.status = 'active'
GROUP BY m.mine_name;
```

**DAX:**

```dax
EVALUATE
ADDCOLUMNS(
    VALUES(dim_mine[mine_name]),
    "Оборудование",
        CONCATENATEX(
            FILTER(RELATEDTABLE(dim_equipment),
                dim_equipment[status] = "active"),
            dim_equipment[equipment_name], ", ",
            dim_equipment[equipment_name], ASC
        ),
    "Кол-во",
        CALCULATE(COUNTROWS(dim_equipment), dim_equipment[status] = "active")
)
```

**Что наблюдаем:**
- STRING_AGG (SQL) собирает значения в строку с разделителем
- CONCATENATEX (DAX) — эквивалент, также поддерживает сортировку
- Оба позволяют задать порядок элементов через ORDER BY

### Шаг 2.3. Условные агрегаты — FILTER-клаузула (PostgreSQL)

**SQL:**

```sql
SELECT
    d.full_date,
    COUNT(*) FILTER (WHERE fp.shift_id = 1) AS shift_1_count,
    COUNT(*) FILTER (WHERE fp.shift_id = 2) AS shift_2_count,
    SUM(fp.tons_mined) FILTER (WHERE fp.shift_id = 1) AS tons_shift_1,
    SUM(fp.tons_mined) FILTER (WHERE fp.shift_id = 2) AS tons_shift_2
FROM fact_production fp
JOIN dim_date d ON fp.date_id = d.date_id
WHERE d.year = 2024 AND d.month = 3
GROUP BY d.full_date
ORDER BY d.full_date
LIMIT 5;
```

**DAX:**

```dax
EVALUATE
TOPN(5,
    ADDCOLUMNS(
        SUMMARIZE(
            FILTER(fact_production,
                fact_production[date_id] >= 20240301
                && fact_production[date_id] <= 20240331),
            dim_date[full_date]
        ),
        "Смена 1", CALCULATE(COUNTROWS(fact_production), fact_production[shift_id] = 1),
        "Смена 2", CALCULATE(COUNTROWS(fact_production), fact_production[shift_id] = 2),
        "Тонн см.1", CALCULATE(SUM(fact_production[tons_mined]), fact_production[shift_id] = 1),
        "Тонн см.2", CALCULATE(SUM(fact_production[tons_mined]), fact_production[shift_id] = 2)
    ),
    dim_date[full_date], ASC
)
```

**Что наблюдаем:**
- В PostgreSQL FILTER-клаузула при агрегатах — удобная альтернатива CASE WHEN
- В DAX для условной агрегации используется CALCULATE с фильтром

### Шаг 2.4. Статистические функции

**SQL:**

```sql
SELECT
    ROUND(STDDEV(fe_content), 3) AS std_dev,
    ROUND(VARIANCE(fe_content), 3) AS variance,
    ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY fe_content), 2) AS median_fe,
    ROUND(PERCENTILE_CONT(0.9) WITHIN GROUP (ORDER BY fe_content), 2) AS perc_90
FROM fact_ore_quality
WHERE date_id BETWEEN 20240301 AND 20240331;
```

**DAX:**

```dax
EVALUATE
VAR _data = FILTER(fact_ore_quality,
    fact_ore_quality[date_id] >= 20240301
    && fact_ore_quality[date_id] <= 20240331)
RETURN
ROW(
    "Станд. откл.", CALCULATE(STDEV.S(fact_ore_quality[fe_content]), _data),
    "Медиана",      CALCULATE(MEDIAN(fact_ore_quality[fe_content]), _data),
    "Перц. 90",     CALCULATE(PERCENTILEX.INC(fact_ore_quality, fact_ore_quality[fe_content], 0.9), _data)
)
```

---

## Часть 3. Функции преобразования типов (10 мин)

### Шаг 3.1. CAST и :: — приведение типов

**SQL:**

```sql
-- Стандартный CAST
SELECT
    CAST(date_id AS VARCHAR)    AS date_str,
    CAST('123.45' AS NUMERIC)   AS num_value,
    CAST(tons_mined AS INTEGER) AS tons_int
FROM fact_production
LIMIT 3;

-- Краткий оператор PostgreSQL ::
SELECT
    date_id::VARCHAR               AS date_str,
    '123.45'::NUMERIC              AS num_value,
    tons_mined::INTEGER            AS tons_int
FROM fact_production
LIMIT 3;
```

**DAX:**

```dax
EVALUATE
ROW(
    "Целое",   CONVERT(56.78, INTEGER),
    "Текст",   CONVERT(20240315, STRING),
    "Дробное", CONVERT("123.45", DOUBLE)
)
```

**Что наблюдаем:**
- В SQL два синтаксиса: стандартный CAST и краткий ::
- В DAX используется CONVERT с указанием типа
- Быстрые функции DAX: INT(x), VALUE("строка")

### Шаг 3.2. TO_DATE, TO_CHAR — форматирование

**SQL:**

```sql
-- Строка -> Дата
SELECT TO_DATE('15.03.2024', 'DD.MM.YYYY') AS parsed_date;

-- Число -> Строка с форматированием
SELECT TO_CHAR(12345.678, 'FM999G999D00') AS formatted_num;

-- Дата -> Отформатированная строка
SELECT TO_CHAR(NOW(), 'DD.MM.YYYY HH24:MI') AS formatted_now;

-- Практика: date_id -> читаемая дата
SELECT
    date_id,
    TO_DATE(date_id::VARCHAR, 'YYYYMMDD') AS real_date,
    TO_CHAR(TO_DATE(date_id::VARCHAR, 'YYYYMMDD'), 'DD Mon YYYY') AS formatted
FROM fact_production
WHERE date_id BETWEEN 20240301 AND 20240305
GROUP BY date_id
ORDER BY date_id;
```

**DAX:**

```dax
EVALUATE
ROW(
    "Сегодня",     FORMAT(TODAY(), "DD.MM.YYYY"),
    "Полная дата", FORMAT(TODAY(), "DD MMMM YYYY"),
    "Число",       FORMAT(12345.678, "#,##0.00"),
    "Процент",     FORMAT(0.856, "0.0%")
)
```

**Что наблюдаем:**
- В SQL для форматирования — TO_CHAR, для разбора строк — TO_DATE, TO_TIMESTAMP
- В DAX для форматирования — FORMAT, для разбора — DATEVALUE, TIMEVALUE

### Шаг 3.3. Неявное vs явное преобразование

**SQL:**

```sql
-- Неявное (PostgreSQL при конкатенации с ||):
SELECT 'Добыто: ' || tons_mined || ' тонн' AS message
FROM fact_production LIMIT 1;

-- Явное (рекомендуется):
SELECT 'Добыто: ' || CAST(tons_mined AS VARCHAR) || ' тонн' AS message
FROM fact_production LIMIT 1;

-- ОШИБКА в PostgreSQL (строгая типизация):
-- SELECT '10' + 5;  -- Ошибка!
-- Правильно:
SELECT '10'::INTEGER + 5 AS result;  -- 15
```

> **Рекомендация:** Всегда используйте явное преобразование в производственном коде. Неявное преобразование может вести себя по-разному в разных СУБД.

---

## Часть 4. Условная логика (10 мин)

### Шаг 4.1. CASE WHEN — классификация руды

**SQL:**

```sql
SELECT
    sample_number,
    fe_content,
    CASE
        WHEN fe_content >= 65 THEN 'Богатая руда'
        WHEN fe_content >= 55 THEN 'Средняя руда'
        WHEN fe_content >= 45 THEN 'Бедная руда'
        ELSE 'Забалансовая'
    END AS ore_category,
    CASE
        WHEN fe_content >= 60 THEN 'Соответствует'
        ELSE 'Не соответствует'
    END AS meets_target
FROM fact_ore_quality
WHERE date_id = 20240315
ORDER BY fe_content DESC;
```

**DAX:**

```dax
EVALUATE
ADDCOLUMNS(
    FILTER(fact_ore_quality, fact_ore_quality[date_id] = 20240315),
    "Категория",
        SWITCH(TRUE(),
            fact_ore_quality[fe_content] >= 65, "Богатая руда",
            fact_ore_quality[fe_content] >= 55, "Средняя руда",
            fact_ore_quality[fe_content] >= 45, "Бедная руда",
            "Забалансовая"),
    "Целевой",
        IF(fact_ore_quality[fe_content] >= 60, "Соответствует", "Не соответствует")
)
```

**Что наблюдаем:**
- SQL CASE WHEN проверяет условия сверху вниз, первое истинное срабатывает
- В DAX SWITCH(TRUE(), ...) — эквивалент поискового CASE WHEN
- Для простых условий в DAX достаточно IF

### Шаг 4.2. CASE внутри агрегатных функций

**SQL:**

```sql
SELECT
    d.full_date,
    SUM(CASE WHEN oq.fe_content >= 60 THEN 1 ELSE 0 END) AS good_samples,
    SUM(CASE WHEN oq.fe_content < 60  THEN 1 ELSE 0 END) AS poor_samples,
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

### Шаг 4.3. COALESCE и NULLIF

**SQL:**

```sql
-- COALESCE: подстановка значений по умолчанию
SELECT
    sample_number,
    fe_content,
    COALESCE(sio2_content, 0)  AS sio2_safe,
    COALESCE(al2o3_content, 0) AS al2o3_safe
FROM fact_ore_quality
WHERE date_id = 20240315;

-- NULLIF: защита от деления на ноль
SELECT
    equipment_id,
    tons_transported,
    trips_count,
    ROUND(
        tons_transported / NULLIF(trips_count, 0), 2
    ) AS tons_per_trip
FROM fact_production
WHERE date_id = 20240315;

-- Комбинация: безопасное деление с подстановкой
SELECT
    COALESCE(
        ROUND(tons_transported / NULLIF(trips_count, 0), 2),
        0
    ) AS tons_per_trip_safe
FROM fact_production
WHERE date_id = 20240315;
```

**DAX:**

```dax
// DIVIDE — безопасное деление (одна функция вместо NULLIF + COALESCE)
EVALUATE
ADDCOLUMNS(
    FILTER(fact_production, fact_production[date_id] = 20240315),
    "Тонн/рейс", DIVIDE(fact_production[tons_transported], fact_production[trips_count], 0)
)
```

### Шаг 4.4. GREATEST / LEAST

**SQL:**

```sql
SELECT
    sample_number,
    fe_content,
    COALESCE(sio2_content, 0) AS sio2,
    COALESCE(al2o3_content, 0) AS al2o3,
    GREATEST(COALESCE(sio2_content, 0), COALESCE(al2o3_content, 0)) AS max_impurity,
    -- Clamp: ограничение Fe в диапазоне [40, 70]
    GREATEST(LEAST(fe_content, 70.0), 40.0) AS fe_clamped
FROM fact_ore_quality
WHERE date_id = 20240315;
```

> **Примечание:** В DAX нет GREATEST/LEAST. Используйте MAX(a, b) / MIN(a, b) в вычисляемых столбцах или вложенные IF.

---

## Часть 5. Работа с NULL (5 мин)

### Шаг 5.1. IS NULL, подсчёт пропусков

**SQL:**

```sql
-- Статистика по NULL значениям
SELECT
    COUNT(*) AS total_rows,
    COUNT(sio2_content) AS with_sio2,
    COUNT(*) - COUNT(sio2_content) AS null_sio2,
    ROUND(100.0 * (COUNT(*) - COUNT(sio2_content)) / COUNT(*), 1) AS null_pct
FROM fact_ore_quality;

-- Поиск незавершённых простоев
SELECT fd.downtime_id, e.equipment_name, fd.start_time
FROM fact_equipment_downtime fd
JOIN dim_equipment e ON fd.equipment_id = e.equipment_id
WHERE fd.end_time IS NULL;
```

### Шаг 5.2. Ловушки NULL

**SQL:**

```sql
-- Демонстрация: NULL в логике
SELECT
    CASE WHEN NULL = NULL    THEN 'TRUE' ELSE 'FALSE' END AS test1,   -- FALSE!
    CASE WHEN NULL IS NULL   THEN 'TRUE' ELSE 'FALSE' END AS test2,   -- TRUE
    CASE WHEN NULL <> 1     THEN 'TRUE' ELSE 'FALSE' END AS test3;   -- FALSE!

-- NULL в арифметике
SELECT
    5 + NULL AS result1,      -- NULL
    5 * NULL AS result2,      -- NULL
    COALESCE(5 + NULL, 0) AS result3; -- 0
```

**DAX:**

```dax
// Отличие BLANK от NULL
EVALUATE
ROW(
    "BLANK + 5",  BLANK() + 5,     // 5  (не BLANK!)
    "BLANK * 10", BLANK() * 10,    // 0
    "BLANK = BLANK", BLANK() = BLANK() // TRUE (в SQL: UNKNOWN)
)
```

> **Критическая разница:** В DAX BLANK() + 5 = 5, а в SQL NULL + 5 = NULL. Помните об этом при миграции запросов между платформами!

---

## Итоги практической работы

| Тема | SQL (PostgreSQL) | DAX |
|------|-----------------|-----|
| Округление | ROUND, CEIL, FLOOR, TRUNC | ROUND, CEILING, FLOOR, TRUNC |
| Модуль числа | ABS | ABS |
| Агрегаты | SUM, AVG, COUNT, STRING_AGG | SUM, AVERAGE, COUNTROWS, CONCATENATEX |
| Преобразование | CAST, ::, TO_DATE, TO_CHAR | CONVERT, FORMAT, INT, VALUE |
| Условная логика | CASE WHEN, COALESCE, NULLIF | IF, SWITCH, COALESCE, DIVIDE |
| NULL | IS NULL, COALESCE, NULLIF, NULLS FIRST/LAST | ISBLANK, COALESCE, BLANK() |
