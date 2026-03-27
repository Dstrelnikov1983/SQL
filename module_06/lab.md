# Лабораторная работа — Модуль 6

## Использование встроенных функций

**Продолжительность:** 60 минут
**Формат:** самостоятельная работа
**Инструменты:** PostgreSQL (SQL) + DAX Studio (DAX)
**База данных:** «Руда+» (MES-система горнодобывающего предприятия)

---

## Общие указания

- Каждое задание требует **двух решений**: на SQL и на DAX.
- Сравнивайте результаты: количество строк и значения должны совпадать.
- Сохраняйте все запросы в файлы `lab_solutions.sql` и `lab_solutions.dax`.
- Задания расположены по возрастанию сложности.

---

## Задание 1. Округление результатов анализов (математические функции)

**Бизнес-задача:** Лаборатория качества готовит отчёт по результатам анализов проб за 15 марта 2024 года. Содержание компонентов необходимо округлить до 1 десятичного знака.

**Требования:**
- Выведите: номер пробы, содержание Fe, SiO2, Al2O3
- Содержание Fe округлите до 1 знака (ROUND)
- Содержание SiO2 округлите вверх (CEIL / CEILING)
- Содержание Al2O3 округлите вниз (FLOOR)
- Отсортируйте по содержанию Fe (убывание)

**Подсказка SQL:**
```sql
SELECT sample_number, ROUND(fe_content, 1) AS ..., CEIL(...) AS ..., FLOOR(...) AS ...
FROM fact_ore_quality WHERE date_id = 20240315 ORDER BY ...;
```

**Подсказка DAX:** Используйте `ADDCOLUMNS` + `FILTER` + `ROUND`, `CEILING`, `FLOOR`.

<details>
<summary>Решение (DAX)</summary>

```dax
EVALUATE
    SELECTCOLUMNS(
        FILTER(
            fact_ore_quality,
            fact_ore_quality[date_id] = 20240315
        ),
        "sample_number", fact_ore_quality[sample_number],
        "fe_rounded", ROUND(fact_ore_quality[fe_content], 1),
        "sio2_ceil", CEILING(fact_ore_quality[sio2_content], 1),
        "al2o3_floor", FLOOR(fact_ore_quality[al2o3_content], 1)
    )
ORDER BY [fe_rounded] DESC
```

</details>

---

## Задание 2. Отклонение от целевого содержания Fe (ABS, SIGN, POWER)

**Бизнес-задача:** Инженер качества хочет оценить, насколько пробы за март 2024 отклоняются от целевого содержания Fe = 60%. Нужно определить абсолютное отклонение, его направление и квадрат отклонения.

**Требования:**
- Выведите: номер пробы, содержание Fe, отклонение (fe_content - 60)
- Добавьте абсолютное отклонение (ABS)
- Добавьте направление: «Выше нормы» / «В норме» / «Ниже нормы» (SIGN + CASE / SWITCH)
- Добавьте квадрат отклонения (POWER)
- Отсортируйте по абсолютному отклонению (убывание), первые 10

**Ожидаемые столбцы:**

| sample_number | fe_content | deviation | abs_deviation | direction | squared_dev |
|---------------|-----------|-----------|--------------|-----------|-------------|
| ... | 67.5 | 7.5 | 7.5 | Выше нормы | 56.25 |
| ... | 51.2 | -8.8 | 8.8 | Ниже нормы | 77.44 |

<details>
<summary>Решение (DAX)</summary>

```dax
EVALUATE
VAR march_data =
    SELECTCOLUMNS(
        FILTER(
            fact_ore_quality,
            fact_ore_quality[date_id] >= 20240301
                && fact_ore_quality[date_id] <= 20240331
        ),
        "sample_number", fact_ore_quality[sample_number],
        "fe_content", fact_ore_quality[fe_content],
        "deviation", ROUND(fact_ore_quality[fe_content] - 60, 2),
        "abs_deviation", ROUND(ABS(fact_ore_quality[fe_content] - 60), 2),
        "direction",
            SWITCH(
                TRUE(),
                fact_ore_quality[fe_content] > 60, "Выше нормы",
                fact_ore_quality[fe_content] = 60, "В норме",
                "Ниже нормы"
            ),
        "squared_dev", ROUND(POWER(fact_ore_quality[fe_content] - 60, 2), 2)
    )
RETURN
    TOPN(10, march_data, [abs_deviation], DESC)
ORDER BY [abs_deviation] DESC
```

