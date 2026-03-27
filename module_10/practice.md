# Практическая работа — Модуль 10

## Использование подзапросов

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

## Часть 1. Замкнутые (самостоятельные) подзапросы — скалярные

### Шаг 1.1. Скалярный подзапрос в WHERE

Найдём оборудование, у которого средняя добыча за смену превышает общую среднюю добычу по всему предприятию.

```sql
-- Сначала узнаем среднюю добычу по предприятию
SELECT ROUND(AVG(tons_mined), 2) AS avg_tons
FROM fact_production;

-- Теперь используем скалярный подзапрос
SELECT
    e.equipment_name,
    et.type_name,
    ROUND(AVG(fp.tons_mined), 2) AS avg_tons
FROM fact_production fp
JOIN dim_equipment e  ON fp.equipment_id = e.equipment_id
JOIN dim_equipment_type et ON e.equipment_type_id = et.equipment_type_id
GROUP BY e.equipment_name, et.type_name
HAVING AVG(fp.tons_mined) > (
    SELECT AVG(tons_mined) FROM fact_production
)
ORDER BY avg_tons DESC;
```

**Что наблюдаем:** подзапрос `(SELECT AVG(tons_mined) FROM fact_production)` возвращает одно значение (скаляр). Он выполняется один раз и результат сравнивается с каждой группой.

> **Обсуждение:** Почему нельзя написать `WHERE AVG(fp.tons_mined) > ...`? В чём разница между WHERE и HAVING при работе с агрегатами?

### Шаг 1.2. Скалярный подзапрос в SELECT

```sql
-- Добыча каждого оператора и отклонение от средней по шахте
SELECT
    o.last_name || ' ' || LEFT(o.first_name, 1) || '.' AS operator_name,
    m.mine_name,
    ROUND(AVG(fp.tons_mined), 2) AS avg_tons,
    (SELECT ROUND(AVG(fp2.tons_mined), 2)
     FROM fact_production fp2
     WHERE fp2.mine_id = fp.mine_id) AS mine_avg_tons,
    ROUND(AVG(fp.tons_mined) -
        (SELECT AVG(fp2.tons_mined)
         FROM fact_production fp2
         WHERE fp2.mine_id = fp.mine_id), 2) AS deviation
FROM fact_production fp
JOIN dim_operator o ON fp.operator_id = o.operator_id
JOIN dim_mine m     ON fp.mine_id = m.mine_id
WHERE fp.date_id BETWEEN 20240101 AND 20240331
GROUP BY o.last_name, o.first_name, m.mine_name, fp.mine_id
ORDER BY deviation DESC
LIMIT 10;
```

**Что наблюдаем:** подзапрос в SELECT рассчитывает среднюю добычу по конкретной шахте для каждой строки. Обратите внимание: подзапрос ссылается на `fp.mine_id` — это **коррелированный** подзапрос (будет рассмотрен позже).

### Шаг 1.3. Аналог в DAX

Откройте DAX Studio и выполните:

```dax
// Скалярный подзапрос: оборудование с добычей выше средней
EVALUATE
VAR OverallAvg = AVERAGE(fact_production[tons_mined])
RETURN
FILTER(
    ADDCOLUMNS(
        SUMMARIZE(
            fact_production,
            dim_equipment[equipment_name],
            dim_equipment_type[type_name]
        ),
        "AvgTons", CALCULATE(AVERAGE(fact_production[tons_mined]))
    ),
    [AvgTons] > OverallAvg
)
ORDER BY [AvgTons] DESC
```

> **Обсуждение:** В DAX нет подзапросов в привычном SQL-смысле. Какая конструкция играет роль скалярного подзапроса? (Ответ: переменная VAR + CALCULATE.)

---

## Часть 2. Замкнутые подзапросы — многозначные

### Шаг 2.1. Подзапрос с IN

Найдём операторов, которые работали на оборудовании типа «ПДМ» (погрузочно-доставочная машина).

```sql
-- Шаг 1: подзапрос возвращает список equipment_id типа ПДМ
SELECT equipment_id
FROM dim_equipment e
JOIN dim_equipment_type et ON e.equipment_type_id = et.equipment_type_id
WHERE et.type_code = 'LHD';

-- Шаг 2: используем подзапрос с IN
SELECT DISTINCT
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

**Что наблюдаем:** подзапрос возвращает набор значений `equipment_id`. Оператор `IN` проверяет принадлежность к этому набору.

### Шаг 2.2. NOT IN — шахты без внеплановых простоев за месяц

```sql
-- Шахты, в которых НЕ БЫЛО внеплановых простоев в марте 2024
SELECT m.mine_name, m.mine_code
FROM dim_mine m
WHERE m.mine_id NOT IN (
    SELECT DISTINCT e.mine_id
    FROM fact_equipment_downtime fd
    JOIN dim_equipment e ON fd.equipment_id = e.equipment_id
    WHERE fd.date_id BETWEEN 20240301 AND 20240331
      AND fd.is_planned = FALSE
)
AND m.status = 'active';
```

**Внимание!** Если подзапрос в `NOT IN` может вернуть NULL, результат будет пустым. Убедитесь, что `mine_id` в подзапросе не содержит NULL.

### Шаг 2.3. Подзапрос с ANY / ALL

```sql
-- Оборудование, добывшее за любую смену больше, чем максимум любого самосвала
SELECT DISTINCT
    e.equipment_name,
    et.type_name,
    fp.tons_mined
