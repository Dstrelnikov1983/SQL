# Практическая работа — Модуль 13

## Использование оконных функций

**Продолжительность:** 60 минут
**Инструменты:** Yandex Managed Service for PostgreSQL (SQL) | Power BI + DAX Studio (DAX)
**Предприятие:** «Руда+» — добыча железной руды

---

## Предварительные требования

1. База данных «Руда+» развёрнута на PostgreSQL (скрипты `01_create_schema.sql`, `02_insert_dimensions.sql`, `03_insert_facts.sql` из каталога `common/scripts/`)
2. Клиент SQL (DBeaver, pgAdmin или psql) подключён к PostgreSQL
3. Модель данных импортирована в Power BI
4. DAX Studio установлен и подключён к модели Power BI
5. Файл `examples.sql` открыт для справки

---

## Часть 1. Конструкция OVER(), PARTITION BY, ORDER BY

### Шаг 1.1. OVER() без параметров — глобальный агрегат

```sql
-- Добавляем общую сумму добычи ко всем строкам
SELECT
    e.equipment_name,
    fp.tons_mined,
    SUM(fp.tons_mined) OVER () AS grand_total,
    ROUND(fp.tons_mined * 100.0 / SUM(fp.tons_mined) OVER (), 2)
        AS pct_of_total
FROM fact_production fp
JOIN dim_equipment e ON e.equipment_id = fp.equipment_id
WHERE fp.date_id = 20240115 AND fp.shift_id = 1;
```

**Что наблюдаем:** `OVER()` без параметров вычисляет агрегат по всему результирующему набору. Каждая строка содержит как свою индивидуальную добычу, так и общую сумму.

### Шаг 1.2. PARTITION BY — разбивка по группам

```sql
-- Итого по шахтам: каждая строка видит сумму своей шахты
SELECT
    e.equipment_name,
    m.mine_name,
    fp.tons_mined,
    SUM(fp.tons_mined) OVER (PARTITION BY fp.mine_id)
        AS mine_total,
    ROUND(
        fp.tons_mined * 100.0
        / SUM(fp.tons_mined) OVER (PARTITION BY fp.mine_id),
        1
    ) AS pct_of_mine,
    COUNT(*) OVER (PARTITION BY fp.mine_id)
        AS equipment_count_in_mine
FROM fact_production fp
JOIN dim_equipment e ON e.equipment_id = fp.equipment_id
JOIN dim_mine m ON m.mine_id = fp.mine_id
WHERE fp.date_id = 20240115 AND fp.shift_id = 1;
```

**Что наблюдаем:** PARTITION BY делит набор строк на группы (разделы). Агрегация происходит внутри каждого раздела отдельно, при этом строки **не схлопываются** (в отличие от GROUP BY).

### Шаг 1.3. PARTITION BY с несколькими столбцами

```sql
-- Агрегация по комбинации шахта + смена
SELECT
    m.mine_name,
    s.shift_name,
    e.equipment_name,
    fp.tons_mined,
    SUM(fp.tons_mined) OVER (
        PARTITION BY fp.mine_id, fp.shift_id
    ) AS mine_shift_total,
    AVG(fp.tons_mined) OVER (
        PARTITION BY fp.mine_id, fp.shift_id
    ) AS mine_shift_avg
FROM fact_production fp
JOIN dim_equipment e ON e.equipment_id = fp.equipment_id
JOIN dim_mine m ON m.mine_id = fp.mine_id
JOIN dim_shift s ON s.shift_id = fp.shift_id
WHERE fp.date_id = 20240115;
```

### Шаг 1.4. ORDER BY в окне — нарастающий итог

```sql
-- Нарастающий итог добычи (running total)
SELECT
    d.full_date,
    SUM(fp.tons_mined) AS daily_tons,
    SUM(SUM(fp.tons_mined)) OVER (
        ORDER BY d.full_date
    ) AS running_total
FROM fact_production fp
JOIN dim_date d ON d.date_id = fp.date_id
WHERE fp.mine_id = 1
  AND d.year = 2024 AND d.month = 1
GROUP BY d.full_date
ORDER BY d.full_date;
```

**Что наблюдаем:** ORDER BY в окне задаёт порядок строк для вычисления. По умолчанию при наличии ORDER BY рамка окна — от начала до текущей строки (RANGE BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW), что даёт нарастающий итог.

### Шаг 1.5. Аналог в DAX — контекст фильтра как замена PARTITION BY

