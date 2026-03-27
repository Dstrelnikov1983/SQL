# Практическая работа — Модуль 11

## Использование табличных выражений

**Продолжительность:** 60 минут
**Инструменты:** Yandex Managed Service for PostgreSQL (SQL) | Power BI + DAX Studio (DAX)
**Предприятие:** «Руда+» — добыча железной руды

---

## Предварительные требования

1. База данных «Руда+» развёрнута на PostgreSQL (скрипты `01_create_schema.sql`, `02_insert_dimensions.sql`, `03_insert_facts.sql` из каталога `common/scripts/`)
2. Модель данных импортирована в Power BI
3. DAX Studio установлен и подключён к модели Power BI
4. Клиент SQL (DBeaver, pgAdmin или psql) подключён к PostgreSQL

---

## Часть 1. Представления (Views)

### Шаг 1.1. Создание обычного представления

Создадим представление для сводки по добыче руды по шахтам и месяцам.

```sql
-- Сводка добычи по шахтам и месяцам
CREATE OR REPLACE VIEW v_mine_monthly_production AS
SELECT
    m.mine_name,
    d.year,
    d.month,
    d.month_name,
    d.year_month,
    COUNT(*)              AS records_count,
    SUM(fp.tons_mined)    AS total_tons_mined,
    SUM(fp.tons_transported) AS total_tons_transported,
    SUM(fp.trips_count)   AS total_trips,
    AVG(fp.tons_mined)    AS avg_tons_per_shift,
    SUM(fp.fuel_consumed_l) AS total_fuel,
    SUM(fp.operating_hours) AS total_hours
FROM fact_production fp
JOIN dim_mine m  ON fp.mine_id = m.mine_id
JOIN dim_date d  ON fp.date_id = d.date_id
GROUP BY m.mine_name, d.year, d.month, d.month_name, d.year_month;
```

**Что наблюдаем:** представление создано. Проверим его:

```sql
-- Используем VIEW как таблицу
SELECT mine_name, year_month, total_tons_mined
FROM v_mine_monthly_production
WHERE year = 2024
ORDER BY mine_name, year_month;
```

### Шаг 1.2. Представление для безопасности данных

```sql
-- Скрываем персональные данные операторов
CREATE OR REPLACE VIEW v_operator_anonymous AS
SELECT
    operator_id,
    tab_number,
    SUBSTRING(last_name, 1, 1) || '.' AS last_initial,
    SUBSTRING(first_name, 1, 1) || '.' AS first_initial,
    position,
    qualification,
    mine_id,
    status
FROM dim_operator;

-- Проверяем
SELECT * FROM v_operator_anonymous LIMIT 10;
```

**Что наблюдаем:** ФИО заменены на инициалы. Аналитик MES-системы видит только обезличенные данные.

### Шаг 1.3. Обновляемое представление с WITH CHECK OPTION

```sql
-- Представление активного оборудования
CREATE OR REPLACE VIEW v_active_equipment AS
SELECT
    equipment_id,
    equipment_name,
    inventory_number,
    equipment_type_id,
    mine_id,
    manufacturer,
    model,
    status
FROM dim_equipment
WHERE status = 'active'
WITH CHECK OPTION;

-- Проверяем, что через VIEW видно только активное оборудование
SELECT COUNT(*) AS active_count FROM v_active_equipment;
SELECT COUNT(*) AS total_count FROM dim_equipment;
```

**Попробуем обновить:**

```sql
-- Это сработает (статус остаётся 'active')
-- UPDATE v_active_equipment SET manufacturer = 'БЕЛАЗ' WHERE equipment_id = 1;

-- А это вызовет ошибку (WITH CHECK OPTION)!
-- UPDATE v_active_equipment SET status = 'maintenance' WHERE equipment_id = 1;
-- ERROR: new row violates check option for view "v_active_equipment"
```

**Что наблюдаем:** WITH CHECK OPTION защищает от обновления данных, которые перестанут быть видны через VIEW.

---

## Часть 2. Материализованные представления

### Шаг 2.1. Создание MATERIALIZED VIEW для анализа качества руды

