# Практическая работа — Модуль 8

## Проектирование стратегий оптимизированных индексов

**Продолжительность:** 45 минут
**Инструменты:** Yandex Managed Service for PostgreSQL (psql / DBeaver / pgAdmin)
**Предприятие:** «Руда+» — MES-система горнодобывающего предприятия

---

## Предварительные требования

1. База данных «Руда+» развёрнута на PostgreSQL (скрипты `01_create_schema.sql`, `02_insert_dimensions.sql`, `03_insert_facts.sql` из каталога `common/scripts/`)
2. Клиент SQL (DBeaver, pgAdmin или psql) подключён к PostgreSQL
3. Выполнен скрипт `examples.sql` из каталога `module_08/` для создания дополнительных тестовых данных

---

## Часть 1. Анализ существующих индексов

### Шаг 1.1. Просмотр всех индексов базы данных

Выполните запрос для получения списка всех индексов:

```sql
SELECT
    schemaname,
    tablename,
    indexname,
    pg_size_pretty(pg_relation_size(indexname::regclass)) AS index_size
FROM pg_indexes
WHERE schemaname = 'public'
ORDER BY tablename, indexname;
```

**Что наблюдаем:**
- Какие индексы были созданы автоматически (PK, UNIQUE)?
- Какие индексы были созданы явно в DDL-скрипте?
- Обратите внимание на соглашение об именовании: `idx_<таблица>_<столбец>`

### Шаг 1.2. Статистика использования индексов

```sql
SELECT
    schemaname || '.' || relname AS table_name,
    indexrelname AS index_name,
    idx_scan AS index_scans,
    idx_tup_read AS tuples_read,
    idx_tup_fetch AS tuples_fetched,
    pg_size_pretty(pg_relation_size(indexrelid)) AS index_size
FROM pg_stat_user_indexes
WHERE schemaname = 'public'
ORDER BY idx_scan DESC;
```

**Вопрос для размышления:** Есть ли индексы с `idx_scan = 0`? Почему они могут быть не использованы?

### Шаг 1.3. Размеры таблиц vs размеры индексов

```sql
SELECT
    relname AS table_name,
    pg_size_pretty(pg_total_relation_size(relid)) AS total_size,
    pg_size_pretty(pg_relation_size(relid)) AS table_size,
    pg_size_pretty(pg_total_relation_size(relid) - pg_relation_size(relid)) AS indexes_size
FROM pg_catalog.pg_statio_user_tables
WHERE schemaname = 'public'
ORDER BY pg_total_relation_size(relid) DESC;
```

**Обратите внимание:** Суммарный размер индексов может превышать размер самой таблицы!

---

## Часть 2. EXPLAIN — анализ планов выполнения

### Шаг 2.1. Простой EXPLAIN (оценочный план)

```sql
EXPLAIN
SELECT *
FROM fact_production
WHERE equipment_id = 5;
```

**Запишите:** Какой тип сканирования выбран? Какова оценка строк (rows)?

### Шаг 2.2. EXPLAIN ANALYZE (реальный план)

```sql
EXPLAIN ANALYZE
SELECT *
FROM fact_production
WHERE equipment_id = 5;
```

**Сравните:** Совпадает ли оценка `rows` с реальным количеством `actual rows`? Запишите оба значения.

### Шаг 2.3. EXPLAIN (ANALYZE, BUFFERS)

```sql
EXPLAIN (ANALYZE, BUFFERS)
SELECT *
FROM fact_production
WHERE equipment_id = 5;
```

**Запишите:**
- `shared hit` — сколько страниц прочитано из буферного кеша?
- `shared read` — сколько страниц прочитано с диска?
- `Planning Time` и `Execution Time`

### Шаг 2.4. EXPLAIN FORMAT JSON

```sql
EXPLAIN (ANALYZE, BUFFERS, FORMAT JSON)
SELECT *
FROM fact_production
WHERE equipment_id = 5;
```

**Обратите внимание** на структуру JSON: вложенные `Plans`, поля `Shared Hit Blocks`, `Shared Read Blocks`.

---

## Часть 3. Оптимизация запроса: пошаговый сценарий

### Сценарий: Отчёт по добыче за квартал

Диспетчер «Руда+» ежедневно формирует отчёт о добыче по шахтам.

### Шаг 3.1. Запустите медленный запрос

```sql
EXPLAIN (ANALYZE, BUFFERS)
SELECT
    d.full_date,
    m.mine_name,
    SUM(p.tons_mined) AS total_tons,
    SUM(p.tons_transported) AS total_transported,
    COUNT(*) AS records
FROM fact_production p
JOIN dim_date d ON d.date_id = p.date_id
JOIN dim_mine m ON m.mine_id = p.mine_id
WHERE d.year = 2024
  AND d.quarter = 1
GROUP BY d.full_date, m.mine_name
ORDER BY d.full_date, m.mine_name;
```

**Запишите:**
- Общее время выполнения (Execution Time)
- Тип сканирования fact_production (Seq Scan? Index Scan?)
- Тип соединения (Hash Join? Nested Loop?)

### Шаг 3.2. Определите узкое место

Найдите в плане узел с наибольшим `actual time`. Это и есть «бутылочное горлышко».

### Шаг 3.3. Создайте индекс

```sql
CREATE INDEX idx_prod_date_mine_covering
    ON fact_production(date_id, mine_id)
    INCLUDE (tons_mined, tons_transported);
```

