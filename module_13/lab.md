# Лабораторная работа — Модуль 13

## Использование оконных функций

**Продолжительность:** 60 минут
**Формат:** самостоятельная работа
**Инструменты:** PostgreSQL (Yandex Managed Service for PostgreSQL)
**База данных:** «Руда+» (MES-система горнодобывающего предприятия)

---

## Общие указания

- Для каждого задания напишите SQL-запрос и сохраните его в файл `lab_solutions.sql`
- Задания расположены по возрастанию сложности
- Используйте именованные окна (WINDOW) там, где это уместно
- Проверяйте результаты на логическую корректность

---

## Задание 1. Доля оборудования в общей добыче (простое)

**Бизнес-задача:** Начальник смены хочет видеть, какую долю от суточной добычи обеспечивает каждая единица оборудования.

**Требования:**

1. Для даты `20240115`, смены 1, выведите:
   - Название оборудования
   - Тонны добычи
   - Общую сумму добычи за смену (через `SUM() OVER()`)
   - Процент от общей добычи (округлить до 1 десятичного)
2. Отсортируйте по убыванию добычи

**Ожидаемый результат:** таблица с 4 столбцами, где сумма процентов равна 100%.

<details>
<summary>Решение (DAX)</summary>

```dax
EVALUATE
ADDCOLUMNS (
    SUMMARIZE (
        FILTER (
            fact_production,
            fact_production[date_id] = 20240115
                && fact_production[shift_id] = 1
        ),
        dim_equipment[equipment_name]
    ),
    "tons", [tons_mined],
    "total_tons",
        CALCULATE (
            [tons_mined],
            ALLEXCEPT ( fact_production, fact_production[date_id], fact_production[shift_id] )
        ),
    "pct",
        DIVIDE (
            [tons_mined],
            CALCULATE (
                [tons_mined],
                ALLEXCEPT ( fact_production, fact_production[date_id], fact_production[shift_id] )
            )
        ) * 100
)
ORDER BY [tons_mined] DESC
```

> В DAX нет прямого аналога `SUM() OVER()`. Вместо этого используется `CALCULATE` с `ALLEXCEPT` для снятия фильтра по оборудованию, сохраняя фильтр по дате и смене.

</details>

---

## Задание 2. Нарастающий итог по шахтам (простое)

**Бизнес-задача:** Построить график нарастающей добычи за январь 2024 года с разбивкой по шахтам.

**Требования:**

1. Для каждой шахты за январь 2024 рассчитайте:
   - Дату
   - Суточную добычу
   - Нарастающий итог добычи с начала месяца (PARTITION BY mine_id, ORDER BY full_date)
2. Отсортируйте по шахте и дате

**Подсказка:** Используйте `SUM(SUM(...)) OVER (PARTITION BY ... ORDER BY ...)` с предварительным GROUP BY.

<details>
<summary>Решение (DAX)</summary>

```dax
EVALUATE
ADDCOLUMNS (
    CROSSJOIN (
        VALUES ( dim_mine[mine_name] ),
        FILTER (
            VALUES ( dim_date[full_date] ),
            YEAR ( dim_date[full_date] ) = 2024
                && MONTH ( dim_date[full_date] ) = 1
        )
    ),
    "daily_tons", [tons_mined],
    "running_total",
        CALCULATE (
            [tons_mined],
            FILTER (
                ALL ( dim_date ),
                dim_date[full_date] <= EARLIER ( dim_date[full_date] )
                    && YEAR ( dim_date[full_date] ) = 2024
                    && MONTH ( dim_date[full_date] ) = 1
            )
        )
)
ORDER BY [mine_name], [full_date]
```

> В DAX нарастающий итог реализуется через `CALCULATE` + `FILTER(ALL(dim_date), ...)` с условием `<= EARLIER(...)`, что аналогично `SUM() OVER (ORDER BY ...)` в SQL.

</details>

---

## Задание 3. Скользящее среднее расхода ГСМ (простое)

**Бизнес-задача:** Логист хочет отслеживать тренд суточного расхода топлива с помощью 7-дневного скользящего среднего.

