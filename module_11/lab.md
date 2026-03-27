# Лабораторная работа — Модуль 11

## Использование табличных выражений

**Продолжительность:** 60 минут
**Формат:** самостоятельная работа
**Инструменты:** PostgreSQL (Yandex Managed Service for PostgreSQL)
**База данных:** «Руда+» (MES-система горнодобывающего предприятия)

---

## Общие указания

- Для каждого задания напишите SQL-запрос и сохраните его в файл `lab_solutions.sql`
- Где требуется создание объектов (VIEW, FUNCTION), добавьте команды очистки в конце файла
- Задания расположены по возрастанию сложности

---

## Задание 1. Представление — сводка по добыче (простое)

**Бизнес-задача:** Аналитику MES-системы нужен удобный источник для ежедневных отчётов по добыче.

**Требования:**

1. Создайте представление `v_daily_production_summary`, которое выводит:
   - Дата (`full_date` из `dim_date`)
   - Название шахты
   - Название смены
   - Количество записей
   - Суммарная добыча (тонн)
   - Суммарный расход топлива (л)
   - Среднее количество рейсов
2. Проверьте представление запросом: данные за март 2024, шахта «Северная»
3. Добавьте фильтрацию по количеству записей > 5

**Подсказка:** `CREATE OR REPLACE VIEW v_daily_production_summary AS SELECT ...`

<details>
<summary>Решение (DAX)</summary>

```dax
EVALUATE
FILTER(
    ADDCOLUMNS(
        SUMMARIZE(
            CALCULATETABLE(
                fact_production,
                dim_date[date_id] >= 20240301 && dim_date[date_id] <= 20240331,
                dim_mine[mine_name] = "Шахта ""Северная"""
            ),
            dim_date[full_date],
            dim_mine[mine_name],
            dim_shift[shift_name]
        ),
        "record_count", CALCULATE(COUNTROWS(fact_production)),
        "total_tons", CALCULATE(SUM(fact_production[tons_mined])),
        "total_fuel", CALCULATE(SUM(fact_production[fuel_consumed_l])),
        "avg_trips", CALCULATE(AVERAGE(fact_production[trips_count]))
    ),
    [record_count] > 0
)
ORDER BY dim_date[full_date], dim_shift[shift_name]
```

> **Примечание:** Представления (VIEW) в SQL — объекты схемы БД. В DAX/Power BI аналогом является сохранённый DAX-запрос или мера. Столбцы: `tons_mined` -> `ore_mined_tons`, `fuel_consumed_l` -> `fuel_consumed_liters`.

</details>

---

## Задание 2. Представление с ограничением обновления (простое)

**Бизнес-задача:** Необходимо ограничить видимость данных о простоях — показывать только внеплановые простои.

**Требования:**

1. Создайте представление `v_unplanned_downtime` на основе `fact_equipment_downtime` с условием `WHERE is_planned = FALSE`
2. Добавьте `WITH CHECK OPTION`
3. Выполните `SELECT COUNT(*)` из представления и из базовой таблицы — убедитесь, что представление содержит только подмножество данных
4. Объясните в комментарии: что произойдёт при попытке выполнить `INSERT INTO v_unplanned_downtime (..., is_planned, ...) VALUES (..., TRUE, ...)`?

> **DAX:** Задание связано с созданием VIEW с CHECK OPTION — это SQL-специфичная концепция управления целостностью данных. В Power BI/DAX модели данных доступны только для чтения, поэтому аналога нет.

---

## Задание 3. Материализованное представление для качества руды (среднее)

**Бизнес-задача:** Отчёт по качеству руды по шахтам и месяцам — тяжёлый запрос. Нужно его кэшировать.

**Требования:**

1. Создайте `MATERIALIZED VIEW mv_monthly_ore_quality` со следующими столбцами:
   - Название шахты
   - Год-месяц (`year_month`)
   - Количество проб
   - Среднее содержание Fe (округлённое до 2 знаков)
   - Мин. и макс. содержание Fe
   - Среднее содержание SiO2
   - Среднее содержание влажности
2. Создайте индекс по `mine_name` и `year_month`
3. Выполните `EXPLAIN ANALYZE` для запроса к материализованному представлению и сравните с аналогичным запросом напрямую к таблицам
4. Выполните `REFRESH MATERIALIZED VIEW`

**Вопрос:** Какой индекс нужен для `REFRESH ... CONCURRENTLY`?

<details>
<summary>Решение (DAX)</summary>

