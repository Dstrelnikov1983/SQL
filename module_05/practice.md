# Практическая работа — Модуль 5

## Использование DML для изменения данных

**Продолжительность:** 45 минут
**Инструменты:** Yandex Managed Service for PostgreSQL (SQL)
**Предприятие:** «Руда+» — добыча железной руды

---

## Предварительные требования

1. База данных «Руда+» развёрнута на PostgreSQL (скрипты `01_create_schema.sql`, `02_insert_dimensions.sql`, `03_insert_facts.sql` из каталога `common/scripts/`)
2. Выполнен скрипт `scripts/create_practice_tables.sql` из каталога модуля 5 — он создаст копии таблиц и staging-таблицы для безопасной практики
3. Клиент SQL (DBeaver, pgAdmin или psql) подключён к PostgreSQL

> **Важно:** Все операции в этой практической работе выполняются на **practice_** таблицах. Основные таблицы не затрагиваются.

---

## Часть 1. INSERT — Добавление данных

### Шаг 1.1. Вставка одной строки

**Бизнес-контекст:** На предприятие поступило новое оборудование. Нужно добавить его в справочник.

```sql
-- Добавить новую ПДМ в справочник оборудования
INSERT INTO practice_dim_equipment (
    equipment_id, equipment_type_id, mine_id,
    equipment_name, inventory_number,
    manufacturer, model, year_manufactured,
    commissioning_date, status,
    has_video_recorder, has_navigation
)
VALUES (
    100, 1, 1,
    'ПДМ-20 «Титан»', 'INV-LHD-020',
    'Atlas Copco', 'Scooptram ST18', 2025,
    '2025-03-01', 'active',
    TRUE, TRUE
);
```

**Проверка:**

```sql
SELECT equipment_id, equipment_name, inventory_number, status
FROM practice_dim_equipment
WHERE equipment_id = 100;
```

**Ожидаемый результат:**

| equipment_id | equipment_name | inventory_number | status |
|---|---|---|---|
| 100 | ПДМ-20 «Титан» | INV-LHD-020 | active |

### Шаг 1.2. Вставка нескольких строк

**Бизнес-контекст:** Добавить в справочник новые причины простоев, выявленные за последний квартал.

```sql
INSERT INTO practice_dim_downtime_reason (
    reason_id, reason_name, reason_code, category, description
)
VALUES
    (100, 'Замена конвейерной ленты',  'CONV_BELT',  'плановый',
     'Плановая замена изношенной конвейерной ленты'),
    (101, 'Обрыв тягового каната',     'ROPE_BREAK', 'внеплановый',
     'Аварийный обрыв тягового каната скипового подъёмника'),
    (102, 'Калибровка навигации',       'NAV_CALIB',  'плановый',
     'Плановая калибровка подземной навигационной системы');
```

**Проверка:**

```sql
SELECT reason_id, reason_name, reason_code, category
FROM practice_dim_downtime_reason
WHERE reason_id >= 100
ORDER BY reason_id;
```

**Что наблюдаем:** Три новых записи добавлены одним оператором INSERT.

### Шаг 1.3. INSERT ... SELECT — копирование из staging

**Бизнес-контекст:** Данные о добыче за смену загружены в staging-таблицу. Нужно перенести валидированные записи в основную таблицу.

```sql
-- Посмотрим, что в staging
SELECT staging_id, date_id, equipment_id, tons_mined, is_validated
FROM staging_production;
```

Обратите внимание: 4 записи с `is_validated = TRUE`, 1 запись с `FALSE`.

```sql
-- Перенести валидированные записи
INSERT INTO practice_fact_production (
    production_id, date_id, shift_id, mine_id, shaft_id,
    equipment_id, operator_id, location_id, ore_grade_id,
    tons_mined, tons_transported, trips_count,
    distance_km, fuel_consumed_l, operating_hours
)
SELECT
    1000 + staging_id,
    date_id, shift_id, mine_id, shaft_id,
    equipment_id, operator_id, location_id, ore_grade_id,
    tons_mined, tons_transported, trips_count,
    distance_km, fuel_consumed_l, operating_hours
FROM staging_production
WHERE is_validated = TRUE;
```

