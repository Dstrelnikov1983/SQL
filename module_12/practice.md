# Практическая работа — Модуль 12

## Использование операторов набора

**Продолжительность:** 30 минут
**Инструменты:** Yandex Managed Service for PostgreSQL (SQL) | Power BI + DAX Studio (DAX)
**Предприятие:** «Руда+» — добыча железной руды

---

## Предварительные требования

1. База данных «Руда+» развёрнута на PostgreSQL (скрипты `01_create_schema.sql`, `02_insert_dimensions.sql`, `03_insert_facts.sql` из каталога `common/scripts/`)
2. Модель данных импортирована в Power BI
3. DAX Studio установлен и подключён к модели Power BI
4. Клиент SQL (DBeaver, pgAdmin или psql) подключён к PostgreSQL

---

## Часть 1. UNION и UNION ALL

### Шаг 1.1. UNION ALL — объединение данных из разных таблиц

Объединим записи о добыче и простоях в единый журнал событий.

```sql
-- Журнал событий оборудования: добыча + простои
SELECT
    'Добыча'      AS event_type,
    fp.date_id,
    fp.equipment_id,
    e.equipment_name,
    fp.tons_mined AS metric_value,
    'тонн'        AS unit
FROM fact_production fp
JOIN dim_equipment e ON fp.equipment_id = e.equipment_id
WHERE fp.date_id = 20240315

UNION ALL

SELECT
    'Простой'       AS event_type,
    fd.date_id,
    fd.equipment_id,
    e.equipment_name,
    fd.duration_min AS metric_value,
    'мин.'          AS unit
FROM fact_equipment_downtime fd
JOIN dim_equipment e ON fd.equipment_id = e.equipment_id
WHERE fd.date_id = 20240315

ORDER BY equipment_name, event_type;
```

**Что наблюдаем:** UNION ALL объединяет строки из двух запросов. Столбцы должны совпадать по количеству и типам. Дубликаты **не удаляются**.

### Шаг 1.2. UNION — удаление дубликатов

```sql
-- Все шахты, упоминаемые в добыче или простоях за Q1 2024
SELECT m.mine_name, 'Добыча' AS source
FROM fact_production fp
JOIN dim_mine m ON fp.mine_id = m.mine_id
WHERE fp.date_id BETWEEN 20240101 AND 20240331

UNION  -- удаляет дубликаты

SELECT m.mine_name, 'Простой' AS source
FROM fact_equipment_downtime fd
JOIN dim_equipment e ON fd.equipment_id = e.equipment_id
JOIN dim_mine m      ON e.mine_id = m.mine_id
WHERE fd.date_id BETWEEN 20240101 AND 20240331

ORDER BY mine_name;
```

> **Обсуждение:** Чем UNION отличается от UNION ALL? Когда использовать каждый? (Ответ: UNION выполняет DISTINCT, что дороже по производительности.)

### Шаг 1.3. UNION ALL с агрегацией — сводный отчёт

```sql
-- Сводный отчёт: добыча и простои по шахтам (разные метрики в одном отчёте)
SELECT mine_name, metric, value
FROM (
    SELECT m.mine_name, 'Добыча (тонн)' AS metric,
           ROUND(SUM(fp.tons_mined), 0) AS value
    FROM fact_production fp
    JOIN dim_mine m ON fp.mine_id = m.mine_id
    WHERE fp.date_id BETWEEN 20240301 AND 20240331
    GROUP BY m.mine_name

    UNION ALL

    SELECT m.mine_name, 'Простои (часы)' AS metric,
           ROUND(SUM(fd.duration_min) / 60.0, 0)
    FROM fact_equipment_downtime fd
    JOIN dim_equipment e ON fd.equipment_id = e.equipment_id
    JOIN dim_mine m      ON e.mine_id = m.mine_id
    WHERE fd.date_id BETWEEN 20240301 AND 20240331
    GROUP BY m.mine_name

    UNION ALL

    SELECT m.mine_name, 'Качество Fe (%)' AS metric,
           ROUND(AVG(q.fe_content), 2)
    FROM fact_ore_quality q
    JOIN dim_mine m ON q.mine_id = m.mine_id
    WHERE q.date_id BETWEEN 20240301 AND 20240331
    GROUP BY m.mine_name
) combined
ORDER BY mine_name, metric;
```

**Что наблюдаем:** UNION ALL позволяет объединять метрики разного характера в один плоский отчёт.

### Шаг 1.4. Аналог в DAX

```dax
// UNION — объединение таблиц в DAX
EVALUATE
VAR ProductionEvents =
    SELECTCOLUMNS(
        FILTER(fact_production, fact_production[date_id] = 20240315),
        "EventType", "Добыча",
        "equipment_id", fact_production[equipment_id],
        "MetricValue", fact_production[tons_mined],
        "Unit", "тонн"
    )
VAR DowntimeEvents =
    SELECTCOLUMNS(
        FILTER(fact_equipment_downtime, fact_equipment_downtime[date_id] = 20240315),
        "EventType", "Простой",
        "equipment_id", fact_equipment_downtime[equipment_id],
        "MetricValue", fact_equipment_downtime[duration_min],
        "Unit", "мин."
    )
RETURN
UNION(ProductionEvents, DowntimeEvents)
ORDER BY [equipment_id], [EventType]
```

