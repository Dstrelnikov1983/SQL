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

**Ожидаемый результат:** две строки (Шахта «Северная» и Шахта «Южная») с суммарными показателями.

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
- [x] Успешно выполнены 5 DAX-запросов с результатами
