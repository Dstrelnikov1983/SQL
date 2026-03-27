# Лабораторная работа — Модуль 3

## Сравнение простейших запросов на языке SQL и DAX

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

## Задание 1. Справочник шахт (простой SELECT)

**Бизнес-задача:** Инженеру по планированию нужен список всех шахт предприятия с основными характеристиками.

**Требования:**
- Выведите название шахты, код шахты, регион, город, максимальную глубину и статус
- Результат должен содержать 2 строки

**Ожидаемый результат:**

| mine_name | mine_code | region | city | max_depth_m | status |
|-----------|-----------|--------|------|-------------|--------|
| Шахта "Северная" | MINE_N | Курская область | г. Железногорск | 620.00 | active |
| Шахта "Южная" | MINE_S | Белгородская область | г. Губкин | 540.00 | active |

<details>
<summary>Решение (DAX)</summary>

```dax
EVALUATE
    SELECTCOLUMNS(
        dim_mine,
        "mine_name", dim_mine[mine_name],
        "mine_code", dim_mine[mine_code],
        "region", dim_mine[region],
        "city", dim_mine[city],
        "max_depth_m", dim_mine[max_depth_m],
        "status", dim_mine[status]
    )
ORDER BY [mine_name]
```

</details>

---

## Задание 2. Фильтрация оборудования (WHERE / FILTER)

**Бизнес-задача:** Механик запрашивает список всего оборудования, которое выпущено **до 2019 года** (включительно) и имеет **видеорегистратор**.

**Требования:**
- Выведите: название, инвентарный номер, производитель, модель, год выпуска
- Условия: `year_manufactured <= 2019` AND `has_video_recorder = TRUE`
- Отсортируйте по году выпуска (от старого к новому)

**Подсказка для DAX:** Используйте `CALCULATETABLE` с двумя фильтрами или `FILTER` с составным условием.

<details>
<summary>Решение (DAX)</summary>

```dax
EVALUATE
    SELECTCOLUMNS(
        FILTER(
            dim_equipment,
            dim_equipment[year_manufactured] <= 2019
                && dim_equipment[has_video_recorder] = TRUE()
        ),
        "equipment_name", dim_equipment[equipment_name],
        "inventory_number", dim_equipment[inventory_number],
        "manufacturer", dim_equipment[manufacturer],
        "model", dim_equipment[model],
        "year_manufactured", dim_equipment[year_manufactured]
    )
ORDER BY [year_manufactured] ASC
```

</details>

---

## Задание 3. Операторы шахты «Южная» (фильтрация по связанной таблице)

**Бизнес-задача:** Начальник участка шахты «Южная» хочет получить список своих операторов.

**Требования:**
- Выведите: фамилию, имя, отчество, должность, квалификацию, дату приёма
- Фильтр: только операторы шахты «Южная» (`mine_id = 2`)
- Только активные сотрудники (`status = 'active'`)
- Отсортируйте по дате приёма (от ранней к поздней)

**Ожидаемое количество строк:** 3 оператора.

<details>
<summary>Решение (DAX)</summary>

```dax
EVALUATE
    SELECTCOLUMNS(
        FILTER(
            dim_operator,
            RELATED(dim_mine[mine_name]) = "Шахта ""Южная"""
                && dim_operator[status] = "active"
        ),
        "full_name", dim_operator[full_name],
        "position", dim_operator[position],
        "qualification", dim_operator[qualification],
        "hire_date", dim_operator[hire_date]
    )
ORDER BY [hire_date] ASC
```

</details>

---

## Задание 4. Простои за конкретный месяц (JOIN + фильтрация)

**Бизнес-задача:** Для ежемесячного отчёта нужен список всех простоев за **март 2024 года** с расшифровкой.

**Требования:**
- Выведите: дату (из `dim_date.full_date`), название оборудования, причину простоя, категорию причины, длительность в минутах, признак плановости, комментарий
- Фильтр: `date_id` от `20240301` до `20240331`
- Отсортируйте по длительности простоя (убывание)