FROM fact_production fp
JOIN dim_equipment e  ON fp.equipment_id = e.equipment_id
JOIN dim_equipment_type et ON e.equipment_type_id = et.equipment_type_id
WHERE fp.tons_mined > ALL (
    SELECT fp2.tons_mined
    FROM fact_production fp2
    JOIN dim_equipment e2 ON fp2.equipment_id = e2.equipment_id
    JOIN dim_equipment_type et2 ON e2.equipment_type_id = et2.equipment_type_id
    WHERE et2.type_code = 'TRUCK'
)
ORDER BY fp.tons_mined DESC;
```

**Что наблюдаем:** `> ALL(подзапрос)` означает «больше каждого значения из подзапроса», т.е. больше максимального.

> **Обсуждение:** Как переписать `> ALL(...)` без подзапроса? (Подсказка: `> (SELECT MAX(...) ...)`)

### Шаг 2.4. Аналог в DAX

```dax
// Операторы, работавшие на ПДМ (аналог IN)
EVALUATE
VAR LHD_Equipment =
    CALCULATETABLE(
        VALUES(dim_equipment[equipment_id]),
        dim_equipment_type[type_code] = "LHD"
    )
RETURN
CALCULATETABLE(
    SUMMARIZE(
        fact_production,
        dim_operator[last_name],
        dim_operator[first_name],
        dim_operator[position]
    ),
    TREATAS(LHD_Equipment, dim_equipment[equipment_id])
)
ORDER BY dim_operator[last_name]
```

---

## Часть 3. Коррелированные подзапросы

### Шаг 3.1. Базовый коррелированный подзапрос

Для каждого оборудования найдём дату его максимальной добычи.

```sql
SELECT
    e.equipment_name,
    d.full_date,
    fp.tons_mined
FROM fact_production fp
JOIN dim_equipment e ON fp.equipment_id = e.equipment_id
JOIN dim_date d      ON fp.date_id = d.date_id
WHERE fp.tons_mined = (
    -- Коррелированный подзапрос: выполняется для каждой строки внешнего запроса
    SELECT MAX(fp2.tons_mined)
    FROM fact_production fp2
    WHERE fp2.equipment_id = fp.equipment_id  -- связь с внешним запросом
)
ORDER BY fp.tons_mined DESC;
```

**Что наблюдаем:** подзапрос ссылается на `fp.equipment_id` из внешнего запроса. Он выполняется **для каждой строки** внешнего запроса (концептуально — оптимизатор может трансформировать).

### Шаг 3.2. Коррелированный подзапрос для сравнения со средним по группе

```sql
-- Смены, где добыча превысила среднюю для данного оборудования
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
WHERE fp.tons_mined > (
    SELECT AVG(fp2.tons_mined) * 1.2  -- на 20% выше средней
    FROM fact_production fp2
    WHERE fp2.equipment_id = fp.equipment_id
)
ORDER BY fp.tons_mined DESC
LIMIT 15;
```

**Что наблюдаем:** для каждой строки вычисляется средняя добыча именно для этого оборудования.

### Шаг 3.3. Аналог в DAX

```dax
// Коррелированный подзапрос: смены с добычей выше средней для данного оборудования
EVALUATE
VAR ProductionWithAvg =
    ADDCOLUMNS(
        fact_production,
        "EquipAvg",
            CALCULATE(
                AVERAGE(fact_production[tons_mined]),
                ALLEXCEPT(fact_production, fact_production[equipment_id])
            )
    )
RETURN
SELECTCOLUMNS(
    FILTER(
        ProductionWithAvg,
        fact_production[tons_mined] > [EquipAvg] * 1.2
    ),
    "equipment_id", fact_production[equipment_id],
    "date_id", fact_production[date_id],
    "tons_mined", fact_production[tons_mined],
    "EquipAvg", [EquipAvg]
)
```

> **Обсуждение:** Какая конструкция в DAX соответствует коррелированному подзапросу? (Ответ: CALCULATE с ALLEXCEPT — контекст строки преобразуется в контекст фильтра.)

---

## Часть 4. Предикат EXISTS

### Шаг 4.1. EXISTS — оборудование с простоями

Найдём оборудование, у которого были внеплановые простои в I квартале 2024.

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

**Что наблюдаем:** `EXISTS` возвращает `TRUE`, если подзапрос возвращает хотя бы одну строку. Обратите внимание на `SELECT 1` — конкретные столбцы не важны.

### Шаг 4.2. NOT EXISTS — операторы без простоев

```sql
-- Операторы, чьё оборудование НЕ имело внеплановых простоев в марте
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