### Шаг 3.4. Повторите EXPLAIN

```sql
EXPLAIN (ANALYZE, BUFFERS)
SELECT
    d.full_date,
    m.mine_name,
    SUM(p.tons_mined) AS total_tons,
    SUM(p.tons_transported) AS total_transported,
    COUNT(*) AS records
FROM fact_production p
JOIN dim_date d ON d.date_id = p.date_id
JOIN dim_mine m ON m.mine_id = p.mine_id
WHERE d.year = 2024
  AND d.quarter = 1
GROUP BY d.full_date, m.mine_name
ORDER BY d.full_date, m.mine_name;
```

**Сравните:**
- Изменился ли тип сканирования?
- Насколько уменьшилось время выполнения?
- Обратите внимание на `Heap Fetches` — если 0, значит Index Only Scan.

### Шаг 3.5. Проверьте размер индекса

```sql
SELECT
    indexname,
    pg_size_pretty(pg_relation_size(indexname::regclass)) AS index_size
FROM pg_indexes
WHERE indexname = 'idx_prod_date_mine_covering';
```

---

## Часть 4. Частичные индексы

### Шаг 4.1. Запрос по внеплановым простоям

```sql
EXPLAIN (ANALYZE, BUFFERS)
SELECT
    fd.date_id,
    e.equipment_name,
    dr.reason_name,
    fd.duration_min
FROM fact_equipment_downtime fd
JOIN dim_equipment e ON e.equipment_id = fd.equipment_id
JOIN dim_downtime_reason dr ON dr.reason_id = fd.reason_id
WHERE fd.is_planned = FALSE
  AND fd.date_id BETWEEN 20240301 AND 20240331
ORDER BY fd.duration_min DESC;
```

**Запишите** план выполнения.

### Шаг 4.2. Создайте частичный индекс

```sql
CREATE INDEX idx_downtime_unplanned_partial
    ON fact_equipment_downtime(date_id, equipment_id, reason_id)
    INCLUDE (duration_min)
    WHERE is_planned = FALSE;
```

### Шаг 4.3. Повторите запрос и сравните планы

Выполните тот же EXPLAIN ANALYZE и сравните:
- Изменился ли узел сканирования?
- Уменьшилось ли количество `shared hit` / `shared read`?

### Шаг 4.4. Сравните размеры индексов

```sql
-- Размер частичного индекса
SELECT pg_size_pretty(pg_relation_size('idx_downtime_unplanned_partial'));

-- Для сравнения: создадим полный индекс с теми же столбцами
CREATE INDEX idx_downtime_full_temp
    ON fact_equipment_downtime(date_id, equipment_id, reason_id)
    INCLUDE (duration_min);

SELECT pg_size_pretty(pg_relation_size('idx_downtime_full_temp'));

-- Удалим временный
DROP INDEX idx_downtime_full_temp;
```

**Вопрос:** На сколько процентов частичный индекс меньше полного?

---

## Часть 5. Мониторинг и обслуживание

### Шаг 5.1. Найдите неиспользуемые индексы

```sql
SELECT
    indexrelname AS index_name,
    relname AS table_name,
    idx_scan,
    pg_size_pretty(pg_relation_size(indexrelid)) AS size
FROM pg_stat_user_indexes
WHERE idx_scan = 0
  AND schemaname = 'public'
ORDER BY pg_relation_size(indexrelid) DESC;
```

### Шаг 5.2. Проверьте статистику столбцов

```sql
SELECT
    attname,
    n_distinct,
    correlation,
    most_common_vals,
    most_common_freqs
FROM pg_stats
WHERE tablename = 'fact_production'
  AND attname IN ('equipment_id', 'mine_id', 'date_id', 'shift_id');
```

**Обратите внимание:**
- `correlation` для `date_id` — близка ли к 1? (данные упорядочены?)
- `n_distinct` для `mine_id` — подтверждает ли низкую кардинальность?

### Шаг 5.3. Обновите статистику и сравните

```sql
-- Обновляем статистику
ANALYZE fact_production;

-- Повторяем запрос pg_stats и сравниваем значения
SELECT attname, n_distinct, correlation
FROM pg_stats
WHERE tablename = 'fact_production'
  AND attname = 'date_id';
```

---

## Часть 6. Очистка

После выполнения практической работы удалите созданные индексы:

```sql
DROP INDEX IF EXISTS idx_prod_date_mine_covering;
DROP INDEX IF EXISTS idx_downtime_unplanned_partial;
```

---

## Контрольные вопросы

1. В чём разница между `EXPLAIN` и `EXPLAIN ANALYZE`?
2. Что означает `Heap Fetches: 0` в Index Only Scan?
3. Когда частичный индекс эффективнее полного?
4. Почему порядок столбцов в составном индексе важен?
5. Как определить, что индекс «раздулся» и нужен REINDEX?

---

## Дополнительное задание (для продвинутых)

Создайте индекс на выражении для поиска простоев длительностью более 2 часов:

```sql
CREATE INDEX idx_downtime_long_hours
    ON fact_equipment_downtime((duration_min / 60.0))
    WHERE is_planned = FALSE;

-- Проверьте, что индекс используется:
EXPLAIN ANALYZE
SELECT *
FROM fact_equipment_downtime
WHERE duration_min / 60.0 > 2
  AND is_planned = FALSE;
```