```sql
-- Тяжёлый аналитический запрос — материализуем
CREATE MATERIALIZED VIEW mv_daily_ore_quality_summary AS
SELECT
    d.full_date,
    d.year_month,
    m.mine_name,
    sh.shaft_name,
    g.grade_name,
    COUNT(*)               AS samples_count,
    ROUND(AVG(q.fe_content), 2)    AS avg_fe_content,
    ROUND(MIN(q.fe_content), 2)    AS min_fe_content,
    ROUND(MAX(q.fe_content), 2)    AS max_fe_content,
    ROUND(AVG(q.sio2_content), 2)  AS avg_sio2,
    ROUND(AVG(q.moisture), 2)      AS avg_moisture
FROM fact_ore_quality q
JOIN dim_date d       ON q.date_id = d.date_id
JOIN dim_mine m       ON q.mine_id = m.mine_id
JOIN dim_shaft sh     ON q.shaft_id = sh.shaft_id
LEFT JOIN dim_ore_grade g ON q.ore_grade_id = g.ore_grade_id
GROUP BY d.full_date, d.year_month, m.mine_name, sh.shaft_name, g.grade_name;

-- Создаём индексы для быстрого доступа
CREATE INDEX idx_mv_ore_quality_date ON mv_daily_ore_quality_summary(full_date);
CREATE INDEX idx_mv_ore_quality_mine ON mv_daily_ore_quality_summary(mine_name);
```

### Шаг 2.2. Использование и обновление

```sql
-- Быстрый запрос к материализованному представлению
SELECT mine_name, year_month, avg_fe_content, samples_count
FROM mv_daily_ore_quality_summary
WHERE mine_name = 'Шахта Северная'
  AND full_date >= '2024-01-01'
ORDER BY full_date;

-- Для конкурентного обновления (без блокировки чтения) нужен UNIQUE INDEX
CREATE UNIQUE INDEX idx_mv_ore_quality_uniq
ON mv_daily_ore_quality_summary(full_date, mine_name, shaft_name, COALESCE(grade_name, ''));

-- Обновление с конкурентным доступом
REFRESH MATERIALIZED VIEW CONCURRENTLY mv_daily_ore_quality_summary;
```

**Что наблюдаем:** запрос к MATERIALIZED VIEW значительно быстрее, чем к исходным таблицам (данные предварительно вычислены).

### Шаг 2.3. Сравнение производительности

```sql
-- Замерим время: VIEW vs MATERIALIZED VIEW
EXPLAIN ANALYZE
SELECT mine_name, year_month, avg_fe_content
FROM mv_daily_ore_quality_summary
WHERE mine_name = 'Шахта Северная';

-- Сравним с прямым запросом к таблицам
EXPLAIN ANALYZE
SELECT
    m.mine_name, d.year_month,
    AVG(q.fe_content) AS avg_fe_content
FROM fact_ore_quality q
JOIN dim_date d  ON q.date_id = d.date_id
JOIN dim_mine m  ON q.mine_id = m.mine_id
WHERE m.mine_name = 'Шахта Северная'
GROUP BY m.mine_name, d.year_month;
```

**Зафиксируйте время выполнения обоих запросов в комментариях.**

---

## Часть 3. Табличные функции

### Шаг 3.1. Функция: отчёт по добыче для шахты

```sql
-- Табличная функция: добыча за период по шахте
CREATE OR REPLACE FUNCTION fn_mine_production_report(
    p_mine_id   INT,
    p_date_from INT,
    p_date_to   INT
)
RETURNS TABLE (
    shift_name      VARCHAR,
    operator_name   TEXT,
    equipment_name  VARCHAR,
    total_tons      NUMERIC,
    total_trips     BIGINT,
    avg_fuel_l      NUMERIC,
    total_hours     NUMERIC
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        s.shift_name,
        (o.last_name || ' ' || LEFT(o.first_name, 1) || '.')::TEXT,
        e.equipment_name,
        ROUND(SUM(fp.tons_mined), 1),
        SUM(fp.trips_count)::BIGINT,
        ROUND(AVG(fp.fuel_consumed_l), 1),
        ROUND(SUM(fp.operating_hours), 1)
    FROM fact_production fp
    JOIN dim_shift s     ON fp.shift_id = s.shift_id
    JOIN dim_operator o  ON fp.operator_id = o.operator_id
    JOIN dim_equipment e ON fp.equipment_id = e.equipment_id
    WHERE fp.mine_id = p_mine_id
      AND fp.date_id BETWEEN p_date_from AND p_date_to
    GROUP BY s.shift_name, o.last_name, o.first_name, e.equipment_name
    ORDER BY total_tons DESC;
END;
$$ LANGUAGE plpgsql;
```

