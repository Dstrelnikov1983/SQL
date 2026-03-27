# Лабораторная работа — Модуль 12

## Использование операторов набора

**Продолжительность:** 40 минут
**Формат:** самостоятельная работа
**Инструменты:** PostgreSQL (Yandex Managed Service for PostgreSQL)
**База данных:** «Руда+» (MES-система горнодобывающего предприятия)

---

## Общие указания

- Для каждого задания напишите SQL-запрос и сохраните его в файл `lab_solutions.sql`
- Где указано, сравните с альтернативными подходами (NOT IN, NOT EXISTS, JOIN)
- Задания расположены по возрастанию сложности

---

## Задание 1. UNION ALL — объединённый журнал событий (простое)

**Бизнес-задача:** Диспетчер хочет видеть единую хронологию событий оборудования за 15 марта 2024: записи о добыче и простоях.

**Требования:**

1. Объедините с помощью `UNION ALL` данные из `fact_production` и `fact_equipment_downtime` за `date_id = 20240315`
2. Для каждой записи выведите:
   - Тип события (`'Добыча'` / `'Простой'`)
   - Название оборудования
   - Числовое значение (тонн добычи или минут простоя)
   - Единица измерения (`'тонн'` / `'мин.'`)
3. Отсортируйте по названию оборудования и типу события

**Ожидаемый результат:** единая таблица с чередующимися записями добычи и простоев.

<details>
<summary>Решение (DAX)</summary>

```dax
EVALUATE
VAR ProductionEvents =
    SELECTCOLUMNS(
        CALCULATETABLE(fact_production, dim_date[date_id] = 20240315),
        "event_type", "Добыча",
        "equipment_name", RELATED(dim_equipment[equipment_name]),
        "value", fact_production[tons_mined],
        "unit", "тонн"
    )
VAR DowntimeEvents =
    SELECTCOLUMNS(
        CALCULATETABLE(fact_equipment_downtime, dim_date[date_id] = 20240315),
        "event_type", "Простой",
        "equipment_name", RELATED(dim_equipment[equipment_name]),
        "value", fact_equipment_downtime[duration_min],
        "unit", "мин."
    )
RETURN
UNION(ProductionEvents, DowntimeEvents)
ORDER BY [equipment_name], [event_type]
```

> **Примечание:** `UNION ALL` в SQL соответствует `UNION` в DAX (DAX `UNION` всегда сохраняет дубликаты, как `UNION ALL` в SQL). Столбцы: `tons_mined` -> `ore_mined_tons`, `duration_min` -> `duration_minutes`.

</details>

---

## Задание 2. UNION — уникальные шахты с активностью (простое)

**Бизнес-задача:** Определить все шахты, в которых была хоть какая-то активность (добыча ИЛИ простои) за I квартал 2024.

**Требования:**

1. Используя `UNION` (без ALL), объедините:
   - `mine_id` из `fact_production` (через `dim_mine`)
   - `mine_id` из `fact_equipment_downtime` (через `dim_equipment` → `dim_mine`)
2. Присоедините `dim_mine` для получения названий
3. Подсчитайте количество уникальных шахт

**Вопрос:** Если заменить UNION на UNION ALL, изменится ли количество строк? Почему?

<details>
<summary>Решение (DAX)</summary>

```dax
EVALUATE
VAR ProductionMines =
    SELECTCOLUMNS(
        SUMMARIZE(
            CALCULATETABLE(
                fact_production,
                dim_date[date_id] >= 20240101 && dim_date[date_id] <= 20240331
            ),
            dim_mine[mine_name]
        ),
        "mine_name", dim_mine[mine_name]
    )
VAR DowntimeMines =
    SELECTCOLUMNS(
        SUMMARIZE(
            CALCULATETABLE(
                fact_equipment_downtime,
                dim_date[date_id] >= 20240101 && dim_date[date_id] <= 20240331
            ),
            dim_mine[mine_name]
        ),
        "mine_name", dim_mine[mine_name]
    )
RETURN
DISTINCT(UNION(ProductionMines, DowntimeMines))
```

