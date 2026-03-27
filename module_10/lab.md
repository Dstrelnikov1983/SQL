# Лабораторная работа — Модуль 10

## Использование подзапросов

**Продолжительность:** 60 минут
**Формат:** самостоятельная работа
**Инструменты:** PostgreSQL (Yandex Managed Service for PostgreSQL)
**База данных:** «Руда+» (MES-система горнодобывающего предприятия)

---

## Общие указания

- Для каждого задания напишите SQL-запрос и сохраните его в файл `lab_solutions.sql`
- Проверяйте результаты на разумность (количество строк, диапазоны значений)
- Задания расположены по возрастанию сложности

---

## Задание 1. Скалярный подзапрос — фильтрация (простое)

**Бизнес-задача:** Начальник смены хочет узнать, какие операторы за март 2024 добыли руды больше средней добычи по предприятию.

**Требования:**

1. Напишите запрос, который выводит:
   - ФИО оператора (фамилия + инициал имени)
   - Суммарная добыча за март 2024 (`date_id BETWEEN 20240301 AND 20240331`)
   - Средняя добыча по предприятию за тот же период (одно число для всех строк)
2. Используйте скалярный подзапрос для вычисления средней добычи
3. Отфильтруйте только операторов, чья суммарная добыча выше средней
4. Отсортируйте по убыванию добычи

**Ожидаемый результат:** список операторов-передовиков с их суммарной добычей.

<details>
<summary>Решение (DAX)</summary>

```dax
EVALUATE
VAR AvgProduction =
    AVERAGEX(
        VALUES(dim_operator[full_name]),
        CALCULATE(
            SUM(fact_production[tons_mined]),
            dim_date[date_id] >= 20240301 && dim_date[date_id] <= 20240331
        )
    )
RETURN
FILTER(
    ADDCOLUMNS(
        VALUES(dim_operator[full_name]),
        "total_mined", CALCULATE(
            SUM(fact_production[tons_mined]),
            dim_date[date_id] >= 20240301 && dim_date[date_id] <= 20240331
        ),
        "avg_production", AvgProduction
    ),
    [total_mined] > AvgProduction
)
ORDER BY [total_mined] DESC
```

> **Примечание:** В DAX вместо скалярного подзапроса используется переменная `VAR` для хранения среднего значения, а `FILTER` заменяет `HAVING`.

</details>

---

## Задание 2. Многозначный подзапрос с IN (простое)

**Бизнес-задача:** Технический директор запрашивает список датчиков, установленных на оборудовании, которое участвовало в добыче в I квартале 2024.

**Требования:**

1. Используя подзапрос с `IN`, найдите все датчики (`dim_sensor`), установленные на оборудовании, которое присутствует в `fact_production` за период `date_id BETWEEN 20240101 AND 20240331`
2. Выведите:
   - Код датчика (`sensor_code`)
   - Название типа датчика (из `dim_sensor_type`)
   - Название оборудования (из `dim_equipment`)
   - Статус датчика
3. Отсортируйте по названию оборудования, затем по коду датчика

**Подсказка:** подзапрос должен возвращать `DISTINCT equipment_id` из `fact_production`.

<details>
<summary>Решение (DAX)</summary>

```dax
EVALUATE
VAR ActiveEquipment =
    CALCULATETABLE(
        VALUES(fact_production[equipment_id]),
        dim_date[date_id] >= 20240101 && dim_date[date_id] <= 20240331
    )
RETURN
FILTER(
    ADDCOLUMNS(
        NATURALINNERJOIN(
            NATURALINNERJOIN(dim_sensor, dim_sensor_type),
            dim_equipment
        ),
        "is_active", dim_equipment[equipment_id] IN ActiveEquipment
    ),
    [is_active]
)
ORDER BY dim_equipment[equipment_name], dim_sensor[sensor_code]
```

> **Примечание:** В DAX оператор `IN` заменяет подзапрос с `IN`. Функция `CALCULATETABLE` формирует набор значений, аналогичный подзапросу.

</details>

---

## Задание 3. NOT IN и ловушка с NULL (среднее)

**Бизнес-задача:** Найти оборудование, которое ни разу не использовалось для добычи руды.

**Требования:**

1. Напишите запрос с `NOT IN`, который находит оборудование из `dim_equipment`, отсутствующее в `fact_production`
2. Выведите название оборудования, тип, шахту и статус
3. Убедитесь, что подзапрос не возвращает NULL (добавьте `WHERE equipment_id IS NOT NULL`)
4. Перепишите запрос с использованием `NOT EXISTS` и сравните результат

