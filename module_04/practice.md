# Практическая работа — Модуль 4

## Работа с типами данных PostgreSQL

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

## Часть 1. Строковые функции (15 минут)

### Шаг 1.1. Исследование строковых данных в таблице оборудования

**SQL (PostgreSQL):**

```sql
-- Посмотрим на строковые столбцы таблицы dim_equipment
SELECT equipment_name,
       inventory_number,
       manufacturer,
       model
FROM dim_equipment
ORDER BY equipment_name;
```

**Что наблюдаем:**
- Формат inventory_number: `INV-LHD-001`, `INV-TRUCK-005` и т.д.
- equipment_name содержит русские названия: «ПДМ-01», «Самосвал-05»
- Данные структурированы — можно разбирать на части

### Шаг 1.2. Длина строк и базовые операции

**SQL:**

```sql
-- Длина названий оборудования
SELECT equipment_name,
       LENGTH(equipment_name) AS name_length,
       LENGTH(inventory_number) AS inv_length,
       UPPER(status) AS status_upper,
       LOWER(manufacturer) AS manufacturer_lower
FROM dim_equipment;
```

**DAX:**

```dax
EVALUATE
SELECTCOLUMNS(
    dim_equipment,
    "Название", dim_equipment[equipment_name],
    "Длина названия", LEN(dim_equipment[equipment_name]),
    "Длина инв. номера", LEN(dim_equipment[inventory_number]),
    "Статус (верхний)", UPPER(dim_equipment[status]),
    "Производитель (нижний)", LOWER(dim_equipment[manufacturer])
)
```

> **Обратите внимание:** в SQL — `LENGTH()`, в DAX — `LEN()`.

### Шаг 1.3. Разбор инвентарного номера (SPLIT_PART)

**SQL:**

```sql
-- Разбираем инвентарный номер: INV-LHD-001
SELECT inventory_number,
       SPLIT_PART(inventory_number, '-', 1) AS prefix,
       SPLIT_PART(inventory_number, '-', 2) AS type_code,
       SPLIT_PART(inventory_number, '-', 3) AS serial_number,
       CAST(SPLIT_PART(inventory_number, '-', 3) AS INTEGER) AS serial_int
FROM dim_equipment;
```

**DAX (эмуляция SPLIT_PART):**

```dax
EVALUATE
SELECTCOLUMNS(
    dim_equipment,
    "Инв. номер", dim_equipment[inventory_number],
    "Тип",
        MID(
            dim_equipment[inventory_number],
            SEARCH("-", dim_equipment[inventory_number]) + 1,
            SEARCH("-", dim_equipment[inventory_number],
                   SEARCH("-", dim_equipment[inventory_number]) + 1)
            - SEARCH("-", dim_equipment[inventory_number]) - 1
        )
)
```

> **Обратите внимание:** в DAX извлечение подстроки между разделителями — значительно сложнее, чем в PostgreSQL.

### Шаг 1.4. Формирование полного имени оператора

**SQL:**

```sql
-- Полное имя: "Иванов И.П."
SELECT CONCAT(
           last_name, ' ',
           LEFT(first_name, 1), '.',
           CASE
               WHEN middle_name IS NOT NULL
               THEN LEFT(middle_name, 1) || '.'
               ELSE ''
           END
       ) AS short_name,
       -- Полное имя
       CONCAT_WS(' ', last_name, first_name, middle_name) AS full_name
FROM dim_operator;
```

**DAX:**

```dax
EVALUATE
SELECTCOLUMNS(
    dim_operator,
    "Краткое имя",
        dim_operator[last_name] & " " &
        LEFT(dim_operator[first_name], 1) & "." &
        IF(
            ISBLANK(dim_operator[middle_name]),
            "",
            LEFT(dim_operator[middle_name], 1) & "."
        ),
    "Полное имя",
        dim_operator[last_name] & " " &
        dim_operator[first_name] & " " &
        IF(ISBLANK(dim_operator[middle_name]), "", dim_operator[middle_name])
)
```

> **Обратите внимание:** `CONCAT_WS` (с разделителем) — функция PostgreSQL, в DAX аналога нет.

### Шаг 1.5. Агрегация строк: STRING_AGG

**SQL:**

```sql
-- Список оборудования по каждой шахте (через запятую)
SELECT m.mine_name,
       STRING_AGG(e.equipment_name, ', ' ORDER BY e.equipment_name) AS equipment_list
FROM dim_equipment e
JOIN dim_mine m ON e.mine_id = m.mine_id
GROUP BY m.mine_name;
```

**DAX:**

```dax
EVALUATE
SELECTCOLUMNS(
    dim_mine,
    "Шахта", dim_mine[mine_name],
    "Оборудование",
        CONCATENATEX(
            RELATEDTABLE(dim_equipment),
            dim_equipment[equipment_name],
            ", ",
            dim_equipment[equipment_name], ASC
        )
)
```

> **Обратите внимание:** в SQL — `STRING_AGG`, в DAX — `CONCATENATEX`. Оба поддерживают сортировку.

---

## Часть 2. Шаблонный поиск (10 минут)