**Проверка:**

```sql
SELECT COUNT(*) AS total,
       COUNT(*) FILTER (WHERE production_id >= 1000) AS from_staging
FROM practice_fact_production;
```

### Шаг 1.4. INSERT ... RETURNING

**Бизнес-контекст:** Добавить нового оператора и сразу получить присвоенный идентификатор для записи в журнал.

```sql
INSERT INTO practice_dim_operator (
    operator_id, tab_number, last_name, first_name, middle_name,
    position, qualification, hire_date, mine_id
)
VALUES (
    100, 'TAB-042', 'Козлов', 'Андрей', 'Петрович',
    'Машинист ПДМ', '5 разряд', '2025-01-15', 1
)
RETURNING operator_id, tab_number,
          last_name || ' ' || first_name AS full_name;
```

**Что наблюдаем:** Оператор INSERT одновременно вставляет строку и возвращает результат без дополнительного SELECT.

---

## Часть 2. UPDATE — Изменение данных

### Шаг 2.1. Базовый UPDATE

**Бизнес-контекст:** ПДМ с ID=5 отправляется на плановое техобслуживание.

```sql
-- Сначала посмотрим текущий статус
SELECT equipment_id, equipment_name, status
FROM practice_dim_equipment
WHERE equipment_id = 5;

-- Обновляем статус
UPDATE practice_dim_equipment
SET status = 'maintenance'
WHERE equipment_id = 5;

-- Проверяем
SELECT equipment_id, equipment_name, status
FROM practice_dim_equipment
WHERE equipment_id = 5;
```

### Шаг 2.2. UPDATE нескольких столбцов

**Бизнес-контекст:** На 3 единицы оборудования установлены новые навигационные модули и видеорегистраторы.

```sql
UPDATE practice_dim_equipment
SET has_navigation = TRUE,
    has_video_recorder = TRUE
WHERE equipment_id IN (4, 5, 6);
```

**Проверка:**

```sql
SELECT equipment_id, equipment_name,
       has_navigation, has_video_recorder
FROM practice_dim_equipment
WHERE equipment_id IN (4, 5, 6);
```

### Шаг 2.3. UPDATE с подзапросом

**Бизнес-контекст:** Все единицы оборудования, у которых были внеплановые простои более 120 минут, нужно перевести на диагностику.

```sql
-- Сначала посмотрим, какое оборудование будет затронуто
SELECT DISTINCT e.equipment_id, e.equipment_name, e.status
FROM practice_dim_equipment e
JOIN practice_fact_downtime d ON e.equipment_id = d.equipment_id
WHERE d.is_planned = FALSE
  AND d.duration_min > 120;

-- Выполняем UPDATE
UPDATE practice_dim_equipment
SET status = 'maintenance'
WHERE equipment_id IN (
    SELECT DISTINCT d.equipment_id
    FROM practice_fact_downtime d
    WHERE d.is_planned = FALSE
      AND d.duration_min > 120
)
AND status = 'active';
```

### Шаг 2.4. UPDATE ... FROM (специфика PostgreSQL)

**Бизнес-контекст:** Из системы мониторинга пришли обновлённые статусы оборудования в staging-таблицу.

```sql
-- Смотрим, что в staging
SELECT inventory_number, new_status
FROM staging_equipment_status
WHERE new_status IS NOT NULL;

-- Обновляем оборудование из staging
UPDATE practice_dim_equipment e
SET status = s.new_status
FROM staging_equipment_status s
WHERE e.inventory_number = s.inventory_number
  AND s.new_status IS NOT NULL
  AND e.status IS DISTINCT FROM s.new_status;
```