---

## Часть 2. EXCEPT (MINUS)

### Шаг 2.1. EXCEPT — оборудование без простоев

```sql
-- Оборудование, участвовавшее в добыче, но НЕ имевшее простоев в марте
SELECT equipment_id FROM fact_production
WHERE date_id BETWEEN 20240301 AND 20240331

EXCEPT

SELECT equipment_id FROM fact_equipment_downtime
WHERE date_id BETWEEN 20240301 AND 20240331;
```

**Что наблюдаем:** EXCEPT возвращает строки из первого запроса, отсутствующие во втором. Дубликаты автоматически удаляются.

### Шаг 2.2. EXCEPT с расшифровкой

```sql
-- С расшифровкой через JOIN
SELECT
    e.equipment_name,
    et.type_name,
    m.mine_name
FROM dim_equipment e
JOIN dim_equipment_type et ON e.equipment_type_id = et.equipment_type_id
JOIN dim_mine m            ON e.mine_id = m.mine_id
WHERE e.equipment_id IN (
    SELECT equipment_id FROM fact_production
    WHERE date_id BETWEEN 20240301 AND 20240331

    EXCEPT

    SELECT equipment_id FROM fact_equipment_downtime
    WHERE date_id BETWEEN 20240301 AND 20240331
)
ORDER BY e.equipment_name;
```

### Шаг 2.3. Аналог в DAX

```dax
// EXCEPT — оборудование с добычей, но без простоев
EVALUATE
VAR ProdEquip =
    CALCULATETABLE(
        VALUES(fact_production[equipment_id]),
        fact_production[date_id] >= 20240301,
        fact_production[date_id] <= 20240331
    )
VAR DowntimeEquip =
    CALCULATETABLE(
        VALUES(fact_equipment_downtime[equipment_id]),
        fact_equipment_downtime[date_id] >= 20240301,
        fact_equipment_downtime[date_id] <= 20240331
    )
RETURN
EXCEPT(ProdEquip, DowntimeEquip)
```

> **Обсуждение:** Как реализовать EXCEPT без оператора набора? (Ответ: NOT IN или NOT EXISTS.)

---

## Часть 3. INTERSECT

### Шаг 3.1. INTERSECT — оборудование с добычей И простоями

```sql
-- Оборудование, у которого есть и добыча, и простои в марте
SELECT equipment_id FROM fact_production
WHERE date_id BETWEEN 20240301 AND 20240331

INTERSECT

SELECT equipment_id FROM fact_equipment_downtime
WHERE date_id BETWEEN 20240301 AND 20240331;
```

### Шаг 3.2. INTERSECT для проверки полноты данных

```sql
-- Операторы, упомянутые и в добыче, и в простоях
SELECT operator_id FROM fact_production
WHERE date_id BETWEEN 20240301 AND 20240331

INTERSECT

SELECT operator_id FROM fact_equipment_downtime
WHERE date_id BETWEEN 20240301 AND 20240331
  AND operator_id IS NOT NULL;
```

### Шаг 3.3. Аналог в DAX

```dax
// INTERSECT — оборудование с добычей И простоями
EVALUATE
VAR ProdEquip =
    CALCULATETABLE(
        VALUES(fact_production[equipment_id]),
        fact_production[date_id] >= 20240301,
        fact_production[date_id] <= 20240331
    )
VAR DowntimeEquip =
    CALCULATETABLE(
        VALUES(fact_equipment_downtime[equipment_id]),
        fact_equipment_downtime[date_id] >= 20240301,
        fact_equipment_downtime[date_id] <= 20240331
    )
RETURN
INTERSECT(ProdEquip, DowntimeEquip)
```

---

## Часть 4. LATERAL JOIN (CROSS APPLY)

### Шаг 4.1. LATERAL — топ-3 записи для каждой шахты

```sql
-- Для каждой шахты — 3 рекордные смены по добыче
SELECT m.mine_name, top3.*
FROM dim_mine m
CROSS JOIN LATERAL (
    SELECT
        d.full_date,
        e.equipment_name,
        fp.tons_mined
    FROM fact_production fp
    JOIN dim_date d      ON fp.date_id = d.date_id
    JOIN dim_equipment e ON fp.equipment_id = e.equipment_id
    WHERE fp.mine_id = m.mine_id
      AND fp.date_id BETWEEN 20240101 AND 20240331
    ORDER BY fp.tons_mined DESC
    LIMIT 3
) top3
WHERE m.status = 'active'
ORDER BY m.mine_name, top3.tons_mined DESC;
```

**Что наблюдаем:** LATERAL позволяет подзапросу ссылаться на столбцы из внешнего FROM. Это аналог CROSS APPLY в SQL Server.

### Шаг 4.2. LEFT JOIN LATERAL — включая шахты без данных

