# Практическая работа 2: Подключение Power BI к PostgreSQL и первые DAX-запросы

## Цель работы

Научиться подключать Power BI Desktop к базе данных PostgreSQL, импортировать данные аналитической модели предприятия «Руда+» и выполнять первые DAX-запросы в DAX Studio.

## Время выполнения

20 минут (преподаватель демонстрирует, слушатели повторяют).

## Предварительные требования

- Установлен **Power BI Desktop** (бесплатная версия)
- Установлен **DAX Studio** (скачать с [daxstudio.org](https://daxstudio.org))
- Установлен драйвер **Npgsql** для PostgreSQL (если не установлен, Power BI предложит скачать автоматически)
- Доступ к серверу Yandex Managed Service for PostgreSQL с базой данных «Руда+»

## Часть 1: Подключение Power BI к PostgreSQL

### Шаг 1. Запуск Power BI Desktop

1. Откройте **Power BI Desktop**.
2. На стартовом экране закройте окно приветствия.

### Шаг 2. Подключение к PostgreSQL

1. На вкладке **Главная** (Home) нажмите **Получить данные** (Get Data).
2. В списке источников выберите **База данных** → **PostgreSQL**.
3. Нажмите **Подключить** (Connect).
4. В диалоговом окне укажите параметры:

   | Параметр | Значение |
   |----------|----------|
   | Сервер | `<адрес-кластера>.mdb.yandexcloud.net` |
   | Порт | `6432` |
   | База данных | `ruda_plus` |

5. Нажмите **ОК**.
6. Введите учётные данные:
   - **Пользователь:** `student`
   - **Пароль:** `<пароль, выданный преподавателем>`
7. Нажмите **Подключить**.

### Шаг 3. Выбор таблиц

В навигаторе раскройте схему и отметьте следующие таблицы:

**Измерения (Dimensions):**
- `dim_mine` — шахты
- `dim_shaft` — стволы и горизонты
- `dim_location` — подземные локации
- `dim_equipment` — оборудование
- `dim_equipment_type` — типы оборудования
- `dim_sensor` — датчики
- `dim_sensor_type` — типы датчиков
- `dim_operator` — операторы
- `dim_shift` — смены
- `dim_ore_grade` — сорта руды
- `dim_downtime_reason` — причины простоев
- `dim_date` — измерение даты
- `dim_time` — измерение времени

**Факт-таблицы:**
- `fact_production` — добыча руды
- `fact_equipment_downtime` — простои оборудования
- `fact_ore_quality` — качество руды
- `fact_equipment_telemetry` — телеметрия

### Шаг 4. Загрузка данных

1. Убедитесь, что выбран режим **Импорт** (Import) — это режим по умолчанию.
2. Нажмите **Загрузить** (Load).
3. Дождитесь окончания загрузки. В правом нижнем углу отображается индикатор прогресса.

> **Примечание:** Загрузка может занять 1–2 минуты в зависимости от объёма данных и скорости сети.

### Шаг 5. Проверка модели данных

1. Перейдите в представление **Модель** (Model View) — иконка с тремя связанными таблицами на левой панели.
2. Убедитесь, что Power BI автоматически создал связи между таблицами по внешним ключам.
3. Проверьте ключевые связи:

   | Факт-таблица | Связь | Измерение |
   |---|---|---|
   | `fact_production.mine_id` | → | `dim_mine.mine_id` |
   | `fact_production.equipment_id` | → | `dim_equipment.equipment_id` |
   | `fact_production.operator_id` | → | `dim_operator.operator_id` |
   | `fact_production.shift_id` | → | `dim_shift.shift_id` |
   | `fact_production.date_id` | → | `dim_date.date_id` |
   | `dim_equipment.equipment_type_id` | → | `dim_equipment_type.equipment_type_id` |
   | `dim_equipment.mine_id` | → | `dim_mine.mine_id` |
   | `dim_shaft.mine_id` | → | `dim_mine.mine_id` |

4. Если какая-то связь не создалась автоматически, создайте её вручную:
   - Перетащите поле из одной таблицы на соответствующее поле другой таблицы.

### Шаг 6. Сохранение файла

1. **Файл** → **Сохранить как**.
2. Сохраните файл под именем `RudaPlus_Module02.pbix`.

---

## Часть 2: Подключение DAX Studio

### Шаг 7. Запуск DAX Studio

1. Убедитесь, что файл `RudaPlus_Module02.pbix` открыт в Power BI Desktop.
2. Запустите **DAX Studio**.
3. В окне подключения выберите **PBI / SSDT Model** и в списке найдите ваш файл Power BI.
4. Нажмите **Connect**.

### Шаг 8. Знакомство с интерфейсом DAX Studio

Изучите основные области интерфейса:

| Область | Описание |
|---------|----------|
| **Редактор запросов** (центр) | Здесь пишем DAX-запросы |
| **Панель метаданных** (справа) | Список таблиц и столбцов модели |
| **Панель результатов** (внизу) | Результаты выполнения запроса |
| **Кнопка Run (F5)** | Выполнить запрос |

---

## Часть 3: Первые DAX-запросы

### Запрос 1: Просмотр содержимого таблицы

Введите в редакторе и нажмите **F5**:

```dax
EVALUATE
    dim_equipment_type
```

**Ожидаемый результат:** таблица с 4 строками (ПДМ, Самосвал, Вагонетка, Скиповой подъёмник) и всеми столбцами таблицы `dim_equipment_type`.

### Запрос 2: Фильтрация данных

```dax
EVALUATE
    FILTER(
        dim_equipment,
        dim_equipment[status] = "active"
            && dim_equipment[has_navigation] = TRUE
    )
```

**Ожидаемый результат:** список активного оборудования, подключённого к навигационной системе.

### Запрос 3: Агрегация — общая добыча по шахтам

```dax
EVALUATE
    SUMMARIZECOLUMNS(
        dim_mine[mine_name],
        "Добыча, т", SUM(fact_production[tons_mined]),
        "Перевезено, т", SUM(fact_production[tons_transported]),
        "Рейсов", SUM(fact_production[trips_count])
    )
ORDER BY [Добыча, т] DESC
```

**Ожидаемый результат:** две строки (Шахта "Северная" и Шахта "Южная") с суммарными показателями.

### Запрос 4: Добыча по шахтам и сменам

```dax
EVALUATE
    SUMMARIZECOLUMNS(
        dim_mine[mine_name],
        dim_shift[shift_name],
        "Добыча, т", SUM(fact_production[tons_mined]),
        "Средняя добыча, т", AVERAGE(fact_production[tons_mined])
    )
ORDER BY
    dim_mine[mine_name] ASC,
    [Добыча, т] DESC
```

**Ожидаемый результат:** 4 строки (2 шахты × 2 смены) с суммарной и средней добычей.

### Запрос 5: Использование DEFINE для локальных мер

```dax
DEFINE
    MEASURE fact_production[Эффективность перевозки] =
        DIVIDE(
            SUM(fact_production[tons_transported]),
            SUM(fact_production[tons_mined]),
            0
        )

EVALUATE
    SUMMARIZECOLUMNS(
        dim_mine[mine_name],
        "Добыто, т", SUM(fact_production[tons_mined]),
        "Перевезено, т", SUM(fact_production[tons_transported]),
        "Эффективность, %", [Эффективность перевозки] * 100
    )
```

**Ожидаемый результат:** таблица с процентом перевезённой руды от добытой для каждой шахты.

### Запрос 6: Использование DEFINE COLUMN — вычисляемый столбец в запросе

В DAX можно определить **временный вычисляемый столбец** прямо в запросе с помощью `DEFINE COLUMN`. Такой столбец существует **только на время выполнения запроса** и не сохраняется в модели.

```dax
DEFINE
    COLUMN dim_equipment[Полное_описание] =
        dim_equipment[equipment_name]
            & " (" & RELATED(dim_equipment_type[type_name]) & ")"

    COLUMN dim_equipment[Возраст_лет] =
        YEAR(TODAY()) - dim_equipment[year_manufactured]

EVALUATE
    SELECTCOLUMNS(
        FILTER(dim_equipment, dim_equipment[status] = "active"),
        "Оборудование", dim_equipment[Полное_описание],
        "Возраст, лет", dim_equipment[Возраст_лет],
        "Шахта", RELATED(dim_mine[mine_name])
    )
ORDER BY dim_equipment[Возраст_лет] DESC
```

**Ожидаемый результат:** список активного оборудования с описанием вида `ПДМ-7 (Погрузочно-доставочная машина)` и возрастом в годах.

> **Важно:** `DEFINE COLUMN` — это **не** то же самое, что вычисляемый столбец в модели Power BI:
>
> | | DEFINE COLUMN (запрос) | Calculated Column (модель) |
> |---|---|---|
> | **Хранение** | Только на время запроса | Физически в VertiPaq |
> | **Доступен в отчётах** | Нет | Да |
> | **Можно использовать в мерах** | Только в том же запросе | Да, в любых мерах |

**SQL-эквивалент — вычисляемое выражение в SELECT:**

```sql
SELECT
    e.equipment_name || ' (' || et.type_name || ')' AS "Оборудование",
    EXTRACT(YEAR FROM CURRENT_DATE) - e.year_manufactured AS "Возраст, лет",
    m.mine_name AS "Шахта"
FROM dim_equipment e
JOIN dim_equipment_type et ON e.equipment_type_id = et.equipment_type_id
JOIN dim_mine m ON e.mine_id = m.mine_id
WHERE e.status = 'active'
ORDER BY "Возраст, лет" DESC;
```

> **Сравните:** в SQL вычисляемое выражение пишется прямо в `SELECT` — это аналог `DEFINE COLUMN`, а не аналог постоянного вычисляемого столбца.

---

## Часть 4: CALCULATE и контекст вычислений

В этой части мы на практике увидим, как одна и та же мера возвращает разные значения в зависимости от контекста, и научимся управлять контекстом с помощью `CALCULATE`.

### Шаг 1. Создание базовой меры

Создадим в Power BI Desktop меру для общей добычи. В представлении **Данные** (Data View):

1. Выберите таблицу `fact_production`.
2. На вкладке **Моделирование** → **Новая мера** (New Measure).
3. Введите формулу:

```dax
Добыча_Итого = SUM(fact_production[tons_mined])
```

4. Нажмите **Enter**.

### Шаг 2. Наблюдаем работу контекста фильтра

Мера `Добыча_Итого` содержит только `SUM`, без указания фильтров. Но её значение **меняется** в зависимости от того, где она используется. Выполните последовательно три запроса в DAX Studio и сравните результаты:

**Запрос 6а: Мера без контекста (итого по всем данным)**

```dax
DEFINE
    MEASURE fact_production[Добыча_Итого] =
        SUM(fact_production[tons_mined])

EVALUATE
    ROW("Добыча всего, т", [Добыча_Итого])
```

**Ожидаемый результат:** одно число — сумма добычи по **всем** шахтам и сменам.

**Запрос 6б: Мера в контексте шахты**

```dax
DEFINE
    MEASURE fact_production[Добыча_Итого] =
        SUM(fact_production[tons_mined])

EVALUATE
    ADDCOLUMNS(
        VALUES(dim_mine[mine_name]),
        "Добыча, т", [Добыча_Итого]
    )
```

**Ожидаемый результат:** та же мера, но теперь она вычисляется **для каждой шахты отдельно** — контекст фильтра автоматически ограничивает данные.

**Запрос 6в: Мера в контексте шахты + смены**

```dax
DEFINE
    MEASURE fact_production[Добыча_Итого] =
        SUM(fact_production[tons_mined])

EVALUATE
    ADDCOLUMNS(
        CROSSJOIN(
            VALUES(dim_mine[mine_name]),
            VALUES(dim_shift[shift_name])
        ),
        "Добыча, т", [Добыча_Итого]
    )
ORDER BY dim_mine[mine_name], dim_shift[shift_name]
```

**Ожидаемый результат:** та же самая формула `SUM(fact_production[tons_mined])`, но теперь для каждой комбинации шахта + смена.

> **Ключевое наблюдение:** формула меры **не менялась**. Менялся только контекст, в котором она вычисляется. Это принципиальное отличие DAX от SQL, где для каждого среза нужно переписывать запрос с другим `GROUP BY`.

### Шаг 3. Управление контекстом с CALCULATE

Теперь научимся **переопределять** контекст с помощью `CALCULATE`.

**Запрос 7а: Фиксированный фильтр — добыча только по шахте «Северная»**

```dax
DEFINE
    MEASURE fact_production[Добыча_Итого] =
        SUM(fact_production[tons_mined])
    MEASURE fact_production[Добыча_Северная] =
        CALCULATE(
            [Добыча_Итого],
            dim_mine[mine_id] = 1  -- Шахта "Северная"
        )

EVALUATE
    ADDCOLUMNS(
        VALUES(dim_mine[mine_name]),
        "Добыча шахты, т", [Добыча_Итого],
        "Добыча Северной, т", [Добыча_Северная]
    )
```

**Ожидаемый результат:**

| mine_name | Добыча шахты, т | Добыча Северной, т |
|---|---|---|
| Шахта "Северная" | 549 106 | 549 106 |
| Шахта "Южная" | 317 303 | 549 106 |

> **Обратите внимание:** мера `Добыча_Северная` **всегда возвращает 549 106**, потому что `CALCULATE` заменяет текущий контекст шахты на фиксированный фильтр по шахте "Северная".

**Запрос 7б: Доля шахты от общей добычи (снятие фильтра через ALL)**

```dax
DEFINE
    MEASURE fact_production[Добыча_Итого] =
        SUM(fact_production[tons_mined])
    MEASURE fact_production[Добыча_Всего] =
        CALCULATE(
            [Добыча_Итого],
            ALL(dim_mine)
        )
    MEASURE fact_production[Доля_Шахты] =
        DIVIDE([Добыча_Итого], [Добыча_Всего]) * 100

EVALUATE
    ADDCOLUMNS(
        VALUES(dim_mine[mine_name]),
        "Добыча шахты, т", [Добыча_Итого],
        "Добыча всего, т", [Добыча_Всего],
        "Доля, %", [Доля_Шахты]
    )
```

**Ожидаемый результат:**

| mine_name | Добыча шахты, т | Добыча всего, т | Доля, % |
|---|---|---|---|
| Шахта "Северная" | 549 106 | 866 408 | 63.4% |
| Шахта "Южная" | 317 303 | 866 408 | 36.6% |

> **Обратите внимание:** `ALL(dim_mine)` **снимает** фильтр по шахте, поэтому `Добыча_Всего` одинакова для всех строк.

**Запрос 7в: Комбинация фильтров — добыча 1-й смены на каждой шахте**

```dax
DEFINE
    MEASURE fact_production[Добыча_Итого] =
        SUM(fact_production[tons_mined])
    MEASURE fact_production[Добыча_Смена1] =
        CALCULATE(
            [Добыча_Итого],
            dim_shift[shift_id] = 1
        )

EVALUATE
    ADDCOLUMNS(
        VALUES(dim_mine[mine_name]),
        "Добыча всех смен, т", [Добыча_Итого],
        "Добыча 1-й смены, т", [Добыча_Смена1]
    )
```

> **Обратите внимание:** контекст шахты **сохраняется** (он приходит от `VALUES`), а `CALCULATE` **добавляет** фильтр по смене, потому что это **другой столбец**.

### Шаг 4. KEEPFILTERS vs замена фильтра

**Запрос 8: Разница между заменой и пересечением фильтров**

```dax
DEFINE
    MEASURE fact_production[Добыча_Итого] =
        SUM(fact_production[tons_mined])

    -- Замена фильтра (по умолчанию)
    MEASURE fact_production[CALCULATE_Замена] =
        CALCULATE(
            [Добыча_Итого],
            dim_mine[mine_id] = 1  -- Шахта "Северная"
        )

    -- Пересечение фильтров (KEEPFILTERS)
    MEASURE fact_production[CALCULATE_Пересечение] =
        CALCULATE(
            [Добыча_Итого],
            KEEPFILTERS(dim_mine[mine_id] = 1  -- Шахта "Северная")
        )

EVALUATE
    ADDCOLUMNS(
        VALUES(dim_mine[mine_name]),
        "Добыча шахты, т", [Добыча_Итого],
        "Замена, т", [CALCULATE_Замена],
        "Пересечение, т", [CALCULATE_Пересечение]
    )
```

**Ожидаемый результат:**

| mine_name | Добыча шахты, т | Замена, т | Пересечение, т |
|---|---|---|---|
| Шахта "Северная" | 549 106 | 549 106 | 549 106 |
| Шахта "Южная" | 317 303 | 549 106 | *(пусто)* |

> **Ключевое различие:**
> - Без `KEEPFILTERS`: в строке «Южная» фильтр **заменяется** на «Северная» → 549 106.
> - С `KEEPFILTERS`: «Южная» AND «Северная» = пустое пересечение → пусто (BLANK).

### Шаг 5. SQL-эквивалент — как выглядит та же логика на SQL

Запустите в PostgreSQL (psql или pgAdmin) запросы, аналогичные DAX-мерам:

**SQL-эквивалент запроса 7б (доля шахты):**

```sql
SELECT
    m.mine_name                              AS "Шахта",
    SUM(fp.tons_mined)                       AS "Добыча шахты, т",
    SUM(SUM(fp.tons_mined)) OVER ()          AS "Добыча всего, т",
    ROUND(
        SUM(fp.tons_mined) * 100.0
        / SUM(SUM(fp.tons_mined)) OVER (), 1
    )                                        AS "Доля, %"
FROM fact_production fp
JOIN dim_mine m ON fp.mine_id = m.mine_id
GROUP BY m.mine_name;
```

**SQL-эквивалент запроса 7в (добыча 1-й смены с сохранением контекста шахты):**

```sql
SELECT
    m.mine_name,
    SUM(fp.tons_mined)                                       AS "Добыча всех смен, т",
    SUM(fp.tons_mined) FILTER (WHERE s.shift_id = 1)     AS "Добыча 1-й смены, т"
FROM fact_production fp
JOIN dim_mine m  ON fp.mine_id = m.mine_id
JOIN dim_shift s ON fp.shift_id = s.shift_id
GROUP BY m.mine_name;
```

> **Сравните:**
> - В DAX логика фильтрации **вынесена в меру** — один раз определил, везде переиспользуешь.
> - В SQL каждый срез нужно явно прописывать в запросе (`WHERE`, `FILTER`, оконная функция).

---

### Шаг 6. Мера vs выражение внутри итератора

Этот шаг показывает важный нюанс: **мера** автоматически выполняет переход контекста (context transition), а **выражение** — нет.

**Запрос 9а: Мера внутри MAXX — корректный результат**

```dax
DEFINE
    MEASURE fact_production[Добыча_Итого] =
        SUM(fact_production[tons_mined])

EVALUATE
    ADDCOLUMNS(
        VALUES(dim_mine[mine_name]),
        "Макс. суточная добыча, т",
            MAXX(
                VALUES(dim_date[full_date]),
                [Добыча_Итого]  -- мера: автоматический context transition
            )
    )
```

**Запрос 9б: Выражение БЕЗ CALCULATE — некорректный результат**

```dax
EVALUATE
    ADDCOLUMNS(
        VALUES(dim_mine[mine_name]),
        "Макс. суточная добыча, т",
            MAXX(
                VALUES(dim_date[full_date]),
                SUM(fact_production[tons_mined])  -- НЕ мера! context transition НЕ происходит
            )
    )
```

**Запрос 9в: Выражение С CALCULATE — корректный результат**

```dax
EVALUATE
    ADDCOLUMNS(
        VALUES(dim_mine[mine_name]),
        "Макс. суточная добыча, т",
            MAXX(
                VALUES(dim_date[full_date]),
                CALCULATE(SUM(fact_production[tons_mined]))  -- явный context transition
            )
    )
```

> **Сравните результаты трёх запросов:**
>
> | Запрос | Шахта "Северная" | Шахта "Южная" | Почему |
> |---|---|---|---|
> | 9а (мера) | 1 430 т | 846 т | Мера → автоматический переход контекста → SUM по каждой дате |
> | 9б (SUM без CALCULATE) | **866 408 т** | **866 408 т** | SUM игнорирует контекст строки → суммирует **все** даты по **всем** шахтам |
> | 9в (CALCULATE + SUM) | 1 430 т | 846 т | Явный переход контекста → SUM по каждой дате |
>
> **Вывод:** запрос 9б возвращает **общую добычу**, а не максимум за день, потому что `SUM` внутри итератора без `CALCULATE` не «видит» текущую дату. Используйте **меры** внутри итераторов — это безопаснее.

---

### Контрольные вопросы по CALCULATE и контексту

1. Что произойдёт, если мера `SUM(fact_production[tons_mined])` используется в строке матрицы с фильтром по шахте? Какой контекст применяется?
2. Чем отличается поведение `CALCULATE` от простого `SUM` при наличии внешнего фильтра?
3. Почему `CALCULATE` с фильтром по тому же столбцу **заменяет**, а не дополняет существующий фильтр?
4. В каких случаях нужен `KEEPFILTERS`?
5. Как на SQL реализовать аналог `ALL(dim_mine)` — снятие фильтра по одному измерению?

---

## Сравнение: SQL-эквивалент запроса 3

Для наглядности — тот же запрос на SQL (PostgreSQL):

```sql
SELECT
    m.mine_name        AS "Шахта",
    SUM(fp.tons_mined) AS "Добыча, т",
    SUM(fp.tons_transported) AS "Перевезено, т",
    SUM(fp.trips_count) AS "Рейсов"
FROM fact_production fp
JOIN dim_mine m ON fp.mine_id = m.mine_id
GROUP BY m.mine_name
ORDER BY "Добыча, т" DESC;
```

**Обратите внимание:**
- В SQL нужен явный `JOIN` для связи таблиц.
- В DAX связь уже определена в модели, поэтому `SUMMARIZECOLUMNS` автоматически использует relationship.

---

## Контрольные вопросы

1. Какой режим подключения к данным мы использовали (Import или DirectQuery)? Почему?
2. Какую роль выполняет оператор `EVALUATE` в DAX?
3. Чем функция `SUMMARIZECOLUMNS` в DAX похожа на `GROUP BY` в SQL?
4. Почему в DAX-запросе не нужен оператор JOIN?
5. Для чего используется блок `DEFINE` в DAX-запросе?

---

## Результат работы

По завершении практической работы у вас должно быть:

- [x] Файл `RudaPlus_Module02.pbix` с загруженными данными
- [x] Настроенные связи между таблицами в модели Power BI
- [x] DAX Studio подключён к модели Power BI
- [x] Успешно выполнены 5 DAX-запросов (часть 3) + запрос 6 с DEFINE COLUMN
- [x] Создана мера `Добыча_Итого` в Power BI
- [x] Выполнены запросы 6а–6в: наблюдение за изменением контекста
- [x] Выполнены запросы 7а–7в: управление контекстом через CALCULATE
- [x] Выполнен запрос 8: KEEPFILTERS vs замена фильтра
- [x] Выполнены SQL-эквиваленты для сравнения подходов
