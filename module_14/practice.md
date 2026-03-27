# Практическая работа — Модуль 14

## Свёртывание и наборы группировки

**Продолжительность:** 20 минут
**Инструменты:** Yandex Managed Service for PostgreSQL (SQL) | Power BI + DAX Studio (DAX)
**Предприятие:** «Руда+» — добыча железной руды

---

## Предварительные требования

1. База данных «Руда+» развёрнута на PostgreSQL (скрипты `01_create_schema.sql`, `02_insert_dimensions.sql`, `03_insert_facts.sql` из каталога `common/scripts/`)
2. Расширение `tablefunc` установлено: `CREATE EXTENSION IF NOT EXISTS tablefunc;`
3. Клиент SQL (DBeaver, pgAdmin или psql) подключён к PostgreSQL
4. Модель данных импортирована в Power BI
5. DAX Studio установлен и подключён к модели Power BI

---

## Часть 1. GROUPING SETS — гибкие наборы группировки

### Шаг 1.1. Базовый GROUPING SETS

```sql
-- Добыча: по шахтам, по сменам и общий итог — в одном запросе
SELECT
    m.mine_name,
    s.shift_name,
    ROUND(SUM(fp.tons_mined), 0) AS total_tons,
    COUNT(*) AS records
FROM fact_production fp
JOIN dim_mine m ON fp.mine_id = m.mine_id
JOIN dim_shift s ON fp.shift_id = s.shift_id
WHERE fp.date_id BETWEEN 20240101 AND 20240131
GROUP BY GROUPING SETS (
    (m.mine_name, s.shift_name),   -- детализация: шахта + смена
    (m.mine_name),                  -- подитог по шахтам
    (s.shift_name),                 -- подитог по сменам
    ()                              -- общий итог
)
ORDER BY
    GROUPING(m.mine_name),
    GROUPING(s.shift_name),
    m.mine_name, s.shift_name;
```

**Что наблюдаем:** Один запрос возвращает 4 уровня агрегации. NULL в столбце означает «все значения» (подитог). Функция `GROUPING()` возвращает 1, если столбец свёрнут (NULL означает «итого»), и 0 — если это реальное значение.

### Шаг 1.2. Использование GROUPING() для маркировки

```sql
SELECT
    CASE WHEN GROUPING(m.mine_name) = 1 THEN '== ВСЕ ШАХТЫ =='
         ELSE m.mine_name END AS mine,
    CASE WHEN GROUPING(s.shift_name) = 1 THEN '== ВСЕ СМЕНЫ =='
         ELSE s.shift_name END AS shift,
    ROUND(SUM(fp.tons_mined), 0) AS total_tons,
    GROUPING(m.mine_name, s.shift_name) AS grouping_level
FROM fact_production fp
JOIN dim_mine m ON fp.mine_id = m.mine_id
JOIN dim_shift s ON fp.shift_id = s.shift_id
WHERE fp.date_id BETWEEN 20240101 AND 20240131
GROUP BY GROUPING SETS (
    (m.mine_name, s.shift_name),
    (m.mine_name),
    (s.shift_name),
    ()
)
ORDER BY grouping_level, mine, shift;
```

**Что наблюдаем:** `GROUPING(col1, col2)` возвращает битовую маску — это удобно для сортировки и фильтрации уровней.

### Шаг 1.3. Аналог в DAX

```dax
// В DAX — SUMMARIZE с ROLLUPADDISSUBTOTAL
// Добавляет строки подитогов аналогично GROUPING SETS
EVALUATE
SUMMARIZECOLUMNS(
    ROLLUPADDISSUBTOTAL(
        dim_mine[mine_name], "IsMineTotal",
        dim_shift[shift_name], "IsShiftTotal"
    ),
    FILTER(fact_production,
        fact_production[date_id] >= 20240101
        && fact_production[date_id] <= 20240131),
    "TotalTons", ROUND(SUM(fact_production[tons_mined]), 0),
    "Records", COUNTROWS(fact_production)
)
ORDER BY [IsMineTotal], [IsShiftTotal], dim_mine[mine_name]
```

