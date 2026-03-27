# Практическая работа №1: Подключение к БД и первые SQL-запросы

**Модуль 1** — Введение в язык SQL и СУБД PostgreSQL
**Продолжительность:** 15–20 минут
**Формат:** выполняется под руководством преподавателя

---

## Цели практической работы

- Подключиться к Yandex Managed Service for PostgreSQL
- Ознакомиться со структурой аналитической базы данных «Руда+»
- Выполнить первые SQL-запросы к справочным таблицам

---

## Предварительные требования

- Установленный SQL-клиент: **DBeaver**, **DataGrip** или **psql** (командная строка)
- Параметры подключения к кластеру (выдаются преподавателем)

---

## Шаг 1. Подключение к базе данных

### Параметры подключения

| Параметр         | Значение                                      |
|------------------|-----------------------------------------------|
| Хост (Host)      | `<выдаётся преподавателем>`                   |
| Порт (Port)      | `6432`                                        |
| База данных (DB) | `ruda_plus`                                   |
| Пользователь     | `student`                                     |
| Пароль           | `<выдаётся преподавателем>`                   |
| SSL              | `require`                                     |

### Подключение через DBeaver

1. Откройте DBeaver.
2. Нажмите **Файл → Новое подключение** (или значок розетки в панели инструментов).
3. Выберите **PostgreSQL** и нажмите **Далее**.
4. Заполните поля:
   - **Host:** вставьте хост кластера
   - **Port:** `6432`
   - **Database:** `ruda_plus`
   - **Username:** `student`
   - **Password:** вставьте пароль
5. Перейдите на вкладку **SSL** и поставьте галочку **Использовать SSL**.
6. Нажмите **Тест соединения** — убедитесь, что подключение успешно.
7. Нажмите **Готово**.

### Подключение через psql (командная строка)

```bash
psql "host=<хост> port=6432 dbname=ruda_plus user=student sslmode=require"
```

При запросе введите пароль.

---

## Шаг 2. Обзор структуры базы данных

После подключения выполните запросы для изучения структуры БД.

### 2.1. Список таблиц

```sql
-- Показать все таблицы в схеме public
SELECT table_name, table_type
FROM information_schema.tables
WHERE table_schema = 'public'
ORDER BY table_name;
```

**Ожидаемый результат:** 17 таблиц (13 измерений `dim_*` + 4 факт-таблицы `fact_*`).

### 2.2. Структура конкретной таблицы

```sql
-- Посмотреть столбцы таблицы dim_mine
SELECT column_name, data_type, is_nullable, column_default
FROM information_schema.columns
WHERE table_name = 'dim_mine'
ORDER BY ordinal_position;
```

### 2.3. Комментарии к таблицам (документация в БД)

```sql
-- Комментарии к таблицам
SELECT
    c.relname AS table_name,
    pg_catalog.obj_description(c.oid) AS description
FROM pg_catalog.pg_class c
JOIN pg_catalog.pg_namespace n ON n.oid = c.relnamespace
WHERE n.nspname = 'public'
  AND c.relkind = 'r'
  AND pg_catalog.obj_description(c.oid) IS NOT NULL
ORDER BY c.relname;
```

---

## Шаг 3. Знакомство с данными измерений

### 3.1. Шахты предприятия

```sql
SELECT mine_id, mine_name, mine_code, region, city, max_depth_m, status
FROM dim_mine
ORDER BY mine_id;
```

**Вопрос преподавателя:** Сколько шахт в системе? В каких регионах они расположены?

### 3.2. Типы оборудования

```sql
SELECT type_name, type_code, max_payload_tons, engine_power_kw, fuel_type
FROM dim_equipment_type
ORDER BY equipment_type_id;
```

### 3.3. Оборудование с типами и шахтами

```sql
SELECT
    e.equipment_name,
    e.inventory_number,
    et.type_name AS equipment_type,
    m.mine_name,
    e.manufacturer,
    e.model,
    e.year_manufactured,
    e.status
FROM dim_equipment e
JOIN dim_equipment_type et ON e.equipment_type_id = et.equipment_type_id
JOIN dim_mine m ON e.mine_id = m.mine_id
ORDER BY et.type_name, e.equipment_name;
```

**Вопрос преподавателя:** Какие производители оборудования представлены? Какое оборудование имеет видеорегистраторы?

### 3.4. Сводка по количеству оборудования

```sql
SELECT
    m.mine_name,
    et.type_name,
    COUNT(*) AS equipment_count
FROM dim_equipment e
JOIN dim_mine m ON e.mine_id = m.mine_id
JOIN dim_equipment_type et ON e.equipment_type_id = et.equipment_type_id
GROUP BY m.mine_name, et.type_name
ORDER BY m.mine_name, et.type_name;
```

---

## Шаг 4. Знакомство с данными фактов

### 4.1. Объём данных в факт-таблицах

```sql
SELECT
    'fact_production' AS table_name, COUNT(*) AS row_count FROM fact_production
UNION ALL
SELECT
    'fact_equipment_telemetry', COUNT(*) FROM fact_equipment_telemetry
UNION ALL
SELECT
    'fact_equipment_downtime', COUNT(*) FROM fact_equipment_downtime
UNION ALL
SELECT
    'fact_ore_quality', COUNT(*) FROM fact_ore_quality
ORDER BY table_name;
```

### 4.2. Пример данных из таблицы добычи

```sql
SELECT
    fp.production_id,
    d.full_date,
    s.shift_name,
    m.mine_name,
    e.equipment_name,
    op.last_name || ' ' || op.first_name AS operator,
    fp.tons_mined,
    fp.trips_count,
    fp.operating_hours
FROM fact_production fp
JOIN dim_date d ON fp.date_id = d.date_id
JOIN dim_shift s ON fp.shift_id = s.shift_id
JOIN dim_mine m ON fp.mine_id = m.mine_id
JOIN dim_equipment e ON fp.equipment_id = e.equipment_id
JOIN dim_operator op ON fp.operator_id = op.operator_id
ORDER BY d.full_date DESC, s.shift_name
LIMIT 10;
```

---

## Шаг 5. Полезные приёмы в DBeaver

1. **Ctrl+Enter** — выполнить текущий запрос (где стоит курсор)
2. **Ctrl+Shift+Enter** — выполнить выделенный текст как запрос
3. **Ctrl+Space** — автодополнение имён таблиц и столбцов
4. **F4** на имени таблицы — открыть описание таблицы
5. **ER-диаграмма**: правый клик на схеме → «Показать ER-диаграмму»

---

## Контрольные вопросы

1. Сколько таблиц измерений и сколько факт-таблиц в базе данных «Руда+»?
2. Какие типы горного оборудования зарегистрированы в системе?
3. Какая максимальная глубина шахт предприятия?
4. Сколько операторов работает на каждой шахте?

---

## Результат практической работы

По завершении вы должны:
- Успешно подключиться к БД через SQL-клиент
- Понимать структуру таблиц измерений и фактов
- Уметь выполнять простые SELECT-запросы с JOIN и GROUP BY
- Ориентироваться в предметной области «Руда+»