```dax
// Аналог OVER (PARTITION BY mine_id): процент добычи от шахты
EVALUATE
ADDCOLUMNS(
    SUMMARIZE(
        FILTER(fact_production, fact_production[date_id] = 20240115
            && fact_production[shift_id] = 1),
        dim_equipment[equipment_name],
        dim_mine[mine_name]
    ),
    "TonsMined",
        CALCULATE(SUM(fact_production[tons_mined])),
    "MineTotalTons",
        CALCULATE(
            SUM(fact_production[tons_mined]),
            ALLEXCEPT(fact_production, dim_mine[mine_name])
        ),
    "PctOfMine",
        DIVIDE(
            CALCULATE(SUM(fact_production[tons_mined])),
            CALCULATE(
                SUM(fact_production[tons_mined]),
                ALLEXCEPT(fact_production, dim_mine[mine_name])
            )
        ) * 100
)
ORDER BY dim_mine[mine_name], [TonsMined] DESC
```

**Что наблюдаем:** В DAX нет прямого аналога OVER(PARTITION BY). Вместо этого используется CALCULATE с функциями ALL/ALLEXCEPT для изменения контекста фильтра.

> **Обсуждение:** В чём принципиальная разница между GROUP BY и PARTITION BY? Когда нужен один подход, а когда другой?

---

## Часть 2. Спецификация рамки (ROWS / RANGE BETWEEN)

### Шаг 2.1. Скользящее среднее за 7 дней (ROWS)

```sql
-- 7-дневное скользящее среднее добычи
SELECT
    d.full_date,
    SUM(fp.tons_mined) AS daily_tons,
    ROUND(
        AVG(SUM(fp.tons_mined)) OVER (
            ORDER BY d.full_date
            ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
        ), 2
    ) AS ma_7d,
    ROUND(
        AVG(SUM(fp.tons_mined)) OVER (
            ORDER BY d.full_date
            ROWS BETWEEN 14 PRECEDING AND CURRENT ROW
        ), 2
    ) AS ma_15d
FROM fact_production fp
JOIN dim_date d ON d.date_id = fp.date_id
WHERE fp.mine_id = 1
  AND d.year = 2024 AND d.quarter = 1
GROUP BY d.full_date
ORDER BY d.full_date;
```

**Что наблюдаем:** ROWS BETWEEN определяет рамку окна в физических строках. `6 PRECEDING AND CURRENT ROW` — это 7 строк (текущая + 6 предыдущих).

### Шаг 2.2. Центрированное скользящее среднее

```sql
-- Центрированное среднее: 3 строки до + текущая + 3 после
SELECT
    d.full_date,
    SUM(fp.tons_mined) AS daily_tons,
    ROUND(
        AVG(SUM(fp.tons_mined)) OVER (
            ORDER BY d.full_date
            ROWS BETWEEN 3 PRECEDING AND 3 FOLLOWING
        ), 2
    ) AS centered_ma_7d
FROM fact_production fp
JOIN dim_date d ON d.date_id = fp.date_id
WHERE fp.mine_id = 1 AND d.year = 2024 AND d.month = 1
GROUP BY d.full_date
ORDER BY d.full_date;
```

### Шаг 2.3. Скользящие min/max и размах (range)

```sql
-- Скользящий минимум, максимум и размах за 7 дней
SELECT
    d.full_date,
    SUM(fp.tons_mined) AS daily_tons,
    MIN(SUM(fp.tons_mined)) OVER w7 AS min_7d,
    MAX(SUM(fp.tons_mined)) OVER w7 AS max_7d,
    MAX(SUM(fp.tons_mined)) OVER w7
      - MIN(SUM(fp.tons_mined)) OVER w7 AS range_7d
FROM fact_production fp
JOIN dim_date d ON d.date_id = fp.date_id
WHERE fp.mine_id = 1 AND d.year = 2024 AND d.month <= 2
GROUP BY d.full_date
WINDOW w7 AS (ORDER BY d.full_date ROWS BETWEEN 6 PRECEDING AND CURRENT ROW)
ORDER BY d.full_date;
```

### Шаг 2.4. ROWS vs RANGE vs GROUPS — наглядное сравнение

Чтобы увидеть разницу **всех трёх** режимов, нужны данные с двумя свойствами:
1. **Дубликаты** в ORDER BY — несколько строк с одинаковым значением (→ ROWS отличается от RANGE/GROUPS)
2. **Пропуски** в значениях — не все числа между min и max присутствуют (→ RANGE отличается от GROUPS)

> **Важно:** `RANGE` с `N PRECEDING` требует **ровно одно** числовое/дата поле в ORDER BY.
> С несколькими полями ORDER BY поддерживаются только `UNBOUNDED` и `CURRENT ROW`.

Используем типы оборудования: **1** (ПДМ), **3** (Самосвал), **7** (Подъёмник) — каждый тип представлен 2 единицами (дубликаты), между типами есть пропуски (нет типов 2, 4, 5, 6).