> **Примечание:** `UNION` без `ALL` в SQL удаляет дубликаты. В DAX для этого нужно обернуть `UNION` в `DISTINCT`.

</details>

---

## Задание 3. EXCEPT — оборудование без данных о качестве (среднее)

**Бизнес-задача:** Найти оборудование, у которого есть записи о добыче, но нет связанных данных о качестве руды за I квартал 2024.

**Требования:**

1. Используя `EXCEPT`, найдите `equipment_id`:
   - Первый набор: уникальные `equipment_id` из `fact_production` за Q1 2024
   - Второй набор: уникальные `equipment_id` из `fact_ore_quality` (через `fact_production`, связывая по `mine_id`, `shaft_id`, `date_id`)
2. Расшифруйте результат — выведите название оборудования и тип
3. Перепишите этот же запрос с `NOT EXISTS` и сравните результаты

<details>
<summary>Решение (DAX)</summary>

```dax
EVALUATE
VAR Q1Filter = dim_date[date_id] >= 20240101 && dim_date[date_id] <= 20240331
VAR ProductionEquipment =
    CALCULATETABLE(
        DISTINCT(SELECTCOLUMNS(fact_production, "eq_id", fact_production[equipment_id])),
        Q1Filter
    )
VAR QualityEquipment =
    CALCULATETABLE(
        DISTINCT(SELECTCOLUMNS(fact_ore_quality, "eq_id", fact_ore_quality[equipment_id])),
        Q1Filter
    )
RETURN
VAR DiffEquipment = EXCEPT(ProductionEquipment, QualityEquipment)
RETURN
SELECTCOLUMNS(
    FILTER(
        dim_equipment,
        dim_equipment[equipment_id] IN DiffEquipment
    ),
    "equipment_name", dim_equipment[equipment_name],
    "type_name", RELATED(dim_equipment_type[type_name])
)
ORDER BY [equipment_name]
```

> **Примечание:** `EXCEPT` в SQL напрямую соответствует `EXCEPT` в DAX. Обе функции возвращают строки из первого набора, отсутствующие во втором.

</details>

---

## Задание 4. INTERSECT — операторы на нескольких типах оборудования (среднее)

**Бизнес-задача:** Найти операторов-универсалов, которые работали и на ПДМ, и на самосвалах.

**Требования:**

1. Используя `INTERSECT`, найдите `operator_id`:
   - Набор 1: операторы, работавшие на оборудовании типа `LHD` (ПДМ)
   - Набор 2: операторы, работавшие на оборудовании типа `TRUCK` (самосвал)
2. Расшифруйте: выведите ФИО, должность, квалификацию
3. Подсчитайте, сколько процентов от общего числа операторов являются универсалами

**Подсказка:**

```sql
SELECT fp.operator_id
FROM fact_production fp
JOIN dim_equipment e ON fp.equipment_id = e.equipment_id
JOIN dim_equipment_type et ON e.equipment_type_id = et.equipment_type_id
WHERE et.type_code = 'LHD'

INTERSECT

SELECT fp.operator_id
FROM ...
WHERE et.type_code = 'TRUCK'
```

<details>
<summary>Решение (DAX)</summary>

```dax
EVALUATE
VAR LhdOperators =
    CALCULATETABLE(
        DISTINCT(SELECTCOLUMNS(fact_production, "op_id", fact_production[operator_id])),
        dim_equipment_type[type_code] = "LHD"
    )
VAR TruckOperators =
    CALCULATETABLE(
        DISTINCT(SELECTCOLUMNS(fact_production, "op_id", fact_production[operator_id])),
        dim_equipment_type[type_code] = "TRUCK"
    )
VAR UniversalOperators = INTERSECT(LhdOperators, TruckOperators)
RETURN
SELECTCOLUMNS(
    FILTER(
        dim_operator,
        dim_operator[operator_id] IN UniversalOperators
    ),
    "operator_name", dim_operator[full_name],
    "position", dim_operator[position],
    "qualification", dim_operator[qualification]
)
ORDER BY [operator_name]
```