</details>

---

## Задание 3. Статистика добычи по сменам (агрегатные функции)

**Бизнес-задача:** Начальник производства запросил сводку добычи за март 2024 с разбивкой по сменам: количество записей, суммарная добыча, средняя добыча, количество уникальных операторов.

**Требования:**
- Группировка по shift_id
- Используйте: COUNT(*), SUM, ROUND(AVG, 2), COUNT(DISTINCT operator_id)
- Добавьте название смены через CASE (1='Утренняя', 2='Дневная', 3='Ночная')
- Отсортируйте по shift_id

**Подсказка SQL:**
```sql
SELECT
    shift_id,
    CASE shift_id WHEN 1 THEN 'Утренняя' ... END AS shift_name,
    COUNT(*) AS ...,
    SUM(tons_mined) AS ...,
    ROUND(AVG(tons_mined), 2) AS ...,
    COUNT(DISTINCT operator_id) AS ...
FROM fact_production
WHERE date_id BETWEEN 20240301 AND 20240331
GROUP BY shift_id
ORDER BY shift_id;
```

**Подсказка DAX:** Используйте `SUMMARIZE` + `ADDCOLUMNS` + `SWITCH`.

<details>
<summary>Решение (DAX)</summary>

```dax
EVALUATE
    ADDCOLUMNS(
        SUMMARIZECOLUMNS(
            dim_shift[shift_id],
            FILTER(
                dim_date,
                dim_date[date_id] >= 20240301 && dim_date[date_id] <= 20240331
            ),
            "record_count", COUNTROWS(fact_production),
            "total_tons", SUM(fact_production[tons_mined]),
            "avg_tons", ROUND(AVERAGE(fact_production[tons_mined]), 2),
            "unique_operators", DISTINCTCOUNT(fact_production[operator_id])
        ),
        "shift_name",
            SWITCH(
                [shift_id],
                1, "Утренняя",
                2, "Дневная",
                3, "Ночная"
            )
    )
ORDER BY [shift_id]
```

</details>

---

## Задание 4. Список причин простоев по оборудованию (STRING_AGG / CONCATENATEX)

**Бизнес-задача:** Механик хочет увидеть для каждого оборудования все причины простоев за март 2024, объединённые в одну строку, и суммарную длительность.

**Требования:**
- Группировка по equipment_name
- Используйте STRING_AGG (SQL) / CONCATENATEX (DAX) для объединения уникальных причин простоев через «; »
- Добавьте суммарную длительность простоев (SUM duration_min)
- Добавьте количество инцидентов простоев
- Отсортируйте по суммарной длительности (убывание)

**Подсказка SQL:**
```sql
SELECT
    e.equipment_name,
    STRING_AGG(DISTINCT dr.reason_name, '; ' ORDER BY dr.reason_name) AS reasons,
    SUM(fd.duration_min) AS total_min,
    COUNT(*) AS incidents
FROM fact_equipment_downtime fd
JOIN dim_equipment e ON fd.equipment_id = e.equipment_id
JOIN dim_downtime_reason dr ON fd.reason_id = dr.reason_id
WHERE fd.date_id BETWEEN 20240301 AND 20240331
GROUP BY e.equipment_name
ORDER BY total_min DESC;
```

<details>
<summary>Решение (DAX)</summary>

```dax
EVALUATE
VAR march_downtime =
    SUMMARIZE(
        FILTER(
            fact_equipment_downtime,
            fact_equipment_downtime[date_id] >= 20240301
                && fact_equipment_downtime[date_id] <= 20240331
        ),
        dim_equipment[equipment_name]
    )
RETURN
    ADDCOLUMNS(
        march_downtime,
        "reasons",
            CONCATENATEX(
                VALUES(dim_downtime_reason[reason_name]),
                dim_downtime_reason[reason_name],
                "; ",
                dim_downtime_reason[reason_name], ASC
            ),
        "total_min", SUM(fact_equipment_downtime[duration_min]),
        "incidents", COUNTROWS(fact_equipment_downtime)
    )
ORDER BY [total_min] DESC
```

