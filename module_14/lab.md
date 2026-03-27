# Лабораторная работа — Модуль 14

## Свёртывание и наборы группировки

**Продолжительность:** 20 минут
**Формат:** самостоятельная работа
**Инструменты:** PostgreSQL (Yandex Managed Service for PostgreSQL)
**База данных:** «Руда+» (MES-система горнодобывающего предприятия)

---

## Общие указания

- Для каждого задания напишите SQL-запрос и сохраните его в файл `lab_solutions.sql`
- Убедитесь, что расширение tablefunc установлено: `CREATE EXTENSION IF NOT EXISTS tablefunc;`
- Задания расположены по возрастанию сложности

---

## Задание 1. ROLLUP — сменный рапорт с подитогами (простое)

**Бизнес-задача:** Начальник участка хочет получить сменный рапорт по добыче за 15 января 2024 с подитогами по шахтам и общим итогом.

**Требования:**

1. Используя `GROUP BY ROLLUP(mine_name, shift_name)`, сформируйте отчёт:
   - Название шахты
   - Название смены
   - Суммарная добыча (тонн)
   - Количество единиц оборудования
2. Замените NULL в подитоговых строках на понятные подписи с помощью `CASE WHEN GROUPING(...) = 1`
3. Отсортируйте так, чтобы подитоги шли после детализации, общий итог — в конце

**Ожидаемый результат:** Таблица с детализацией, подитогами по шахтам и общим итогом.

<details>
<summary>Решение (DAX)</summary>

```dax
EVALUATE
SUMMARIZECOLUMNS (
    dim_mine[mine_name],
    dim_shift[shift_name],
    FILTER ( dim_date, dim_date[date_id] = 20240115 ),
    "total_tons", SUM ( fact_production[tons_mined] ),
    "equipment_count", DISTINCTCOUNT ( fact_production[equipment_id] )
)
ORDER BY [mine_name], [shift_name]
```

> В DAX нет прямого аналога `ROLLUP`. Подитоги автоматически рассчитываются визуальными элементами Power BI (матрица, таблица). Для программного получения подитогов можно использовать `SUMMARIZECOLUMNS` с `ROLLUPADDISSUBTOTAL`.

</details>

---

## Задание 2. CUBE — матрица «шахта x тип оборудования» (простое)

**Бизнес-задача:** Главный инженер хочет видеть добычу по всем комбинациям «шахта / тип оборудования» с итогами по строкам и столбцам.

**Требования:**

1. Используя `GROUP BY CUBE(mine_name, type_name)`, сформируйте отчёт за I квартал 2024:
   - Шахта (или «ВСЕ ШАХТЫ» для подитога)
   - Тип оборудования (или «ВСЕ ТИПЫ» для подитога)
   - Суммарная добыча
   - Средняя добыча на единицу оборудования
2. Добавьте столбец `grouping_level` с помощью `GROUPING(mine_name, type_name)`
3. Отсортируйте по уровню группировки, шахте и типу

**Вопрос:** Сколько строк вернёт CUBE для 3 шахт и 4 типов оборудования? (Ответ: 3x4 + 3 + 4 + 1 = 20.)

<details>
<summary>Решение (DAX)</summary>

```dax
EVALUATE
SUMMARIZECOLUMNS (
    ROLLUPADDISSUBTOTAL (
        dim_mine[mine_name], "mine_subtotal",
        dim_equipment[type_name], "type_subtotal"
    ),
    TREATAS ( { 2024 }, dim_date[year] ),
    TREATAS ( { 1 }, dim_date[quarter] ),
    "total_tons", SUM ( fact_production[tons_mined] ),
    "avg_tons_per_equip",
        DIVIDE (
            SUM ( fact_production[tons_mined] ),
            DISTINCTCOUNT ( fact_production[equipment_id] )
        )
)
```

> `ROLLUPADDISSUBTOTAL` в DAX — ближайший аналог `CUBE`. Он добавляет столбцы-флаги, указывающие, является ли строка подитогом.