> **Примечание:** `INTERSECT` в SQL напрямую соответствует `INTERSECT` в DAX. Столбцы: `qualification` -> `qualification_level`.

</details>

---

## Задание 5. Диаграмма Венна: комплексный анализ (среднее)

**Бизнес-задача:** Классифицировать операторов по типу оборудования: только ПДМ, только самосвалы, оба типа.

**Требования:**

1. Используя комбинацию `UNION ALL`, `INTERSECT` и `EXCEPT`, постройте отчёт:
   - «Оба типа» — количество операторов (INTERSECT)
   - «Только ПДМ» — количество операторов (EXCEPT)
   - «Только самосвал» — количество (EXCEPT в другом порядке)
2. Выведите: категория, количество, процент от общего числа
3. Убедитесь, что суммы сходятся

<details>
<summary>Решение (DAX)</summary>

```dax
EVALUATE
VAR LhdOps =
    CALCULATETABLE(
        DISTINCT(SELECTCOLUMNS(fact_production, "op_id", fact_production[operator_id])),
        dim_equipment_type[type_code] = "LHD"
    )
VAR TruckOps =
    CALCULATETABLE(
        DISTINCT(SELECTCOLUMNS(fact_production, "op_id", fact_production[operator_id])),
        dim_equipment_type[type_code] = "TRUCK"
    )
VAR BothCount = COUNTROWS(INTERSECT(LhdOps, TruckOps))
VAR OnlyLhdCount = COUNTROWS(EXCEPT(LhdOps, TruckOps))
VAR OnlyTruckCount = COUNTROWS(EXCEPT(TruckOps, LhdOps))
VAR TotalOps = COUNTROWS(DISTINCT(SELECTCOLUMNS(fact_production, "op_id", fact_production[operator_id])))
RETURN
{
    ("Оба типа", BothCount, ROUND(DIVIDE(BothCount, TotalOps) * 100, 1)),
    ("Только ПДМ", OnlyLhdCount, ROUND(DIVIDE(OnlyLhdCount, TotalOps) * 100, 1)),
    ("Только самосвал", OnlyTruckCount, ROUND(DIVIDE(OnlyTruckCount, TotalOps) * 100, 1))
}
```

> **Примечание:** Комбинация `INTERSECT` и `EXCEPT` в DAX полностью аналогична SQL. Таблица-конструктор `{(...), (...)}` используется для формирования итогового набора.

</details>

---

## Задание 6. LATERAL — топ-N записей для каждой группы (среднее)

**Бизнес-задача:** Для каждой шахты показать 5 самых длительных внеплановых простоев за I квартал 2024.

**Требования:**

1. Используя `CROSS JOIN LATERAL`, для каждой активной шахты (`dim_mine.status = 'active'`) выберите 5 самых длительных внеплановых простоев
2. Выведите:
   - Название шахты
   - Дата (`full_date`)
   - Название оборудования
   - Причина простоя
   - Длительность (минуты и часы)
3. Отсортируйте по шахте, затем по длительности убыванию

**Подсказка:**

```sql
SELECT m.mine_name, top5.*
FROM dim_mine m
CROSS JOIN LATERAL (
    SELECT ...
    FROM fact_equipment_downtime fd
    JOIN ...
    WHERE e.mine_id = m.mine_id  -- ссылка на внешний запрос!
      AND fd.is_planned = FALSE
      AND fd.date_id BETWEEN 20240101 AND 20240331
    ORDER BY fd.duration_min DESC
    LIMIT 5
) top5
WHERE m.status = 'active'
...
```

