# Лабораторная работа — Модуль 8

## Проектирование стратегий оптимизированных индексов

**Продолжительность:** 60 минут
**Формат:** самостоятельная работа
**Инструменты:** PostgreSQL (Yandex Managed Service for PostgreSQL)
**База данных:** «Руда+» (MES-система горнодобывающего предприятия)

---

## Общие указания

- Для каждого задания необходимо:
  1. Выполнить `EXPLAIN (ANALYZE, BUFFERS)` **до** создания индекса
  2. Создать предложенный индекс
  3. Выполнить `EXPLAIN (ANALYZE, BUFFERS)` **после** создания индекса
  4. Зафиксировать разницу во времени выполнения и типе сканирования
- Сохраняйте все запросы и результаты в файл `lab_solutions.sql`
- Задания расположены по возрастанию сложности

---

## Задание 1. Анализ селективности (простое)

**Бизнес-задача:** Определить, для каких столбцов таблицы `fact_production` целесообразно создавать B-tree индексы.

**Требования:**

1. Напишите запрос, который для каждого столбца таблицы `fact_production` рассчитывает:
   - Количество уникальных значений (`n_distinct` из `pg_stats`)
   - Корреляцию с физическим порядком (`correlation`)
   - Долю NULL-значений (`null_frac`)

2. На основании результатов ответьте:
   - Какие столбцы имеют высокую селективность?
   - Для какого столбца BRIN-индекс был бы эффективнее B-tree? Почему?

**Подсказка:** Используйте представление `pg_stats` с фильтром `tablename = 'fact_production'`.

---

## Задание 2. Покрывающий индекс для отчёта по добыче (среднее)

**Бизнес-задача:** Начальник смены запрашивает ежедневную сводку по добыче конкретного оборудования.

**Запрос:**

```sql
SELECT date_id,
       SUM(tons_mined) AS total_tons,
       SUM(trips_count) AS total_trips,
       SUM(operating_hours) AS total_hours
FROM fact_production
WHERE equipment_id = 5
  AND date_id BETWEEN 20240101 AND 20240331
GROUP BY date_id
ORDER BY date_id;
```

**Требования:**

1. Выполните `EXPLAIN (ANALYZE, BUFFERS)` для запроса без дополнительного индекса
2. Создайте покрывающий индекс, который обеспечит **Index Only Scan**
3. Выполните `EXPLAIN (ANALYZE, BUFFERS)` повторно
4. Убедитесь, что `Heap Fetches = 0` (при необходимости выполните `VACUUM fact_production`)

**Ожидаемый результат:** Переход от Index Scan / Seq Scan к Index Only Scan.

---

## Задание 3. Частичный индекс для тревожных показаний (среднее)

**Бизнес-задача:** Диспетчер контролирует тревожные показания датчиков за текущую смену.

**Запрос:**

```sql
SELECT t.date_id, t.time_id,
       s.sensor_code,
       t.sensor_value,
       t.quality_flag
FROM fact_equipment_telemetry t
JOIN dim_sensor s ON s.sensor_id = t.sensor_id
WHERE t.equipment_id = 7
  AND t.is_alarm = TRUE
  AND t.date_id = 20240315
ORDER BY t.time_id DESC;
```

**Требования:**

1. Получите план выполнения до оптимизации
2. Создайте **частичный индекс** с условием `WHERE is_alarm = TRUE`
3. Получите план после создания индекса
4. Сравните размер частичного индекса с гипотетическим полным индексом на тех же столбцах

**Вопрос:** Почему частичный индекс особенно выгоден, если тревожных показаний всего 2-3%?

---

## Задание 4. Индекс на выражении (среднее)

**Бизнес-задача:** Аналитик ищет все простои длительностью более 4 часов.

**Запрос:**

```sql
SELECT fd.downtime_id, fd.date_id,
       e.equipment_name,
       dr.reason_name,
       fd.duration_min,
       ROUND(fd.duration_min / 60.0, 1) AS duration_hours
FROM fact_equipment_downtime fd
JOIN dim_equipment e ON e.equipment_id = fd.equipment_id
JOIN dim_downtime_reason dr ON dr.reason_id = fd.reason_id
WHERE fd.duration_min / 60.0 > 4
ORDER BY fd.duration_min DESC;
```

**Требования:**

1. Выполните EXPLAIN — убедитесь, что обычный индекс на `duration_min` **не используется** при фильтрации по выражению
2. Создайте индекс на выражении `(duration_min / 60.0)`
3. Повторите EXPLAIN и подтвердите использование индекса
4. Альтернативный подход: перепишите WHERE как `duration_min > 240`. Какой индекс используется теперь?

---

## Задание 5. Составной индекс: порядок столбцов (среднее)