**Вопрос для размышления:** Что произойдёт, если убрать `WHERE equipment_id IS NOT NULL` из подзапроса `NOT IN`? Почему?

<details>
<summary>Решение (DAX)</summary>

```dax
EVALUATE
VAR ProductionEquipment =
    VALUES(fact_production[equipment_id])
RETURN
FILTER(
    ADDCOLUMNS(
        dim_equipment,
        "type_name", RELATED(dim_equipment_type[type_name]),
        "mine_name", RELATED(dim_mine[mine_name])
    ),
    NOT(dim_equipment[equipment_id] IN ProductionEquipment)
)
ORDER BY dim_equipment[equipment_name]
```

> **Примечание:** В DAX нет ловушки с NULL как в SQL `NOT IN` — оператор `IN` в DAX корректно обрабатывает пустые значения. Это аналог `NOT EXISTS` в SQL.

</details>

---

## Задание 4. Коррелированный подзапрос — сравнение внутри группы (среднее)

**Бизнес-задача:** Для каждой шахты найти смены, в которых добыча была ниже средней по этой шахте.

**Требования:**

1. Напишите запрос, который для каждой записи в `fact_production` (I квартал 2024) проверяет, является ли `tons_mined` ниже средней добычи **по этой же шахте**
2. Выведите:
   - Название шахты
   - Дата (`full_date` из `dim_date`)
   - Название оборудования
   - Добыча за смену
   - Средняя добыча по шахте (через коррелированный подзапрос в SELECT)
3. Ограничьте результат 20 записями
4. Отсортируйте по отклонению от средней (от самого большого отклонения вниз)

**Подсказка:** В WHERE используйте `fp.tons_mined < (SELECT AVG(...) FROM ... WHERE mine_id = fp.mine_id)`.

<details>
<summary>Решение (DAX)</summary>

```dax
EVALUATE
VAR Q1Filter = dim_date[date_id] >= 20240101 && dim_date[date_id] <= 20240331
RETURN
TOPN(
    20,
    ADDCOLUMNS(
        FILTER(
            ADDCOLUMNS(
                SUMMARIZE(
                    CALCULATETABLE(fact_production, Q1Filter),
                    dim_mine[mine_name],
                    dim_date[full_date],
                    dim_equipment[equipment_name],
                    "tons_mined", SUM(fact_production[tons_mined])
                ),
                "mine_avg", CALCULATE(
                    AVERAGE(fact_production[tons_mined]),
                    ALLEXCEPT(fact_production, dim_mine[mine_name]),
                    Q1Filter
                )
            ),
            [tons_mined] < [mine_avg]
        ),
        "deviation", [tons_mined] - [mine_avg]
    ),
    [deviation], ASC
)
```

> **Примечание:** В DAX коррелированный подзапрос реализуется через `CALCULATE` с `ALLEXCEPT` — функция снимает фильтры со всех столбцов, кроме указанных, что эквивалентно корреляции по `mine_id`.

</details>

---

## Задание 5. EXISTS — оборудование с тревожными показаниями (среднее)

**Бизнес-задача:** Инженер по надёжности запрашивает список оборудования, у которого были тревожные показания телеметрии (`is_alarm = TRUE`) в марте 2024.

**Требования:**

1. Используя `EXISTS`, найдите оборудование из `dim_equipment`, для которого в `fact_equipment_telemetry` есть записи с `is_alarm = TRUE` за март 2024
2. Выведите:
   - Название оборудования
   - Тип оборудования
   - Шахта
   - Количество тревожных показаний (дополнительный коррелированный подзапрос в SELECT)
3. Отсортируйте по количеству тревог (по убыванию)

**Вопрос:** Можно ли решить эту задачу без подзапроса (через JOIN + GROUP BY)? Какой вариант более читаемый?

<details>
<summary>Решение (DAX)</summary>

```dax
EVALUATE
ADDCOLUMNS(
    FILTER(
        dim_equipment,
        CALCULATE(
            COUNTROWS(fact_equipment_telemetry),
            fact_equipment_telemetry[is_alarm] = TRUE(),
            dim_date[date_id] >= 20240301 && dim_date[date_id] <= 20240331
        ) > 0
    ),
    "type_name", RELATED(dim_equipment_type[type_name]),
    "mine_name", RELATED(dim_mine[mine_name]),
    "alarm_count", CALCULATE(
        COUNTROWS(fact_equipment_telemetry),
        fact_equipment_telemetry[is_alarm] = TRUE(),
        dim_date[date_id] >= 20240301 && dim_date[date_id] <= 20240331
    )
)
ORDER BY [alarm_count] DESC
```