> **Обратите внимание:** `IS DISTINCT FROM` вместо `!=` корректно обрабатывает NULL-значения.

### Шаг 2.5. UPDATE ... RETURNING

**Бизнес-контекст:** Вернуть все единицы оборудования из обслуживания в работу и получить список изменений.

```sql
UPDATE practice_dim_equipment
SET status = 'active'
WHERE status = 'maintenance'
RETURNING equipment_id, equipment_name,
          'maintenance → active' AS change_description;
```

**Что наблюдаем:** Получаем список всех единиц, вернувшихся в работу, одним запросом.

---

## Часть 3. DELETE — Удаление данных

### Шаг 3.1. Базовый DELETE

**Бизнес-контекст:** Удалить ошибочные записи телеметрии (с флагом ERROR).

```sql
-- Сначала посмотрим, сколько ошибочных записей
SELECT COUNT(*) AS error_count
FROM practice_fact_telemetry
WHERE quality_flag = 'ERROR';

-- Удаляем
DELETE FROM practice_fact_telemetry
WHERE quality_flag = 'ERROR';
```

### Шаг 3.2. DELETE с подзапросом

**Бизнес-контекст:** Удалить записи о добыче, ошибочно загруженные за выходные дни марта 2024.

```sql
-- Проверяем: есть ли записи за выходные?
SELECT fp.production_id, dd.full_date, dd.day_of_week_name
FROM practice_fact_production fp
JOIN dim_date dd ON fp.date_id = dd.date_id
WHERE dd.is_weekend = TRUE
  AND dd.year = 2024 AND dd.month = 3;

-- Удаляем
DELETE FROM practice_fact_production
WHERE date_id IN (
    SELECT date_id
    FROM dim_date
    WHERE is_weekend = TRUE
      AND year = 2024 AND month = 3
);
```

### Шаг 3.3. DELETE ... RETURNING + архивирование

**Бизнес-контекст:** Удалить устаревшую телеметрию, но сохранить её в архиве.

```sql
-- Архивирование через CTE
WITH deleted AS (
    DELETE FROM practice_fact_telemetry
    WHERE is_alarm = TRUE
    RETURNING *
)
INSERT INTO practice_archive_telemetry (
    telemetry_id, date_id, time_id, equipment_id,
    sensor_id, location_id, sensor_value,
    is_alarm, quality_flag, loaded_at
)
SELECT * FROM deleted;

-- Проверяем архив
SELECT * FROM practice_archive_telemetry;
```

**Что наблюдаем:** Данные удалены из основной таблицы и одновременно записаны в архив — всё в одной транзакции.

### Шаг 3.4. TRUNCATE vs DELETE

```sql
-- Сравнение скорости (на staging-таблице)
-- DELETE: проходит по каждой строке, вызывает триггеры
DELETE FROM staging_telemetry;

-- TRUNCATE: моментальная очистка, сброс счётчиков
TRUNCATE TABLE staging_telemetry RESTART IDENTITY;
```

> **Запомните:** TRUNCATE используется для полной очистки таблицы (например, staging после загрузки). DELETE — для выборочного удаления.

---

## Часть 4. MERGE и UPSERT

### Шаг 4.1. MERGE — синхронизация справочника (PostgreSQL 15+)

**Бизнес-контекст:** Из центрального офиса пришёл обновлённый справочник причин простоев. Нужно синхронизировать: обновить существующие, добавить новые.

```sql
-- Смотрим, что в staging
SELECT * FROM staging_downtime_reasons;

-- MERGE: синхронизация
MERGE INTO practice_dim_downtime_reason AS target
USING staging_downtime_reasons AS source
    ON target.reason_code = source.reason_code
WHEN MATCHED THEN
    UPDATE SET
        reason_name = source.reason_name,
        category    = source.category,
        description = source.description
WHEN NOT MATCHED THEN
    INSERT (reason_id, reason_name, reason_code, category, description)
    VALUES (
        (SELECT COALESCE(MAX(reason_id), 0) + 1
         FROM practice_dim_downtime_reason),
        source.reason_name, source.reason_code,
        source.category, source.description
    );

-- Проверяем результат
SELECT * FROM practice_dim_downtime_reason
ORDER BY reason_id;
```