**Подсказки:**
- SQL: потребуется JOIN с `dim_date`, `dim_equipment`, `dim_downtime_reason`
- DAX: используйте `RELATED()` для доступа к связанным таблицам

<details>
<summary>Решение (DAX)</summary>

```dax
EVALUATE
    SELECTCOLUMNS(
        FILTER(
            fact_equipment_downtime,
            fact_equipment_downtime[date_id] >= 20240301
                && fact_equipment_downtime[date_id] <= 20240331
        ),
        "full_date", RELATED(dim_date[full_date]),
        "equipment_name", RELATED(dim_equipment[equipment_name]),
        "reason_name", RELATED(dim_downtime_reason[reason_name]),
        "category", RELATED(dim_downtime_reason[category]),
        "duration_min", fact_equipment_downtime[duration_min],
        "is_planned", fact_equipment_downtime[is_planned],
        "comment", fact_equipment_downtime[comment]
    )
ORDER BY [duration_min] DESC
```

</details>

---

## Задание 5. Добыча по типам оборудования (GROUP BY / SUMMARIZE)

**Бизнес-задача:** Руководство хочет знать, какой тип оборудования даёт наибольший объём добычи.

**Требования:**
- Сгруппируйте данные по названию типа оборудования (`dim_equipment_type.type_name`)
- Выведите: тип оборудования, общий объём добычи (тонн), средний объём за смену, количество рабочих смен, общий расход топлива (литров)
- Отсортируйте по общему объёму добычи (убывание)

**Подсказки:**
- SQL: JOIN `fact_production` → `dim_equipment` → `dim_equipment_type`, GROUP BY
- DAX: `SUMMARIZECOLUMNS` с колонкой из `dim_equipment_type`

<details>
<summary>Решение (DAX)</summary>

```dax
EVALUATE
    SUMMARIZECOLUMNS(
        dim_equipment_type[type_name],
        "total_tons", SUM(fact_production[tons_mined]),
        "avg_per_shift", AVERAGE(fact_production[tons_mined]),
        "shift_count", COUNTROWS(fact_production),
        "total_fuel", SUM(fact_production[fuel_consumed_l])
    )
ORDER BY [total_tons] DESC
```

</details>

---

## Задание 6. Среднее содержание Fe по шахтам и сменам (многомерная группировка)

**Бизнес-задача:** Технолог анализирует качество руды в разрезе шахт и смен.

**Требования:**
- Сгруппируйте данные из `fact_ore_quality` по: шахте (`dim_mine.mine_name`) и смене (`dim_shift.shift_name`)
- Выведите: шахту, смену, количество проб, среднее содержание Fe (%), минимальное и максимальное содержание Fe
- Округлите значения до 2 знаков

**Ожидаемый результат:** 4 строки (2 шахты x 2 смены) или 3, если по одной из шахт нет ночных проб.

<details>
<summary>Решение (DAX)</summary>

```dax
EVALUATE
    SUMMARIZECOLUMNS(
        dim_mine[mine_name],
        dim_shift[shift_name],
        "sample_count", COUNTROWS(fact_ore_quality),
        "avg_fe", ROUND(AVERAGE(fact_ore_quality[fe_content]), 2),
        "min_fe", ROUND(MIN(fact_ore_quality[fe_content]), 2),
        "max_fe", ROUND(MAX(fact_ore_quality[fe_content]), 2)
    )
ORDER BY [mine_name], [shift_name]
```

</details>

---

## Задание 7. Топ-3 месяца по добыче для каждой шахты (GROUP BY + LIMIT)

**Бизнес-задача:** Директор хочет знать, в какие 3 месяца была максимальная добыча на шахте «Северная».

**Требования:**
- Данные из `fact_production`, фильтр: `mine_id = 1`
- Сгруппируйте по месяцу (`dim_date.year_month`)
- Выведите: месяц, общий объём добычи, среднее за смену
- Покажите только топ-3 месяца по общему объёму