</details>

---

## Задание 3. GROUPING SETS — сводка KPI по нескольким срезам (среднее)

**Бизнес-задача:** Для ежемесячного совещания подготовить сводку по добыче за январь 2024 в разрезе: по шахтам, по сменам, по типам оборудования, общий итог.

**Требования:**

1. Используя GROUPING SETS, в одном запросе получите 4 среза:
   - `(mine_name)` — итого по шахтам
   - `(shift_name)` — итого по сменам
   - `(type_name)` — итого по типам оборудования
   - `()` — общий итог
2. Добавьте столбец `dimension` с названием среза: «Шахта», «Смена», «Тип оборудования», «ИТОГО»
3. Выведите: dimension, dimension_value, total_tons, total_trips, avg_tons_per_trip

**Подсказка:**

```sql
SELECT
    CASE
        WHEN GROUPING(m.mine_name) = 0 THEN 'Шахта'
        WHEN GROUPING(s.shift_name) = 0 THEN 'Смена'
        WHEN GROUPING(et.type_name) = 0 THEN 'Тип оборудования'
        ELSE 'ИТОГО'
    END AS dimension,
    COALESCE(m.mine_name, s.shift_name, et.type_name, 'Все') AS dimension_value,
    ...
```

<details>
<summary>Решение (DAX)</summary>

```dax
// Срез по шахтам
EVALUATE
SUMMARIZECOLUMNS (
    dim_mine[mine_name],
    TREATAS ( { 2024 }, dim_date[year] ),
    TREATAS ( { 1 }, dim_date[month] ),
    "total_tons", SUM ( fact_production[tons_mined] ),
    "total_trips", SUM ( fact_production[trips_count] ),
    "avg_tons_per_trip",
        DIVIDE (
            SUM ( fact_production[tons_mined] ),
            SUM ( fact_production[trips_count] )
        )
)

// В Power BI несколько GROUPING SETS эмулируются через
// отдельные меры или UNION нескольких SUMMARIZECOLUMNS
```

> В DAX нет аналога `GROUPING SETS`. Каждый срез формируется отдельным запросом `SUMMARIZECOLUMNS`. В Power BI подобный отчёт строится через несколько визуальных элементов или через паттерн «виртуальная таблица» с `UNION`.

</details>

---

## Задание 4. Условная агрегация — PIVOT (среднее)

**Бизнес-задача:** Построить таблицу «Качество руды по шахтам и месяцам» в формате Excel-сводной таблицы.

**Требования:**

1. С помощью условной агрегации (CASE WHEN) разверните данные fact_ore_quality за I полугодие 2024:
   - Строки: mine_name
   - Столбцы: месяцы (Янв, Фев, ..., Июн)
   - Значения: среднее содержание Fe (%), округлённое до 2 знаков
2. Добавьте столбец «Среднее за период»
3. Добавьте строку «ИТОГО» с помощью `GROUPING SETS` или `UNION ALL`

<details>
<summary>Решение (DAX)</summary>

```dax
EVALUATE
ADDCOLUMNS (
    VALUES ( dim_mine[mine_name] ),
    "Янв",
        CALCULATE (
            AVERAGE ( fact_ore_quality[fe_content] ),
            dim_date[year] = 2024, dim_date[month] = 1
        ),
    "Фев",
        CALCULATE (
            AVERAGE ( fact_ore_quality[fe_content] ),
            dim_date[year] = 2024, dim_date[month] = 2
        ),
    "Мар",
        CALCULATE (
            AVERAGE ( fact_ore_quality[fe_content] ),
            dim_date[year] = 2024, dim_date[month] = 3
        ),
    "Апр",
        CALCULATE (
            AVERAGE ( fact_ore_quality[fe_content] ),
            dim_date[year] = 2024, dim_date[month] = 4
        ),
    "Май",
        CALCULATE (
            AVERAGE ( fact_ore_quality[fe_content] ),
            dim_date[year] = 2024, dim_date[month] = 5
        ),
    "Июн",
        CALCULATE (
            AVERAGE ( fact_ore_quality[fe_content] ),
            dim_date[year] = 2024, dim_date[month] = 6
        ),
    "Среднее",
        CALCULATE (
            AVERAGE ( fact_ore_quality[fe_content] ),
            dim_date[year] = 2024, dim_date[month] <= 6
        )
)
```