### Шаг 2.1. LIKE и ILIKE

**SQL:**

```sql
-- Оборудование, начинающееся с "ПДМ"
SELECT equipment_name, inventory_number
FROM dim_equipment
WHERE equipment_name LIKE 'ПДМ%';

-- Поиск без учёта регистра
SELECT mine_name
FROM dim_mine
WHERE mine_name ILIKE '%северная%';

-- Инвентарные номера ПДМ с произвольным серийным номером
SELECT inventory_number
FROM dim_equipment
WHERE inventory_number LIKE 'INV-LHD-___';
```

### Шаг 2.2. SIMILAR TO и регулярные выражения

**SQL:**

```sql
-- SIMILAR TO: оборудование типа LHD или TRUCK
SELECT inventory_number, equipment_name
FROM dim_equipment
WHERE inventory_number SIMILAR TO 'INV-(LHD|TRUCK)-%';

-- POSIX regex: извлечь числовую часть из инвентарного номера
SELECT inventory_number,
       (REGEXP_MATCH(inventory_number, '(\d+)$'))[1] AS trailing_number
FROM dim_equipment;

-- Замена по регулярному выражению
SELECT comment,
       REGEXP_REPLACE(comment, '\s+', ' ', 'g') AS normalized_comment
FROM fact_equipment_downtime
WHERE comment IS NOT NULL
LIMIT 5;
```

**DAX (ограниченный поиск):**

```dax
// DAX: только простой поиск подстроки
EVALUATE
FILTER(
    dim_equipment,
    CONTAINSSTRING(dim_equipment[inventory_number], "LHD")
    || CONTAINSSTRING(dim_equipment[inventory_number], "TRUCK")
)
```

> **Важно:** DAX не поддерживает регулярные выражения. Для сложного текстового парсинга используйте SQL или Power Query (M).

---

## Часть 3. Дата и время (20 минут)

### Шаг 3.1. Текущая дата и извлечение компонентов

**SQL:**

```sql
-- Текущая дата и время
SELECT CURRENT_DATE AS today,
       CURRENT_TIME AS now_time,
       NOW() AS now_timestamp;

-- Извлечение компонентов из даты ввода в эксплуатацию
SELECT equipment_name,
       commissioning_date,
       EXTRACT(YEAR  FROM commissioning_date)  AS comm_year,
       EXTRACT(MONTH FROM commissioning_date)  AS comm_month,
       EXTRACT(DOW   FROM commissioning_date)  AS day_of_week,
       EXTRACT(QUARTER FROM commissioning_date) AS comm_quarter
FROM dim_equipment
WHERE commissioning_date IS NOT NULL;
```

**DAX:**

```dax
EVALUATE
SELECTCOLUMNS(
    FILTER(dim_equipment, NOT ISBLANK(dim_equipment[commissioning_date])),
    "Оборудование", dim_equipment[equipment_name],
    "Дата ввода", dim_equipment[commissioning_date],
    "Год", YEAR(dim_equipment[commissioning_date]),
    "Месяц", MONTH(dim_equipment[commissioning_date]),
    "День недели", WEEKDAY(dim_equipment[commissioning_date]),
    "Квартал", QUARTER(dim_equipment[commissioning_date])
)
```

### Шаг 3.2. DATE_TRUNC — усечение даты

**SQL:**

```sql
-- Группировка добычи по месяцам
SELECT DATE_TRUNC('month', d.full_date) AS month_start,
       SUM(fp.tons_mined) AS total_tons
FROM fact_production fp
JOIN dim_date d ON fp.date_id = d.date_id
WHERE d.year = 2024
GROUP BY DATE_TRUNC('month', d.full_date)
ORDER BY month_start;

-- Усечение начала простоя до часа
SELECT DATE_TRUNC('hour', start_time) AS hour_bucket,
       COUNT(*) AS downtime_count
FROM fact_equipment_downtime
GROUP BY DATE_TRUNC('hour', start_time)
ORDER BY downtime_count DESC
LIMIT 10;
```

**DAX (эмуляция DATE_TRUNC):**

```dax
// Группировка добычи по месяцам
EVALUATE
ADDCOLUMNS(
    SUMMARIZE(
        fact_production,
        dim_date[year],
        dim_date[month]
    ),
    "Начало месяца", DATE(dim_date[year], dim_date[month], 1),
    "Всего тонн", CALCULATE(SUM(fact_production[tons_mined]))
)
ORDER BY dim_date[year], dim_date[month]
```

### Шаг 3.3. Арифметика дат и AGE

**SQL:**

```sql
-- Возраст оборудования
SELECT equipment_name,
       commissioning_date,
       AGE(CURRENT_DATE, commissioning_date) AS full_age,
       EXTRACT(YEAR FROM AGE(CURRENT_DATE, commissioning_date)) AS years,
       CURRENT_DATE - commissioning_date AS total_days
FROM dim_equipment
WHERE commissioning_date IS NOT NULL
ORDER BY total_days DESC;

-- Дата следующего ТО (каждые 90 дней от ввода в эксплуатацию)
SELECT equipment_name,
       commissioning_date,
       commissioning_date + INTERVAL '90 days' AS first_to,
       commissioning_date + INTERVAL '180 days' AS second_to,
       commissioning_date + INTERVAL '365 days' AS annual_to
FROM dim_equipment
WHERE commissioning_date IS NOT NULL;
```