```sql
-- Включаем шахты без добычи (LEFT JOIN LATERAL вместо CROSS JOIN LATERAL)
SELECT m.mine_name, top3.*
FROM dim_mine m
LEFT JOIN LATERAL (
    SELECT
        d.full_date,
        e.equipment_name,
        fp.tons_mined
    FROM fact_production fp
    JOIN dim_date d      ON fp.date_id = d.date_id
    JOIN dim_equipment e ON fp.equipment_id = e.equipment_id
    WHERE fp.mine_id = m.mine_id
      AND fp.date_id BETWEEN 20240101 AND 20240331
    ORDER BY fp.tons_mined DESC
    LIMIT 3
) top3 ON TRUE
ORDER BY m.mine_name, top3.tons_mined DESC NULLS LAST;
```

**Что наблюдаем:** LEFT JOIN LATERAL возвращает строки из левой таблицы, даже если подзапрос не вернул результатов (аналог OUTER APPLY).

### Шаг 4.3. LATERAL с табличной функцией

```sql
-- Вызов табличной функции для каждой шахты
SELECT m.mine_name, r.shift_name, r.operator_name, r.total_tons
FROM dim_mine m
CROSS JOIN LATERAL fn_mine_production_report(
    m.mine_id, 20240101, 20240131
) r
WHERE m.status = 'active'
ORDER BY m.mine_name, r.total_tons DESC;
```

### Шаг 4.4. Аналог LATERAL в DAX

```dax
// CROSS APPLY / LATERAL — топ-3 записи добычи по шахтам
// В DAX — через TOPN + SUMMARIZE в контексте шахты
EVALUATE
VAR Top3ByMine =
    GENERATE(
        FILTER(VALUES(dim_mine[mine_name]), dim_mine[status] = "active"),
        TOPN(3,
            ADDCOLUMNS(
                SUMMARIZE(
                    fact_production,
                    dim_date[full_date],
                    dim_equipment[equipment_name]
                ),
                "TonsMined", CALCULATE(MAX(fact_production[tons_mined]))
            ),
            [TonsMined], DESC
        )
    )
RETURN
Top3ByMine
ORDER BY dim_mine[mine_name], [TonsMined] DESC
```

> **Обсуждение:** GENERATE в DAX — аналог CROSS APPLY. Как работает контекст строки при вызове GENERATE? Чем GENERATEALL отличается от GENERATE? (GENERATEALL — аналог OUTER APPLY.)

---

## Часть 5. Комбинирование операторов набора

### Шаг 5.1. Комплексный анализ пересечений

```sql
-- Аналитика: какие операторы работали на разных типах оборудования
WITH lhd_operators AS (
    SELECT DISTINCT fp.operator_id
    FROM fact_production fp
    JOIN dim_equipment e ON fp.equipment_id = e.equipment_id
    JOIN dim_equipment_type et ON e.equipment_type_id = et.equipment_type_id
    WHERE et.type_code = 'LHD'
),
truck_operators AS (
    SELECT DISTINCT fp.operator_id
    FROM fact_production fp
    JOIN dim_equipment e ON fp.equipment_id = e.equipment_id
    JOIN dim_equipment_type et ON e.equipment_type_id = et.equipment_type_id
    WHERE et.type_code = 'TRUCK'
)
-- Работали на обоих типах (INTERSECT)
SELECT 'ПДМ и самосвал' AS category, COUNT(*) AS cnt
FROM (SELECT operator_id FROM lhd_operators INTERSECT SELECT operator_id FROM truck_operators) x

UNION ALL

-- Только на ПДМ (EXCEPT)
SELECT 'Только ПДМ', COUNT(*)
FROM (SELECT operator_id FROM lhd_operators EXCEPT SELECT operator_id FROM truck_operators) x

UNION ALL

-- Только на самосвале (EXCEPT)
SELECT 'Только самосвал', COUNT(*)
FROM (SELECT operator_id FROM truck_operators EXCEPT SELECT operator_id FROM lhd_operators) x;
```

**Что наблюдаем:** комбинация UNION ALL, INTERSECT и EXCEPT позволяет проводить анализ пересечений (диаграмма Венна).

---

## Контрольные вопросы

1. В чём разница между UNION и UNION ALL по производительности и результату?
2. Какие требования предъявляются к столбцам в операторах набора?
3. Как реализовать EXCEPT без использования оператора EXCEPT? (NOT IN / NOT EXISTS / LEFT JOIN ... IS NULL)
4. Чем CROSS JOIN LATERAL отличается от обычного подзапроса?
5. Какие функции DAX соответствуют UNION, EXCEPT, INTERSECT?
6. Что такое GENERATE / GENERATEALL и какие SQL-конструкции они заменяют?

---

## Итоги практической работы

По результатам практики вы должны уметь:

1. Объединять результаты запросов с помощью UNION / UNION ALL
2. Находить разности наборов через EXCEPT
3. Находить пересечения через INTERSECT
4. Использовать LATERAL JOIN (CROSS APPLY) для параметризованных подзапросов
5. Применять аналоги операторов набора в DAX (UNION, EXCEPT, INTERSECT, GENERATE)