### Шаг 3.2. Вызов функции

```sql
-- Простой вызов
SELECT * FROM fn_mine_production_report(1, 20240101, 20240131);

-- Фильтрация результата
SELECT shift_name, operator_name, total_tons
FROM fn_mine_production_report(1, 20240101, 20240331)
WHERE total_tons > 50
ORDER BY total_tons DESC;

-- LATERAL JOIN: вызов функции для каждой шахты
SELECT m.mine_name, r.*
FROM dim_mine m
CROSS JOIN LATERAL fn_mine_production_report(
    m.mine_id, 20240101, 20240131
) r
WHERE m.status = 'active';
```

**Что наблюдаем:** LATERAL позволяет вызвать табличную функцию для каждой строки левой таблицы.

### Шаг 3.3. SQL-функция (без plpgsql)

```sql
-- Чистая SQL-функция (может быть оптимизирована, inline)
CREATE OR REPLACE FUNCTION fn_downtime_summary(
    p_date_from INT,
    p_date_to   INT
)
RETURNS TABLE (
    reason_name     VARCHAR,
    category        VARCHAR,
    events_count    BIGINT,
    total_hours     NUMERIC,
    avg_duration_h  NUMERIC
) AS $$
    SELECT
        dr.reason_name,
        dr.category,
        COUNT(*),
        ROUND(SUM(dt.duration_min) / 60.0, 1),
        ROUND(AVG(dt.duration_min) / 60.0, 2)
    FROM fact_equipment_downtime dt
    JOIN dim_downtime_reason dr ON dt.reason_id = dr.reason_id
    WHERE dt.date_id BETWEEN p_date_from AND p_date_to
    GROUP BY dr.reason_name, dr.category
    ORDER BY 4 DESC;
$$ LANGUAGE sql;

-- Вызов
SELECT * FROM fn_downtime_summary(20240101, 20240630);
```

---

## Часть 4. CTE и рекурсивные CTE

### Шаг 4.1. Множественные CTE

```sql
-- Комплексный отчёт: добыча + простои по шахтам
WITH production_summary AS (
    SELECT
        fp.mine_id,
        SUM(fp.tons_mined) AS total_tons,
        SUM(fp.operating_hours) AS work_hours,
        COUNT(DISTINCT fp.equipment_id) AS equipment_used
    FROM fact_production fp
    WHERE fp.date_id BETWEEN 20240101 AND 20240331
    GROUP BY fp.mine_id
),
downtime_summary AS (
    SELECT
        e.mine_id,
        SUM(dt.duration_min) / 60.0 AS downtime_hours,
        SUM(CASE WHEN dt.is_planned = FALSE THEN dt.duration_min ELSE 0 END) / 60.0
            AS unplanned_hours
    FROM fact_equipment_downtime dt
    JOIN dim_equipment e ON dt.equipment_id = e.equipment_id
    WHERE dt.date_id BETWEEN 20240101 AND 20240331
    GROUP BY e.mine_id
)
SELECT
    m.mine_name,
    ROUND(p.total_tons, 0)    AS total_tons,
    p.equipment_used,
    ROUND(p.work_hours, 0)    AS work_hours,
    ROUND(COALESCE(d.downtime_hours, 0), 0)   AS downtime_hours,
    ROUND(COALESCE(d.unplanned_hours, 0), 0)  AS unplanned_hours,
    ROUND(p.work_hours / NULLIF(p.work_hours + COALESCE(d.downtime_hours, 0), 0) * 100, 1)
        AS availability_pct
FROM production_summary p
JOIN dim_mine m ON p.mine_id = m.mine_id
LEFT JOIN downtime_summary d ON p.mine_id = d.mine_id
ORDER BY total_tons DESC;
```

**Что наблюдаем:** CTE делают запрос модульным — каждый блок решает свою задачу.

### Шаг 4.2. Подготовка данных для рекурсивного CTE

