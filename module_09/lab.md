# Лабораторная работа — Модуль 9

## Колоночное хранение и оптимизация аналитических запросов

**Продолжительность:** 45 минут
**Формат:** самостоятельная работа
**Инструменты:** PostgreSQL (SQL) + DAX Studio (DAX)
**База данных:** «Руда+» (MES-система горнодобывающего предприятия)

---

## Общие указания

- Каждое задание содержит бизнес-задачу и технические требования.
- Сохраняйте все SQL-запросы в файл `lab_solutions.sql`.
- Фиксируйте результаты измерений (размеры таблиц, время выполнения) в комментариях.
- Для DAX-заданий сохраняйте запросы в файл `lab_solutions.dax`.
- Используйте `EXPLAIN (ANALYZE, BUFFERS)` для анализа планов выполнения.

---

## Задание 1. Колоночная таблица фактов добычи (Citus Columnar)

**Бизнес-задача:** Руководство «Руда+» хочет ускорить ежемесячные отчёты по добыче руды. Предложено перевести историческую таблицу добычи в колоночный формат.

**Требования:**

1. Создайте колоночную копию таблицы `fact_production` с именем `fact_production_columnar`:

```sql
CREATE TABLE fact_production_columnar (
    -- перечислите все столбцы из fact_production
) USING columnar;
```

2. Загрузите данные из `fact_production` в колоночную таблицу.

3. Сравните размеры строковой и колоночной таблиц:

```sql
SELECT 'row_store' AS storage,
       pg_size_pretty(pg_total_relation_size('fact_production')) AS size
UNION ALL
SELECT 'column_store',
       pg_size_pretty(pg_total_relation_size('fact_production_columnar'));
```

4. Запишите результат (коэффициент сжатия) в комментарии.

**Ожидаемый результат:** колоночная таблица должна быть в 3-7 раз меньше.

---

## Задание 2. BRIN-индекс для таблицы простоев

**Бизнес-задача:** Аналитик MES-системы часто запрашивает данные о простоях за определённый период. Таблица `fact_equipment_downtime` содержит записи, вставляемые хронологически.

**Требования:**

1. Создайте BRIN-индекс на столбце `date_id` таблицы `fact_equipment_downtime`:

```sql
CREATE INDEX idx_downtime_date_brin
    ON fact_equipment_downtime
    USING brin (date_id)
    WITH (pages_per_range = 32);
```

2. Создайте обычный B-tree индекс на том же столбце для сравнения:

```sql
CREATE INDEX idx_downtime_date_btree
    ON fact_equipment_downtime (date_id);
```

3. Сравните размеры обоих индексов.

4. Выполните запрос с фильтрацией по дате и сравните планы выполнения:

```sql
-- С BRIN
EXPLAIN (ANALYZE, BUFFERS)
SELECT d.equipment_id,
       r.reason_name,
       SUM(d.duration_minutes) AS total_downtime
FROM fact_equipment_downtime d
JOIN dim_downtime_reason r ON d.reason_id = r.reason_id
WHERE d.date_id BETWEEN 20240201 AND 20240228
GROUP BY d.equipment_id, r.reason_name
ORDER BY total_downtime DESC;
```

**Вопрос для размышления:** В каком случае BRIN-индекс на `fact_equipment_downtime` может оказаться неэффективным?

---

## Задание 3. Секционирование таблицы качества руды

**Бизнес-задача:** Таблица `fact_ore_quality` содержит результаты анализов проб руды по обеим шахтам. Геологи часто запрашивают данные по конкретной шахте. Предложено секционировать таблицу по шахтам (LIST).

**Требования:**

1. Создайте секционированную таблицу:

```sql
CREATE TABLE fact_ore_quality_partitioned (
    quality_id      BIGINT,
    date_id         INTEGER NOT NULL,
    mine_id         INTEGER NOT NULL,
    location_id     INTEGER,
    equipment_id    INTEGER,
    ore_grade_id    INTEGER,
    fe_content      NUMERIC(5,2),
    moisture_pct    NUMERIC(5,2),
    density         NUMERIC(6,3),
    sample_weight_kg NUMERIC(8,2),
    shift_id        INTEGER
) PARTITION BY LIST (mine_id);
```

2. Создайте секции для каждой шахты (mine_id = 1 и mine_id = 2).

3. Загрузите данные из `fact_ore_quality`.

4. Проверьте распределение данных:

```sql
SELECT tableoid::regclass AS partition_name,
       COUNT(*) AS row_count
FROM fact_ore_quality_partitioned
GROUP BY tableoid;
```

5. Выполните запрос только по шахте «Северная» и покажите с помощью `EXPLAIN`, что сканируется только одна секция.

---

## Задание 4. Комбинация секционирования и BRIN

**Бизнес-задача:** Для таблицы телеметрии необходимо обеспечить максимальную производительность аналитических запросов. Используйте комбинацию RANGE-секционирования по месяцам и BRIN-индексов внутри секций.

**Требования:**

1. Создайте секционированную таблицу `fact_telemetry_optimized` (PARTITION BY RANGE по date_id) с секциями за январь-июнь 2024.

2. Загрузите данные из `fact_equipment_telemetry`.

3. Создайте BRIN-индекс на `recorded_at` внутри каждой секции:

```sql
-- Пример для одной секции
CREATE INDEX idx_tel_opt_2024_01_brin
    ON fact_telemetry_opt_2024_01
    USING brin (recorded_at);
```

4. Выполните аналитический запрос и убедитесь, что используются и partition pruning, и BRIN:

```sql
EXPLAIN (ANALYZE, BUFFERS)
SELECT equipment_id,
       AVG(sensor_value) AS avg_value,
       MIN(sensor_value) AS min_value,
       MAX(sensor_value) AS max_value
FROM fact_telemetry_optimized
WHERE date_id BETWEEN 20240215 AND 20240315
GROUP BY equipment_id
ORDER BY avg_value DESC;
```