```dax
EVALUATE
ADDCOLUMNS(
    SUMMARIZE(
        fact_ore_quality,
        dim_mine[mine_name],
        dim_date[year],
        dim_date[month]
    ),
    "year_month", FORMAT(dim_date[year], "0000") & "-" & FORMAT(dim_date[month], "00"),
    "sample_count", CALCULATE(COUNTROWS(fact_ore_quality)),
    "avg_fe", ROUND(CALCULATE(AVERAGE(fact_ore_quality[fe_content])), 2),
    "min_fe", ROUND(CALCULATE(MIN(fact_ore_quality[fe_content])), 2),
    "max_fe", ROUND(CALCULATE(MAX(fact_ore_quality[fe_content])), 2),
    "avg_sio2", ROUND(CALCULATE(AVERAGE(fact_ore_quality[sio2_content])), 2),
    "avg_moisture", ROUND(CALCULATE(AVERAGE(fact_ore_quality[moisture])), 2)
)
ORDER BY dim_mine[mine_name], [year_month]
```

> **Примечание:** Материализованные представления (MATERIALIZED VIEW) в SQL — это кэшированные результаты запросов. В Power BI аналогом является агрегационная таблица или кэш VertiPaq (данные хранятся в памяти в сжатом виде). Столбцы: `moisture_pct` -> `moisture_percent`, `month` -> `month_number`.

</details>

---

## Задание 4. Производная таблица — ранжирование операторов (среднее)

**Бизнес-задача:** Определить лучшего оператора каждой смены за I квартал 2024.

**Требования:**

1. Используя производную таблицу (подзапрос в FROM), напишите запрос, который:
   - Рассчитывает суммарную добычу для каждого оператора в каждой смене
   - Присваивает ранг (`ROW_NUMBER`) в разрезе смен
   - Во внешнем запросе отбирает только ранг = 1
2. Выведите: название смены, ФИО оператора, суммарную добычу
3. Отсортируйте по названию смены

**Подсказка:** `SELECT * FROM (SELECT ..., ROW_NUMBER() OVER (PARTITION BY shift_id ORDER BY ...) AS rn ...) sub WHERE rn = 1`

<details>
<summary>Решение (DAX)</summary>

```dax
EVALUATE
VAR RankedOperators =
    ADDCOLUMNS(
        SUMMARIZE(
            CALCULATETABLE(
                fact_production,
                dim_date[date_id] >= 20240101 && dim_date[date_id] <= 20240331
            ),
            dim_shift[shift_name],
            dim_operator[full_name]
        ),
        "total_mined", CALCULATE(SUM(fact_production[tons_mined]))
    )
RETURN
GENERATE(
    VALUES(dim_shift[shift_name]),
    TOPN(
        1,
        FILTER(RankedOperators, dim_shift[shift_name] = EARLIER(dim_shift[shift_name])),
        [total_mined], DESC
    )
)
ORDER BY dim_shift[shift_name]
```

> **Примечание:** Производная таблица (подзапрос в FROM) с `ROW_NUMBER` в SQL заменяется комбинацией `GENERATE` + `TOPN` в DAX. `GENERATE` перебирает группы (смены), а `TOPN(1, ...)` выбирает лучшего оператора в каждой.

</details>

---

## Задание 5. CTE — комплексный отчёт по эффективности (среднее)

**Бизнес-задача:** Сформировать отчёт «Доступность оборудования по шахтам» за I квартал 2024.

**Требования:**

1. Напишите запрос с двумя CTE:
   - `production_cte`: суммарные рабочие часы и добыча по `mine_id`
   - `downtime_cte`: суммарные часы простоев по `mine_id` (через `dim_equipment`)
2. В основном запросе:
   - Соедините CTE с `dim_mine`
   - Рассчитайте доступность = рабочие часы / (рабочие часы + простои) × 100
   - Выведите: название шахты, рабочие часы, простои (часы), добычу, доступность (%)
3. Отсортируйте по доступности по возрастанию (худшие шахты сверху)

<details>
<summary>Решение (DAX)</summary>