```sql
-- Одинаковая рамка 1 PRECEDING AND CURRENT ROW — три разных результата
WITH data AS (
    SELECT * FROM (VALUES
        (1, 'ПДМ-01',       100),
        (1, 'ПДМ-02',       120),
        (3, 'Самосвал-01',  200),
        (3, 'Самосвал-02',  180),
        (7, 'Подъёмник-01', 250),
        (7, 'Подъёмник-02', 230)
    ) AS t(type_id, equip_name, tons)
)
SELECT
    type_id, equip_name, tons,
    SUM(tons) OVER (ORDER BY type_id
        ROWS   BETWEEN 1 PRECEDING AND CURRENT ROW) AS sum_rows,
    SUM(tons) OVER (ORDER BY type_id
        RANGE  BETWEEN 1 PRECEDING AND CURRENT ROW) AS sum_range,
    SUM(tons) OVER (ORDER BY type_id
        GROUPS BETWEEN 1 PRECEDING AND CURRENT ROW) AS sum_groups
FROM data;
```

**Ожидаемый результат:**

| type_id | equip_name   | tons | sum_rows | sum_range | sum_groups |
|---------|--------------|------|----------|-----------|------------|
| 1       | ПДМ-01       | 100  | 100      | 220       | 220        |
| 1       | ПДМ-02       | 120  | 220      | 220       | 220        |
| **3**   | **Самосвал-01**  | **200** | **320** | **380** | **600** |
| 3       | Самосвал-02  | 180  | 380      | 380       | 600        |
| **7**   | **Подъёмник-01** | **250** | **430** | **480** | **860** |
| 7       | Подъёмник-02 | 230  | 480      | 480       | 860        |

**Разбор строки Самосвал-01 (type_id = 3):**

- **ROWS** `1 PRECEDING` — 1 физическая строка назад (ПДМ-02, 120) + текущая (200) = **320**
- **RANGE** `1 PRECEDING` — значения от 2 до 3. Тип 2 не существует! Только тип 3: 200 + 180 = **380**
- **GROUPS** `1 PRECEDING` — предыдущая группа (тип 1: 100 + 120) + текущая (тип 3: 200 + 180) = **600**

**Все три значения разные!** Это происходит потому, что:
- Дубликаты (2 единицы на тип) → ROWS ≠ RANGE (ROWS берёт 1 строку, RANGE берёт все строки с близким значением)
- Пропуски (нет типа 2) → RANGE ≠ GROUPS (RANGE не находит тип 2, GROUPS перешагивает к типу 1)

### Шаг 2.5. Сводная таблица: ROWS / RANGE / GROUPS

| Характеристика | ROWS | RANGE | GROUPS |
|-----------------|------|-------|--------|
| Единица отсчёта | Физическая строка | Значение ORDER BY | Группа peer-строк |
| `1 PRECEDING` | 1 строка назад | Значение минус 1 | 1 группа назад |
| Дубликаты ORDER BY | По одной строке | Все дубликаты вместе | Все дубликаты вместе |
| Пропуски в значениях | Не замечает | **Теряет** данные через пропуск | **Перешагивает** через пропуск |
| Когда использовать | Скользящее среднее по N строкам | Диапазон по значению (дата ± N дней) | Окно по N логических групп |

### Шаг 2.6. Аналог в DAX — скользящее среднее

```dax
// Скользящее среднее за 7 дней в DAX
// Мера Moving Average 7d:
// Скользящее среднее рассчитывается через CALCULATE + DATESINPERIOD или вручную
EVALUATE
ADDCOLUMNS(
    FILTER(VALUES(dim_date[full_date]),
        dim_date[year] = 2024 && dim_date[month] = 1),
    "DailyTons",
        CALCULATE(
            SUM(fact_production[tons_mined]),
            fact_production[mine_id] = 1
        ),
    "MA_7d",
        VAR CurrentDate = dim_date[full_date]
        RETURN
        AVERAGEX(
            FILTER(
                ALL(dim_date[full_date]),
                dim_date[full_date] >= CurrentDate - 6
                    && dim_date[full_date] <= CurrentDate
            ),
            CALCULATE(
                SUM(fact_production[tons_mined]),
                fact_production[mine_id] = 1
            )
        )
)
ORDER BY dim_date[full_date]
```

**Что наблюдаем:** В DAX нет прямого аналога ROWS BETWEEN. Скользящие окна реализуются через CALCULATE с ручным заданием диапазона дат.

> **Обсуждение:** Какие бизнес-задачи на предприятии «Руда+» можно решить с помощью скользящих средних? (Ответ: мониторинг тренда добычи, сглаживание суточных колебаний, раннее обнаружение деградации оборудования.)

---

## Часть 3. Агрегатные оконные функции (SUM, AVG, COUNT OVER)