**Требования:**

1. Для шахты 1 за I квартал 2024 рассчитайте:
   - Дату
   - Суточный расход топлива (fuel_consumed_l)
   - 7-дневное скользящее среднее (`ROWS BETWEEN 6 PRECEDING AND CURRENT ROW`)
   - 14-дневное скользящее среднее
2. Округлите средние до 2 знаков

**Вопрос:** Почему первые 6 значений скользящего среднего за 7 дней рассчитаны по меньшему количеству строк? Как это влияет на точность?

<details>
<summary>Решение (DAX)</summary>

```dax
EVALUATE
ADDCOLUMNS (
    FILTER (
        VALUES ( dim_date[full_date] ),
        YEAR ( dim_date[full_date] ) = 2024
            && dim_date[quarter] = 1
            && RELATED ( dim_mine[mine_id] ) = 1
    ),
    "daily_fuel", [fuel_consumed_l],
    "ma_7",
        AVERAGEX (
            FILTER (
                ALL ( dim_date ),
                dim_date[full_date] >= EARLIER ( dim_date[full_date] ) - 6
                    && dim_date[full_date] <= EARLIER ( dim_date[full_date] )
            ),
            [fuel_consumed_l]
        ),
    "ma_14",
        AVERAGEX (
            FILTER (
                ALL ( dim_date ),
                dim_date[full_date] >= EARLIER ( dim_date[full_date] ) - 13
                    && dim_date[full_date] <= EARLIER ( dim_date[full_date] )
            ),
            [fuel_consumed_l]
        )
)
ORDER BY [full_date]
```

> Скользящее среднее в DAX реализуется через `AVERAGEX` с `FILTER(ALL(dim_date), ...)`, задавая окно через разницу дат. Аналог `ROWS BETWEEN 6 PRECEDING AND CURRENT ROW`.

</details>

---

## Задание 4. Рейтинг операторов по типам оборудования (среднее)

**Бизнес-задача:** HR-служба хочет ранжировать операторов по производительности внутри каждого типа оборудования для I полугодия 2024.

**Требования:**

1. Для каждого оператора рассчитайте:
   - ФИО оператора (фамилия + инициал)
   - Тип оборудования
   - Суммарную добычу за период
   - Ранг внутри типа оборудования (`RANK() OVER(PARTITION BY ... ORDER BY ...)`)
   - Плотный ранг (`DENSE_RANK`)
   - Квартиль (`NTILE(4)`)
2. Выведите только операторов с рангом (RANK) <= 5
3. Отсортируйте по типу оборудования и рангу

<details>
<summary>Решение (DAX)</summary>

```dax
EVALUATE
VAR OperatorStats =
    ADDCOLUMNS (
        SUMMARIZE (
            FILTER (
                fact_production,
                YEAR ( RELATED ( dim_date[full_date] ) ) = 2024
                    && MONTH ( RELATED ( dim_date[full_date] ) ) <= 6
            ),
            dim_operator[full_name],
            dim_equipment[type_name]
        ),
        "total_tons", [tons_mined]
    )
VAR Ranked =
    ADDCOLUMNS (
        OperatorStats,
        "rnk",
            RANKX (
                FILTER ( OperatorStats, [type_name] = EARLIER ( [type_name] ) ),
                [total_tons],
                ,
                DESC,
                Dense
            )
    )
RETURN
    FILTER ( Ranked, [rnk] <= 5 )
ORDER BY [type_name], [rnk]
```

> В DAX функция `RANKX` заменяет `RANK() OVER (PARTITION BY ...)`. Для эмуляции `PARTITION BY` используется `FILTER` по текущему значению группировки через `EARLIER`.

</details>

---

## Задание 5. Сравнение дневной и ночной смены (среднее)

**Бизнес-задача:** Проанализировать разницу в добыче между дневной и ночной сменами за январь 2024, шахта 1.

**Требования:**

1. Для каждой комбинации дата+смена рассчитайте:
   - Суммарную добычу за смену
   - Добычу предыдущей смены (`LAG`)
   - Процент смены от суточной добычи (`SUM OVER PARTITION BY full_date`)
   - 7-дневное скользящее среднее для каждой смены отдельно