**Что наблюдаем:** `ROLLUPADDISSUBTOTAL` добавляет булевы столбцы-маркеры подитогов — аналог GROUPING() в SQL.

> **Обсуждение:** В каких управленческих отчётах предприятия «Руда+» необходимы промежуточные итоги? (Сменные рапорты, месячные сводки по шахтам, квартальные отчёты.)

---

## Часть 2. ROLLUP — иерархические итоги

### Шаг 2.1. ROLLUP по иерархии шахта → смена

```sql
-- ROLLUP создаёт итоги «снизу вверх» по иерархии
SELECT
    COALESCE(m.mine_name, '== ИТОГО ==') AS mine,
    COALESCE(s.shift_name, '== Итого по шахте ==') AS shift,
    ROUND(SUM(fp.tons_mined), 0) AS total_tons,
    SUM(fp.trips_count) AS total_trips
FROM fact_production fp
JOIN dim_mine m ON fp.mine_id = m.mine_id
JOIN dim_shift s ON fp.shift_id = s.shift_id
WHERE fp.date_id BETWEEN 20240101 AND 20240131
GROUP BY ROLLUP (m.mine_name, s.shift_name)
ORDER BY
    GROUPING(m.mine_name),
    m.mine_name,
    GROUPING(s.shift_name),
    s.shift_name;
```

**Что наблюдаем:** `ROLLUP(A, B)` эквивалентен `GROUPING SETS ((A, B), (A), ())`. Итоги формируются иерархически: детализация → подитог по шахте → общий итог.

### Шаг 2.2. ROLLUP по временной иерархии

```sql
-- Иерархия: год → квартал → месяц
SELECT
    COALESCE(d.year::TEXT, 'ИТОГО') AS year,
    COALESCE('Q' || d.quarter::TEXT, 'Итого за год') AS quarter,
    COALESCE(d.month_name, 'Итого за квартал') AS month,
    ROUND(SUM(fp.tons_mined), 0) AS total_tons
FROM fact_production fp
JOIN dim_date d ON fp.date_id = d.date_id
WHERE d.year = 2024 AND fp.mine_id = 1
GROUP BY ROLLUP (d.year, d.quarter, d.month_name)
ORDER BY
    GROUPING(d.year),
    d.year,
    GROUPING(d.quarter),
    d.quarter,
    GROUPING(d.month_name);
```

### Шаг 2.3. Аналог в DAX

```dax
// ROLLUP в DAX — через ROLLUPADDISSUBTOTAL с иерархией
EVALUATE
SUMMARIZECOLUMNS(
    ROLLUPADDISSUBTOTAL(
        dim_mine[mine_name], "IsMineTotal",
        dim_shift[shift_name], "IsShiftTotal"
    ),
    FILTER(fact_production,
        fact_production[date_id] >= 20240101
        && fact_production[date_id] <= 20240131),
    "TotalTons", ROUND(SUM(fact_production[tons_mined]), 0),
    "TotalTrips", SUM(fact_production[trips_count])
)
ORDER BY [IsMineTotal], dim_mine[mine_name], [IsShiftTotal]
```

---

## Часть 3. CUBE — все комбинации

### Шаг 3.1. CUBE по двум измерениям

```sql
-- CUBE создаёт итоги по ВСЕМ комбинациям столбцов
SELECT
    CASE WHEN GROUPING(m.mine_name) = 1 THEN '== ВСЕ ==' ELSE m.mine_name END AS mine,
    CASE WHEN GROUPING(et.type_name) = 1 THEN '== ВСЕ ==' ELSE et.type_name END AS equip_type,
    ROUND(SUM(fp.tons_mined), 0) AS total_tons,
    ROUND(AVG(fp.tons_mined), 2) AS avg_tons,
    COUNT(DISTINCT fp.equipment_id) AS equip_count
FROM fact_production fp
JOIN dim_mine m ON fp.mine_id = m.mine_id
JOIN dim_equipment e ON fp.equipment_id = e.equipment_id
JOIN dim_equipment_type et ON e.equipment_type_id = et.equipment_type_id
WHERE fp.date_id BETWEEN 20240101 AND 20240331
GROUP BY CUBE (m.mine_name, et.type_name)
ORDER BY
    GROUPING(m.mine_name),
    GROUPING(et.type_name),
    m.mine_name, et.type_name;
```