> **Примечание:** `FILTER` + `CALCULATE` в DAX заменяет `EXISTS` + коррелированный подзапрос. Столбец `is_alarm` в SSAS-модели называется `is_anomaly`.

</details>

---

## Задание 6. NOT EXISTS — поиск «пробелов» в данных (среднее)

**Бизнес-задача:** Найти даты в марте 2024, когда для определённого оборудования (`equipment_id = 5`) не было записей о добыче.

**Требования:**

1. Используя `NOT EXISTS`, для каждой даты из `dim_date` (март 2024) проверьте, есть ли запись в `fact_production` для данного оборудования
2. Выведите:
   - Дату (`full_date`)
   - День недели (`day_of_week_name`)
   - Признак выходного (`is_weekend`)
3. Отсортируйте по дате

**Ожидаемый результат:** список дней, когда оборудование не работало. Вероятнее всего, это выходные и праздники.

<details>
<summary>Решение (DAX)</summary>

```dax
EVALUATE
VAR MarchDates =
    FILTER(
        dim_date,
        dim_date[date_id] >= 20240301 && dim_date[date_id] <= 20240331
    )
VAR ProductionDates =
    CALCULATETABLE(
        VALUES(fact_production[date_id]),
        fact_production[equipment_id] = 1
    )
RETURN
SELECTCOLUMNS(
    FILTER(
        MarchDates,
        NOT(dim_date[date_id] IN ProductionDates)
    ),
    "full_date", dim_date[full_date],
    "day_name", dim_date[day_of_week_name],
    "is_weekend", dim_date[is_weekend]
)
ORDER BY [full_date]
```

> **Примечание:** `NOT EXISTS` в SQL заменяется на `NOT(... IN ...)` в DAX. Столбец `day_of_week_name` в SSAS-модели называется `day_name`.

</details>

---

## Задание 7. Подзапрос с ANY/ALL (среднее)

**Бизнес-задача:** Найти записи добычи, где объём за одну смену превышает максимальную добычу любого самосвала (`type_code = 'TRUCK'`) за любую смену.

**Требования:**

1. Используя оператор `> ALL(подзапрос)`, найдите записи `fact_production`, где `tons_mined` больше любого значения `tons_mined` для самосвалов
2. Выведите:
   - Название оборудования и его тип
   - Дата, смена
   - Добыча (тонн)
3. Перепишите запрос, заменив `ALL` на `(SELECT MAX(...))` — убедитесь, что результаты совпадают
4. Напишите ещё один запрос с `> ANY(подзапрос)` — объясните разницу в результатах

<details>
<summary>Решение (DAX)</summary>

```dax
EVALUATE
VAR MaxTruckTons =
    CALCULATE(
        MAX(fact_production[tons_mined]),
        dim_equipment_type[type_code] = "TRUCK"
    )
RETURN
SELECTCOLUMNS(
    FILTER(
        ADDCOLUMNS(
            fact_production,
            "equipment_name", RELATED(dim_equipment[equipment_name]),
            "type_name", RELATED(dim_equipment_type[type_name])
        ),
        fact_production[tons_mined] > MaxTruckTons
    ),
    "equipment_name", [equipment_name],
    "type_name", [type_name],
    "date_id", fact_production[date_id],
    "shift_id", fact_production[shift_id],
    "tons_mined", fact_production[tons_mined]
)
ORDER BY [tons_mined] DESC
```

> **Примечание:** В DAX нет прямых аналогов `ANY`/`ALL`. Оператор `> ALL(...)` эквивалентен `> MAX(...)`, который легко выражается через переменную с `MAX`. Столбец `type_code` сохраняет то же имя в SSAS-модели.

</details>

---

## Задание 8. Коррелированный подзапрос для «последней записи» (сложное)

**Бизнес-задача:** Для каждого оборудования найти дату и результат его **последней** записи о добыче.

**Требования:**

1. Напишите запрос, который для каждого оборудования из `dim_equipment` находит запись с максимальным `date_id` в `fact_production`
2. Используйте коррелированный подзапрос в WHERE:
   ```
   WHERE fp.date_id = (SELECT MAX(fp2.date_id) FROM fact_production fp2 WHERE fp2.equipment_id = fp.equipment_id)
   ```
3. Выведите:
   - Название оборудования
   - Тип
   - Дата последней работы (`full_date`)
   - Добыча за последнюю смену
   - Оператор, работавший в эту смену
4. Отсортируйте по дате последней работы (от самого старого)

**Вопрос:** Как решить эту задачу через оконную функцию `ROW_NUMBER()`? Какой вариант предпочтительнее?

