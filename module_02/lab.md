# Лабораторная работа 2: Исследование модели данных «Руда+» с помощью DAX

## Цель работы

Самостоятельно исследовать табличную модель данных предприятия «Руда+» в DAX Studio, закрепить понимание структуры DAX-запросов и научиться извлекать аналитическую информацию из модели.

## Время выполнения

15–20 минут (самостоятельная работа).

## Предварительные требования

- Выполнена практическая работа 2 (файл `RudaPlus_Module02.pbix` открыт в Power BI Desktop).
- DAX Studio подключён к модели.

---

## Задания

### Задание 1. Справочник шахт и стволов

Напишите DAX-запрос, который выводит список всех стволов и горизонтов с указанием шахты, типа ствола и глубины.

**Подсказка:** используйте `EVALUATE` и функцию `SELECTCOLUMNS` или `SUMMARIZECOLUMNS` для объединения данных из `dim_shaft` и `dim_mine`.

**Ожидаемый результат:**

| mine_name | shaft_name | shaft_type | depth_m |
|---|---|---|---|
| Шахта «Северная» | Ствол №1 Главный | вертикальный | 620.00 |
| Шахта «Северная» | Ствол №2 Вентиляционный | вертикальный | 580.00 |
| Шахта «Северная» | Горизонт -480 м | горизонт | 480.00 |
| ... | ... | ... | ... |

<details>
<summary>Решение</summary>

```dax
EVALUATE
    SELECTCOLUMNS(
        dim_shaft,
        "Шахта", RELATED(dim_mine[mine_name]),
        "Ствол/горизонт", dim_shaft[shaft_name],
        "Тип", dim_shaft[shaft_type],
        "Глубина, м", dim_shaft[depth_m]
    )
ORDER BY [Шахта], [Глубина, м]
```

</details>

---

### Задание 2. Активное оборудование по типам

Напишите запрос, который показывает количество единиц **активного** оборудования по каждому типу.

**Подсказка:** используйте `SUMMARIZECOLUMNS` с фильтром по статусу.

**Ожидаемый результат:**

| type_name | Количество |
|---|---|
| Погрузочно-доставочная машина | 5 |
| Шахтный самосвал | 5 |
| Вагонетка | 4 |
| Скиповой подъёмник | 3 |

<details>
<summary>Решение</summary>

```dax
EVALUATE
    SUMMARIZECOLUMNS(
        dim_equipment_type[type_name],
        FILTER(
            dim_equipment,
            dim_equipment[status] = "active"
        ),
        "Количество", COUNTROWS(dim_equipment)
    )
ORDER BY [Количество] DESC
```

</details>

---

### Задание 3. Добыча по операторам

Напишите запрос, который выводит суммарную добычу (тонн) и количество рейсов для каждого оператора. Отсортируйте по убыванию добычи.

**Ожидаемый результат:** таблица с ФИО оператора, должностью, суммарной добычей и количеством рейсов.

<details>
<summary>Решение</summary>

```dax
EVALUATE
    SUMMARIZECOLUMNS(
        dim_operator[last_name],
        dim_operator[first_name],
        dim_operator[position],
        "Добыча, т", SUM(fact_production[tons_mined]),
        "Рейсов", SUM(fact_production[trips_count])
    )
ORDER BY [Добыча, т] DESC
```

</details>

---

### Задание 4. Средний расход топлива по типу оборудования

Рассчитайте средний расход топлива за смену для каждого типа оборудования. Используйте блок `DEFINE` для создания локальной меры.

**Ожидаемый результат:**

| type_name | Средний расход, л |
|---|---|
| Шахтный самосвал | ~195 |
| Погрузочно-доставочная машина | ~112 |

<details>
<summary>Решение</summary>

```dax
DEFINE
    MEASURE fact_production[Средний расход] =
        AVERAGE(fact_production[fuel_consumed_l])

EVALUATE
    SUMMARIZECOLUMNS(
        dim_equipment_type[type_name],
        "Средний расход, л", [Средний расход]
    )
ORDER BY [Средний расход, л] DESC
```