2. Используйте именованные окна (`WINDOW`)
3. Отсортируйте по дате и смене

<details>
<summary>Решение (DAX)</summary>

```dax
EVALUATE
VAR ShiftData =
    ADDCOLUMNS (
        SUMMARIZE (
            FILTER (
                fact_production,
                RELATED ( dim_mine[mine_id] ) = 1
                    && YEAR ( RELATED ( dim_date[full_date] ) ) = 2024
                    && MONTH ( RELATED ( dim_date[full_date] ) ) = 1
            ),
            dim_date[full_date],
            dim_shift[shift_name],
            fact_production[shift_id]
        ),
        "shift_tons", [tons_mined],
        "pct_of_day",
            DIVIDE (
                [tons_mined],
                CALCULATE (
                    [tons_mined],
                    ALLEXCEPT ( fact_production, fact_production[date_id] )
                )
            ) * 100
    )
RETURN
    ShiftData
ORDER BY [full_date], [shift_id]
```

> В DAX нет прямого аналога `LAG()`. Для получения значения предыдущей строки можно использовать `OFFSET` (в новых версиях DAX) или вычислять через `CALCULATE` с фильтрацией по предыдущей дате/смене.

</details>

---

## Задание 6. Интервалы между внеплановыми простоями (среднее)

**Бизнес-задача:** Служба надёжности хочет проанализировать интервалы между поломками оборудования для планирования профилактики.

**Требования:**

1. Для каждого внепланового простоя (`is_planned = FALSE`) выведите:
   - Название оборудования
   - Дату простоя
   - Причину простоя
   - Длительность (минуты)
   - Дату предыдущего простоя этого же оборудования (`LAG`)
   - Количество дней между простоями
   - Дату следующего простоя (`LEAD`)
2. Рассчитайте среднее количество дней между поломками для каждого оборудования
3. Отсортируйте по оборудованию и дате

**Подсказка:**

```sql
LAG(d.full_date) OVER (
    PARTITION BY fd.equipment_id
    ORDER BY d.full_date
) AS prev_downtime_date
```

---

## Задание 7. Обнаружение выбросов по содержанию Fe методом IQR (среднее)

**Бизнес-задача:** Лаборатория хочет автоматически выявлять аномальные пробы качества руды.

**Требования:**

1. Для каждой шахты за I полугодие 2024 рассчитайте квартили содержания Fe:
   - Q1 = PERCENTILE_CONT(0.25)
   - Q3 = PERCENTILE_CONT(0.75)
   - IQR = Q3 - Q1
2. Пометьте пробы как выбросы, если:
   - `fe_content < Q1 - 1.5 * IQR` — «Выброс (низ)»
   - `fe_content > Q3 + 1.5 * IQR` — «Выброс (верх)»
3. Выведите только пробы-выбросы с расшифровкой (шахта, дата, номер пробы, содержание Fe, статус)
4. Подсчитайте общее количество выбросов по каждой шахте

---

## Задание 8. ТОП-3 рекордных дня для каждой единицы оборудования (среднее)

**Бизнес-задача:** Для доски почёта определить 3 лучших дня по добыче для каждой единицы оборудования за 2024 год.

**Требования:**

1. Используя `ROW_NUMBER() OVER (PARTITION BY equipment_id ORDER BY daily_tons DESC)`, пронумеруйте дни каждого оборудования по убыванию добычи
2. Отфильтруйте только первые 3 записи (rn <= 3)
3. Выведите: оборудование, тип, дату, добычу, номер рекорда
4. Добавьте столбец с разницей между рекордом #1 и текущей записью

**Подсказка:** Используйте CTE (WITH) для промежуточных вычислений.

<details>
<summary>Решение (DAX)</summary>