### Шаг 4.3. EXISTS vs IN — сравнение производительности

```sql
-- Вариант с IN
EXPLAIN ANALYZE
SELECT DISTINCT e.equipment_name
FROM dim_equipment e
WHERE e.equipment_id IN (
    SELECT fd.equipment_id
    FROM fact_equipment_downtime fd
    WHERE fd.is_planned = FALSE
);

-- Вариант с EXISTS
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

**Что наблюдаем:** сравните планы выполнения. PostgreSQL часто трансформирует IN в JOIN, а EXISTS — в Semi Join. Производительность может отличаться в зависимости от наличия индексов.

### Шаг 4.4. Аналог EXISTS в DAX

```dax
// NOT EXISTS: операторы без внеплановых простоев
EVALUATE
VAR OperatorsWithDowntime =
    CALCULATETABLE(
        VALUES(fact_equipment_downtime[operator_id]),
        fact_equipment_downtime[is_planned] = FALSE,
        fact_equipment_downtime[date_id] >= 20240301,
        fact_equipment_downtime[date_id] <= 20240331
    )
RETURN
FILTER(
    SELECTCOLUMNS(
        dim_operator,
        "Оператор", dim_operator[last_name] & " " & LEFT(dim_operator[first_name], 1) & ".",
        "Должность", dim_operator[position],
        "operator_id", dim_operator[operator_id]
    ),
    NOT([operator_id] IN OperatorsWithDowntime)
)
```

> **Обсуждение:** В DAX нет прямого аналога EXISTS. Какие стратегии можно использовать? (CALCULATETABLE + ISEMPTY, COUNTROWS > 0, TREATAS.)

---

## Часть 5. Подзапросы в FROM (производные таблицы)

### Шаг 5.1. Производная таблица для ранжирования

```sql
-- Топ-3 оператора по добыче в каждой шахте
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
    JOIN dim_mine m     ON fp.mine_id = m.mine_id
    WHERE fp.date_id BETWEEN 20240101 AND 20240331
    GROUP BY fp.mine_id, m.mine_name, o.last_name, o.first_name
) ranked
WHERE ranked.rn <= 3
ORDER BY ranked.mine_name, ranked.rn;
```

**Что наблюдаем:** производная таблица (subquery в FROM) позволяет фильтровать по результату оконной функции.

### Шаг 5.2. Множественные производные таблицы

```sql
-- Сравнение добычи и простоев по шахтам
SELECT
    prod.mine_name,
    prod.total_tons,
    prod.work_hours,
    COALESCE(dt.downtime_hours, 0) AS downtime_hours,
    ROUND(prod.work_hours /
        NULLIF(prod.work_hours + COALESCE(dt.downtime_hours, 0), 0) * 100, 1)
        AS availability_pct
FROM (
    SELECT fp.mine_id, m.mine_name,
           ROUND(SUM(fp.tons_mined), 0) AS total_tons,
           ROUND(SUM(fp.operating_hours), 0) AS work_hours
    FROM fact_production fp
    JOIN dim_mine m ON fp.mine_id = m.mine_id
    WHERE fp.date_id BETWEEN 20240101 AND 20240331
    GROUP BY fp.mine_id, m.mine_name
) prod
LEFT JOIN (
    SELECT e.mine_id,
           ROUND(SUM(fd.duration_min) / 60.0, 0) AS downtime_hours
    FROM fact_equipment_downtime fd
    JOIN dim_equipment e ON fd.equipment_id = e.equipment_id
    WHERE fd.date_id BETWEEN 20240101 AND 20240331
    GROUP BY e.mine_id
) dt ON prod.mine_id = dt.mine_id
ORDER BY availability_pct;
```

---

## Контрольные вопросы

1. Какой подзапрос называется замкнутым (самостоятельным), а какой — коррелированным?
2. В чём опасность использования `NOT IN` при наличии NULL в подзапросе?
3. Когда `EXISTS` эффективнее, чем `IN`?
4. Можно ли использовать подзапрос в списке SELECT? Какое ограничение на него накладывается?
5. Какая конструкция DAX наиболее близка к коррелированному подзапросу?
6. Чем производная таблица (подзапрос в FROM) отличается от CTE?

---

## Очистка

Практическая работа использует только SELECT-запросы — удаление объектов не требуется.

---

## Итоги практической работы

По результатам практики вы должны уметь:

1. Составлять скалярные и многозначные замкнутые подзапросы
2. Использовать коррелированные подзапросы для сравнения внутри групп
3. Применять EXISTS / NOT EXISTS для проверки наличия связанных данных
4. Использовать подзапросы в FROM (производные таблицы)
5. Сравнивать подходы SQL и DAX для решения аналогичных задач