</details>

---

### Задание 5. Простои оборудования по категориям

Напишите запрос, который показывает общую длительность простоев (в часах) по категориям причин (плановый, внеплановый, организационный).

**Подсказка:** поле `duration_min` содержит длительность в минутах, разделите на 60 для получения часов.

**Ожидаемый результат:**

| category | Простой, часов |
|---|---|
| плановый | ... |
| внеплановый | ... |
| организационный | ... |

<details>
<summary>Решение</summary>

```dax
EVALUATE
    SUMMARIZECOLUMNS(
        dim_downtime_reason[category],
        "Простой, часов",
            DIVIDE(
                SUM(fact_equipment_downtime[duration_min]),
                60,
                0
            )
    )
ORDER BY [Простой, часов] DESC
```

</details>

---

### Задание 6. Качество руды — среднее содержание Fe по шахтам

Рассчитайте среднее содержание железа (Fe) в пробах руды для каждой шахты. Дополнительно выведите минимальное и максимальное значение.

<details>
<summary>Решение</summary>

```dax
EVALUATE
    SUMMARIZECOLUMNS(
        dim_mine[mine_name],
        "Среднее Fe, %", AVERAGE(fact_ore_quality[fe_content]),
        "Мин Fe, %", MIN(fact_ore_quality[fe_content]),
        "Макс Fe, %", MAX(fact_ore_quality[fe_content])
    )
```

</details>

---

### Задание 7. Топ-5 дат по объёму добычи

Найдите 5 дат с максимальным суммарным объёмом добычи по всем шахтам. Используйте функцию `TOPN`.

**Подсказка:** `TOPN(N, таблица, выражение_для_сортировки)` возвращает N строк с наибольшими значениями.

<details>
<summary>Решение</summary>

```dax
EVALUATE
VAR production_by_date =
    SUMMARIZECOLUMNS(
        dim_date[full_date],
        dim_date[day_of_week_name],
        "Добыча, т", SUM(fact_production[tons_mined])
    )
RETURN
    TOPN(
        5,
        production_by_date,
        [Добыча, т],
        DESC
    )
ORDER BY [Добыча, т] DESC
```

</details>

---

## Часть 2: Контекст и CALCULATE

### Задание 9. Доля простоев по категориям

Напишите запрос, который для каждой категории простоев (плановый, внеплановый, организационный) показывает:
- длительность простоев в часах,
- общую длительность простоев по **всем** категориям,
- долю категории в процентах.

**Подсказка:** используйте `CALCULATE` с `ALL(dim_downtime_reason)` для снятия фильтра по категории.

<details>
<summary>Решение</summary>

```dax
DEFINE
    MEASURE fact_equipment_downtime[Простой_ч] =
        DIVIDE(SUM(fact_equipment_downtime[duration_min]), 60, 0)
    MEASURE fact_equipment_downtime[Простой_Всего_ч] =
        CALCULATE([Простой_ч], ALL(dim_downtime_reason))
    MEASURE fact_equipment_downtime[Доля] =
        DIVIDE([Простой_ч], [Простой_Всего_ч]) * 100

EVALUATE
    ADDCOLUMNS(
        VALUES(dim_downtime_reason[category]),
        "Простой, ч", [Простой_ч],
        "Всего, ч", [Простой_Всего_ч],
        "Доля, %", [Доля]
    )
ORDER BY [Простой, ч] DESC
```

</details>

---

### Задание 10. Добыча по шахтам: общая, дневная смена, доля

Для каждой шахты рассчитайте:
- общую добычу (все смены),
- добычу **только дневной смены** (shift_id = 1),
- общую добычу по **всем** шахтам (для расчёта доли),
- долю шахты от общей добычи в процентах.

**Подсказка:** вам нужны три меры с `CALCULATE`: одна с фильтром по смене, одна с `ALL(dim_mine)`, и одна с `DIVIDE`.