**Бизнес-задача:** BI-аналитик строит отчёт по добыче: конкретная шахта, конкретный месяц, сортировка по сменам.

**Запрос:**

```sql
SELECT p.date_id, p.shift_id,
       SUM(p.tons_mined) AS total_tons,
       AVG(p.fuel_consumed_l) AS avg_fuel
FROM fact_production p
WHERE p.mine_id = 1
  AND p.date_id BETWEEN 20240201 AND 20240229
GROUP BY p.date_id, p.shift_id
ORDER BY p.date_id, p.shift_id;
```

**Требования:**

1. Создайте три варианта составного индекса с **разным порядком** столбцов:

```sql
-- Вариант A:
CREATE INDEX idx_test_a ON fact_production(mine_id, date_id, shift_id);
-- Вариант B:
CREATE INDEX idx_test_b ON fact_production(date_id, mine_id, shift_id);
-- Вариант C:
CREATE INDEX idx_test_c ON fact_production(shift_id, mine_id, date_id);
```

2. Для каждого варианта (отключив остальные через `DROP INDEX`) выполните `EXPLAIN (ANALYZE, BUFFERS)`
3. Заполните таблицу сравнения:

| Вариант | Тип сканирования | Execution Time (мс) | Shared Blocks |
|---------|-------------------|---------------------|---------------|
| A       |                   |                     |               |
| B       |                   |                     |               |
| C       |                   |                     |               |

4. Объясните, почему один вариант лучше остальных

**После выполнения:** удалите все три индекса.

---

## Задание 6. BRIN-индекс для телеметрии (среднее)

**Бизнес-задача:** Инженер по надёжности запрашивает показания телеметрии за конкретную дату.

**Запрос:**

```sql
SELECT t.time_id, t.sensor_id, t.sensor_value, t.is_alarm
FROM fact_equipment_telemetry t
WHERE t.date_id = 20240315;
```

**Требования:**

1. Проверьте корреляцию столбца `date_id`:

```sql
SELECT correlation
FROM pg_stats
WHERE tablename = 'fact_equipment_telemetry' AND attname = 'date_id';
```

2. Создайте BRIN-индекс:

```sql
CREATE INDEX idx_telemetry_date_brin
    ON fact_equipment_telemetry USING BRIN (date_id)
    WITH (pages_per_range = 64);
```

3. Создайте обычный B-tree индекс для сравнения:

```sql
CREATE INDEX idx_telemetry_date_btree
    ON fact_equipment_telemetry(date_id);
```

4. Сравните:
   - Размеры обоих индексов (`pg_relation_size`)
   - Планы выполнения запроса с каждым индексом
   - Время выполнения

5. Удалите оба индекса после сравнения.

**Вопрос:** В каком случае BRIN проигрывает B-tree?

---

## Задание 7. Мониторинг и очистка индексов (сложное)

**Бизнес-задача:** Администратор БД проводит аудит индексов перед плановым обслуживанием.

**Требования:**

1. Напишите запрос, который выводит для **каждой таблицы**:
   - Имя таблицы
   - Количество индексов
   - Суммарный размер индексов
   - Размер самой таблицы
   - Отношение размера индексов к размеру таблицы (в процентах)

2. Напишите запрос, который находит **дублирующиеся индексы** (индексы с одинаковым набором столбцов на одной таблице).

**Подсказка для дубликатов:**

```sql
SELECT
    a.indexrelid::regclass AS index1,
    b.indexrelid::regclass AS index2,
    a.indrelid::regclass AS table_name
FROM pg_index a
JOIN pg_index b ON a.indrelid = b.indrelid
    AND a.indexrelid < b.indexrelid
    AND a.indkey = b.indkey
WHERE a.indrelid::regclass::text NOT LIKE 'pg_%';
```

3. Найдите все индексы с `idx_scan = 0` и оцените, сколько дискового пространства можно освободить при их удалении.

---

## Задание 8. Комплексная оптимизация (сложное)

**Бизнес-задача:** MES-система формирует ежемесячный отчёт OEE (Overall Equipment Effectiveness) по каждой единице оборудования.

**Запрос:**

