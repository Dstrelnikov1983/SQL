# Практическая работа — Модуль 9

## Колоночное хранение и оптимизация аналитических запросов

**Продолжительность:** 30 минут
**Инструменты:** Yandex Managed Service for PostgreSQL (SQL) | Power BI + DAX Studio (DAX)
**Предприятие:** «Руда+» — добыча железной руды

---

## Предварительные требования

1. База данных «Руда+» развёрнута на PostgreSQL (скрипты `01_create_schema.sql`, `02_insert_dimensions.sql`, `03_insert_facts.sql` из каталога `common/scripts/`)
2. Расширение Citus установлено (для колоночного хранения)
3. Модель данных импортирована в Power BI
4. DAX Studio установлен и подключён к модели Power BI
5. Клиент SQL (DBeaver, pgAdmin или psql) подключён к PostgreSQL

---

## Часть 1. Создание колоночной таблицы (Citus Columnar)

### Шаг 1.1. Проверка расширения Citus

```sql
-- Проверяем, установлено ли расширение
SELECT * FROM pg_extension WHERE extname = 'citus';

-- Если не установлено:
CREATE EXTENSION IF NOT EXISTS citus;
```

**Что наблюдаем:** расширение citus должно появиться в списке.

### Шаг 1.2. Создание колоночной таблицы телеметрии

```sql
-- Создаём колоночную копию таблицы телеметрии
CREATE TABLE fact_telemetry_columnar (
    telemetry_id    BIGINT,
    date_id         INTEGER,
    time_id         INTEGER,
    equipment_id    INTEGER,
    sensor_id       INTEGER,
    sensor_value    NUMERIC(12,4),
    quality_flag    VARCHAR(10),
    recorded_at     TIMESTAMP
) USING columnar;
```

**Что наблюдаем:** таблица создана с форматом хранения `columnar` вместо стандартного `heap`.

### Шаг 1.3. Загрузка данных

```sql
-- Копируем данные из строковой таблицы
INSERT INTO fact_telemetry_columnar
SELECT telemetry_id, date_id, time_id, equipment_id,
       sensor_id, sensor_value, quality_flag, recorded_at
FROM fact_equipment_telemetry;

-- Проверяем количество строк
SELECT COUNT(*) FROM fact_telemetry_columnar;
```

### Шаг 1.4. Сравнение размеров

```sql
-- Размер строковой таблицы
SELECT pg_size_pretty(pg_total_relation_size('fact_equipment_telemetry'))
    AS row_store_size;

-- Размер колоночной таблицы
SELECT pg_size_pretty(pg_total_relation_size('fact_telemetry_columnar'))
    AS column_store_size;
```

**Что наблюдаем:** колоночная таблица должна быть значительно меньше (в 3-7 раз) за счёт сжатия.

> **Обсуждение:** Почему разница в размере именно такая? Какие столбцы сжимаются лучше всего?

---

## Часть 2. BRIN-индексы

### Шаг 2.1. Создание BRIN-индекса

```sql
-- Создаём BRIN-индекс по date_id на строковой таблице
CREATE INDEX idx_telemetry_date_brin
    ON fact_equipment_telemetry
    USING brin (date_id)
    WITH (pages_per_range = 32);
```

### Шаг 2.2. Сравнение размеров индексов

```sql
-- Создаём обычный B-tree индекс для сравнения
CREATE INDEX idx_telemetry_date_btree
    ON fact_equipment_telemetry (date_id);

-- Сравниваем размеры
SELECT indexname,
       pg_size_pretty(pg_relation_size(indexname::regclass)) AS index_size
FROM pg_indexes
WHERE tablename = 'fact_equipment_telemetry'
  AND indexname LIKE 'idx_telemetry_date%'
ORDER BY pg_relation_size(indexname::regclass);
```

**Что наблюдаем:** BRIN-индекс занимает на порядки меньше места, чем B-tree.

### Шаг 2.3. Анализ плана выполнения

```sql
-- Запрос с использованием BRIN-индекса
EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
SELECT equipment_id,
       AVG(sensor_value) AS avg_value,
       COUNT(*) AS readings_count
FROM fact_equipment_telemetry
WHERE date_id BETWEEN 20240101 AND 20240131
GROUP BY equipment_id;
```

**Что наблюдаем:** в плане выполнения должен быть `Bitmap Heap Scan` с `Bitmap Index Scan` по BRIN-индексу. Обратите внимание на количество прочитанных буферов (`Buffers: shared hit=...`).

### Шаг 2.4. Сравнение производительности

```sql
-- Принудительно отключаем BRIN, чтобы использовался Seq Scan
SET enable_bitmapscan = off;

EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
SELECT equipment_id,
       AVG(sensor_value) AS avg_value,
       COUNT(*) AS readings_count
FROM fact_equipment_telemetry
WHERE date_id BETWEEN 20240101 AND 20240131
GROUP BY equipment_id;

-- Возвращаем настройку
SET enable_bitmapscan = on;
```

