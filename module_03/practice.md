# Практическая работа — Модуль 3

## Сравнение простейших запросов на языке SQL и DAX

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

## Часть 1. Простые запросы SELECT / EVALUATE

### Шаг 1.1. Просмотр всей таблицы оборудования

**SQL (PostgreSQL):**

```sql
SELECT *
FROM dim_equipment;
```

**DAX (DAX Studio):**

```dax
EVALUATE
dim_equipment
```

**Что наблюдаем:**
- SQL возвращает таблицу с колонками из определения DDL
- DAX возвращает таблицу из модели данных Power BI
- Количество строк должно совпадать: **18 единиц оборудования**

### Шаг 1.2. Выбор определённых столбцов

**SQL:**

```sql
SELECT equipment_name,
       inventory_number,
       manufacturer,
       model,
       status
FROM dim_equipment;
```

**DAX:**

```dax
EVALUATE
SELECTCOLUMNS(
    dim_equipment,
    "Название",       dim_equipment[equipment_name],
    "Инв. номер",     dim_equipment[inventory_number],
    "Производитель",  dim_equipment[manufacturer],
    "Модель",         dim_equipment[model],
    "Статус",         dim_equipment[status]
)
```

> **Обратите внимание:** в DAX обязательно указывать псевдонимы (строки в кавычках) для каждого столбца в `SELECTCOLUMNS`.

### Шаг 1.3. Уникальные значения

**SQL:**

```sql
SELECT DISTINCT manufacturer
FROM dim_equipment;
```

**DAX:**

```dax
EVALUATE
DISTINCT(dim_equipment[manufacturer])
```

**Ожидаемый результат:** 4 производителя — Sandvik, Caterpillar, Epiroc, НКМЗ, Siemag Tecberg.

### Шаг 1.4. Подсчёт записей

**SQL:**

```sql
SELECT COUNT(*) AS total_equipment
FROM dim_equipment;
```

**DAX:**

```dax
EVALUATE
ROW("Всего оборудования", COUNTROWS(dim_equipment))
```

**Ожидаемый результат:** 18.

---

## Часть 2. Фильтрация данных

### Шаг 2.1. Фильтр по равенству — оборудование шахты «Северная»

**SQL:**

```sql
SELECT equipment_name,
       inventory_number,
       manufacturer,
       model,
       status
FROM dim_equipment
WHERE mine_id = 1;
```

**DAX (вариант 1 — CALCULATETABLE):**

```dax
EVALUATE
CALCULATETABLE(
    SELECTCOLUMNS(
        dim_equipment,
        "Название",       dim_equipment[equipment_name],
        "Инв. номер",     dim_equipment[inventory_number],
        "Производитель",  dim_equipment[manufacturer],
        "Модель",         dim_equipment[model],
        "Статус",         dim_equipment[status]
    ),
    dim_equipment[mine_id] = 1
)
```

**DAX (вариант 2 — FILTER):**

```dax
EVALUATE
FILTER(
    SELECTCOLUMNS(
        dim_equipment,
        "Название",       dim_equipment[equipment_name],
        "Инв. номер",     dim_equipment[inventory_number],
        "Производитель",  dim_equipment[manufacturer],
        "Модель",         dim_equipment[model],
        "Статус",         dim_equipment[status],
        "mine_id",        dim_equipment[mine_id]
    ),
    [mine_id] = 1
)
```

**Ожидаемый результат:** 11 единиц оборудования (3 ПДМ, 3 самосвала, 2 вагонетки, 2 скипа, 1 ПДМ-003).

> **Обсудите:** В чём разница между `CALCULATETABLE` и `FILTER`? Какой вариант предпочтительнее для простых условий?

### Шаг 2.2. Несколько условий — ПДМ шахты «Северная»

**SQL:**

```sql
SELECT equipment_name, manufacturer, model, year_manufactured
FROM dim_equipment
WHERE equipment_type_id = 1
  AND mine_id = 1;
```

**DAX:**

```dax
EVALUATE
CALCULATETABLE(
    SELECTCOLUMNS(
        dim_equipment,
        "Название",      dim_equipment[equipment_name],
        "Производитель", dim_equipment[manufacturer],
        "Модель",        dim_equipment[model],
        "Год выпуска",   dim_equipment[year_manufactured]
    ),
    dim_equipment[equipment_type_id] = 1,
    dim_equipment[mine_id] = 1
)
```

**Ожидаемый результат:** 3 ПДМ — ПДМ-001, ПДМ-002, ПДМ-003.

### Шаг 2.3. Сравнение и диапазоны

**SQL — добыча за январь 2024, более 100 тонн:**

```sql
SELECT date_id, equipment_id, operator_id,
       tons_mined, trips_count
FROM fact_production
WHERE date_id BETWEEN 20240101 AND 20240131
  AND tons_mined > 100;
```