<details>
<summary>Решение (DAX)</summary>

```dax
EVALUATE
VAR Q1Filter = dim_date[date_id] >= 20240101 && dim_date[date_id] <= 20240331
RETURN
GENERATE(
    FILTER(dim_mine, dim_mine[status] = "active"),
    TOPN(
        5,
        ADDCOLUMNS(
            CALCULATETABLE(
                fact_equipment_downtime,
                fact_equipment_downtime[is_planned] = FALSE(),
                Q1Filter,
                dim_mine[mine_id] = EARLIER(dim_mine[mine_id])
            ),
            "full_date", RELATED(dim_date[full_date]),
            "equipment_name", RELATED(dim_equipment[equipment_name]),
            "reason_name", RELATED(dim_downtime_reason[reason_name]),
            "duration_hours", ROUND(DIVIDE(fact_equipment_downtime[duration_min], 60), 1)
        ),
        fact_equipment_downtime[duration_min], DESC
    )
)
ORDER BY dim_mine[mine_name], [duration_min] DESC
```

> **Примечание:** `CROSS JOIN LATERAL` в SQL соответствует `GENERATE` в DAX. `GENERATE` перебирает строки первой таблицы и для каждой вычисляет вторую таблицу (как LATERAL-подзапрос).

</details>

---

## Задание 7. LEFT JOIN LATERAL — последнее показание для каждого датчика (сложное)

**Бизнес-задача:** Для каждого активного датчика показать его последнее показание.

**Требования:**

1. Используя `LEFT JOIN LATERAL`, для каждого датчика из `dim_sensor` (где `status = 'active'`) найдите последнюю запись из `fact_equipment_telemetry`
2. Выведите:
   - Код датчика
   - Тип датчика
   - Оборудование
   - Дата и время последнего показания
   - Значение показания
   - Признак тревоги
3. Отсортируйте по дате последнего показания (самые «застывшие» датчики сверху)

**Вопрос:** Почему `LEFT JOIN LATERAL` предпочтительнее `CROSS JOIN LATERAL` в этом случае?

<details>
<summary>Решение (DAX)</summary>

```dax
EVALUATE
ADDCOLUMNS(
    FILTER(dim_sensor, dim_sensor[status] = "active"),
    "sensor_type", RELATED(dim_sensor_type[type_name]),
    "equipment_name", RELATED(dim_equipment[equipment_name]),
    "last_date_id", CALCULATE(MAX(fact_equipment_telemetry[date_id])),
    "last_time_id", CALCULATE(
        MAX(fact_equipment_telemetry[time_id]),
        fact_equipment_telemetry[date_id] = CALCULATE(MAX(fact_equipment_telemetry[date_id]))
    ),
    "last_value", CALCULATE(
        MAX(fact_equipment_telemetry[sensor_value]),
        TOPN(
            1,
            fact_equipment_telemetry,
            fact_equipment_telemetry[date_id], DESC,
            fact_equipment_telemetry[time_id], DESC
        )
    ),
    "last_is_alarm", CALCULATE(
        MAX(fact_equipment_telemetry[is_alarm]),
        TOPN(
            1,
            fact_equipment_telemetry,
            fact_equipment_telemetry[date_id], DESC,
            fact_equipment_telemetry[time_id], DESC
        )
    )
)
ORDER BY [last_date_id] ASC
```

> **Примечание:** `LEFT JOIN LATERAL` сохраняет строки без совпадений (датчики без показаний). В DAX `ADDCOLUMNS` ведёт себя аналогично — если `CALCULATE` не находит данных, возвращает BLANK (аналог NULL). Столбец `is_alarm` -> `is_anomaly`.

</details>

---

## Задание 8. UNION ALL + агрегация — сводный KPI-отчёт (сложное)

**Бизнес-задача:** Построить «таблицу KPI» по шахтам за март 2024 с разными метриками в одном отчёте.

**Требования:**