```sql
-- Создаём таблицу иерархии локаций
CREATE TABLE IF NOT EXISTS dim_location_hierarchy (
    location_id     INT PRIMARY KEY,
    parent_id       INT REFERENCES dim_location_hierarchy(location_id),
    location_name   VARCHAR(200) NOT NULL,
    location_type   VARCHAR(50) NOT NULL,
    depth_level     INT
);

-- Заполняем тестовыми данными
INSERT INTO dim_location_hierarchy VALUES
    (1, NULL, 'Шахта Северная',       'шахта',    0),
    (2, 1,    'Ствол Главный',        'ствол',    1),
    (3, 1,    'Ствол Вентиляционный', 'ствол',    1),
    (4, 2,    'Горизонт -300м',       'горизонт', 2),
    (5, 2,    'Горизонт -450м',       'горизонт', 2),
    (6, 3,    'Горизонт -300м (В)',   'горизонт', 2),
    (7, 4,    'Штрек 3-Северный',     'штрек',    3),
    (8, 4,    'Штрек 3-Южный',        'штрек',    3),
    (9, 5,    'Штрек 4-Центральный',  'штрек',    3),
    (10, 7,   'Забой 3С-1',           'забой',    4),
    (11, 7,   'Забой 3С-2',           'забой',    4),
    (12, 8,   'Забой 3Ю-1',           'забой',    4),
    (13, 9,   'Забой 4Ц-1',           'забой',    4),
    (14, 9,   'Забой 4Ц-2',           'забой',    4),
    (15, NULL, 'Шахта Южная',         'шахта',    0),
    (16, 15,  'Ствол Основной',       'ствол',    1),
    (17, 16,  'Горизонт -200м',       'горизонт', 2),
    (18, 17,  'Штрек 1-Западный',     'штрек',    3),
    (19, 18,  'Забой 1З-1',           'забой',    4),
    (20, 18,  'Забой 1З-2',           'забой',    4)
ON CONFLICT (location_id) DO NOTHING;
```

### Шаг 4.3. Рекурсивный обход дерева локаций

```sql
-- Полное дерево от корня (Шахта Северная)
WITH RECURSIVE location_tree AS (
    -- Якорь: корневой элемент
    SELECT
        location_id,
        parent_id,
        location_name,
        location_type,
        location_name::TEXT AS full_path,
        1 AS tree_depth
    FROM dim_location_hierarchy
    WHERE location_id = 1  -- Шахта Северная

    UNION ALL

    -- Рекурсия: все потомки
    SELECT
        child.location_id,
        child.parent_id,
        child.location_name,
        child.location_type,
        tree.full_path || ' → ' || child.location_name,
        tree.tree_depth + 1
    FROM dim_location_hierarchy child
    JOIN location_tree tree ON child.parent_id = tree.location_id
    WHERE tree.tree_depth < 10  -- защита от бесконечной рекурсии
)
SELECT
    REPEAT('  ', tree_depth - 1) || location_name AS hierarchy,
    location_type,
    full_path,
    tree_depth
FROM location_tree
ORDER BY full_path;
```

**Что наблюдаем:** дерево локаций отображается с отступами, показывая вложенность.

### Шаг 4.4. Обратный обход: от забоя к шахте

```sql
-- Путь от забоя «3С-1» вверх до шахты
WITH RECURSIVE path_up AS (
    SELECT location_id, parent_id, location_name, location_type, 1 AS level
    FROM dim_location_hierarchy
    WHERE location_id = 10  -- Забой 3С-1

    UNION ALL

    SELECT p.location_id, p.parent_id, p.location_name, p.location_type,
           pu.level + 1
    FROM dim_location_hierarchy p
    JOIN path_up pu ON p.location_id = pu.parent_id
)
SELECT location_name, location_type, level
FROM path_up
ORDER BY level;
```

### Шаг 4.5. Генерация последовательности дат (рекурсивный CTE)

