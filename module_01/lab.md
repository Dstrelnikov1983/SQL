# Лабораторная работа №1: Исследование базы данных «Руда+»

**Модуль 1** — Введение в язык SQL и СУБД PostgreSQL
**Продолжительность:** 20–30 минут
**Формат:** самостоятельная работа

---

## Цель

Самостоятельно исследовать структуру и данные аналитической базы данных «Руда+», закрепить навыки написания базовых SQL-запросов.

---

## Предварительные требования

- Выполнена практическая работа №1 (подключение к БД установлено)
- Открыт SQL-клиент с активным подключением к базе `ruda_plus`

---

## Задания

### Задание 1. Исследование справочника датчиков (простое)

Выведите список всех типов датчиков с указанием единицы измерения и допустимого диапазона значений.

**Требования:**
- Используйте таблицу `dim_sensor_type`
- Столбцы: название типа, код типа, единица измерения, мин. значение, макс. значение
- Отсортируйте по названию типа

**Ожидаемый результат:** 10 типов датчиков.

<details>
<summary>Подсказка</summary>

```sql
SELECT type_name, type_code, unit_of_measure, min_value, max_value
FROM dim_sensor_type
ORDER BY type_name;
```
</details>

---

### Задание 2. Операторы по шахтам (простое)

Выведите список всех активных операторов с указанием фамилии, имени, должности и названия шахты, к которой они прикреплены.

**Требования:**
- Используйте таблицы `dim_operator` и `dim_mine`
- Фильтр: только активные операторы (`status = 'active'`)
- Отсортируйте по названию шахты, затем по фамилии

**Ожидаемый результат:** 10 операторов.

<details>
<summary>Подсказка</summary>

```sql
SELECT
    o.last_name,
    o.first_name,
    o.position,
    o.qualification,
    m.mine_name
FROM dim_operator o
JOIN dim_mine m ON o.mine_id = m.mine_id
WHERE o.status = 'active'
ORDER BY m.mine_name, o.last_name;
```
</details>

---

### Задание 3. Датчики на оборудовании (среднее)

Для каждой единицы оборудования подсчитайте количество установленных датчиков. Выведите название оборудования, тип оборудования и количество датчиков.

**Требования:**
- Используйте таблицы `dim_sensor`, `dim_equipment`, `dim_equipment_type`
- Выведите только оборудование, у которого есть хотя бы 1 датчик
- Отсортируйте по количеству датчиков (от большего к меньшему)

**Ожидаемый результат:** несколько строк; у самосвалов — больше всего датчиков.

<details>
<summary>Подсказка</summary>

```sql
SELECT
    e.equipment_name,
    et.type_name,
    COUNT(s.sensor_id) AS sensor_count
FROM dim_equipment e
JOIN dim_equipment_type et ON e.equipment_type_id = et.equipment_type_id
JOIN dim_sensor s ON s.equipment_id = e.equipment_id
GROUP BY e.equipment_name, et.type_name
ORDER BY sensor_count DESC;
```
</details>

---

### Задание 4. Подземные локации по шахтам (среднее)

Выведите иерархию: шахта → ствол/горизонт → локации. Для каждой локации укажите тип и отметку уровня.

**Требования:**
- Используйте таблицы `dim_mine`, `dim_shaft`, `dim_location`
- Столбцы: название шахты, название ствола, тип ствола, название локации, тип локации, уровень (м)
- Отсортируйте по шахте, затем по стволу, затем по уровню

<details>
<summary>Подсказка</summary>

```sql
SELECT
    m.mine_name,
    sh.shaft_name,
    sh.shaft_type,
    loc.location_name,
    loc.location_type,
    loc.level_m
FROM dim_mine m
JOIN dim_shaft sh ON m.mine_id = sh.mine_id
JOIN dim_location loc ON sh.shaft_id = loc.shaft_id
ORDER BY m.mine_name, sh.shaft_name, loc.level_m;
```
</details>

---

### Задание 5. Причины простоев по категориям (среднее)

Подсчитайте количество причин простоев в каждой категории (плановый, внеплановый, организационный).