**DAX:**

```dax
EVALUATE
FILTER(
    CALCULATETABLE(
        SELECTCOLUMNS(
            fact_production,
            "date_id",       fact_production[date_id],
            "equipment_id",  fact_production[equipment_id],
            "operator_id",   fact_production[operator_id],
            "Добыто, т",     fact_production[tons_mined],
            "Рейсов",        fact_production[trips_count]
        ),
        fact_production[date_id] >= 20240101,
        fact_production[date_id] <= 20240131
    ),
    [Добыто, т] > 100
)
```

### Шаг 2.4. Оператор IN и поиск по шаблону

**SQL:**

```sql
-- Производители Sandvik и Caterpillar
SELECT equipment_name, manufacturer, model
FROM dim_equipment
WHERE manufacturer IN ('Sandvik', 'Caterpillar');

-- ПДМ (по шаблону названия)
SELECT equipment_name, inventory_number
FROM dim_equipment
WHERE equipment_name LIKE 'ПДМ%';
```

**DAX:**

```dax
// IN
EVALUATE
CALCULATETABLE(
    SELECTCOLUMNS(
        dim_equipment,
        "Название",      dim_equipment[equipment_name],
        "Производитель", dim_equipment[manufacturer],
        "Модель",        dim_equipment[model]
    ),
    dim_equipment[manufacturer] IN {"Sandvik", "Caterpillar"}
)

// LIKE (через CONTAINSSTRING)
EVALUATE
FILTER(
    SELECTCOLUMNS(
        dim_equipment,
        "Название",   dim_equipment[equipment_name],
        "Инв. номер", dim_equipment[inventory_number]
    ),
    CONTAINSSTRING([Название], "ПДМ")
)
```

---

## Часть 3. Сортировка данных

### Шаг 3.1. Простая сортировка

**SQL:**

```sql
SELECT equipment_name, manufacturer, model, year_manufactured
FROM dim_equipment
ORDER BY year_manufactured DESC;
```

**DAX:**

```dax
EVALUATE
SELECTCOLUMNS(
    dim_equipment,
    "Название",      dim_equipment[equipment_name],
    "Производитель", dim_equipment[manufacturer],
    "Модель",        dim_equipment[model],
    "Год выпуска",   dim_equipment[year_manufactured]
)
ORDER BY [Год выпуска] DESC
```

### Шаг 3.2. Топ-5 записей добычи

**SQL:**

```sql
SELECT date_id, equipment_id, operator_id,
       tons_mined, trips_count
FROM fact_production
ORDER BY tons_mined DESC
LIMIT 5;
```

**DAX:**

```dax
EVALUATE
TOPN(
    5,
    SELECTCOLUMNS(
        fact_production,
        "date_id",       fact_production[date_id],
        "equipment_id",  fact_production[equipment_id],
        "operator_id",   fact_production[operator_id],
        "Добыто, т",     fact_production[tons_mined],
        "Рейсов",        fact_production[trips_count]
    ),
    [Добыто, т], DESC
)
```

> **Обратите внимание:** `TOPN` — это функция (возвращает таблицу), а `LIMIT` — модификатор запроса. `TOPN` требует указания столбца сортировки.

---

## Часть 4. Соединение таблиц

### Шаг 4.1. Оборудование с расшифровкой типа и шахты

**SQL:**

```sql
SELECT e.equipment_name,
       et.type_name    AS equipment_type,
       m.mine_name
FROM dim_equipment e
INNER JOIN dim_equipment_type et ON e.equipment_type_id = et.equipment_type_id
INNER JOIN dim_mine m            ON e.mine_id = m.mine_id;
```

**DAX:**

```dax
EVALUATE
SELECTCOLUMNS(
    dim_equipment,
    "Название",  dim_equipment[equipment_name],
    "Тип",       RELATED(dim_equipment_type[type_name]),
    "Шахта",     RELATED(dim_mine[mine_name])
)
```

> **Ключевое отличие:** в SQL нужно явно указать JOIN и условия ON. В DAX функция `RELATED()` автоматически использует связи модели данных.

### Шаг 4.2. Фильтрация по связанной таблице

**SQL:**

```sql
SELECT e.equipment_name,
       et.type_name,
       e.manufacturer, e.model
FROM dim_equipment e
INNER JOIN dim_equipment_type et ON e.equipment_type_id = et.equipment_type_id
INNER JOIN dim_mine m            ON e.mine_id = m.mine_id
WHERE m.mine_name = 'Шахта "Северная"';
```

**DAX:**