<details>
<summary>Решение (DAX)</summary>

```dax
EVALUATE
ADDCOLUMNS(
    FILTER(
        dim_equipment,
        NOT ISBLANK(
            CALCULATE(MAX(fact_production[date_id]))
        )
    ),
    "type_name", RELATED(dim_equipment_type[type_name]),
    "last_date", CALCULATE(MAX(dim_date[full_date])),
    "last_tons", CALCULATE(
        SUM(fact_production[tons_mined]),
        FILTER(
            fact_production,
            fact_production[date_id] = CALCULATE(MAX(fact_production[date_id]))
        )
    ),
    "last_operator", CALCULATE(
        MAX(dim_operator[full_name]),
        FILTER(
            fact_production,
            fact_production[date_id] = CALCULATE(MAX(fact_production[date_id]))
        )
    )
)
ORDER BY [last_date] ASC
```

> **Примечание:** Коррелированный подзапрос `WHERE date_id = (SELECT MAX(...))` реализуется через `CALCULATE` с вложенным `FILTER`. В DAX нет прямого аналога `ROW_NUMBER`, но `TOPN(1, ...)` решает ту же задачу.

</details>

---

## Задание 9. Комплексный запрос с вложенными подзапросами (сложное)

**Бизнес-задача:** Руководство запрашивает отчёт: для каждой шахты — среднее время внеплановых простоев оборудования, которое имеет добычу выше средней по предприятию.

**Требования:**

1. Напишите запрос, объединяющий несколько уровней вложенности:
   - Внутренний уровень: определить среднюю добычу по предприятию за I квартал 2024
   - Средний уровень: найти `equipment_id` с суммарной добычей выше средней
   - Внешний уровень: рассчитать среднее время внеплановых простоев для этого оборудования по шахтам
2. Выведите:
   - Название шахты
   - Количество оборудования-«передовиков»
   - Среднее время простоя (минуты)
   - Суммарное время простоя (часы)
3. Отсортируйте по суммарному времени простоя по убыванию

**Подсказка:**

```sql
SELECT m.mine_name, ...
FROM fact_equipment_downtime fd
JOIN dim_equipment e ON ...
JOIN dim_mine m ON ...
WHERE fd.is_planned = FALSE
  AND fd.equipment_id IN (
    SELECT fp.equipment_id
    FROM fact_production fp
    WHERE fp.date_id BETWEEN 20240101 AND 20240331
    GROUP BY fp.equipment_id
    HAVING SUM(fp.tons_mined) > (
        SELECT AVG(total_tons)
        FROM (
            SELECT SUM(tons_mined) AS total_tons
            FROM fact_production
            WHERE date_id BETWEEN 20240101 AND 20240331
            GROUP BY equipment_id
        ) sub
    )
  )
GROUP BY m.mine_name
...
```

<details>
<summary>Решение (DAX)</summary>

```dax
EVALUATE
VAR Q1Filter = dim_date[date_id] >= 20240101 && dim_date[date_id] <= 20240331
VAR AvgTotalTons =
    AVERAGEX(
        VALUES(dim_equipment[equipment_id]),
        CALCULATE(SUM(fact_production[tons_mined]), Q1Filter)
    )
VAR TopEquipment =
    FILTER(
        ADDCOLUMNS(
            VALUES(dim_equipment[equipment_id]),
            "eq_total", CALCULATE(SUM(fact_production[tons_mined]), Q1Filter)
        ),
        [eq_total] > AvgTotalTons
    )
RETURN
ADDCOLUMNS(
    SUMMARIZE(
        FILTER(
            NATURALINNERJOIN(fact_equipment_downtime, dim_equipment),
            fact_equipment_downtime[is_planned] = FALSE()
                && dim_equipment[equipment_id] IN TopEquipment
        ),
        dim_mine[mine_name]
    ),
    "top_equipment_count", CALCULATE(DISTINCTCOUNT(dim_equipment[equipment_id])),
    "avg_downtime_min", AVERAGE(fact_equipment_downtime[duration_min]),
    "total_downtime_hours", DIVIDE(SUM(fact_equipment_downtime[duration_min]), 60)
)
ORDER BY [total_downtime_hours] DESC
```

> **Примечание:** Многоуровневая вложенность подзапросов в SQL заменяется каскадом переменных `VAR` в DAX.

</details>

---

## Задание 10. Подзапрос для расчёта KPI: OEE по оборудованию (продвинутое)

**Бизнес-задача:** Рассчитать OEE (Overall Equipment Effectiveness) для каждого оборудования за I квартал 2024, используя подзапросы для всех компонентов.