```sql
-- Генерация дат за январь 2024
WITH RECURSIVE date_series AS (
    SELECT DATE '2024-01-01' AS dt
    UNION ALL
    SELECT dt + INTERVAL '1 day'
    FROM date_series
    WHERE dt < DATE '2024-01-31'
)
SELECT dt::DATE AS calendar_date,
       EXTRACT(DOW FROM dt) AS day_of_week,
       CASE WHEN EXTRACT(DOW FROM dt) IN (0, 6) THEN 'Выходной' ELSE 'Рабочий' END AS day_type
FROM date_series;

-- Применение: найти дни без добычи
WITH RECURSIVE date_series AS (
    SELECT DATE '2024-01-01' AS dt
    UNION ALL
    SELECT dt + INTERVAL '1 day'
    FROM date_series
    WHERE dt < DATE '2024-01-31'
),
production_dates AS (
    SELECT DISTINCT d.full_date
    FROM fact_production fp
    JOIN dim_date d ON fp.date_id = d.date_id
    WHERE fp.mine_id = 1
      AND d.full_date BETWEEN '2024-01-01' AND '2024-01-31'
)
SELECT ds.dt::DATE AS missing_date
FROM date_series ds
LEFT JOIN production_dates pd ON ds.dt = pd.full_date
WHERE pd.full_date IS NULL
ORDER BY ds.dt;
```

---

## Часть 5. DAX: аналогичные конструкции

### Шаг 5.1. DAX: вычисляемая таблица (аналог VIEW)

Откройте DAX Studio и выполните:

```dax
// Аналог v_mine_monthly_production
EVALUATE
ADDCOLUMNS(
    SUMMARIZE(
        fact_production,
        dim_mine[mine_name],
        dim_date[year_month]
    ),
    "Total Tons", CALCULATE(SUM(fact_production[tons_mined])),
    "Total Trips", CALCULATE(SUM(fact_production[trips_count])),
    "Avg Tons", CALCULATE(AVERAGE(fact_production[tons_mined]))
)
ORDER BY dim_mine[mine_name], dim_date[year_month]
```

### Шаг 5.2. DAX: VAR (аналог CTE)

```dax
// Аналог множественных CTE: добыча + эффективность
EVALUATE
VAR ProductionByMine =
    ADDCOLUMNS(
        VALUES(dim_mine[mine_name]),
        "TotalTons", CALCULATE(SUM(fact_production[tons_mined])),
        "TotalHours", CALCULATE(SUM(fact_production[operating_hours]))
    )
VAR WithEfficiency =
    ADDCOLUMNS(
        ProductionByMine,
        "TonsPerHour",
            DIVIDE([TotalTons], [TotalHours], 0)
    )
RETURN
    WithEfficiency
ORDER BY [TotalTons] DESC
```

### Шаг 5.3. DAX: PATH для иерархий

В модели Power BI создайте вычисляемые столбцы в таблице `dim_location_hierarchy`:

```dax
// Вычисляемый столбец: полный путь
LocationPath = PATH(dim_location_hierarchy[location_id], dim_location_hierarchy[parent_id])

// Глубина вложенности
PathDepth = PATHLENGTH(dim_location_hierarchy[LocationPath])

// Имя элемента 2-го уровня (ствол)
Level2Name =
VAR Level2ID = PATHITEM(dim_location_hierarchy[LocationPath], 2, INTEGER)
RETURN
    IF(
        ISBLANK(Level2ID),
        BLANK(),
        LOOKUPVALUE(
            dim_location_hierarchy[location_name],
            dim_location_hierarchy[location_id],
            Level2ID
        )
    )
```

---

## Контрольные вопросы

1. В чём разница между VIEW и MATERIALIZED VIEW?
2. Когда табличная функция предпочтительнее VIEW?
3. Почему CTE считается более читаемым, чем вложенные производные таблицы?
4. Из каких частей состоит рекурсивный CTE?
5. Как защититься от бесконечной рекурсии?
6. Что делает конструкция VAR/RETURN в DAX?

---

## Очистка (опционально)

```sql
-- Удаление созданных объектов
DROP VIEW IF EXISTS v_mine_monthly_production;
DROP VIEW IF EXISTS v_operator_anonymous;
DROP VIEW IF EXISTS v_active_equipment;
DROP MATERIALIZED VIEW IF EXISTS mv_daily_ore_quality_summary;
DROP FUNCTION IF EXISTS fn_mine_production_report(INT, INT, INT);
DROP FUNCTION IF EXISTS fn_downtime_summary(INT, INT);
DROP TABLE IF EXISTS dim_location_hierarchy;
```