**Что наблюдаем:** `CUBE(A, B)` эквивалентен `GROUPING SETS ((A, B), (A), (B), ())` — всего 2^N комбинаций. Для двух столбцов это 4 группы:
1. Детализация (шахта + тип)
2. Подитог по шахте
3. Подитог по типу оборудования
4. Общий итог

### Шаг 3.2. Аналог в DAX

```dax
// CUBE — все комбинации
// В DAX — SUMMARIZECOLUMNS с ROLLUPADDISSUBTOTAL по каждому измерению
EVALUATE
SUMMARIZECOLUMNS(
    ROLLUPADDISSUBTOTAL(
        dim_mine[mine_name], "IsMineTotal",
        dim_equipment_type[type_name], "IsTypeTotal"
    ),
    FILTER(fact_production,
        fact_production[date_id] >= 20240101
        && fact_production[date_id] <= 20240331),
    "TotalTons", ROUND(SUM(fact_production[tons_mined]), 0),
    "AvgTons", ROUND(AVERAGE(fact_production[tons_mined]), 2),
    "EquipCount", DISTINCTCOUNT(fact_production[equipment_id])
)
ORDER BY [IsMineTotal], [IsTypeTotal], dim_mine[mine_name]
```

> **Обсуждение:** Когда использовать ROLLUP, а когда CUBE? (ROLLUP — для иерархий, CUBE — когда нужны все пересечения.)

---

## Часть 4. PIVOT / UNPIVOT через crosstab и условную агрегацию

### Шаг 4.1. Условная агрегация (ручной PIVOT)

```sql
-- Разворот: строки → столбцы через CASE
-- Добыча по шахтам: месяцы становятся столбцами
SELECT
    m.mine_name,
    ROUND(SUM(CASE WHEN d.month = 1 THEN fp.tons_mined END), 0) AS jan,
    ROUND(SUM(CASE WHEN d.month = 2 THEN fp.tons_mined END), 0) AS feb,
    ROUND(SUM(CASE WHEN d.month = 3 THEN fp.tons_mined END), 0) AS mar,
    ROUND(SUM(CASE WHEN d.month = 4 THEN fp.tons_mined END), 0) AS apr,
    ROUND(SUM(CASE WHEN d.month = 5 THEN fp.tons_mined END), 0) AS may,
    ROUND(SUM(CASE WHEN d.month = 6 THEN fp.tons_mined END), 0) AS jun,
    ROUND(SUM(fp.tons_mined), 0) AS total
FROM fact_production fp
JOIN dim_mine m ON fp.mine_id = m.mine_id
JOIN dim_date d ON fp.date_id = d.date_id
WHERE d.year = 2024 AND d.month <= 6
GROUP BY m.mine_name
ORDER BY m.mine_name;
```

**Что наблюдаем:** Условная агрегация (CASE + SUM) — универсальный метод «поворота» таблицы в PostgreSQL.

### Шаг 4.2. Функция crosstab (расширение tablefunc)

```sql
-- Установка расширения (один раз)
CREATE EXTENSION IF NOT EXISTS tablefunc;

-- crosstab: динамический разворот
SELECT * FROM crosstab(
    $$
    SELECT
        m.mine_name,
        s.shift_name,
        ROUND(SUM(fp.tons_mined), 0)::TEXT
    FROM fact_production fp
    JOIN dim_mine m ON fp.mine_id = m.mine_id
    JOIN dim_shift s ON fp.shift_id = s.shift_id
    WHERE fp.date_id BETWEEN 20240101 AND 20240131
    GROUP BY m.mine_name, s.shift_name
    ORDER BY m.mine_name, s.shift_name
    $$,
    $$
    SELECT DISTINCT shift_name FROM dim_shift ORDER BY shift_name
    $$
) AS ct(
    mine_name VARCHAR,
    day_shift TEXT,
    night_shift TEXT
);
```