### Шаг 3.1. Доля оператора с нарастающим процентом (анализ Парето)

```sql
SELECT
    o.last_name || ' ' || LEFT(o.first_name, 1) || '.' AS operator,
    SUM(fp.tons_mined) AS total_tons,
    ROUND(
        SUM(fp.tons_mined) * 100.0
        / SUM(SUM(fp.tons_mined)) OVER (),
        1
    ) AS pct_total,
    ROUND(
        SUM(SUM(fp.tons_mined)) OVER (
            ORDER BY SUM(fp.tons_mined) DESC
        ) * 100.0
        / SUM(SUM(fp.tons_mined)) OVER (),
        1
    ) AS cumulative_pct
FROM fact_production fp
JOIN dim_operator o ON o.operator_id = fp.operator_id
WHERE fp.date_id BETWEEN 20240101 AND 20240131
GROUP BY o.operator_id, o.last_name, o.first_name
ORDER BY total_tons DESC;
```

**Что наблюдаем:** Нарастающий процент позволяет определить, какие операторы обеспечивают 80% добычи (правило Парето 80/20).

### Шаг 3.2. Сравнение с средним по группе

```sql
SELECT
    e.equipment_name,
    et.type_name,
    SUM(fp.tons_mined) AS total_tons,
    ROUND(AVG(SUM(fp.tons_mined)) OVER (
        PARTITION BY e.equipment_type_id
    ), 2) AS avg_for_type,
    ROUND(
        SUM(fp.tons_mined)
        - AVG(SUM(fp.tons_mined)) OVER (PARTITION BY e.equipment_type_id),
        2
    ) AS diff_from_avg,
    CASE
        WHEN SUM(fp.tons_mined) > AVG(SUM(fp.tons_mined))
            OVER (PARTITION BY e.equipment_type_id) THEN 'Выше среднего'
        ELSE 'Ниже среднего'
    END AS performance
FROM fact_production fp
JOIN dim_equipment e ON e.equipment_id = fp.equipment_id
JOIN dim_equipment_type et ON et.equipment_type_id = e.equipment_type_id
WHERE fp.date_id BETWEEN 20240101 AND 20240331
GROUP BY e.equipment_id, e.equipment_name,
         e.equipment_type_id, et.type_name
ORDER BY et.type_name, total_tons DESC;
```

### Шаг 3.3. Аналог в DAX — нарастающий итог

```dax
// Кумулятивный % добычи по операторам (Парето)
EVALUATE
VAR OperatorTons =
    ADDCOLUMNS(
        SUMMARIZE(
            FILTER(fact_production,
                fact_production[date_id] >= 20240101
                && fact_production[date_id] <= 20240131),
            dim_operator[last_name]
        ),
        "TotalTons", CALCULATE(SUM(fact_production[tons_mined]))
    )
VAR GrandTotal = SUMX(OperatorTons, [TotalTons])
RETURN
ADDCOLUMNS(
    OperatorTons,
    "PctTotal", DIVIDE([TotalTons], GrandTotal) * 100,
    "CumulativePct",
        VAR CurrentTons = [TotalTons]
        RETURN
        DIVIDE(
            SUMX(
                FILTER(OperatorTons, [TotalTons] >= CurrentTons),
                [TotalTons]
            ),
            GrandTotal
        ) * 100
)
ORDER BY [TotalTons] DESC
```

> **Обсуждение:** Какие ещё анализы Парето актуальны для горнодобывающего предприятия? (Причины простоев, расход ГСМ, качество руды по забоям.)

---

## Часть 4. Функции ранжирования (ROW_NUMBER, RANK, DENSE_RANK, NTILE)

### Шаг 4.1. Сравнение трёх функций ранжирования

```sql
SELECT
    o.last_name,
    SUM(fp.tons_mined) AS total_tons,
    ROW_NUMBER() OVER (ORDER BY SUM(fp.tons_mined) DESC)  AS row_num,
    RANK()       OVER (ORDER BY SUM(fp.tons_mined) DESC)  AS rank_val,
    DENSE_RANK() OVER (ORDER BY SUM(fp.tons_mined) DESC)  AS dense_rank_val,
    NTILE(3)     OVER (ORDER BY SUM(fp.tons_mined) DESC)  AS tercile
FROM fact_production fp
JOIN dim_operator o ON o.operator_id = fp.operator_id
WHERE fp.date_id BETWEEN 20240101 AND 20240131
GROUP BY o.operator_id, o.last_name
ORDER BY total_tons DESC;
```