```dax
EVALUATE
CALCULATETABLE(
    SELECTCOLUMNS(
        dim_equipment,
        "Название",      dim_equipment[equipment_name],
        "Тип",           RELATED(dim_equipment_type[type_name]),
        "Производитель", dim_equipment[manufacturer],
        "Модель",        dim_equipment[model]
    ),
    dim_mine[mine_name] = "Шахта ""Северная"""
)
```

> **Обратите внимание:** в DAX фильтр по `dim_mine[mine_name]` автоматически «протекает» на `dim_equipment` через связь в модели.

### Шаг 4.3. Многотабличный запрос — добыча за конкретную дату

**SQL:**

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

**DAX:**

```dax
EVALUATE
CALCULATETABLE(
    SELECTCOLUMNS(
        fact_production,
        "Дата",         RELATED(dim_date[full_date]),
        "Смена",        RELATED(dim_shift[shift_name]),
        "Оборудование", RELATED(dim_equipment[equipment_name]),
        "Оператор",     RELATED(dim_operator[last_name]) & " " & RELATED(dim_operator[first_name]),
        "Добыто, т",    fact_production[tons_mined],
        "Рейсов",       fact_production[trips_count]
    ),
    dim_date[full_date] = DATE(2024, 1, 15)
)
ORDER BY [Добыто, т] DESC
```

---

## Часть 5. Группировка и агрегаты

### Шаг 5.1. Добыча по шахтам

**SQL:**

```sql
SELECT m.mine_name,
       SUM(fp.tons_mined)  AS total_tons,
       AVG(fp.tons_mined)  AS avg_tons_per_shift,
       COUNT(*)             AS total_shifts
FROM fact_production fp
INNER JOIN dim_mine m ON fp.mine_id = m.mine_id
GROUP BY m.mine_name;
```

**DAX (вариант 1 — SUMMARIZECOLUMNS):**

```dax
EVALUATE
SUMMARIZECOLUMNS(
    dim_mine[mine_name],
    "Всего тонн",       SUM(fact_production[tons_mined]),
    "Среднее за смену",  AVERAGE(fact_production[tons_mined]),
    "Количество смен",   COUNTROWS(fact_production)
)
```

**DAX (вариант 2 — SUMMARIZE + ADDCOLUMNS):**

```dax
EVALUATE
ADDCOLUMNS(
    SUMMARIZE(fact_production, dim_mine[mine_name]),
    "Всего тонн",       CALCULATE(SUM(fact_production[tons_mined])),
    "Среднее за смену",  CALCULATE(AVERAGE(fact_production[tons_mined])),
    "Количество смен",   CALCULATE(COUNTROWS(fact_production))
)
```

> **Сравните оба варианта DAX.** `SUMMARIZECOLUMNS` — компактнее и рекомендуется Microsoft. `SUMMARIZE + ADDCOLUMNS` — более гибкий, нужен `CALCULATE` для переключения контекста.

### Шаг 5.2. Топ-5 операторов по добыче

**SQL:**

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

**DAX:**

```dax
EVALUATE
TOPN(
    5,
    ADDCOLUMNS(
        SUMMARIZE(
            fact_production,
            dim_operator[last_name],
            dim_operator[first_name],
            dim_operator[position]
        ),
        "Всего тонн",   CALCULATE(SUM(fact_production[tons_mined])),
        "Среднее, т",    CALCULATE(AVERAGE(fact_production[tons_mined])),
        "Кол-во смен",  CALCULATE(COUNTROWS(fact_production))
    ),
    [Всего тонн], DESC
)
```

### Шаг 5.3. Анализ простоев по категориям

**SQL:**

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

**DAX:**

```dax
EVALUATE
ADDCOLUMNS(
    SUMMARIZE(
        fact_equipment_downtime,
        dim_downtime_reason[category],
        dim_downtime_reason[reason_name]
    ),
    "Кол-во простоев",  CALCULATE(COUNTROWS(fact_equipment_downtime)),
    "Всего минут",      CALCULATE(SUM(fact_equipment_downtime[duration_min])),
    "Среднее, мин",     CALCULATE(AVERAGE(fact_equipment_downtime[duration_min]))
)
ORDER BY [Всего минут] DESC
```

---

## Контрольные вопросы

1. Чем `SELECTCOLUMNS` в DAX отличается от простого `SELECT` в SQL?
2. Когда лучше использовать `CALCULATETABLE`, а когда `FILTER`?
3. Почему в DAX не нужен `JOIN`?
4. Чем `SUMMARIZECOLUMNS` отличается от `SUMMARIZE + ADDCOLUMNS`?
5. Как реализовать аналог `HAVING` в DAX?

---

## Дополнительное задание (для продвинутых)

Напишите запросы на SQL и DAX, которые покажут:
- Среднее содержание Fe по месяцам 2024 года для каждой шахты
- Сравнение дневной и ночной смены по расходу топлива на тонну руды
- Топ-3 причины внеплановых простоев по суммарной длительности