**Что наблюдаем:** crosstab принимает два запроса — основной (данные) и категории (заголовки столбцов). Результат — «широкая» таблица.

### Шаг 4.3. UNPIVOT — обратное преобразование (столбцы → строки)

```sql
-- UNPIVOT через LATERAL + VALUES
-- Допустим, у нас есть широкая таблица KPI по оборудованию
WITH wide_data AS (
    SELECT
        e.equipment_name,
        ROUND(SUM(fp.tons_mined), 0) AS tons,
        SUM(fp.trips_count) AS trips,
        ROUND(SUM(fp.fuel_consumed_l), 0) AS fuel_liters,
        ROUND(SUM(fp.operating_hours), 1) AS hours
    FROM fact_production fp
    JOIN dim_equipment e ON fp.equipment_id = e.equipment_id
    WHERE fp.date_id BETWEEN 20240101 AND 20240131
    GROUP BY e.equipment_name
)
SELECT
    w.equipment_name,
    u.metric_name,
    u.metric_value
FROM wide_data w
CROSS JOIN LATERAL (
    VALUES
        ('Добыча (тонн)', w.tons::NUMERIC),
        ('Рейсы', w.trips::NUMERIC),
        ('Топливо (л)', w.fuel_liters::NUMERIC),
        ('Рабочие часы', w.hours::NUMERIC)
) AS u(metric_name, metric_value)
ORDER BY w.equipment_name, u.metric_name;
```

**Что наблюдаем:** В PostgreSQL нет встроенного UNPIVOT. Используется `CROSS JOIN LATERAL (VALUES ...)` для превращения столбцов в строки.

### Шаг 4.4. Аналог PIVOT в DAX

```dax
// В DAX «pivot» не нужен — Power BI делает это визуально через матрицу
// Но для DAX Studio можно показать через CROSSJOIN + CALCULATE
EVALUATE
ADDCOLUMNS(
    VALUES(dim_mine[mine_name]),
    "Январь",
        CALCULATE(
            ROUND(SUM(fact_production[tons_mined]), 0),
            dim_date[month] = 1, dim_date[year] = 2024),
    "Февраль",
        CALCULATE(
            ROUND(SUM(fact_production[tons_mined]), 0),
            dim_date[month] = 2, dim_date[year] = 2024),
    "Март",
        CALCULATE(
            ROUND(SUM(fact_production[tons_mined]), 0),
            dim_date[month] = 3, dim_date[year] = 2024),
    "Итого Q1",
        CALCULATE(
            ROUND(SUM(fact_production[tons_mined]), 0),
            dim_date[quarter] = 1, dim_date[year] = 2024)
)
ORDER BY dim_mine[mine_name]
```

> **Обсуждение:** Почему в Power BI обычно не нужен PIVOT на уровне запроса? (Ответ: визуал «Матрица» автоматически разворачивает данные.)

---

## Контрольные вопросы

1. Чем ROLLUP отличается от CUBE?
2. Как определить, что строка содержит подитог, а не реальное значение NULL?
3. Какие способы «поворота» таблицы есть в PostgreSQL?
4. Какой аналог GROUPING SETS существует в DAX?
5. Когда стоит использовать crosstab, а когда — условную агрегацию?

---

## Итоги практической работы

По результатам практики вы должны уметь:

1. Формировать наборы группировки через GROUPING SETS
2. Использовать ROLLUP для иерархических итогов
3. Использовать CUBE для всех комбинаций
4. Отличать подитоговые строки с помощью GROUPING()
5. Выполнять PIVOT через условную агрегацию и crosstab
6. Выполнять UNPIVOT через LATERAL + VALUES
7. Применять аналоги в DAX (SUMMARIZECOLUMNS + ROLLUPADDISSUBTOTAL)