**Что наблюдаем:**
- `ROW_NUMBER` — уникальный номер строки (1, 2, 3, 4...)
- `RANK` — одинаковые значения получают одинаковый ранг, но следующий ранг пропускается (1, 2, 2, 4)
- `DENSE_RANK` — одинаковые значения получают одинаковый ранг, следующий ранг НЕ пропускается (1, 2, 2, 3)
- `NTILE(N)` — делит набор на N равных групп

### Шаг 4.2. ТОП-3 дня по добыче для каждого оборудования

```sql
WITH daily AS (
    SELECT
        fp.equipment_id,
        e.equipment_name,
        d.full_date,
        SUM(fp.tons_mined) AS daily_tons,
        ROW_NUMBER() OVER (
            PARTITION BY fp.equipment_id
            ORDER BY SUM(fp.tons_mined) DESC
        ) AS rn
    FROM fact_production fp
    JOIN dim_equipment e ON e.equipment_id = fp.equipment_id
    JOIN dim_date d ON d.date_id = fp.date_id
    WHERE d.year = 2024
    GROUP BY fp.equipment_id, e.equipment_name, d.full_date
)
SELECT equipment_name, full_date, daily_tons
FROM daily
WHERE rn <= 3
ORDER BY equipment_name, rn;
```

**Что наблюдаем:** Паттерн «ТОП-N для каждой группы» — одно из самых частых применений ROW_NUMBER + PARTITION BY.

### Шаг 4.3. NTILE — сегментация по эффективности

```sql
WITH equip_stats AS (
    SELECT
        e.equipment_name,
        et.type_name,
        ROUND(AVG(fp.tons_mined / NULLIF(fp.operating_hours, 0)), 2)
            AS tons_per_hour,
        NTILE(4) OVER (
            ORDER BY AVG(fp.tons_mined / NULLIF(fp.operating_hours, 0)) DESC
        ) AS efficiency_quartile
    FROM fact_production fp
    JOIN dim_equipment e ON e.equipment_id = fp.equipment_id
    JOIN dim_equipment_type et ON et.equipment_type_id = e.equipment_type_id
    WHERE fp.date_id BETWEEN 20240101 AND 20240630
    GROUP BY e.equipment_id, e.equipment_name, et.type_name
)
SELECT
    *,
    CASE efficiency_quartile
        WHEN 1 THEN 'Высокая эффективность'
        WHEN 2 THEN 'Выше среднего'
        WHEN 3 THEN 'Ниже среднего'
        WHEN 4 THEN 'Требует внимания'
    END AS efficiency_category
FROM equip_stats
ORDER BY efficiency_quartile, tons_per_hour DESC;
```

### Шаг 4.4. Аналог в DAX — RANKX

```dax
// RANKX — ранжирование операторов по добыче
EVALUATE
VAR OperatorData =
    ADDCOLUMNS(
        SUMMARIZE(
            FILTER(fact_production,
                fact_production[date_id] >= 20240101
                && fact_production[date_id] <= 20240131),
            dim_operator[last_name]
        ),
        "TotalTons", CALCULATE(SUM(fact_production[tons_mined]))
    )
RETURN
ADDCOLUMNS(
    OperatorData,
    "Rank", RANKX(OperatorData, [TotalTons], , DESC, DENSE)
)
ORDER BY [TotalTons] DESC
```

**Что наблюдаем:** DAX RANKX поддерживает параметр Dense (аналог DENSE_RANK) и Skip (аналог RANK). ROW_NUMBER в DAX отсутствует — используется RANKX по уникальному ключу.

> **Обсуждение:** В каких случаях на «Руда+» лучше использовать RANK, а в каких DENSE_RANK? (Ответ: для рейтингов с призами — RANK; для квалификационных категорий — DENSE_RANK.)

---

## Часть 5. Функции смещения (LAG, LEAD, FIRST_VALUE, LAST_VALUE)

### Шаг 5.1. LAG — сравнение с предыдущим днём

```sql
SELECT
    d.full_date,
    SUM(fp.tons_mined) AS today_tons,
    LAG(SUM(fp.tons_mined), 1) OVER (ORDER BY d.full_date)
        AS yesterday_tons,
    LAG(SUM(fp.tons_mined), 7) OVER (ORDER BY d.full_date)
        AS week_ago_tons,
    ROUND(
        (SUM(fp.tons_mined)
         - LAG(SUM(fp.tons_mined), 1) OVER (ORDER BY d.full_date))
        * 100.0
        / NULLIF(LAG(SUM(fp.tons_mined), 1) OVER (ORDER BY d.full_date), 0),
        1
    ) AS day_over_day_pct
FROM fact_production fp
JOIN dim_date d ON d.date_id = fp.date_id
WHERE fp.mine_id = 1 AND d.year = 2024 AND d.month = 1
GROUP BY d.full_date
ORDER BY d.full_date;
```