</details>

---

## Задание 5. Преобразование date_id и форматирование отчёта (CAST, TO_CHAR, FORMAT)

**Бизнес-задача:** Для ежедневного отчёта необходимо преобразовать суррогатный ключ date_id (INTEGER) в читаемый формат даты и отформатировать числовые значения.

**Требования:**
- Преобразуйте date_id в дату (TO_DATE / DATEVALUE)
- Отформатируйте дату как «DD.MM.YYYY» (TO_CHAR / FORMAT)
- Суммарную добычу отформатируйте как строку с разделителем тысяч (TO_CHAR / FORMAT)
- Группировка по date_id, фильтр: первая неделя марта 2024 (20240301-20240307)

**Ожидаемый результат (SQL):**

| date_id | formatted_date | total_tons | formatted_tons |
|---------|---------------|------------|----------------|
| 20240301 | 01.03.2024 | 1234.5 | 1 234,50 |
| 20240302 | 02.03.2024 | 987.3 | 987,30 |

**Подсказка SQL:**
```sql
SELECT
    date_id,
    TO_CHAR(TO_DATE(date_id::VARCHAR, 'YYYYMMDD'), 'DD.MM.YYYY') AS formatted_date,
    SUM(tons_mined) AS total_tons,
    TO_CHAR(SUM(tons_mined), 'FM999G999D00') AS formatted_tons
FROM fact_production
WHERE date_id BETWEEN 20240301 AND 20240307
GROUP BY date_id ORDER BY date_id;
```

**Подсказка DAX:** `FORMAT(значение, "шаблон")`.

<details>
<summary>Решение (DAX)</summary>

```dax
EVALUATE
    ADDCOLUMNS(
        SUMMARIZECOLUMNS(
            dim_date[date_id],
            FILTER(
                dim_date,
                dim_date[date_id] >= 20240301 && dim_date[date_id] <= 20240307
            ),
            "total_tons", SUM(fact_production[tons_mined])
        ),
        "formatted_date", FORMAT(RELATED(dim_date[full_date]), "DD.MM.YYYY"),
        "formatted_tons", FORMAT([total_tons], "#,##0.00")
    )
ORDER BY [date_id]
```

**Примечание:** В DAX функция `FORMAT` позволяет задавать произвольный шаблон форматирования. Для преобразования `date_id` в дату используйте `DATEVALUE` или связь с `dim_date[full_date]`.

</details>

---

## Задание 6. Классификация проб и расчёт процента качества (CASE, COALESCE, NULLIF)

**Бизнес-задача:** Инженер качества готовит ежедневный отчёт за март 2024: количество проб по категориям качества и процент «хороших» проб (Fe >= 60%).

**Требования:**
- Группировка по дате (full_date из dim_date)
- Для каждой даты подсчитайте:
  - Количество проб с Fe >= 65 (богатая руда)
  - Количество проб с 55 <= Fe < 65 (средняя руда)
  - Количество проб с Fe < 55 (бедная руда)
  - Общее количество проб
  - Процент хороших проб (Fe >= 60), используя NULLIF для защиты от деления на 0
- Отсортируйте по дате

**Подсказка SQL:**
```sql
SUM(CASE WHEN fe_content >= 65 THEN 1 ELSE 0 END) AS rich_ore,
ROUND(100.0 * SUM(CASE WHEN fe_content >= 60 THEN 1 ELSE 0 END)
    / NULLIF(COUNT(*), 0), 1) AS good_pct
```

**Подсказка DAX:** Используйте `CALCULATE(COUNTROWS(...), фильтр)` и `DIVIDE`.

<details>
<summary>Решение (DAX)</summary>