**DAX:**

```dax
EVALUATE
SELECTCOLUMNS(
    FILTER(dim_equipment, NOT ISBLANK(dim_equipment[commissioning_date])),
    "Оборудование", dim_equipment[equipment_name],
    "Дата ввода", dim_equipment[commissioning_date],
    "Дней в эксплуатации",
        DATEDIFF(dim_equipment[commissioning_date], TODAY(), DAY),
    "Лет в эксплуатации",
        DATEDIFF(dim_equipment[commissioning_date], TODAY(), YEAR),
    "Первое ТО",
        dim_equipment[commissioning_date] + 90,
    "Годовое ТО",
        dim_equipment[commissioning_date] + 365
)
```

### Шаг 3.4. Форматирование дат (TO_CHAR)

**SQL:**

```sql
-- Различные форматы отображения
SELECT equipment_name,
       commissioning_date,
       TO_CHAR(commissioning_date, 'DD.MM.YYYY')     AS russian_format,
       TO_CHAR(commissioning_date, 'DD Mon YYYY')     AS short_month,
       TO_CHAR(commissioning_date, 'YYYY-"Q"Q')       AS year_quarter,
       TO_CHAR(commissioning_date, 'Day')              AS day_name
FROM dim_equipment
WHERE commissioning_date IS NOT NULL;
```

**DAX:**

```dax
EVALUATE
SELECTCOLUMNS(
    FILTER(dim_equipment, NOT ISBLANK(dim_equipment[commissioning_date])),
    "Оборудование", dim_equipment[equipment_name],
    "Русский формат",
        FORMAT(dim_equipment[commissioning_date], "DD.MM.YYYY"),
    "Год-квартал",
        FORMAT(dim_equipment[commissioning_date], "YYYY") & "-Q" &
        FORMAT(QUARTER(dim_equipment[commissioning_date]), "0"),
    "День недели",
        FORMAT(dim_equipment[commissioning_date], "DDDD")
)
```

### Шаг 3.5. Расчёт длительности простоев из TIMESTAMP

**SQL:**

```sql
-- Вычисление длительности простоя из start_time и end_time
SELECT e.equipment_name,
       dt.start_time,
       dt.end_time,
       -- Разница в минутах
       ROUND(EXTRACT(EPOCH FROM (dt.end_time - dt.start_time)) / 60, 1)
           AS calculated_min,
       dt.duration_min AS stored_min,
       -- Формат длительности
       TO_CHAR(dt.end_time - dt.start_time, 'HH24:MI:SS') AS duration_formatted
FROM fact_equipment_downtime dt
JOIN dim_equipment e ON dt.equipment_id = e.equipment_id
WHERE dt.end_time IS NOT NULL
ORDER BY calculated_min DESC
LIMIT 10;
```

**Что наблюдаем:**
- `EXTRACT(EPOCH FROM ...)` возвращает секунды — делим на 60 для минут
- `TO_CHAR` для INTERVAL позволяет красиво отформатировать длительность
- Вычисленное значение должно совпасть с `duration_min`

---

## Часть 4. Комплексный пример (контроль качества данных)

### Шаг 4.1. Проверка строковых данных

**SQL:**

```sql
-- Поиск пробелов в начале/конце строк
SELECT equipment_name,
       LENGTH(equipment_name) AS original_len,
       LENGTH(TRIM(equipment_name)) AS trimmed_len,
       CASE
           WHEN LENGTH(equipment_name) <> LENGTH(TRIM(equipment_name))
           THEN 'ПРОБЕЛЫ!'
           ELSE 'OK'
       END AS check_result
FROM dim_equipment;

-- Проверка формата инвентарного номера (должен быть INV-XXX-NNN)
SELECT inventory_number,
       CASE
           WHEN inventory_number ~ '^INV-[A-Z]+-\d{3}$'
           THEN 'Корректный'
           ELSE 'ОШИБКА ФОРМАТА'
       END AS format_check
FROM dim_equipment;
```

### Шаг 4.2. Проверка дат

**SQL:**

```sql
-- Оборудование с подозрительными датами
SELECT equipment_name,
       commissioning_date,
       year_manufactured,
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

---

## Самопроверка

После выполнения практической работы вы должны уметь:

- [ ] Использовать строковые функции: LENGTH, SUBSTRING, SPLIT_PART, CONCAT, TRIM, UPPER/LOWER
- [ ] Применять шаблонный поиск: LIKE, ILIKE, SIMILAR TO, POSIX regex
- [ ] Извлекать компоненты дат: EXTRACT, DATE_TRUNC
- [ ] Выполнять арифметику дат: INTERVAL, AGE, разница дат
- [ ] Форматировать даты: TO_CHAR, TO_DATE
- [ ] Сопоставлять функции SQL и DAX для строк и дат