**Что наблюдаем:** LAG(expr, N) возвращает значение из строки, находящейся на N позиций до текущей. Это позволяет сравнивать значения «сегодня vs вчера» и «сегодня vs неделю назад».

### Шаг 5.2. LEAD — следующий плановый простой

```sql
SELECT
    e.equipment_name,
    d.full_date AS downtime_date,
    dr.reason_name,
    fd.duration_min,
    LEAD(d.full_date, 1) OVER (
        PARTITION BY fd.equipment_id
        ORDER BY d.full_date
    ) AS next_downtime_date,
    LEAD(d.full_date, 1) OVER (
        PARTITION BY fd.equipment_id
        ORDER BY d.full_date
    ) - d.full_date AS days_between
FROM fact_equipment_downtime fd
JOIN dim_equipment e ON e.equipment_id = fd.equipment_id
JOIN dim_date d ON d.date_id = fd.date_id
JOIN dim_downtime_reason dr ON dr.reason_id = fd.reason_id
WHERE fd.is_planned AND dr.reason_code = 'MAINT_PLAN'
ORDER BY e.equipment_name, d.full_date;
```

**Что наблюдаем:** LEAD заглядывает вперёд. Вычисляем интервал между плановыми ТО для каждого оборудования.

### Шаг 5.3. FIRST_VALUE и LAST_VALUE

```sql
SELECT
    d.full_date,
    SUM(fp.tons_mined) AS daily_tons,
    FIRST_VALUE(SUM(fp.tons_mined)) OVER (
        PARTITION BY d.month
        ORDER BY d.full_date
    ) AS first_day_tons,
    LAST_VALUE(SUM(fp.tons_mined)) OVER (
        PARTITION BY d.month
        ORDER BY d.full_date
        ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING
    ) AS last_day_tons,
    FIRST_VALUE(d.full_date) OVER (
        PARTITION BY d.month
        ORDER BY SUM(fp.tons_mined) DESC
        ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING
    ) AS best_day_date
FROM fact_production fp
JOIN dim_date d ON d.date_id = fp.date_id
WHERE fp.mine_id = 1 AND d.year = 2024 AND d.month <= 3
GROUP BY d.full_date, d.month
ORDER BY d.full_date;
```

**Внимание:** для LAST_VALUE необходимо явно указывать рамку `ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING`, иначе по умолчанию рамка заканчивается на текущей строке и LAST_VALUE всегда возвращает текущее значение.

### Шаг 5.4. Аналог в DAX — OFFSET (DAX 2022+)

```dax
// LAG в DAX — через функцию OFFSET (доступна в новых версиях Power BI)
EVALUATE
VAR DailyData =
    ADDCOLUMNS(
        FILTER(VALUES(dim_date[full_date]),
            dim_date[year] = 2024 && dim_date[month] = 1),
        "TodayTons",
            CALCULATE(
                SUM(fact_production[tons_mined]),
                fact_production[mine_id] = 1
            )
    )
RETURN
ADDCOLUMNS(
    DailyData,
    "YesterdayTons",
        VAR CurrentDate = dim_date[full_date]
        RETURN
        CALCULATE(
            SUM(fact_production[tons_mined]),
            fact_production[mine_id] = 1,
            FILTER(ALL(dim_date[full_date]),
                dim_date[full_date] = CurrentDate - 1)
        ),
    "DayOverDayPct",
        VAR CurrentDate = dim_date[full_date]
        VAR Today = [TodayTons]
        VAR Yesterday =
            CALCULATE(
                SUM(fact_production[tons_mined]),
                fact_production[mine_id] = 1,
                FILTER(ALL(dim_date[full_date]),
                    dim_date[full_date] = CurrentDate - 1)
            )
        RETURN
        DIVIDE(Today - Yesterday, Yesterday) * 100
)
ORDER BY dim_date[full_date]
```

**Что наблюдаем:** В DAX для LAG/LEAD используется OFFSET (в новых версиях) или ручное вычисление через FILTER + ALL. Это значительно более громоздко, чем в SQL.

> **Обсуждение:** Какие метрики на «Руда+» полезно сравнивать «день к дню» и «неделя к неделе»? (Добыча, расход ГСМ, количество рейсов, содержание Fe.)

---

## Часть 6. Статистические функции (PERCENT_RANK, CUME_DIST, PERCENTILE_CONT)

### Шаг 6.1. PERCENT_RANK и CUME_DIST