```dax
EVALUATE
    ADDCOLUMNS(
        SUMMARIZECOLUMNS(
            dim_date[full_date],
            FILTER(
                dim_date,
                dim_date[date_id] >= 20240301 && dim_date[date_id] <= 20240331
            )
        ),
        "rich_ore",
            CALCULATE(
                COUNTROWS(fact_ore_quality),
                fact_ore_quality[fe_content] >= 65
            ),
        "medium_ore",
            CALCULATE(
                COUNTROWS(fact_ore_quality),
                fact_ore_quality[fe_content] >= 55
                    && fact_ore_quality[fe_content] < 65
            ),
        "poor_ore",
            CALCULATE(
                COUNTROWS(fact_ore_quality),
                fact_ore_quality[fe_content] < 55
            ),
        "total", COUNTROWS(fact_ore_quality),
        "good_pct",
            ROUND(
                DIVIDE(
                    CALCULATE(
                        COUNTROWS(fact_ore_quality),
                        fact_ore_quality[fe_content] >= 60
                    ),
                    COUNTROWS(fact_ore_quality),
                    0
                ) * 100,
                1
            )
    )
ORDER BY [full_date]
```

</details>

---

## Задание 7. Безопасные KPI с обработкой NULL и нуля (COALESCE, NULLIF, GREATEST)

**Бизнес-задача:** Для каждого оператора за март 2024 рассчитать производственные KPI с защитой от NULL и деления на ноль.

**Требования:**
- Группировка по оператору (last_name, first_name)
- Рассчитайте:
  - Суммарная добыча (тонн)
  - Суммарный расход топлива (литров), подставляя 0 вместо NULL через COALESCE
  - Производительность: тонн / рейс — через NULLIF для защиты от деления на 0
  - Расход топлива на тонну — через NULLIF или DIVIDE
  - Максимальная эффективность: GREATEST между производительностью за смену 1 и смену 2
- Все KPI округлите до 2 знаков (ROUND)
- Отсортируйте по производительности (убывание)

**Подсказка SQL:**
```sql
ROUND(SUM(fp.tons_mined) / NULLIF(SUM(fp.trips_count), 0), 2) AS tons_per_trip,
ROUND(COALESCE(SUM(fp.fuel_consumed_l), 0) / NULLIF(SUM(fp.tons_mined), 0), 3) AS fuel_per_ton
```

**Подсказка DAX:** Используйте `DIVIDE(числитель, знаменатель, 0)`.

<details>
<summary>Решение (DAX)</summary>

```dax
EVALUATE
    ADDCOLUMNS(
        SUMMARIZECOLUMNS(
            dim_operator[full_name],
            dim_operator[position],
            FILTER(
                dim_date,
                dim_date[date_id] >= 20240301 && dim_date[date_id] <= 20240331
            ),
            "total_tons", SUM(fact_production[tons_mined]),
            "total_fuel",
                IF(
                    ISBLANK(SUM(fact_production[fuel_consumed_l])),
                    0,
                    SUM(fact_production[fuel_consumed_l])
                ),
            "tons_per_trip",
                ROUND(
                    DIVIDE(
                        SUM(fact_production[tons_mined]),
                        SUM(fact_production[trips_count]),
                        0
                    ),
                    2
                ),
            "fuel_per_ton",
                ROUND(
                    DIVIDE(
                        SUM(fact_production[fuel_consumed_l]),
                        SUM(fact_production[tons_mined]),
                        0
                    ),
                    3
                )
        )
    )
ORDER BY [tons_per_trip] DESC
```

</details>

---

## Задание 8. Анализ пропусков данных (IS NULL, COUNT, CASE)

**Бизнес-задача:** Администратор данных хочет оценить полноту данных в таблице `fact_ore_quality` за март 2024: в каких столбцах больше всего пропусков?

**Требования:**
- Подсчитайте для каждого столбца (sio2_content, al2o3_content, moisture, density, sample_weight_kg):
  - Количество NOT NULL значений
  - Количество NULL значений
  - Процент заполненности
- Выведите результат в одну строку (один запрос)
- Фильтр: date_id BETWEEN 20240301 AND 20240331

**Ожидаемый формат (SQL):**

| total_rows | sio2_filled | sio2_null | sio2_pct | al2o3_filled | al2o3_null | al2o3_pct | ... |
|------------|-------------|-----------|----------|--------------|------------|-----------|-----|

**Подсказка SQL:**
```sql
SELECT
    COUNT(*) AS total_rows,
    COUNT(sio2_content) AS sio2_filled,
    COUNT(*) - COUNT(sio2_content) AS sio2_null,
    ROUND(100.0 * COUNT(sio2_content) / COUNT(*), 1) AS sio2_pct,
    ...
```

**Подсказка DAX:** `COUNT(столбец)` считает только не-BLANK значения.