**Что наблюдаем:** без BRIN-индекса PostgreSQL делает полное сканирование таблицы (Seq Scan). Сравните `actual time` обоих запросов.

---

## Часть 3. Секционирование таблиц

### Шаг 3.1. Создание секционированной таблицы

```sql
-- Создаём секционированную таблицу телеметрии
CREATE TABLE fact_telemetry_partitioned (
    telemetry_id    BIGINT,
    date_id         INTEGER NOT NULL,
    time_id         INTEGER,
    equipment_id    INTEGER,
    sensor_id       INTEGER,
    sensor_value    NUMERIC(12,4),
    quality_flag    VARCHAR(10),
    recorded_at     TIMESTAMP
) PARTITION BY RANGE (date_id);

-- Создаём секции по месяцам
CREATE TABLE fact_telemetry_p2024_01
    PARTITION OF fact_telemetry_partitioned
    FOR VALUES FROM (20240101) TO (20240201);

CREATE TABLE fact_telemetry_p2024_02
    PARTITION OF fact_telemetry_partitioned
    FOR VALUES FROM (20240201) TO (20240301);

CREATE TABLE fact_telemetry_p2024_03
    PARTITION OF fact_telemetry_partitioned
    FOR VALUES FROM (20240301) TO (20240401);

CREATE TABLE fact_telemetry_p2024_04
    PARTITION OF fact_telemetry_partitioned
    FOR VALUES FROM (20240401) TO (20240501);

CREATE TABLE fact_telemetry_p2024_05
    PARTITION OF fact_telemetry_partitioned
    FOR VALUES FROM (20240501) TO (20240601);

CREATE TABLE fact_telemetry_p2024_06
    PARTITION OF fact_telemetry_partitioned
    FOR VALUES FROM (20240601) TO (20240701);
```

### Шаг 3.2. Загрузка данных в секции

```sql
-- Данные автоматически распределяются по секциям
INSERT INTO fact_telemetry_partitioned
SELECT telemetry_id, date_id, time_id, equipment_id,
       sensor_id, sensor_value, quality_flag, recorded_at
FROM fact_equipment_telemetry;

-- Проверяем распределение данных по секциям
SELECT tableoid::regclass AS partition_name,
       COUNT(*) AS row_count
FROM fact_telemetry_partitioned
GROUP BY tableoid
ORDER BY partition_name;
```

### Шаг 3.3. Демонстрация partition pruning

```sql
-- Запрос за январь — должна сканироваться только одна секция
EXPLAIN (ANALYZE, COSTS OFF)
SELECT equipment_id, AVG(sensor_value)
FROM fact_telemetry_partitioned
WHERE date_id BETWEEN 20240115 AND 20240120
GROUP BY equipment_id;
```

**Что наблюдаем:** в плане выполнения видим `Append` с единственной дочерней операцией — сканирование `fact_telemetry_p2024_01`. Остальные секции отсечены (partition pruning).

---

## Часть 4. Анализ VertiPaq в DAX Studio

### Шаг 4.1. Открытие VertiPaq Analyzer

1. Откройте DAX Studio, подключитесь к модели Power BI «Руда+»
2. Меню **Advanced** → **VertiPaq Analyzer** → **Run**
3. Дождитесь загрузки статистики модели

### Шаг 4.2. Анализ таблицы телеметрии

Найдите таблицу `fact_equipment_telemetry` в результатах VertiPaq Analyzer.

**Зафиксируйте:**
- Общий размер таблицы в памяти (Total Size)
- Количество строк (Rows)
- Какой столбец занимает больше всего места?
- Какой столбец имеет наименьшую кардинальность?

### Шаг 4.3. Сравнение размеров в SQL и DAX

```dax
// Размер модели данных в DAX Studio
// Вкладка Tables — суммарный размер всех таблиц

// Запрос для проверки количества строк
EVALUATE
ROW(
    "Строк телеметрии", COUNTROWS(fact_equipment_telemetry),
    "Строк production", COUNTROWS(fact_production),
    "Строк quality", COUNTROWS(fact_ore_quality)
)
```

> **Обсуждение:** Сравните размер данных в PostgreSQL (на диске) и в Power BI (в памяти VertiPaq). Почему размер в VertiPaq значительно меньше?

---

## Часть 5. Удаление временных объектов

```sql
-- Удаляем созданные объекты (необязательно, если работаете в учебной среде)
DROP TABLE IF EXISTS fact_telemetry_columnar;
DROP TABLE IF EXISTS fact_telemetry_partitioned;
DROP INDEX IF EXISTS idx_telemetry_date_brin;
DROP INDEX IF EXISTS idx_telemetry_date_btree;
```

---

## Итоги практической работы

По результатам практики вы должны уметь:

1. Создавать таблицы с колоночным хранением (Citus Columnar)
2. Создавать и использовать BRIN-индексы для аналитических запросов
3. Настраивать секционирование таблиц (PARTITION BY RANGE)
4. Читать планы выполнения (EXPLAIN ANALYZE) и определять использование индексов
5. Использовать VertiPaq Analyzer в DAX Studio для анализа модели данных