**Требования:**
- Используйте таблицу `dim_downtime_reason`
- Группировка по столбцу `category`
- Выведите категорию и количество причин

**Ожидаемый результат:** 3 строки (по одной на каждую категорию).

<details>
<summary>Подсказка</summary>

```sql
SELECT
    category,
    COUNT(*) AS reason_count
FROM dim_downtime_reason
GROUP BY category
ORDER BY category;
```
</details>

---

### Задание 6. Оборудование с видеорегистраторами и навигацией (сложное)

Выведите список оборудования, которое оснащено **одновременно** видеорегистратором и подключением к навигационной системе. Укажите тип оборудования, шахту, производителя и модель.

Дополнительно: подсчитайте общее количество такого оборудования и процент от всего парка.

**Требования:**
- Основной запрос: фильтр по `has_video_recorder = TRUE AND has_navigation = TRUE`
- Дополнительный запрос: используйте подзапрос или CTE для расчёта процента

<details>
<summary>Подсказка</summary>

```sql
-- Основной запрос
SELECT
    e.equipment_name,
    et.type_name,
    m.mine_name,
    e.manufacturer,
    e.model
FROM dim_equipment e
JOIN dim_equipment_type et ON e.equipment_type_id = et.equipment_type_id
JOIN dim_mine m ON e.mine_id = m.mine_id
WHERE e.has_video_recorder = TRUE
  AND e.has_navigation = TRUE
ORDER BY et.type_name, e.equipment_name;

-- Процент от общего парка
SELECT
    COUNT(*) FILTER (WHERE has_video_recorder AND has_navigation) AS equipped_count,
    COUNT(*) AS total_count,
    ROUND(
        100.0 * COUNT(*) FILTER (WHERE has_video_recorder AND has_navigation)
        / COUNT(*), 1
    ) AS percent_equipped
FROM dim_equipment;
```
</details>

---

### Задание 7. Комплексный отчёт по метаданным БД (сложное)

Создайте запрос, который для каждой таблицы базы данных покажет:
- Название таблицы
- Количество столбцов
- Комментарий к таблице (если есть)

**Требования:**
- Используйте `information_schema.tables`, `information_schema.columns` и системный каталог `pg_catalog`
- Только таблицы из схемы `public`
- Отсортируйте по названию таблицы

<details>
<summary>Подсказка</summary>

```sql
SELECT
    t.table_name,
    COUNT(c.column_name) AS column_count,
    pg_catalog.obj_description(
        (SELECT oid FROM pg_catalog.pg_class WHERE relname = t.table_name),
        'pg_class'
    ) AS table_comment
FROM information_schema.tables t
JOIN information_schema.columns c
    ON t.table_name = c.table_name
   AND t.table_schema = c.table_schema
WHERE t.table_schema = 'public'
  AND t.table_type = 'BASE TABLE'
GROUP BY t.table_name
ORDER BY t.table_name;
```
</details>

---

## Критерии оценки

| Задание | Сложность  | Баллы |
|---------|-----------|-------|
| 1       | Простое    | 1     |
| 2       | Простое    | 1     |
| 3       | Среднее    | 2     |
| 4       | Среднее    | 2     |
| 5       | Среднее    | 2     |
| 6       | Сложное    | 3     |
| 7       | Сложное    | 3     |
| **Итого** |          | **14** |

- **12–14 баллов** — отлично
- **9–11 баллов** — хорошо
- **6–8 баллов** — удовлетворительно

---

## Дополнительное задание (для тех, кто закончил раньше)

Напишите запрос, который для каждого типа оборудования покажет:
- Средний возраст оборудования (в годах, от `year_manufactured` до текущего года)
- Самую старую и самую новую единицу (год выпуска)
- Количество единиц на обслуживании (`status = 'maintenance'`)

---

## Результат лабораторной работы

По завершении вы должны:
- Уверенно ориентироваться в структуре БД «Руда+»
- Уметь писать запросы с `SELECT`, `FROM`, `JOIN`, `WHERE`, `GROUP BY`, `ORDER BY`
- Понимать связи между таблицами измерений в схеме «снежинка»
- Использовать системные каталоги PostgreSQL для получения метаданных