> В DAX «разворот» (PIVOT) реализуется через несколько `CALCULATE` с разными фильтрами по месяцам. В Power BI матричный визуал автоматически разворачивает данные по столбцам.

</details>

---

## Задание 5. crosstab — динамический разворот (среднее)

**Бизнес-задача:** Сформировать таблицу простоев: строки — оборудование, столбцы — причины простоев, значения — суммарная длительность (часы).

**Требования:**

1. Установите расширение: `CREATE EXTENSION IF NOT EXISTS tablefunc;`
2. С помощью `crosstab()` постройте сводную таблицу за I квартал 2024:
   - Строки: equipment_name
   - Столбцы: top-5 причин простоев (по общей длительности)
   - Значения: суммарная длительность в часах, округлённая до 1 знака
3. Определите структуру результата в `AS ct(...)` вручную

**Подсказка:** Сначала определите top-5 причин:

```sql
SELECT reason_name FROM dim_downtime_reason dr
JOIN fact_equipment_downtime fd ON dr.reason_id = fd.reason_id
WHERE fd.date_id BETWEEN 20240101 AND 20240331
GROUP BY dr.reason_name
ORDER BY SUM(fd.duration_min) DESC
LIMIT 5;
```

---

## Задание 6. Комплексный отчёт — ROLLUP + PIVOT + итоги (сложное)

**Бизнес-задача:** Подготовить квартальный производственный отчёт для руководства: по каждой шахте — добыча по месяцам, подитоги по кварталу, общий итог по компании.

**Требования:**

1. Сформируйте «широкую» таблицу:
   - Строки: шахта (с подитогом «ИТОГО» через ROLLUP)
   - Столбцы: Январь, Февраль, Март, Q1 Итого (через условную агрегацию)
   - Значения: добыча (тонн)
2. Добавьте столбцы:
   - Изменение Фев vs Янв (%)
   - Изменение Мар vs Фев (%)
   - Тренд: «рост» / «снижение» / «стабильно» (если изменение < 5%)
3. Сформируйте вторую часть отчёта с простоями (UNION ALL):
   - Те же строки и столбцы
   - Значения: простои (часы)
4. Отсортируйте: детализация → подитог

**Подсказка:** Структура запроса:

```sql
-- Часть 1: добыча
SELECT
    COALESCE(m.mine_name, '== ИТОГО ==') AS mine,
    'Добыча (тонн)' AS metric,
    SUM(CASE WHEN d.month = 1 THEN fp.tons_mined END) AS jan,
    SUM(CASE WHEN d.month = 2 THEN fp.tons_mined END) AS feb,
    SUM(CASE WHEN d.month = 3 THEN fp.tons_mined END) AS mar,
    SUM(fp.tons_mined) AS q1_total
FROM fact_production fp
JOIN dim_mine m ON fp.mine_id = m.mine_id
JOIN dim_date d ON fp.date_id = d.date_id
WHERE d.year = 2024 AND d.quarter = 1
GROUP BY ROLLUP(m.mine_name)

UNION ALL

-- Часть 2: простои
SELECT ...
```

---

## Критерии оценки

| Задание | Баллы | Критерий |
|---------|-------|----------|
| 1 | 10 | ROLLUP, подписи через GROUPING |
| 2 | 15 | CUBE, подсчёт строк |
| 3 | 15 | GROUPING SETS, определение среза |
| 4 | 20 | Условная агрегация, строка итогов |
| 5 | 20 | crosstab, определение структуры |
| 6 | 20 | ROLLUP + PIVOT + тренд |
| **Итого** | **100** | |