```dax
EVALUATE
VAR Q1Filter = dim_date[date_id] >= 20240101 && dim_date[date_id] <= 20240331
RETURN
ADDCOLUMNS(
    FILTER(dim_mine, dim_mine[status] = "active"),
    "operating_hours", CALCULATE(SUM(fact_production[operating_hours]), Q1Filter),
    "downtime_hours",
        DIVIDE(
            CALCULATE(SUM(fact_equipment_downtime[duration_min]), Q1Filter),
            60
        ),
    "total_tons", CALCULATE(SUM(fact_production[tons_mined]), Q1Filter),
    "availability_pct",
        VAR OpHours = CALCULATE(SUM(fact_production[operating_hours]), Q1Filter)
        VAR DownHours = DIVIDE(CALCULATE(SUM(fact_equipment_downtime[duration_min]), Q1Filter), 60)
        RETURN DIVIDE(OpHours, OpHours + DownHours) * 100
)
ORDER BY [availability_pct] ASC
```

> **Примечание:** Два CTE в SQL заменяются одним `ADDCOLUMNS` с несколькими вычисляемыми столбцами. Каждый CTE — это просто отдельный `CALCULATE`. Столбец `duration_min` -> `duration_minutes`.

</details>

---

## Задание 6. Табличная функция — отчёт по простоям (среднее)

**Бизнес-задача:** Диспетчеру нужна функция для быстрого получения простоев оборудования за указанный период.

**Требования:**

1. Создайте функцию `fn_equipment_downtime_report(p_equipment_id INT, p_date_from INT, p_date_to INT)`, которая возвращает таблицу:
   - Дата (`full_date`)
   - Причина простоя
   - Категория причины
   - Длительность (минуты)
   - Длительность (часы, округлённая до 1 знака)
   - Признак планового простоя
   - Комментарий
2. Вызовите функцию для `equipment_id = 3` за январь 2024
3. Вызовите функцию через `LATERAL JOIN` для всех единиц оборудования шахты `mine_id = 1`

**Подсказка:** Используйте `LANGUAGE sql` для инлайн-оптимизации.

> **DAX:** Табличные функции — SQL-специфичная концепция. В DAX аналогом является параметризованная таблица с `CALCULATETABLE`:

<details>
<summary>Решение (DAX)</summary>

```dax
EVALUATE
VAR p_equipment_id = 1
VAR p_date_from = 20240101
VAR p_date_to = 20240131
RETURN
ADDCOLUMNS(
    CALCULATETABLE(
        fact_equipment_downtime,
        fact_equipment_downtime[equipment_id] = p_equipment_id,
        dim_date[date_id] >= p_date_from && dim_date[date_id] <= p_date_to
    ),
    "full_date", RELATED(dim_date[full_date]),
    "reason_name", RELATED(dim_downtime_reason[reason_name]),
    "reason_category", RELATED(dim_downtime_reason[category]),
    "duration_hours", ROUND(DIVIDE(fact_equipment_downtime[duration_min], 60), 1),
    "description", fact_equipment_downtime[comment]
)
ORDER BY [full_date]
```

> **Примечание:** В DAX нет `LATERAL JOIN`, но `GENERATE` выполняет аналогичную роль — перебирает строки внешней таблицы и для каждой выполняет вложенный запрос. Столбцы: `duration_min` -> `duration_minutes`, `comment` -> `description`, `category` -> `reason_category`.

</details>

---

## Задание 7. Рекурсивный CTE — иерархия локаций (сложное)

**Бизнес-задача:** Отобразить дерево подземных локаций с полным путём от корня.

**Предварительные действия:** Убедитесь, что таблица `dim_location_hierarchy` создана и заполнена (скрипт из практической работы модуля 11).

**Требования:**

1. Напишите рекурсивный CTE, который:
   - Начинает с корневых элементов (`parent_id IS NULL`)
   - Рекурсивно обходит все дочерние записи
   - Формирует полный путь (`Шахта → Ствол → Горизонт → Штрек → Забой`)
   - Формирует отступ для визуализации иерархии
2. Выведите:
   - Иерархию с отступами (пробелами)
   - Тип локации
   - Полный путь
   - Глубину вложенности
3. Отсортируйте по полному пути

**Дополнительно:** Напишите обратный обход — от забоя `location_id = 13` до корня шахты.

> **DAX:** Рекурсивные CTE — SQL-специфичная концепция. DAX не поддерживает рекурсию напрямую. Для обхода иерархий в Power BI используются функции `PATH`, `PATHITEM`, `PATHLENGTH`:

<details>
<summary>Решение (DAX) — иерархия через PATH</summary>