### Шаг 4.2. INSERT ... ON CONFLICT DO NOTHING

**Бизнес-контекст:** Идемпотентная загрузка операторов — повторный запуск не создаёт дубликатов.

```sql
-- Первая вставка: оператор добавлен
INSERT INTO practice_dim_operator (
    operator_id, tab_number, last_name, first_name,
    position, qualification, hire_date, mine_id
)
VALUES (101, 'TAB-099', 'Новиков', 'Пётр',
        'Водитель самосвала', '4 разряд', '2025-02-01', 2)
ON CONFLICT (tab_number) DO NOTHING;

-- Повторная вставка: конфликт по tab_number, ничего не происходит
INSERT INTO practice_dim_operator (
    operator_id, tab_number, last_name, first_name,
    position, qualification, hire_date, mine_id
)
VALUES (102, 'TAB-099', 'Другой', 'Человек',
        'Другая должность', '1 разряд', '2025-03-01', 1)
ON CONFLICT (tab_number) DO NOTHING;

-- Проверяем: остался первый вариант
SELECT * FROM practice_dim_operator WHERE tab_number = 'TAB-099';
```

### Шаг 4.3. INSERT ... ON CONFLICT DO UPDATE

**Бизнес-контекст:** Обновить справочник сортов руды: если код уже существует — обновить параметры.

```sql
INSERT INTO practice_dim_ore_grade (
    ore_grade_id, grade_name, grade_code,
    fe_content_min, fe_content_max, description
)
VALUES
    (100, 'Премиум-2025', 'PREM', 66.00, 73.00,
     'Обновлённый стандарт качества 2025'),
    (200, 'Ультра',       'ULTR', 72.00, 80.00,
     'Руда ультравысокого качества')
ON CONFLICT (grade_code) DO UPDATE SET
    grade_name     = EXCLUDED.grade_name,
    fe_content_min = EXCLUDED.fe_content_min,
    fe_content_max = EXCLUDED.fe_content_max,
    description    = EXCLUDED.description;

-- Проверяем
SELECT * FROM practice_dim_ore_grade
WHERE grade_code IN ('PREM', 'ULTR');
```

---

## Часть 5. Транзакции

### Шаг 5.1. Безопасный UPDATE с транзакцией

```sql
BEGIN;

-- Обновляем статус
UPDATE practice_dim_equipment
SET status = 'decommissioned'
WHERE equipment_id = 1;

-- Проверяем внутри транзакции
SELECT equipment_id, equipment_name, status
FROM practice_dim_equipment
WHERE equipment_id = 1;

-- Решаем: это было ошибкой!
ROLLBACK;

-- Проверяем: данные вернулись
SELECT equipment_id, equipment_name, status
FROM practice_dim_equipment
WHERE equipment_id = 1;
```

**Что наблюдаем:** После ROLLBACK изменения отменены. Данные в безопасности.

---

## Итоги практической работы

По завершении вы научились:

1. **INSERT** — вставлять одну строку, несколько строк, копировать данные из SELECT, использовать RETURNING
2. **UPDATE** — обновлять данные с условиями, подзапросами, через FROM, получать результат через RETURNING
3. **DELETE** — удалять выборочно, архивировать через CTE + RETURNING, различать DELETE и TRUNCATE
4. **MERGE** — синхронизировать данные из staging-таблиц (PostgreSQL 15+)
5. **UPSERT** — использовать ON CONFLICT для идемпотентных загрузок
6. **Транзакции** — безопасно работать с DML через BEGIN / COMMIT / ROLLBACK
