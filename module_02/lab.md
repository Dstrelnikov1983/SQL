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

## Дополнительное задание (для продвинутых)

### Задание 8. Сравнение SQL и DAX

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
| Задание 8 (SQL + DAX) выполнено | 3 балла |
| **Итого** | **10 баллов** |

- **8–10 баллов** — отлично
- **6–7 баллов** — хорошо
- **4–5 баллов** — удовлетворительно

---

## Результат работы

По завершении лабораторной работы у вас должно быть:

- [ ] Выполнены задания 1–7 в DAX Studio
- [ ] Записаны результаты каждого запроса
- [ ] Выполнено задание 8 (сравнение SQL и DAX)
- [ ] Сформулированы 2–3 наблюдения о различиях SQL и DAX