**Требования:**

1. Для каждого активного оборудования (`dim_equipment.status = 'active'`) рассчитайте:
   - **Доступность** = рабочие часы / (рабочие часы + часы простоев) — через подзапросы к `fact_production` и `fact_equipment_downtime`
   - **Производительность** = фактическая добыча (тонн) / (рабочие часы × максимальная грузоподъёмность из `dim_equipment_type`) — через подзапрос
   - **Качество** = доля проб с `fe_content >= 55` для данного оборудования (через подзапрос к `fact_ore_quality`)
   - **OEE** = Доступность × Производительность × Качество
2. Используйте коррелированные подзапросы в SELECT для каждого компонента
3. Выведите:
   - Название оборудования
   - Тип
   - Доступность (%)
   - Производительность (%)
   - Качество (%)
   - OEE (%)
4. Отсортируйте по OEE по убыванию

<details>
<summary>Решение (DAX)</summary>

```dax
EVALUATE
VAR Q1Filter = dim_date[date_id] >= 20240101 && dim_date[date_id] <= 20240331
RETURN
ADDCOLUMNS(
    FILTER(dim_equipment, dim_equipment[status] = "active"),
    "type_name", RELATED(dim_equipment_type[type_name]),
    "availability_pct",
        VAR OpHours = CALCULATE(SUM(fact_production[operating_hours]), Q1Filter)
        VAR DownHours = DIVIDE(CALCULATE(SUM(fact_equipment_downtime[duration_min]), Q1Filter), 60)
        RETURN DIVIDE(OpHours, OpHours + DownHours) * 100,
    "performance_pct",
        VAR Tons = CALCULATE(SUM(fact_production[tons_mined]), Q1Filter)
        VAR OpHrs = CALCULATE(SUM(fact_production[operating_hours]), Q1Filter)
        VAR MaxLoad = RELATED(dim_equipment_type[max_payload_tons])
        RETURN DIVIDE(Tons, OpHrs * MaxLoad) * 100,
    "quality_pct",
        VAR GoodSamples = CALCULATE(
            COUNTROWS(fact_ore_quality),
            fact_ore_quality[fe_content] >= 55,
            Q1Filter
        )
        VAR TotalSamples = CALCULATE(COUNTROWS(fact_ore_quality), Q1Filter)
        RETURN DIVIDE(GoodSamples, TotalSamples) * 100
)
ORDER BY [availability_pct] DESC
```

> **Примечание:** Коррелированные подзапросы в SQL заменяются вычисляемыми столбцами `ADDCOLUMNS` с `CALCULATE`. Каждый компонент OEE рассчитывается через локальные `VAR` внутри `ADDCOLUMNS`. Столбцы: `duration_min` -> `duration_minutes`, `max_payload_tons` -> `max_load_tons`.

</details>

**Подсказка для доступности:**

```sql
(SELECT COALESCE(SUM(fp.operating_hours), 0)
 FROM fact_production fp
 WHERE fp.equipment_id = e.equipment_id
   AND fp.date_id BETWEEN 20240101 AND 20240331)
/
NULLIF(
  (SELECT COALESCE(SUM(fp.operating_hours), 0)
   FROM fact_production fp
   WHERE fp.equipment_id = e.equipment_id
     AND fp.date_id BETWEEN 20240101 AND 20240331)
  +
  (SELECT COALESCE(SUM(fd.duration_min) / 60.0, 0)
   FROM fact_equipment_downtime fd
   WHERE fd.equipment_id = e.equipment_id
     AND fd.date_id BETWEEN 20240101 AND 20240331)
, 0)
```

---

## Критерии оценки

| Задание | Баллы | Критерий |
|---------|-------|----------|
| 1 | 5 | Корректный скалярный подзапрос, фильтрация в HAVING |
| 2 | 5 | Подзапрос с IN, правильные JOIN-ы к справочникам |
| 3 | 10 | NOT IN и NOT EXISTS, объяснение ловушки с NULL |
| 4 | 10 | Коррелированный подзапрос в WHERE и SELECT |
| 5 | 10 | EXISTS с подсчётом тревог, сравнение с JOIN |
| 6 | 10 | NOT EXISTS для поиска пропущенных дат |
| 7 | 10 | Корректное использование ANY/ALL, сравнение вариантов |
| 8 | 15 | Подзапрос для «последней записи», сравнение с ROW_NUMBER |
| 9 | 10 | Многоуровневая вложенность, корректная логика |
| 10 | 15 | Комплексный расчёт OEE через коррелированные подзапросы |
| **Итого** | **100** | |