```sql
SELECT
    o.last_name,
    et.type_name,
    ROUND(AVG(fp.tons_mined / NULLIF(fp.operating_hours, 0)), 2)
        AS tons_per_hour,
    ROUND(PERCENT_RANK() OVER (
        PARTITION BY e.equipment_type_id
        ORDER BY AVG(fp.tons_mined / NULLIF(fp.operating_hours, 0))
    )::NUMERIC, 3) AS pct_rank,
    ROUND(CUME_DIST() OVER (
        PARTITION BY e.equipment_type_id
        ORDER BY AVG(fp.tons_mined / NULLIF(fp.operating_hours, 0))
    )::NUMERIC, 3) AS cume_dist
FROM fact_production fp
JOIN dim_operator o ON o.operator_id = fp.operator_id
JOIN dim_equipment e ON e.equipment_id = fp.equipment_id
JOIN dim_equipment_type et ON et.equipment_type_id = e.equipment_type_id
WHERE fp.date_id BETWEEN 20240101 AND 20240630
GROUP BY o.operator_id, o.last_name,
         e.equipment_type_id, et.type_name;
```

**Что наблюдаем:**
- `PERCENT_RANK` = (rank - 1) / (total_rows - 1). Диапазон от 0 до 1.
- `CUME_DIST` = count(rows <= current) / total_rows. Диапазон от 1/N до 1.

### Шаг 6.2. PERCENTILE_CONT — медиана и квартили

```sql
SELECT
    m.mine_name,
    COUNT(*) AS samples_count,
    ROUND(AVG(fq.fe_content), 2) AS avg_fe,
    ROUND(PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY fq.fe_content)::NUMERIC, 2) AS q1,
    ROUND(PERCENTILE_CONT(0.50) WITHIN GROUP (ORDER BY fq.fe_content)::NUMERIC, 2) AS median,
    ROUND(PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY fq.fe_content)::NUMERIC, 2) AS q3,
    ROUND(PERCENTILE_DISC(0.90) WITHIN GROUP (ORDER BY fq.fe_content)::NUMERIC, 2) AS p90
FROM fact_ore_quality fq
JOIN dim_mine m ON m.mine_id = fq.mine_id
WHERE fq.date_id BETWEEN 20240101 AND 20240630
GROUP BY m.mine_id, m.mine_name;
```

**Что наблюдаем:** PERCENTILE_CONT выполняет линейную интерполяцию, PERCENTILE_DISC возвращает фактическое значение из набора.

### Шаг 6.3. Аналог в DAX — PERCENTILE.INC

```dax
// Медиана и квартили содержания Fe по шахтам
EVALUATE
ADDCOLUMNS(
    VALUES(dim_mine[mine_name]),
    "SamplesCount",
        CALCULATE(COUNTROWS(fact_ore_quality),
            fact_ore_quality[date_id] >= 20240101,
            fact_ore_quality[date_id] <= 20240630),
    "AvgFe",
        CALCULATE(AVERAGE(fact_ore_quality[fe_content]),
            fact_ore_quality[date_id] >= 20240101,
            fact_ore_quality[date_id] <= 20240630),
    "Median",
        CALCULATE(MEDIAN(fact_ore_quality[fe_content]),
            fact_ore_quality[date_id] >= 20240101,
            fact_ore_quality[date_id] <= 20240630),
    "Q1",
        CALCULATE(
            PERCENTILE.INC(fact_ore_quality[fe_content], 0.25),
            fact_ore_quality[date_id] >= 20240101,
            fact_ore_quality[date_id] <= 20240630),
    "Q3",
        CALCULATE(
            PERCENTILE.INC(fact_ore_quality[fe_content], 0.75),
            fact_ore_quality[date_id] >= 20240101,
            fact_ore_quality[date_id] <= 20240630)
)
```

---

## Часть 7. Именованные окна (WINDOW)

### Шаг 7.1. Несколько именованных окон

```sql
SELECT
    d.full_date,
    SUM(fp.tons_mined) AS daily_tons,
    AVG(SUM(fp.tons_mined)) OVER w7   AS avg_7d,
    MIN(SUM(fp.tons_mined)) OVER w7   AS min_7d,
    MAX(SUM(fp.tons_mined)) OVER w7   AS max_7d,
    AVG(SUM(fp.tons_mined)) OVER w30  AS avg_30d,
    SUM(SUM(fp.tons_mined)) OVER w_cum AS running_total
FROM fact_production fp
JOIN dim_date d ON d.date_id = fp.date_id
WHERE fp.mine_id = 1 AND d.year = 2024 AND d.quarter = 1
GROUP BY d.full_date
WINDOW
    w7    AS (ORDER BY d.full_date ROWS BETWEEN 6 PRECEDING AND CURRENT ROW),
    w30   AS (ORDER BY d.full_date ROWS BETWEEN 29 PRECEDING AND CURRENT ROW),
    w_cum AS (ORDER BY d.full_date)
ORDER BY d.full_date;
```

**Что наблюдаем:** конструкция `WINDOW` позволяет определить именованные окна и использовать их многократно. Код становится чище и легче поддерживается.