```dax
-- В модели Power BI создайте вычисляемый столбец в dim_location_hierarchy:
-- full_path = PATH(dim_location_hierarchy[location_id], dim_location_hierarchy[parent_id])
-- depth = PATHLENGTH(dim_location_hierarchy[full_path]) - 1

EVALUATE
ADDCOLUMNS(
    dim_location_hierarchy,
    "hierarchy", REPT("  ", PATHLENGTH(PATH(dim_location_hierarchy[location_id], dim_location_hierarchy[parent_id])) - 1) & dim_location_hierarchy[location_name],
    "depth", PATHLENGTH(PATH(dim_location_hierarchy[location_id], dim_location_hierarchy[parent_id])) - 1
)
ORDER BY PATH(dim_location_hierarchy[location_id], dim_location_hierarchy[parent_id])
```

> **Примечание:** `PATH` в DAX строит иерархический путь через `|` (например, `1|3|7|13`). Функция `PATHITEM` извлекает элемент по позиции. Это декларативная альтернатива рекурсивному CTE.

</details>

---

## Задание 8. Рекурсивный CTE — генерация календаря и заполнение пропусков (сложное)

**Бизнес-задача:** Найти рабочие дни в феврале 2024, когда не было добычи в шахте `mine_id = 1`.

**Требования:**

1. С помощью рекурсивного CTE сгенерируйте последовательность дат за февраль 2024
2. Используя LEFT JOIN с `fact_production` и `dim_date`, найдите:
   - Дни без добычи (LEFT JOIN + IS NULL)
   - Из них — только рабочие дни (не выходные)
3. Выведите: дату, день недели, тип дня (рабочий/выходной)
4. Подсчитайте: сколько рабочих дней потеряно?

<details>
<summary>Решение (DAX)</summary>

```dax
EVALUATE
VAR FebDates =
    FILTER(
        dim_date,
        dim_date[date_id] >= 20240201 && dim_date[date_id] <= 20240229
    )
VAR ProductionDates =
    CALCULATETABLE(
        VALUES(fact_production[date_id]),
        fact_production[mine_id] = 1
    )
RETURN
SELECTCOLUMNS(
    FILTER(
        FebDates,
        NOT(dim_date[date_id] IN ProductionDates)
            && dim_date[is_weekend] = FALSE()
    ),
    "full_date", dim_date[full_date],
    "day_name", dim_date[day_of_week_name],
    "day_type", "рабочий"
)
ORDER BY [full_date]
```

> **Примечание:** Рекурсивный CTE для генерации дат не нужен в DAX — таблица `dim_date` уже содержит все даты. Генерация последовательностей в DAX возможна через `GENERATESERIES`.

</details>

---

## Задание 9. CTE для скользящего среднего (сложное)

**Бизнес-задача:** Построить 7-дневное скользящее среднее добычи по шахте «Северная» за I квартал 2024.

**Требования:**

1. В первом CTE рассчитайте дневную добычу по `mine_id = 1` за I квартал
2. Во втором CTE или основном запросе рассчитайте:
   - Скользящее среднее за 7 дней (`AVG(...) OVER (ORDER BY date_id ROWS BETWEEN 6 PRECEDING AND CURRENT ROW)`)
   - Скользящий максимум за 7 дней
   - Отклонение текущего дня от скользящего среднего (%)
3. Выведите: дату, дневную добычу, скользящее среднее, отклонение
4. Выделите дни с отклонением > 20% (добавьте флаг «Аномалия»)

<details>
<summary>Решение (DAX)</summary>

```dax
EVALUATE
VAR DailyProd =
    ADDCOLUMNS(
        SUMMARIZE(
            CALCULATETABLE(
                fact_production,
                fact_production[mine_id] = 1,
                dim_date[date_id] >= 20240101 && dim_date[date_id] <= 20240331
            ),
            dim_date[date_id],
            dim_date[full_date]
        ),
        "daily_tons", CALCULATE(SUM(fact_production[tons_mined]))
    )
VAR WithMovingAvg =
    ADDCOLUMNS(
        DailyProd,
        "moving_avg_7d",
            AVERAGEX(
                FILTER(
                    DailyProd,
                    [date_id] >= EARLIER([date_id]) - 6
                        && [date_id] <= EARLIER([date_id])
                ),
                [daily_tons]
            ),
        "moving_max_7d",
            MAXX(
                FILTER(
                    DailyProd,
                    [date_id] >= EARLIER([date_id]) - 6
                        && [date_id] <= EARLIER([date_id])
                ),
                [daily_tons]
            )
    )
RETURN
ADDCOLUMNS(
    WithMovingAvg,
    "deviation_pct", ROUND(DIVIDE([daily_tons] - [moving_avg_7d], [moving_avg_7d]) * 100, 1),
    "anomaly_flag", IF(ABS(DIVIDE([daily_tons] - [moving_avg_7d], [moving_avg_7d]) * 100) > 20, "Аномалия", "")
)
ORDER BY [date_id]
```