```dax
EVALUATE
VAR DailyByEquip =
    ADDCOLUMNS (
        SUMMARIZE (
            FILTER ( fact_production, YEAR ( RELATED ( dim_date[full_date] ) ) = 2024 ),
            dim_equipment[equipment_name],
            dim_equipment[type_name],
            dim_date[full_date]
        ),
        "daily_tons", [tons_mined]
    )
VAR Ranked =
    ADDCOLUMNS (
        DailyByEquip,
        "record_num",
            RANKX (
                FILTER ( DailyByEquip, [equipment_name] = EARLIER ( [equipment_name] ) ),
                [daily_tons],
                ,
                DESC
            )
    )
VAR Top3 = FILTER ( Ranked, [record_num] <= 3 )
RETURN
    ADDCOLUMNS (
        Top3,
        "diff_from_top1",
            MAXX (
                FILTER ( Top3, [equipment_name] = EARLIER ( [equipment_name] ) ),
                [daily_tons]
            ) - [daily_tons]
    )
ORDER BY [equipment_name], [record_num]
```

> `TOPN` в DAX выбирает top-N строк, а `RANKX` нумерует аналогично `ROW_NUMBER`. Для разницы с рекордом используется `MAXX` с фильтром по оборудованию.

</details>

---

## Задание 9. Парето-анализ причин простоев (сложное)

**Бизнес-задача:** Определить 80% причин простоев по принципу Парето для приоритизации мероприятий по повышению надёжности.

**Требования:**

1. За I полугодие 2024 для каждой причины простоя рассчитайте:
   - Общее время простоя (часы)
   - Процент от общего времени простоев
   - Нарастающий процент (кумулятивный)
   - Категория Парето: «A» (до 80%), «B» (80-95%), «C» (95-100%)
2. Используйте `SUM() OVER (ORDER BY ... DESC)` для нарастающего итога
3. Отсортируйте по убыванию времени простоя

**Ожидаемый результат:** Таблица, где видно, какие 20% причин вызывают 80% простоев.

<details>
<summary>Решение (DAX)</summary>

```dax
EVALUATE
VAR ReasonTotals =
    ADDCOLUMNS (
        SUMMARIZE (
            FILTER (
                fact_equipment_downtime,
                YEAR ( RELATED ( dim_date[full_date] ) ) = 2024
                    && MONTH ( RELATED ( dim_date[full_date] ) ) <= 6
            ),
            dim_downtime_reason[reason_name]
        ),
        "total_hours", SUM ( fact_equipment_downtime[duration_min] ) / 60,
        "pct",
            DIVIDE (
                SUM ( fact_equipment_downtime[duration_min] ),
                CALCULATE (
                    SUM ( fact_equipment_downtime[duration_min] ),
                    ALL ( dim_downtime_reason )
                )
            ) * 100
    )
VAR WithCumulative =
    ADDCOLUMNS (
        ReasonTotals,
        "cumulative_pct",
            SUMX (
                FILTER (
                    ReasonTotals,
                    [total_hours] >= EARLIER ( [total_hours] )
                ),
                [pct]
            )
    )
RETURN
    ADDCOLUMNS (
        WithCumulative,
        "pareto_category",
            SWITCH (
                TRUE (),
                [cumulative_pct] <= 80, "A",
                [cumulative_pct] <= 95, "B",
                "C"
            )
    )
ORDER BY [total_hours] DESC
```

> Парето-анализ в DAX: нарастающий процент вычисляется через `SUMX` + `FILTER` с условием `>= EARLIER(...)`, что аналогично `SUM() OVER (ORDER BY ... DESC)`.

</details>

---

## Задание 10. Дедупликация и обработка повторных записей (сложное)

**Бизнес-задача:** В таблице телеметрии могут быть дублирующиеся записи для одного датчика в одно и то же время. Необходимо оставить только последнюю запись.

**Требования:**

1. Используя `ROW_NUMBER() OVER (PARTITION BY sensor_id, date_id, time_id ORDER BY telemetry_id DESC)`, пронумеруйте записи
2. Оставьте только строки с rn = 1
3. Сравните количество строк до и после дедупликации
4. Оберните результат в CTE и выведите итоговую статистику:
   - Всего записей до дедупликации
   - Всего записей после дедупликации
   - Количество удалённых дубликатов
   - Процент дубликатов

---