<details>
<summary>Решение</summary>

```dax
DEFINE
    MEASURE fact_production[Добыча] =
        SUM(fact_production[tons_mined])
    MEASURE fact_production[Добыча_Дневная] =
        CALCULATE([Добыча], dim_shift[shift_id] = 1)
    MEASURE fact_production[Добыча_Общая] =
        CALCULATE([Добыча], ALL(dim_mine))
    MEASURE fact_production[Доля] =
        DIVIDE([Добыча], [Добыча_Общая]) * 100

EVALUATE
    ADDCOLUMNS(
        VALUES(dim_mine[mine_name]),
        "Добыча всего, т", [Добыча],
        "Дневная смена, т", [Добыча_Дневная],
        "Общая по всем, т", [Добыча_Общая],
        "Доля, %", [Доля]
    )
```

</details>

---

### Задание 11. Простои по типам оборудования с долей

Рассчитайте простои (в часах) для каждого типа оборудования и долю каждого типа от общего времени простоев.

**Подсказка:** `ALL(dim_equipment_type)` снимает фильтр по типу оборудования.

<details>
<summary>Решение</summary>

```dax
DEFINE
    MEASURE fact_equipment_downtime[Простой_ч] =
        DIVIDE(SUM(fact_equipment_downtime[duration_min]), 60, 0)
    MEASURE fact_equipment_downtime[Простой_Всего_ч] =
        CALCULATE([Простой_ч], ALL(dim_equipment_type))
    MEASURE fact_equipment_downtime[Доля] =
        DIVIDE([Простой_ч], [Простой_Всего_ч]) * 100

EVALUATE
    ADDCOLUMNS(
        VALUES(dim_equipment_type[type_name]),
        "Простой, ч", [Простой_ч],
        "Всего, ч", [Простой_Всего_ч],
        "Доля, %", [Доля]
    )
ORDER BY [Простой, ч] DESC
```

</details>

---

### Задание 12. KEEPFILTERS — плановые простои

Напишите запрос, который для каждой **категории простоев** показывает:
- фактические часы простоя,
- часы **плановых** простоев с заменой фильтра (обычный `CALCULATE`),
- часы **плановых** простоев с `KEEPFILTERS`.

Объясните, почему результаты отличаются.

<details>
<summary>Решение</summary>

```dax
DEFINE
    MEASURE fact_equipment_downtime[Простой_ч] =
        DIVIDE(SUM(fact_equipment_downtime[duration_min]), 60, 0)

    -- Замена: ВСЕГДА показывает плановые, в любом контексте
    MEASURE fact_equipment_downtime[Плановые_Замена] =
        CALCULATE(
            [Простой_ч],
            dim_downtime_reason[category] = "плановый"
        )

    -- KEEPFILTERS: пересечение текущего контекста с "плановый"
    MEASURE fact_equipment_downtime[Плановые_KF] =
        CALCULATE(
            [Простой_ч],
            KEEPFILTERS(dim_downtime_reason[category] = "плановый")
        )

EVALUATE
    ADDCOLUMNS(
        VALUES(dim_downtime_reason[category]),
        "Простой, ч", [Простой_ч],
        "Плановые (замена), ч", [Плановые_Замена],
        "Плановые (KEEPFILTERS), ч", [Плановые_KF]
    )
```

**Объяснение:**
- `Плановые_Замена` — одинакова для всех строк, потому что фильтр по категории **заменяется** на "плановый".
- `Плановые_KF` — показывает значение **только** для строки "плановый" (пересечение "плановый" AND "плановый" = "плановый"), а для остальных — пусто (BLANK), потому что "внеплановый" AND "плановый" = пустое множество.

</details>

---

### Задание 13. Сравнение с прошлым годом (YoY)

Для каждой шахты и года рассчитайте:
- добычу текущего года,
- добычу **прошлого года** (используйте `SAMEPERIODLASTYEAR`),
- изменение год к году в процентах.