**Подсказки:**
- SQL: GROUP BY + ORDER BY + LIMIT 3
- DAX: TOPN(3, SUMMARIZE/ADDCOLUMNS(...), ...)

<details>
<summary>Решение (DAX)</summary>

```dax
EVALUATE
VAR production_by_month =
    SUMMARIZECOLUMNS(
        dim_date[year_month],
        FILTER(dim_mine, dim_mine[mine_id] = 1),
        "total_tons", SUM(fact_production[tons_mined]),
        "avg_per_shift", AVERAGE(fact_production[tons_mined])
    )
RETURN
    TOPN(
        3,
        production_by_month,
        [total_tons],
        DESC
    )
ORDER BY [total_tons] DESC
```

</details>

---

## Задание 8. Анализ простоев по оборудованию (GROUP BY с HAVING / FILTER)

**Бизнес-задача:** Найти оборудование с суммарным временем **внеплановых** простоев более **1000 минут**.

**Требования:**
- Фильтр: только внеплановые простои (`is_planned = FALSE`)
- Группировка по названию оборудования
- Выведите: название оборудования, количество внеплановых простоев, суммарное время (минут), среднее время одного простоя
- Покажите только те единицы, где суммарное время > 1000 минут
- Отсортируйте по суммарному времени (убывание)

**Подсказки:**
- SQL: WHERE + GROUP BY + HAVING
- DAX: CALCULATETABLE + ADDCOLUMNS(SUMMARIZE(...)) + FILTER с условием на агрегат

<details>
<summary>Решение (DAX)</summary>

```dax
EVALUATE
VAR downtime_summary =
    SUMMARIZECOLUMNS(
        dim_equipment[equipment_name],
        FILTER(
            fact_equipment_downtime,
            fact_equipment_downtime[is_planned] = FALSE()
        ),
        "downtime_count", COUNTROWS(fact_equipment_downtime),
        "total_duration", SUM(fact_equipment_downtime[duration_min]),
        "avg_duration", AVERAGE(fact_equipment_downtime[duration_min])
    )
RETURN
    FILTER(
        downtime_summary,
        [total_duration] > 1000
    )
ORDER BY [total_duration] DESC
```

</details>

---

## Задание 9. Сравнение производительности операторов (сводный отчёт)

**Бизнес-задача:** HR-служба готовит отчёт о производительности операторов для ежегодной аттестации.

**Требования:**
- Для каждого оператора выведите:
  - Фамилию и имя (конкатенация)
  - Должность
  - Количество отработанных смен
  - Общий объём добычи (тонн)
  - Средний объём добычи за смену
  - Общее время работы (часов, из `operating_hours`)
  - Производительность (тонн/час) = общая добыча / общее время
- Отсортируйте по производительности (убывание)

**Подсказки:**
- SQL: используйте `SUM(tons_mined) / NULLIF(SUM(operating_hours), 0)` для расчёта производительности
- DAX: используйте `DIVIDE()` для безопасного деления

<details>
<summary>Решение (DAX)</summary>

```dax
EVALUATE
VAR operator_stats =
    SUMMARIZECOLUMNS(
        dim_operator[full_name],
        dim_operator[position],
        "shift_count", COUNTROWS(fact_production),
        "total_tons", SUM(fact_production[tons_mined]),
        "avg_tons_shift", AVERAGE(fact_production[tons_mined]),
        "total_hours", SUM(fact_production[operating_hours]),
        "productivity", DIVIDE(
            SUM(fact_production[tons_mined]),
            SUM(fact_production[operating_hours]),
            0
        )
    )
RETURN
    operator_stats
ORDER BY [productivity] DESC
```

</details>

---

## Задание 10. Комплексный кейс: ежемесячный отчёт для директора

**Бизнес-задача:** Подготовьте сводный отчёт за **январь 2024** для директора предприятия.

Отчёт должен содержать **3 запроса** (каждый — на SQL и DAX):

### 10.1. Добыча по шахтам за январь 2024