1. С помощью `UNION ALL` объедините 4 запроса, каждый из которых возвращает: `mine_name`, `kpi_name`, `kpi_value`
   - Суммарная добыча (тонн) — из `fact_production`
   - Суммарные простои (часы) — из `fact_equipment_downtime`
   - Среднее содержание Fe (%) — из `fact_ore_quality`
   - Количество тревожных показаний — из `fact_equipment_telemetry`
2. Отсортируйте по шахте и названию KPI
3. Дополнительно: разверните результат в «широкую» таблицу (с помощью условной агрегации или `crosstab`):

```sql
SELECT
    mine_name,
    MAX(CASE WHEN kpi_name = 'Добыча (тонн)' THEN kpi_value END) AS production,
    MAX(CASE WHEN kpi_name = 'Простои (часы)' THEN kpi_value END) AS downtime,
    ...
FROM (...) kpi
GROUP BY mine_name;
```

<details>
<summary>Решение (DAX)</summary>

```dax
EVALUATE
VAR MarchFilter = dim_date[date_id] >= 20240301 && dim_date[date_id] <= 20240331
VAR KpiData =
    UNION(
        SELECTCOLUMNS(
            SUMMARIZE(
                CALCULATETABLE(fact_production, MarchFilter),
                dim_mine[mine_name]
            ),
            "mine_name", dim_mine[mine_name],
            "kpi_name", "Добыча (тонн)",
            "kpi_value", CALCULATE(SUM(fact_production[tons_mined]))
        ),
        SELECTCOLUMNS(
            SUMMARIZE(
                CALCULATETABLE(fact_equipment_downtime, MarchFilter),
                dim_mine[mine_name]
            ),
            "mine_name", dim_mine[mine_name],
            "kpi_name", "Простои (часы)",
            "kpi_value", ROUND(DIVIDE(CALCULATE(SUM(fact_equipment_downtime[duration_min])), 60), 1)
        ),
        SELECTCOLUMNS(
            SUMMARIZE(
                CALCULATETABLE(fact_ore_quality, MarchFilter),
                dim_mine[mine_name]
            ),
            "mine_name", dim_mine[mine_name],
            "kpi_name", "Среднее Fe (%)",
            "kpi_value", ROUND(CALCULATE(AVERAGE(fact_ore_quality[fe_content])), 2)
        ),
        SELECTCOLUMNS(
            SUMMARIZE(
                CALCULATETABLE(
                    fact_equipment_telemetry,
                    fact_equipment_telemetry[is_alarm] = TRUE(),
                    MarchFilter
                ),
                dim_mine[mine_name]
            ),
            "mine_name", dim_mine[mine_name],
            "kpi_name", "Тревожные показания",
            "kpi_value", CALCULATE(COUNTROWS(fact_equipment_telemetry)) * 1.0
        )
    )
RETURN
KpiData
ORDER BY [mine_name], [kpi_name]
```

> **Примечание:** `UNION ALL` + условная агрегация (`CASE WHEN ... THEN ...`) в SQL заменяется на `UNION` нескольких `SELECTCOLUMNS` в DAX. Для «широкой» таблицы в Power BI обычно используется матричная визуализация (Matrix).

</details>

---

## Критерии оценки

| Задание | Баллы | Критерий |
|---------|-------|----------|
| 1 | 10 | UNION ALL, корректные типы столбцов |
| 2 | 10 | UNION, подсчёт уникальных значений |
| 3 | 10 | EXCEPT, альтернатива через NOT EXISTS |
| 4 | 10 | INTERSECT, расшифровка через JOIN |
| 5 | 15 | Диаграмма Венна, проверка сумм |
| 6 | 15 | CROSS JOIN LATERAL, параметризованный подзапрос |
| 7 | 15 | LEFT JOIN LATERAL, последнее показание |
| 8 | 15 | UNION ALL + агрегация, широкая таблица |
| **Итого** | **100** | |