> **Примечание:** Оконные функции (`AVG(...) OVER (ROWS BETWEEN ...)`) не существуют в DAX. Скользящее окно реализуется через `AVERAGEX` с `FILTER` по диапазону. Это более многословно, но концептуально понятно.

</details>

---

## Задание 10. Комплексное задание: VIEW + CTE + функция (продвинутое)

**Бизнес-задача:** Создать набор объектов для модуля «Контроль качества руды» MES-системы.

**Требования:**

1. Создайте **VIEW** `v_ore_quality_detail`:
   - Все поля `fact_ore_quality` + расшифровки из справочников (шахта, смена, сорт руды)
   - Расчётный столбец: категория качества (`CASE WHEN fe_content >= 65 THEN 'Богатая' ...`)

2. Создайте **табличную функцию** `fn_ore_quality_stats(p_mine_id INT, p_year INT, p_month INT)`:
   - Возвращает статистику по качеству руды: количество проб, среднее Fe, стандартное отклонение Fe, доля проб с Fe >= 55%

3. Напишите **запрос с CTE**, который:
   - CTE 1: агрегирует данные из `v_ore_quality_detail` по месяцам
   - CTE 2: рассчитывает скользящее среднее Fe за 3 месяца
   - Основной запрос: выводит месяц, среднее Fe, скользящее среднее, тренд (рост/снижение)

4. Покажите использование всех трёх объектов вместе:
   ```sql
   SELECT m.mine_name, stats.*
   FROM dim_mine m
   CROSS JOIN LATERAL fn_ore_quality_stats(m.mine_id, 2024, 3) stats
   WHERE m.status = 'active';
   ```

<details>
<summary>Решение (DAX) — комплексный запрос качества руды</summary>

```dax
EVALUATE
VAR QualityByMonth =
    ADDCOLUMNS(
        SUMMARIZE(
            fact_ore_quality,
            dim_mine[mine_name],
            dim_date[year],
            dim_date[month]
        ),
        "avg_fe", CALCULATE(AVERAGE(fact_ore_quality[fe_content])),
        "sample_count", CALCULATE(COUNTROWS(fact_ore_quality)),
        "good_pct", DIVIDE(
            CALCULATE(COUNTROWS(fact_ore_quality), fact_ore_quality[fe_content] >= 55),
            CALCULATE(COUNTROWS(fact_ore_quality))
        ) * 100
    )
VAR WithMovingAvg =
    ADDCOLUMNS(
        QualityByMonth,
        "moving_avg_fe_3m",
            AVERAGEX(
                FILTER(
                    QualityByMonth,
                    [mine_name] = EARLIER([mine_name])
                        && [year] * 12 + [month] >= EARLIER([year]) * 12 + EARLIER([month]) - 2
                        && [year] * 12 + [month] <= EARLIER([year]) * 12 + EARLIER([month])
                ),
                [avg_fe]
            )
    )
RETURN
ADDCOLUMNS(
    WithMovingAvg,
    "trend", IF([avg_fe] > [moving_avg_fe_3m], "рост", "снижение")
)
ORDER BY [mine_name], [year], [month]
```

> **Примечание:** В DAX нет VIEW, MATERIALIZED VIEW или табличных функций как объектов БД. Вместо этого используются: меры (measures) для вычислений, вычисляемые таблицы для кэширования, и DAX-запросы для ad-hoc анализа.

</details>

---

## Критерии оценки

| Задание | Баллы | Критерий |
|---------|-------|----------|
| 1 | 5 | VIEW создано, запрос работает |
| 2 | 5 | WITH CHECK OPTION, объяснение поведения |
| 3 | 10 | MATERIALIZED VIEW, индексы, сравнение производительности |
| 4 | 10 | Производная таблица с ROW_NUMBER, ранг = 1 |
| 5 | 10 | Два CTE, корректный расчёт доступности |
| 6 | 10 | Табличная функция, вызов через LATERAL |
| 7 | 15 | Рекурсивный CTE, прямой и обратный обход |
| 8 | 10 | Генерация дат, LEFT JOIN, поиск пропусков |
| 9 | 10 | Скользящее среднее, флаг аномалии |
| 10 | 15 | VIEW + функция + CTE, комплексная интеграция |
| **Итого** | **100** | |