<details>
<summary>Решение (DAX)</summary>

```dax
EVALUATE
ROW(
    "total_rows",
        CALCULATE(
            COUNTROWS(fact_ore_quality),
            fact_ore_quality[date_id] >= 20240301,
            fact_ore_quality[date_id] <= 20240331
        ),
    "sio2_filled",
        CALCULATE(
            COUNT(fact_ore_quality[sio2_content]),
            fact_ore_quality[date_id] >= 20240301,
            fact_ore_quality[date_id] <= 20240331
        ),
    "sio2_null",
        CALCULATE(
            COUNTROWS(fact_ore_quality),
            fact_ore_quality[date_id] >= 20240301,
            fact_ore_quality[date_id] <= 20240331
        )
        - CALCULATE(
            COUNT(fact_ore_quality[sio2_content]),
            fact_ore_quality[date_id] >= 20240301,
            fact_ore_quality[date_id] <= 20240331
        ),
    "al2o3_filled",
        CALCULATE(
            COUNT(fact_ore_quality[al2o3_content]),
            fact_ore_quality[date_id] >= 20240301,
            fact_ore_quality[date_id] <= 20240331
        ),
    "moisture_filled",
        CALCULATE(
            COUNT(fact_ore_quality[moisture]),
            fact_ore_quality[date_id] >= 20240301,
            fact_ore_quality[date_id] <= 20240331
        )
)
```

**Примечание:** В DAX `COUNT(столбец)` считает только не-BLANK значения, а `COUNTROWS` считает все строки. Разница между ними даёт количество BLANK (NULL).

</details>

---

## Задание 9. Комплексный отчёт по эффективности оборудования

**Бизнес-задача:** Подготовить комплексный KPI-отчёт по каждому оборудованию за март 2024 для совещания у директора.

**Требования:**
- Группировка по оборудованию (equipment_name) и типу (type_name)
- Рассчитайте:
  - Количество отработанных смен
  - Суммарная добыча (тонн), округлить до 1 знака
  - Суммарные часы работы, округлить до 1 знака
  - **Производительность** (тонн/час) — с NULLIF / DIVIDE, округлить до 2 знаков
  - **Коэффициент использования** (%) = часы / (смены * 8) * 100, округлить до 1 знака
  - **Расход топлива на тонну** — с COALESCE + NULLIF / DIVIDE, округлить до 3 знаков
  - **Категория эффективности**: «Высокая» (> 20 т/ч), «Средняя» (> 12 т/ч), «Низкая»
  - **Статус данных**: «Полные» если все fuel_consumed_l заполнены, иначе «Неполные»
- Отсортируйте по производительности (убывание)

**Подсказка SQL:** Это объединяет все функции модуля — ROUND, NULLIF, COALESCE, CASE WHEN, SUM, COUNT.

**Подсказка DAX:** Используйте SUMMARIZE + ADDCOLUMNS + DIVIDE + SWITCH(TRUE(), ...) + ROUND.

<details>
<summary>Решение (DAX)</summary>

```dax
EVALUATE
    ADDCOLUMNS(
        SUMMARIZECOLUMNS(
            dim_equipment[equipment_name],
            dim_equipment_type[type_name],
            FILTER(
                dim_date,
                dim_date[date_id] >= 20240301 && dim_date[date_id] <= 20240331
            ),
            "shift_count", COUNTROWS(fact_production),
            "total_tons", ROUND(SUM(fact_production[tons_mined]), 1),
            "total_hours", ROUND(SUM(fact_production[operating_hours]), 1),
            "productivity",
                ROUND(
                    DIVIDE(
                        SUM(fact_production[tons_mined]),
                        SUM(fact_production[operating_hours]),
                        0
                    ),
                    2
                ),
            "utilization",
                ROUND(
                    DIVIDE(
                        SUM(fact_production[operating_hours]),
                        COUNTROWS(fact_production) * 8,
                        0
                    ) * 100,
                    1
                ),
            "fuel_per_ton",
                ROUND(
                    DIVIDE(
                        SUM(fact_production[fuel_consumed_l]),
                        SUM(fact_production[tons_mined]),
                        0
                    ),
                    3
                )
        ),
        "efficiency_category",
            SWITCH(
                TRUE(),
                [productivity] > 20, "Высокая",
                [productivity] > 12, "Средняя",
                "Низкая"
            )
    )
ORDER BY [productivity] DESC
```