### Шаг 7.2. Наследование окон

```sql
-- Базовое окно с PARTITION BY + ORDER BY,
-- конкретные функции добавляют свою рамку
SELECT
    d.full_date,
    e.equipment_name,
    SUM(fp.tons_mined) AS daily_tons,
    SUM(SUM(fp.tons_mined)) OVER (
        base_w ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS running_total,
    AVG(SUM(fp.tons_mined)) OVER (
        base_w ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
    ) AS avg_7d
FROM fact_production fp
JOIN dim_date d ON d.date_id = fp.date_id
JOIN dim_equipment e ON e.equipment_id = fp.equipment_id
WHERE fp.mine_id = 1 AND d.year = 2024 AND d.month = 1
GROUP BY d.full_date, fp.equipment_id, e.equipment_name
WINDOW base_w AS (
    PARTITION BY fp.equipment_id
    ORDER BY d.full_date
)
ORDER BY fp.equipment_id, d.full_date;
```

**Что наблюдаем:** Дочерние окна наследуют PARTITION BY и ORDER BY от базового, но могут определить свою спецификацию рамки.

> **Обсуждение:** В DAX нет прямого аналога WINDOW. Какие приёмы в DAX помогают избежать дублирования кода? (Ответ: переменные VAR, вспомогательные меры.)

---

## Часть 8. Комплексный пример — нарастающий итог и скользящие средние для производственного дашборда

### Шаг 8.1. OEE-дашборд с оконными функциями

```sql
WITH daily_stats AS (
    SELECT
        d.full_date,
        fp.equipment_id,
        e.equipment_name,
        SUM(fp.operating_hours) AS work_hours,
        SUM(fp.tons_mined) AS tons,
        SUM(fp.fuel_consumed_l) AS fuel
    FROM fact_production fp
    JOIN dim_date d ON d.date_id = fp.date_id
    JOIN dim_equipment e ON e.equipment_id = fp.equipment_id
    WHERE d.year = 2024 AND d.month = 1 AND fp.mine_id = 1
    GROUP BY d.full_date, fp.equipment_id, e.equipment_name
)
SELECT
    full_date,
    equipment_name,
    tons,
    -- Ранг по дню
    RANK() OVER (
        PARTITION BY full_date ORDER BY tons DESC
    ) AS daily_rank,
    -- Скользящая производительность 7 дней
    ROUND(AVG(tons / NULLIF(work_hours, 0)) OVER (
        PARTITION BY equipment_id
        ORDER BY full_date
        ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
    ), 2) AS avg_productivity_7d,
    -- Сравнение с предыдущим днём
    LAG(tons) OVER (
        PARTITION BY equipment_id ORDER BY full_date
    ) AS prev_day_tons,
    CASE
        WHEN tons > LAG(tons) OVER (
            PARTITION BY equipment_id ORDER BY full_date
        ) THEN 'рост'
        WHEN tons < LAG(tons) OVER (
            PARTITION BY equipment_id ORDER BY full_date
        ) THEN 'снижение'
        ELSE 'без изменений'
    END AS trend,
    -- Нарастающий итог
    SUM(tons) OVER (
        PARTITION BY equipment_id ORDER BY full_date
    ) AS cumulative_tons
FROM daily_stats
ORDER BY full_date, daily_rank;
```

**Что наблюдаем:** Один запрос сочетает ранжирование, смещение, скользящее среднее и нарастающий итог — полноценная аналитика для дашборда.

---

## Контрольные вопросы

1. В чём разница между `OVER()`, `OVER(PARTITION BY ...)` и `OVER(ORDER BY ...)`?
2. Чем ROWS BETWEEN отличается от RANGE BETWEEN?
3. Почему LAST_VALUE часто возвращает «неправильный» результат без явной рамки?
4. Когда использовать ROW_NUMBER, а когда RANK/DENSE_RANK?
5. Как реализовать скользящее среднее в DAX?
6. Что такое именованные окна и зачем нужно наследование окон?

---

## Итоги практической работы

По результатам практики вы должны уметь:

1. Использовать OVER(), PARTITION BY и ORDER BY для вычисления оконных агрегатов
2. Задавать рамку окна через ROWS BETWEEN и RANGE BETWEEN
3. Вычислять нарастающие итоги и скользящие средние
4. Применять функции ранжирования (ROW_NUMBER, RANK, DENSE_RANK, NTILE)
5. Работать с функциями смещения (LAG, LEAD, FIRST_VALUE, LAST_VALUE)
6. Использовать статистические функции (PERCENT_RANK, CUME_DIST, PERCENTILE_CONT)
7. Определять именованные окна через WINDOW
8. Реализовывать аналогичную функциональность в DAX