- Группировка по шахте
- Показатели: общая добыча (тонн), средняя за смену, количество смен, общий расход топлива, удельный расход (л/т)

<details>
<summary>Решение (DAX)</summary>

```dax
EVALUATE
    SUMMARIZECOLUMNS(
        dim_mine[mine_name],
        FILTER(
            dim_date,
            dim_date[date_id] >= 20240101 && dim_date[date_id] <= 20240131
        ),
        "total_tons", SUM(fact_production[tons_mined]),
        "avg_per_shift", AVERAGE(fact_production[tons_mined]),
        "shift_count", COUNTROWS(fact_production),
        "total_fuel", SUM(fact_production[fuel_consumed_l]),
        "fuel_per_ton", DIVIDE(
            SUM(fact_production[fuel_consumed_l]),
            SUM(fact_production[tons_mined]),
            0
        )
    )
ORDER BY [total_tons] DESC
```

</details>

### 10.2. Простои за январь 2024 (сводка)

- Группировка по категории причины (плановый / внеплановый / организационный)
- Показатели: количество простоев, суммарная длительность (часов), средняя длительность (минут)

<details>
<summary>Решение (DAX)</summary>

```dax
EVALUATE
    SUMMARIZECOLUMNS(
        dim_downtime_reason[category],
        FILTER(
            dim_date,
            dim_date[date_id] >= 20240101 && dim_date[date_id] <= 20240131
        ),
        "downtime_count", COUNTROWS(fact_equipment_downtime),
        "total_hours", DIVIDE(
            SUM(fact_equipment_downtime[duration_min]),
            60,
            0
        ),
        "avg_minutes", AVERAGE(fact_equipment_downtime[duration_min])
    )
ORDER BY [total_hours] DESC
```

</details>

### 10.3. Качество руды за январь 2024

- Группировка по шахте и сорту руды
- Показатели: количество проб, среднее содержание Fe (%), средняя влажность (%)

<details>
<summary>Решение (DAX)</summary>

```dax
EVALUATE
    SUMMARIZECOLUMNS(
        dim_mine[mine_name],
        dim_ore_grade[grade_name],
        FILTER(
            dim_date,
            dim_date[date_id] >= 20240101 && dim_date[date_id] <= 20240131
        ),
        "sample_count", COUNTROWS(fact_ore_quality),
        "avg_fe", ROUND(AVERAGE(fact_ore_quality[fe_content]), 2),
        "avg_moisture", ROUND(AVERAGE(fact_ore_quality[moisture]), 2)
    )
ORDER BY [mine_name], [grade_name]
```

</details>

---

## Критерии оценки

| Критерий | Баллы |
|----------|-------|
| Задания 1-3 (простые) — по 5 баллов | 15 |
| Задания 4-6 (средние) — по 10 баллов | 30 |
| Задания 7-8 (продвинутые) — по 12 баллов | 24 |
| Задание 9 (сводный) — 15 баллов | 15 |
| Задание 10 (комплексный кейс) — 16 баллов | 16 |
| **Итого** | **100** |

**Оценка:**
- 90-100 баллов — «отлично»
- 75-89 баллов — «хорошо»
- 60-74 баллов — «удовлетворительно»
- менее 60 баллов — требуется доработка

---

## Подсказки для самопроверки

- Задание 1: 2 строки
- Задание 2: проверьте, что все единицы оборудования старше 2019 года и с видеорегистратором
- Задание 3: 3 оператора (Новиков, Морозов, Волков)
- Задание 5: ПДМ и самосвалы — основные типы по добыче (вагонетки и скипы в fact_production не участвуют)
- Задание 7: самые продуктивные месяцы обычно приходятся на лето (июнь-август) благодаря сезонному коэффициенту
- Задание 8: помните, что данные генерировались случайно — результаты могут отличаться
- Задание 10: убедитесь, что фильтр по дате `BETWEEN 20240101 AND 20240131` (SQL) или `>= 20240101, <= 20240131` (DAX)
