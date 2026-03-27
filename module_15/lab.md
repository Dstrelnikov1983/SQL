# Лабораторная работа — Модуль 15

## Выполнение хранимых процедур

**Продолжительность:** 40 минут
**Формат:** самостоятельная работа
**Инструменты:** PostgreSQL (Yandex Managed Service for PostgreSQL)
**База данных:** «Руда+» (MES-система горнодобывающего предприятия)

---

## Общие указания

- Для каждого задания напишите SQL-код и сохраните его в файл `lab_solutions.sql`
- После создания каждой функции/процедуры протестируйте её вызовом
- Задания расположены по возрастанию сложности
- Не забывайте очищать тестовые объекты после завершения работы

---

## Задание 1. Скалярная функция — расчёт OEE (простое)

**Бизнес-задача:** Рассчитать показатель общей эффективности оборудования (OEE) по формуле: `OEE = (рабочие_часы / плановые_часы) * (фактическая_добыча / нормативная_добыча) * 100`.

**Требования:**

1. Создайте функцию `calc_oee(p_operating_hours NUMERIC, p_planned_hours NUMERIC, p_actual_tons NUMERIC, p_target_tons NUMERIC)` с возвратом `NUMERIC`
2. Функция должна:
   - Возвращать NULL, если плановые часы или нормативная добыча = 0
   - Округлять результат до 1 десятичного знака
   - Быть помечена как `IMMUTABLE`
3. Протестируйте на примерах:
   - `calc_oee(10, 12, 80, 100)` — ожидаемый результат ~66.7
   - `calc_oee(12, 12, 100, 100)` — ожидаемый результат 100.0
   - `calc_oee(8, 12, 0, 100)` — ожидаемый результат 0.0
4. Используйте функцию в запросе к `fact_production` для расчёта OEE по оборудованию

---

## Задание 2. Функция с условной логикой — классификация простоев (простое)

**Бизнес-задача:** Классифицировать простои по длительности для ежедневных отчётов.

**Требования:**

1. Создайте функцию `classify_downtime(p_duration_min INT)` с возвратом `VARCHAR`:
   - < 15 минут — «Микропростой»
   - 15-60 минут — «Краткий простой»
   - 61-240 минут — «Средний простой»
   - 241-480 минут — «Длительный простой»
   - > 480 минут — «Критический простой»
2. Примените функцию к `fact_equipment_downtime` за январь 2024
3. Подсчитайте количество простоев каждой категории и среднюю длительность
4. Выведите: категория, количество, средняя длительность, процент от общего числа

---

## Задание 3. Табличная функция — детальный отчёт по оборудованию (среднее)

**Бизнес-задача:** Создать параметризованный отчёт, который возвращает сводку по одной единице оборудования за период.

**Требования:**

1. Создайте функцию `get_equipment_summary(p_equipment_id INT, p_date_from INT, p_date_to INT)` с `RETURNS TABLE`:
   - `report_date DATE` — дата
   - `tons_mined NUMERIC` — добыча
   - `trips INT` — рейсы
   - `operating_hours NUMERIC` — рабочие часы
   - `fuel_liters NUMERIC` — расход топлива
   - `tons_per_hour NUMERIC` — производительность (тонн/час)
2. Пометьте как `STABLE`
3. Протестируйте вызов:
   - Для конкретного оборудования: `SELECT * FROM get_equipment_summary(1, 20240101, 20240131)`
   - В составе JOIN: `SELECT e.equipment_name, s.* FROM dim_equipment e CROSS JOIN LATERAL get_equipment_summary(e.equipment_id, 20240101, 20240131) s WHERE e.mine_id = 1`

---

## Задание 4. Функция с дефолтными параметрами — гибкий фильтр (среднее)

**Бизнес-задача:** Создать универсальный отчёт по добыче с необязательными фильтрами.

**Требования:**

1. Создайте функцию `get_production_filtered` с параметрами:
   - `p_date_from INT` — начало периода (обязательный)
   - `p_date_to INT` — конец периода (обязательный)
   - `p_mine_id INT DEFAULT NULL` — шахта (NULL = все)
   - `p_shift_id INT DEFAULT NULL` — смена (NULL = все)
   - `p_equipment_type_id INT DEFAULT NULL` — тип оборудования (NULL = все)