</details>

---

## Задание 10. Категоризация простоев (все функции модуля)

**Бизнес-задача:** Подготовить аналитический отчёт по простоям за март 2024 с категоризацией по длительности, расчётом долей и обработкой незавершённых простоев.

**Требования:**
- Для каждого простоя определите:
  - Название оборудования
  - Причину простоя
  - Длительность в минутах (если NULL — подставить 0 через COALESCE)
  - Длительность в часах (ROUND до 1 знака, деление на 60)
  - Категория длительности (CASE):
    - «Критический» (> 480 мин)
    - «Длительный» (120-480 мин)
    - «Средний» (30-120 мин)
    - «Короткий» (< 30 мин)
  - Статус: «Плановый» / «Внеплановый» (CASE по is_planned)
  - Статус завершения: «Завершён» / «В процессе» (CASE по end_time IS NULL)
- Агрегируйте по категории длительности:
  - Количество простоев
  - Суммарная длительность (часы)
  - Процент от общего времени простоев (ROUND + NULLIF)
- Отсортируйте по суммарной длительности (убывание)

**Подсказка SQL:**
```sql
WITH categorized AS (
    SELECT
        ...,
        COALESCE(fd.duration_min, 0) AS duration_safe,
        CASE
            WHEN COALESCE(fd.duration_min, 0) > 480 THEN 'Критический'
            ...
        END AS category
    FROM fact_equipment_downtime fd ...
)
SELECT category, COUNT(*), ROUND(SUM(duration_safe) / 60.0, 1) AS total_hours, ...
FROM categorized GROUP BY category;
```

<details>
<summary>Решение (DAX)</summary>

```dax
EVALUATE
VAR march_downtime =
    ADDCOLUMNS(
        FILTER(
            fact_equipment_downtime,
            fact_equipment_downtime[date_id] >= 20240301
                && fact_equipment_downtime[date_id] <= 20240331
        ),
        "duration_safe",
            IF(
                ISBLANK(fact_equipment_downtime[duration_min]),
                0,
                fact_equipment_downtime[duration_min]
            ),
        "category",
            SWITCH(
                TRUE(),
                fact_equipment_downtime[duration_min] > 480, "Критический",
                fact_equipment_downtime[duration_min] >= 120, "Длительный",
                fact_equipment_downtime[duration_min] >= 30, "Средний",
                "Короткий"
            )
    )
VAR total_duration = SUMX(march_downtime, [duration_safe])
RETURN
    ADDCOLUMNS(
        GROUPBY(
            march_downtime,
            [category],
            "cnt", COUNTAX(CURRENTGROUP(), 1),
            "total_hours", ROUND(DIVIDE(SUMX(CURRENTGROUP(), [duration_safe]), 60, 0), 1)
        ),
        "pct", ROUND(DIVIDE([total_hours] * 60, total_duration, 0) * 100, 1)
    )
ORDER BY [total_hours] DESC
```

</details>

---

## Критерии оценки

| Критерий | Баллов |
|----------|--------|
| Задания 1-4 выполнены корректно (базовые функции) | 4 |
| Задания 5-6 выполнены (преобразование и условная логика) | 3 |
| Задания 7-8 выполнены (NULL и безопасные вычисления) | 3 |
| Задания 9-10 выполнены (комплексные KPI) | 4 |
| Решения представлены на SQL и DAX | 3 |
| Результаты SQL и DAX совпадают | 2 |
| Код оформлен, прокомментирован | 1 |
| **Итого** | **20** |

---

## Дополнительные задания (для продвинутых)

### Задание Б1. Расчёт RMSE содержания Fe

Рассчитайте RMSE (Root Mean Square Error) содержания Fe относительно целевого значения 60% за каждый день марта 2024.

```sql
-- Формула RMSE: SQRT(AVG(POWER(fe_content - target, 2)))
```

### Задание Б2. Условная агрегация с FILTER

Перепишите задание 6, используя FILTER-клаузулу агрегатов PostgreSQL вместо CASE WHEN.

```sql
COUNT(*) FILTER (WHERE fe_content >= 65) AS rich_ore
```