<details>
<summary>Решение</summary>

```dax
DEFINE
    MEASURE fact_production[Добыча] =
        SUM(fact_production[tons_mined])
    MEASURE fact_production[Добыча_Прошлый_Год] =
        CALCULATE(
            [Добыча],
            SAMEPERIODLASTYEAR(dim_date[full_date])
        )
    MEASURE fact_production[Изменение_YoY] =
        DIVIDE(
            [Добыча] - [Добыча_Прошлый_Год],
            [Добыча_Прошлый_Год]
        ) * 100

EVALUATE
    ADDCOLUMNS(
        CROSSJOIN(
            VALUES(dim_mine[mine_name]),
            VALUES(dim_date[year])
        ),
        "Добыча, т", [Добыча],
        "Прошлый год, т", [Добыча_Прошлый_Год],
        "Изменение YoY, %", [Изменение_YoY]
    )
ORDER BY dim_mine[mine_name], dim_date[year]
```

</details>

---

## Дополнительное задание (для продвинутых)

### Задание 14. Сравнение SQL и DAX

Напишите один и тот же запрос на SQL и DAX:

> **Задача:** для каждого оператора рассчитать среднее количество тонн, добытых за один рейс (tons_mined / trips_count). Вывести только операторов, у которых этот показатель больше 10.

Запишите оба варианта (SQL и DAX) и сравните синтаксис.

<details>
<summary>Решение SQL</summary>

```sql
SELECT
    o.last_name || ' ' || o.first_name AS "Оператор",
    ROUND(
        SUM(fp.tons_mined)::NUMERIC / NULLIF(SUM(fp.trips_count), 0),
        2
    ) AS "Тонн за рейс"
FROM fact_production fp
JOIN dim_operator o ON fp.operator_id = o.operator_id
GROUP BY o.last_name, o.first_name
HAVING SUM(fp.tons_mined)::NUMERIC / NULLIF(SUM(fp.trips_count), 0) > 10
ORDER BY "Тонн за рейс" DESC;
```

</details>

<details>
<summary>Решение DAX</summary>

```dax
EVALUATE
VAR operator_efficiency =
    SUMMARIZECOLUMNS(
        dim_operator[last_name],
        dim_operator[first_name],
        "Тонн за рейс",
            DIVIDE(
                SUM(fact_production[tons_mined]),
                SUM(fact_production[trips_count]),
                0
            )
    )
RETURN
    FILTER(
        operator_efficiency,
        [Тонн за рейс] > 10
    )
ORDER BY [Тонн за рейс] DESC
```

</details>

---

## Критерии оценки

| Критерий | Баллы |
|----------|-------|
| Задания 1–3 выполнены корректно | 3 балла |
| Задания 4–5 выполнены корректно | 2 балла |
| Задания 6–7 выполнены корректно | 2 балла |
| Задания 9–10 (CALCULATE, ALL) выполнены | 3 балла |
| Задания 11–12 (KEEPFILTERS) выполнены | 3 балла |
| Задание 13 (YoY) выполнено | 2 балла |
| Задание 14 (SQL + DAX) выполнено | 3 балла |
| **Итого** | **18 баллов** |

- **15–18 баллов** — отлично
- **11–14 баллов** — хорошо
- **7–10 баллов** — удовлетворительно

---

## Результат работы

По завершении лабораторной работы у вас должно быть:

- [ ] Выполнены задания 1–7 в DAX Studio (базовые запросы)
- [ ] Выполнены задания 9–10 (CALCULATE, ALL, доля)
- [ ] Выполнены задания 11–12 (KEEPFILTERS vs замена фильтра)
- [ ] Выполнено задание 13 (сравнение с прошлым годом — YoY)
- [ ] Выполнено задание 14 (сравнение SQL и DAX)
- [ ] Записаны результаты каждого запроса
- [ ] Сформулированы 2–3 наблюдения о различиях SQL и DAX