## Задание 11. Предиктивное обслуживание: обнаружение аномалий в телеметрии (сложное)

**Бизнес-задача:** Для предотвращения аварий необходимо выявлять аномальные показания датчиков (температура двигателя, вибрация).

**Требования:**

1. Для оборудования с ID = 1 за первую неделю января 2024:
   - Рассчитайте скользящее среднее за 8 показаний (2 часа при 15-минутном интервале)
   - Рассчитайте скользящее стандартное отклонение (`STDDEV() OVER`)
   - Определите дельту (разницу с предыдущим показанием через `LAG`)
   - Рассчитайте `PERCENT_RANK` для каждого датчика
2. Присвойте уровень риска:
   - `pct_rank > 0.95` — «ОПАСНОСТЬ»
   - `pct_rank > 0.85` — «ВНИМАНИЕ»
   - иначе — «Норма»
3. Используйте именованные окна для сокращения дублирования
4. Выведите только записи с уровнем риска выше «Норма»

**Подсказка:**

```sql
WINDOW
    w8 AS (PARTITION BY ft.sensor_id
           ORDER BY ft.date_id, ft.time_id
           ROWS BETWEEN 7 PRECEDING AND CURRENT ROW),
    w_seq AS (PARTITION BY ft.sensor_id
              ORDER BY ft.date_id, ft.time_id)
```

---

## Задание 12. Комплексный производственный дашборд (сложное)

**Бизнес-задача:** Подготовить данные для ежедневного дашборда директора шахты, объединяющего все ключевые метрики с трендами.

**Требования:**

1. Для шахты 1 за январь 2024 постройте одним запросом:
   - Дату
   - Суточную добычу
   - Добычу предыдущего дня (`LAG`)
   - Изменение день-к-дню (%)
   - 7-дневное скользящее среднее добычи
   - Нарастающий итог добычи с начала месяца
   - Ранг дня по добыче за месяц (`RANK`)
   - NTILE(3) для категоризации: «Высокая», «Средняя», «Низкая» добыча
   - Медианное значение добычи за весь месяц (через оконную `PERCENTILE_CONT`)
   - Отклонение от медианы (%)
2. Используйте минимум 2 именованных окна
3. Добавьте текстовый столбец «trend»: «рост» / «снижение» / «стабильно» (если изменение < 5%)

**Подсказка:** Структура запроса:

```sql
WITH daily AS (
    SELECT d.full_date, SUM(fp.tons_mined) AS tons
    FROM fact_production fp
    JOIN dim_date d ON d.date_id = fp.date_id
    WHERE fp.mine_id = 1 AND d.year = 2024 AND d.month = 1
    GROUP BY d.full_date
)
SELECT
    full_date,
    tons,
    LAG(tons) OVER w_seq AS prev_day,
    -- ... остальные оконные функции
FROM daily
WINDOW
    w_seq AS (ORDER BY full_date),
    w7    AS (ORDER BY full_date ROWS BETWEEN 6 PRECEDING AND CURRENT ROW)
ORDER BY full_date;
```

---

## Критерии оценки

| Задание | Баллы | Критерий |
|---------|-------|----------|
| 1 | 5 | Корректный OVER(), процент от суммы |
| 2 | 5 | Нарастающий итог с PARTITION BY |
| 3 | 8 | Скользящее среднее, ROWS BETWEEN |
| 4 | 8 | RANK, DENSE_RANK, NTILE + фильтрация |
| 5 | 10 | LAG, процент от суточной добычи, WINDOW |
| 6 | 10 | LAG/LEAD для дат, интервалы |
| 7 | 10 | PERCENTILE_CONT, IQR-метод |
| 8 | 8 | ROW_NUMBER + TOP-N по группам |
| 9 | 10 | Нарастающий процент, категоризация |
| 10 | 8 | Дедупликация, статистика |
| 11 | 12 | Комплекс: STDDEV, PERCENT_RANK, WINDOW |
| 12 | 16 | Комплексный дашборд: 6+ оконных функций |
| **Итого** | **110** | Максимум 100 баллов (10 бонусных) |