**Ожидаемый результат:** В плане выполнения должны быть видны: `Append` (partition pruning отсёк лишние секции) и `Bitmap Index Scan` по BRIN внутри нужных секций.

---

## Задание 5. Анализ VertiPaq в DAX Studio

**Бизнес-задача:** Дата-инженер должен оптимизировать модель Power BI для «Руда+». Необходимо проанализировать эффективность сжатия VertiPaq.

**Требования:**

1. Откройте DAX Studio и запустите VertiPaq Analyzer (Advanced → VertiPaq Analyzer).

2. Заполните таблицу по результатам анализа:

| Таблица | Строк | Размер в памяти | Самый «тяжёлый» столбец | Кардинальность самого тяжёлого столбца |
|---------|-------|-----------------|--------------------------|----------------------------------------|
| fact_equipment_telemetry | | | | |
| fact_production | | | | |
| fact_ore_quality | | | | |
| dim_equipment | | | | |

3. Выполните DAX-запрос для проверки:

```dax
EVALUATE
ADDCOLUMNS(
    {
        ("fact_equipment_telemetry", COUNTROWS(fact_equipment_telemetry)),
        ("fact_production", COUNTROWS(fact_production)),
        ("fact_ore_quality", COUNTROWS(fact_ore_quality)),
        ("dim_equipment", COUNTROWS(dim_equipment))
    },
    "Количество строк", [Value2]
)
```

4. **Вопрос:** Какие столбцы можно было бы удалить из модели для уменьшения размера? Какие столбцы стоит заменить на целочисленные ключи?

---

## Задание 6. Сравнение производительности запросов

**Бизнес-задача:** Сравните скорость выполнения аналитического запроса на разных типах хранения.

**Требования:**

1. Выполните один и тот же запрос на трёх таблицах и зафиксируйте время:

```sql
-- Запрос: средняя температура по оборудованию за Q1 2024

-- a) Строковая таблица (heap)
EXPLAIN (ANALYZE, BUFFERS, TIMING)
SELECT equipment_id,
       AVG(sensor_value) AS avg_temp
FROM fact_equipment_telemetry
WHERE date_id BETWEEN 20240101 AND 20240331
  AND sensor_id IN (SELECT sensor_id FROM dim_sensor WHERE sensor_type_id = 1)
GROUP BY equipment_id;

-- b) Колоночная таблица (Citus Columnar)
EXPLAIN (ANALYZE, BUFFERS, TIMING)
SELECT equipment_id,
       AVG(sensor_value) AS avg_temp
FROM fact_telemetry_columnar
WHERE date_id BETWEEN 20240101 AND 20240331
  AND sensor_id IN (SELECT sensor_id FROM dim_sensor WHERE sensor_type_id = 1)
GROUP BY equipment_id;

-- c) Секционированная + BRIN
EXPLAIN (ANALYZE, BUFFERS, TIMING)
SELECT equipment_id,
       AVG(sensor_value) AS avg_temp
FROM fact_telemetry_optimized
WHERE date_id BETWEEN 20240101 AND 20240331
  AND sensor_id IN (SELECT sensor_id FROM dim_sensor WHERE sensor_type_id = 1)
GROUP BY equipment_id;
```

2. Заполните таблицу результатов:

| Тип хранения | Время выполнения (мс) | Буферы прочитано | Размер таблицы |
|-------------|----------------------|------------------|----------------|
| Heap (row store) | | | |
| Citus Columnar | | | |
| Partitioned + BRIN | | | |

3. Сделайте выводы: какой вариант оптимален и почему?

---

## Задание 7. Проектирование стратегии хранения (кейс)

**Бизнес-задача:** Руководство «Руда+» планирует внедрить систему предиктивного обслуживания оборудования. Для этого необходимо хранить данные телеметрии за 3 года (ожидаемый объём — 150 млн записей). Аналитики будут выполнять запросы вида:

- Средние показатели датчиков по оборудованию за период
- Поиск аномальных значений за последнюю неделю
- Сравнение показателей текущего месяца с аналогичным периодом прошлого года
- Тренды деградации по конкретному узлу оборудования

**Требования:**

1. Напишите SQL-скрипт создания оптимальной структуры хранения для этих данных. Учтите:
   - Тип секционирования (RANGE, LIST, HASH или комбинация)
   - Тип хранения (heap, columnar или комбинация горячих/холодных данных)
   - Индексы (BRIN, B-tree — где какой)
   - Стратегию управления старыми данными (архивирование)

2. Обоснуйте свой выбор в комментариях SQL-скрипта.

3. Пример структуры:

```sql
-- Горячие данные (последние 3 месяца): heap + B-tree
-- Тёплые данные (3-12 месяцев): heap + BRIN
-- Холодные данные (> 1 года): columnar (сжатие, только чтение)
```

---

## Критерии оценки

| Задание | Баллы | Критерий |
|---------|-------|----------|
| 1. Колоночная таблица | 10 | Таблица создана, данные загружены, размеры сравнены |
| 2. BRIN-индекс | 15 | Индексы созданы, планы проанализированы, выводы сделаны |
| 3. Секционирование | 15 | Секции созданы, partition pruning подтверждён через EXPLAIN |
| 4. Комбинация | 15 | Оба механизма работают вместе, план выполнения корректный |
| 5. VertiPaq | 15 | Таблица заполнена, ответы на вопросы даны |
| 6. Сравнение | 15 | Замеры выполнены, таблица заполнена, выводы обоснованы |
| 7. Проектирование | 15 | Скрипт написан, решение обосновано, учтены все типы запросов |
| **Итого** | **100** | |