2. Возвращаемая таблица: mine_name, shift_name, equipment_type, total_tons, total_trips, equip_count
3. Протестируйте вызовы:
   - Все данные: `SELECT * FROM get_production_filtered(20240101, 20240131)`
   - Только шахта 1: `SELECT * FROM get_production_filtered(20240101, 20240131, p_mine_id := 1)`
   - Шахта 1, дневная смена: `SELECT * FROM get_production_filtered(20240101, 20240131, 1, 1)`

---

## Задание 5. Процедура с транзакциями — архивация данных (среднее)

**Бизнес-задача:** Создать процедуру для архивации старых данных телеметрии.

**Требования:**

1. Создайте таблицу-архив: `CREATE TABLE archive_telemetry (LIKE fact_equipment_telemetry INCLUDING ALL)`
2. Создайте процедуру `archive_old_telemetry(p_before_date_id INT, OUT p_archived INT, OUT p_deleted INT)`:
   - Шаг 1: Скопировать записи из `fact_equipment_telemetry` в `archive_telemetry`, где `date_id < p_before_date_id`
   - COMMIT после копирования
   - Шаг 2: Удалить скопированные записи из исходной таблицы
   - COMMIT после удаления
   - Вернуть количество скопированных и удалённых записей
3. Добавьте `RAISE NOTICE` для логирования каждого шага
4. Протестируйте: `CALL archive_old_telemetry(20240101, NULL, NULL)`
5. Проверьте данные в архивной таблице

**Важно:** Не забудьте очистить тестовые данные после проверки!

---

## Задание 6. Динамический SQL — универсальный счётчик (среднее)

**Бизнес-задача:** Создать функцию для быстрой проверки количества записей в любой таблице за период.

**Требования:**

1. Создайте функцию `count_fact_records(p_table_name TEXT, p_date_from INT, p_date_to INT)` с возвратом `BIGINT`:
   - Принимает имя таблицы фактов (fact_production, fact_equipment_downtime и т.д.)
   - Формирует динамический запрос через `EXECUTE format()`
   - Используйте `%I` для безопасной подстановки имени таблицы
   - Используйте `$1`, `$2` через `USING` для параметров дат
2. Добавьте проверку: таблица должна начинаться с `fact_` (иначе — `RAISE EXCEPTION`)
3. Протестируйте:
   - `SELECT count_fact_records('fact_production', 20240101, 20240131)`
   - `SELECT count_fact_records('fact_equipment_downtime', 20240101, 20240131)`
   - `SELECT count_fact_records('dim_mine', 20240101, 20240131)` — должна быть ошибка

---

## Задание 7. Динамический SQL — построитель отчётов (сложное)

**Бизнес-задача:** Создать универсальный генератор отчётов, который строит GROUP BY по указанному измерению.

**Требования:**

1. Создайте функцию `build_production_report(p_group_by TEXT, p_date_from INT, p_date_to INT, p_order_by TEXT DEFAULT 'total_tons DESC')`:
   - `p_group_by` — одно из: `'mine'`, `'shift'`, `'operator'`, `'equipment'`, `'equipment_type'`
   - Возвращает TABLE (dimension_name VARCHAR, total_tons NUMERIC, total_trips BIGINT, avg_productivity NUMERIC)
2. Используйте CASE для определения JOIN и поля группировки (НЕ подставляйте пользовательский ввод напрямую в SQL)
3. Поддержите сортировку через `p_order_by` (разрешённые значения: `'total_tons DESC'`, `'total_tons ASC'`, `'dimension_name ASC'`)
4. Протестируйте все варианты группировки
5. Убедитесь, что некорректный `p_group_by` вызывает `RAISE EXCEPTION`

**Подсказка:**

```sql
CASE p_group_by
    WHEN 'mine' THEN
        v_join := 'JOIN dim_mine d ON fp.mine_id = d.mine_id';
        v_field := 'd.mine_name';
    WHEN 'equipment' THEN
        v_join := 'JOIN dim_equipment d ON fp.equipment_id = d.equipment_id';
        v_field := 'd.equipment_name';
    -- ...
END CASE;

RETURN QUERY EXECUTE format(
    'SELECT %s::VARCHAR, ROUND(SUM(fp.tons_mined), 2), ... FROM fact_production fp %s WHERE ... GROUP BY 1 ORDER BY %s',
    v_field, v_join, v_order
) USING p_date_from, p_date_to;
```

---

## Задание 8. Комплексная процедура — ежедневная загрузка данных (сложное)

**Бизнес-задача:** Создать процедуру ETL для ежедневной загрузки и валидации производственных данных.

**Требования:**

1. Создайте staging-таблицу:

```sql
CREATE TABLE staging_daily_production (
    date_id INT,
    equipment_id INT,
    shift_id INT,
    operator_id INT,
    tons_mined NUMERIC,
    trips_count INT,
    operating_hours NUMERIC,
    fuel_consumed_l NUMERIC,
    loaded_at TIMESTAMP DEFAULT NOW()
);
```

2. Создайте процедуру `process_daily_production(p_date_id INT)` с OUT-параметрами `p_validated INT`, `p_rejected INT`, `p_loaded INT`:
   - **Шаг 1:** Проверка — есть ли данные в staging за указанную дату. Если нет — `RAISE EXCEPTION`
   - **Шаг 2:** Валидация — пометить записи с невалидными данными (tons_mined < 0, equipment_id не в dim_equipment, и т.д.). Используйте вспомогательную таблицу `staging_rejected` для отбракованных записей
   - COMMIT
   - **Шаг 3:** Удалить старые данные из `fact_production` за эту дату (upsert-логика)
   - **Шаг 4:** Вставить валидные записи из staging в `fact_production`
   - COMMIT
   - Вернуть количество валидных, отбракованных и загруженных записей
3. Добавьте `RAISE NOTICE` на каждом шаге
4. Протестируйте:
   - Вставьте тестовые данные в staging (корректные и некорректные)
   - Вызовите процедуру
   - Проверьте результаты в `fact_production` и `staging_rejected`

**Подсказка:** Структура процедуры:

```sql
CREATE OR REPLACE PROCEDURE process_daily_production(
    p_date_id INT,
    OUT p_validated INT,
    OUT p_rejected INT,
    OUT p_loaded INT
)
LANGUAGE plpgsql
AS $$
BEGIN
    -- Шаг 1: Проверка наличия данных
    IF NOT EXISTS (SELECT 1 FROM staging_daily_production WHERE date_id = p_date_id) THEN
        RAISE EXCEPTION 'Нет данных в staging за date_id = %', p_date_id;
    END IF;

    -- Шаг 2: Валидация
    INSERT INTO staging_rejected
    SELECT s.*, 'Невалидные данные' AS reject_reason
    FROM staging_daily_production s
    WHERE s.date_id = p_date_id
      AND (s.tons_mined < 0
           OR s.equipment_id NOT IN (SELECT equipment_id FROM dim_equipment)
           OR s.operator_id NOT IN (SELECT operator_id FROM dim_operator));
    GET DIAGNOSTICS p_rejected = ROW_COUNT;
    RAISE NOTICE 'Отбраковано: % записей', p_rejected;
    COMMIT;

    -- Шаг 3-4: Удаление + вставка
    DELETE FROM fact_production WHERE date_id = p_date_id;
    -- ...
    COMMIT;
END;
$$;
```

---

## Очистка тестовых объектов

После завершения лабораторной работы выполните:

```sql
-- Удаление функций
DROP FUNCTION IF EXISTS calc_oee(NUMERIC, NUMERIC, NUMERIC, NUMERIC);
DROP FUNCTION IF EXISTS classify_downtime(INT);
DROP FUNCTION IF EXISTS get_equipment_summary(INT, INT, INT);
DROP FUNCTION IF EXISTS get_production_filtered(INT, INT, INT, INT, INT);
DROP FUNCTION IF EXISTS count_fact_records(TEXT, INT, INT);
DROP FUNCTION IF EXISTS build_production_report(TEXT, INT, INT, TEXT);

-- Удаление процедур
DROP PROCEDURE IF EXISTS archive_old_telemetry(INT, INT, INT);
DROP PROCEDURE IF EXISTS process_daily_production(INT, INT, INT, INT);

-- Удаление тестовых таблиц
DROP TABLE IF EXISTS archive_telemetry;
DROP TABLE IF EXISTS staging_daily_production;
DROP TABLE IF EXISTS staging_rejected;
```

---

## Критерии оценки

| Задание | Баллы | Критерий |
|---------|-------|----------|
| 1 | 10 | Скалярная функция, IMMUTABLE, тесты |
| 2 | 10 | Условная логика, применение в запросе |
| 3 | 10 | RETURNS TABLE, STABLE, LATERAL вызов |
| 4 | 10 | DEFAULT параметры, именованные параметры |
| 5 | 15 | PROCEDURE, COMMIT, OUT-параметры |
| 6 | 15 | Динамический SQL, format(%I), валидация |
| 7 | 15 | Динамический SQL, CASE, сортировка |
| 8 | 15 | Комплексная ETL: валидация + транзакции |
| **Итого** | **100** | |