```sql
WITH production_data AS (
    SELECT
        p.equipment_id,
        SUM(p.operating_hours) AS total_operating_hours,
        SUM(p.tons_mined) AS total_tons
    FROM fact_production p
    WHERE p.date_id BETWEEN 20240301 AND 20240331
    GROUP BY p.equipment_id
),
downtime_data AS (
    SELECT
        fd.equipment_id,
        SUM(fd.duration_min) / 60.0 AS total_downtime_hours,
        SUM(CASE WHEN fd.is_planned = FALSE THEN fd.duration_min ELSE 0 END) / 60.0 AS unplanned_hours
    FROM fact_equipment_downtime fd
    WHERE fd.date_id BETWEEN 20240301 AND 20240331
    GROUP BY fd.equipment_id
)
SELECT
    e.equipment_name,
    et.type_name,
    COALESCE(pd.total_operating_hours, 0) AS operating_hours,
    COALESCE(dd.total_downtime_hours, 0) AS downtime_hours,
    COALESCE(dd.unplanned_hours, 0) AS unplanned_downtime,
    COALESCE(pd.total_tons, 0) AS tons_mined,
    CASE
        WHEN COALESCE(pd.total_operating_hours, 0) + COALESCE(dd.total_downtime_hours, 0) > 0
        THEN ROUND(
            COALESCE(pd.total_operating_hours, 0) /
            (COALESCE(pd.total_operating_hours, 0) + COALESCE(dd.total_downtime_hours, 0)) * 100, 1
        )
        ELSE 0
    END AS availability_pct
FROM dim_equipment e
JOIN dim_equipment_type et ON et.equipment_type_id = e.equipment_type_id
LEFT JOIN production_data pd ON pd.equipment_id = e.equipment_id
LEFT JOIN downtime_data dd ON dd.equipment_id = e.equipment_id
WHERE e.status = 'active'
ORDER BY availability_pct ASC;
```

**Требования:**

1. Выполните `EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)` и зафиксируйте полный план
2. Определите, какие узлы занимают больше всего времени
3. Предложите и создайте **минимальный набор индексов** (не более 3) для ускорения запроса
4. Повторите EXPLAIN и зафиксируйте улучшения
5. Заполните таблицу:

| Метрика | До оптимизации | После оптимизации |
|---------|---------------|-------------------|
| Execution Time (мс) | | |
| Тип скана fact_production | | |
| Тип скана fact_equipment_downtime | | |
| Shared Hit Blocks (суммарно) | | |

---

## Задание 9. CREATE INDEX CONCURRENTLY (практика администрирования)

**Бизнес-задача:** На продуктивной базе необходимо создать индекс без блокировки записи.

**Требования:**

1. Создайте индекс в обычном режиме и замерьте время:

```sql
\timing on
CREATE INDEX idx_telemetry_sensor_regular
    ON fact_equipment_telemetry(sensor_id, date_id);
\timing off
```

2. Удалите его и создайте с CONCURRENTLY:

```sql
DROP INDEX idx_telemetry_sensor_regular;

\timing on
CREATE INDEX CONCURRENTLY idx_telemetry_sensor_concurrent
    ON fact_equipment_telemetry(sensor_id, date_id);
\timing off
```

3. Сравните время создания.

4. Проверьте валидность индекса:

```sql
SELECT indexrelid::regclass, indisvalid
FROM pg_index
WHERE indexrelid = 'idx_telemetry_sensor_concurrent'::regclass;
```

5. Удалите индекс после проверки.

**Вопрос:** Почему CONCURRENTLY создаётся дольше? В каких ситуациях он может завершиться с невалидным индексом?

---

## Задание 10. Расширенная статистика (продвинутое)

**Бизнес-задача:** Планировщик ошибается в оценке строк для запроса с коррелированными столбцами.

**Требования:**

1. Выполните запрос и обратите внимание на разницу `rows` vs `actual rows`:

```sql
EXPLAIN ANALYZE
SELECT *
FROM fact_production
WHERE mine_id = 1
  AND shaft_id = 1
  AND date_id BETWEEN 20240101 AND 20240131;
```

2. Создайте расширенную статистику:

```sql
CREATE STATISTICS stat_prod_mine_shaft_date (dependencies)
    ON mine_id, shaft_id, date_id FROM fact_production;

ANALYZE fact_production;
```

3. Повторите EXPLAIN ANALYZE. Улучшилась ли оценка `rows`?

4. Просмотрите созданную статистику:

```sql
SELECT stxname, stxkeys, stxkind
FROM pg_statistic_ext
WHERE stxname = 'stat_prod_mine_shaft_date';
```

---

## Критерии оценки

| Задание | Баллы | Критерий |
|---------|-------|----------|
| 1 | 5 | Корректный запрос к pg_stats, обоснованные выводы |
| 2 | 10 | Покрывающий индекс, Index Only Scan, Heap Fetches = 0 |
| 3 | 10 | Частичный индекс, сравнение размеров |
| 4 | 10 | Индекс на выражении, альтернативный подход |
| 5 | 15 | Три варианта, заполненная таблица, объяснение |
| 6 | 10 | BRIN vs B-tree, сравнение размеров |
| 7 | 15 | Аудит индексов, поиск дубликатов |
| 8 | 15 | Комплексная оптимизация, не более 3 индексов |
| 9 | 5 | CONCURRENTLY, сравнение времени |
| 10 | 5 | Расширенная статистика, улучшение оценки |
| **Итого** | **100** | |
