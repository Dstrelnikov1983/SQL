# Практическая работа — Модуль 7

## Введение в индексы: EXPLAIN ANALYZE и создание индексов

**Продолжительность:** 45 минут
**Инструменты:** Yandex Managed Service for PostgreSQL (psql / DBeaver / pgAdmin)
**Предприятие:** «Руда+» — MES-система горнодобывающего предприятия

---

## Предварительные требования

1. База данных «Руда+» развёрнута на PostgreSQL (скрипты `01_create_schema.sql`, `02_insert_dimensions.sql`, `03_insert_facts.sql` из каталога `common/scripts/`)
2. Клиент SQL (DBeaver, pgAdmin или psql) подключён к PostgreSQL
3. Файл `examples.sql` из каталога `module_07/` открыт для справки

---

## Часть 1. Знакомство с EXPLAIN ANALYZE

### Шаг 1.1. Базовый EXPLAIN

Выполните запрос и изучите план:

```sql
EXPLAIN
SELECT * FROM fact_production
WHERE date_id = 20240315;
```

**Что наблюдаем:**
- `EXPLAIN` без `ANALYZE` показывает **оценочный план** — запрос не выполняется
- Обратите внимание на тип сканирования (Seq Scan или Index Scan)
- `cost` — оценка стоимости (startup..total)
- `rows` — оценка количества возвращаемых строк

### Шаг 1.2. EXPLAIN ANALYZE — реальное выполнение

```sql
EXPLAIN ANALYZE
SELECT * FROM fact_production
WHERE date_id = 20240315;
```

**Что наблюдаем:**
- `Actual time` — реальное время (мс)
- `actual rows` — реальное количество строк
- `Planning Time` — время планирования
- `Execution Time` — время выполнения
- Сравните оценочные `rows` с `actual rows`

### Шаг 1.3. EXPLAIN с дополнительными параметрами

```sql
EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
SELECT * FROM fact_production
WHERE date_id = 20240315;
```

**Дополнительная информация:**
- `Buffers: shared hit=N` — страницы, прочитанные из кэша
- `Buffers: shared read=N` — страницы, прочитанные с диска
- Чем меньше `shared read`, тем лучше

---

## Часть 2. Sequential Scan vs Index Scan

### Шаг 2.1. Запрос без подходящего индекса

```sql
-- Поиск по расходу топлива — индекса нет
EXPLAIN ANALYZE
SELECT equipment_id, date_id, fuel_consumed_l
FROM fact_production
WHERE fuel_consumed_l > 50;
```

**Ожидаемый результат:**
- `Seq Scan on fact_production` — полное сканирование таблицы
- `Filter: (fuel_consumed_l > 50)` — фильтрация после чтения
- `Rows Removed by Filter: N` — сколько строк отброшено

### Шаг 2.2. Создаём индекс и проверяем

```sql
-- Создаём индекс
CREATE INDEX idx_prod_fuel ON fact_production(fuel_consumed_l);

-- Повторяем запрос
EXPLAIN ANALYZE
SELECT equipment_id, date_id, fuel_consumed_l
FROM fact_production
WHERE fuel_consumed_l > 50;
```

**Что изменилось?**
- Тип сканирования: `Index Scan` или `Bitmap Index Scan`
- Время выполнения уменьшилось

> **Примечание:** PostgreSQL может всё равно выбрать Seq Scan, если таблица маленькая или условие отбирает большую долю строк. Оптимизатор считает, что последовательное чтение дешевле.

### Шаг 2.3. Убираем индекс для чистоты

```sql
DROP INDEX idx_prod_fuel;
```

---

## Часть 3. Просмотр существующих индексов

### Шаг 3.1. Системный каталог pg_indexes

```sql
-- Все индексы таблицы fact_production
SELECT indexname, indexdef
FROM pg_indexes
WHERE tablename = 'fact_production'
ORDER BY indexname;
```

**Запишите:** сколько индексов уже существует? Какие столбцы они покрывают?

### Шаг 3.2. Размеры индексов

```sql
SELECT indexrelname AS index_name,
       pg_size_pretty(pg_relation_size(indexrelid)) AS index_size,
       idx_scan AS times_used
FROM pg_stat_user_indexes
WHERE relname = 'fact_production'
ORDER BY pg_relation_size(indexrelid) DESC;
```

### Шаг 3.3. Таблица vs индексы

```sql
SELECT pg_size_pretty(pg_table_size('fact_production')) AS table_size,
       pg_size_pretty(pg_indexes_size('fact_production')) AS indexes_size,
       pg_size_pretty(pg_total_relation_size('fact_production')) AS total_size;
```

**Вопрос для обсуждения:** Какую долю от общего размера занимают индексы?

---

## Часть 4. Создание различных типов индексов

### Шаг 4.1. Частичный индекс

```sql
-- Индекс только по аварийным показаниям
CREATE INDEX idx_telemetry_alarm
ON fact_equipment_telemetry(date_id, equipment_id)
WHERE is_alarm = TRUE;

-- Проверяем: запрос с условием is_alarm = TRUE
EXPLAIN ANALYZE
SELECT * FROM fact_equipment_telemetry
WHERE date_id = 20240315
  AND equipment_id = 3
  AND is_alarm = TRUE;

-- Проверяем: запрос БЕЗ условия is_alarm
EXPLAIN ANALYZE
SELECT * FROM fact_equipment_telemetry
WHERE date_id = 20240315
  AND equipment_id = 3;
```

**Что наблюдаем:** Частичный индекс используется только когда условие WHERE запроса включает `is_alarm = TRUE`.

### Шаг 4.2. Индекс по выражению

```sql
-- Индекс для поиска по году-месяцу
CREATE INDEX idx_prod_year_month
ON fact_production ((date_id / 100));

-- Проверяем
EXPLAIN ANALYZE
SELECT * FROM fact_production
WHERE date_id / 100 = 202403;

-- А если написать условие иначе?
EXPLAIN ANALYZE
SELECT * FROM fact_production
WHERE date_id BETWEEN 20240301 AND 20240399;
```

**Важно:** Обратите внимание, что второй запрос НЕ использует индекс по выражению — выражение в запросе должно точно совпадать с выражением в индексе.

### Шаг 4.3. Покрывающий индекс

```sql
-- Покрывающий индекс
CREATE INDEX idx_prod_date_covering
ON fact_production(date_id)
INCLUDE (equipment_id, tons_mined);

-- Запрос, который использует Index Only Scan
EXPLAIN ANALYZE
SELECT date_id, equipment_id, tons_mined
FROM fact_production
WHERE date_id = 20240315;

-- Запрос с дополнительным столбцом — уже не Index Only Scan
EXPLAIN ANALYZE
SELECT date_id, equipment_id, tons_mined, fuel_consumed_l
FROM fact_production
WHERE date_id = 20240315;
```

**Что наблюдаем:** `Index Only Scan` возможен только когда все запрашиваемые столбцы есть в индексе (ключевые + INCLUDE).

---

## Часть 5. Композитные индексы и порядок столбцов

### Шаг 5.1. Создание и тестирование композитного индекса

```sql
-- Композитный индекс: equipment_id + date_id
CREATE INDEX idx_prod_equip_date
ON fact_production(equipment_id, date_id);

-- Запрос 1: оба столбца (оптимально)
EXPLAIN ANALYZE
SELECT * FROM fact_production
WHERE equipment_id = 5
  AND date_id BETWEEN 20240301 AND 20240331;

-- Запрос 2: только ведущий столбец (работает)
EXPLAIN ANALYZE
SELECT * FROM fact_production
WHERE equipment_id = 5;

-- Запрос 3: только второй столбец (НЕ работает для данного индекса)
EXPLAIN ANALYZE
SELECT * FROM fact_production
WHERE date_id = 20240315;
```

**Зафиксируйте результаты:**

| Запрос | Тип сканирования | Время (мс) | Использованный индекс |
|--------|------------------|------------|----------------------|
| equipment_id = 5 AND date_id BETWEEN ... | ? | ? | ? |
| equipment_id = 5 | ? | ? | ? |
| date_id = 20240315 | ? | ? | ? |

### Шаг 5.2. Порядок столбцов: эксперимент

```sql
-- Создаём индекс с обратным порядком столбцов
CREATE INDEX idx_prod_date_equip
ON fact_production(date_id, equipment_id);

-- Тот же запрос — какой индекс выберет PostgreSQL?
EXPLAIN ANALYZE
SELECT * FROM fact_production
WHERE equipment_id = 5
  AND date_id BETWEEN 20240301 AND 20240331;
```

**Вопрос:** Какой из двух индексов выбрал оптимизатор? Почему?

---

## Часть 6. Команда CLUSTER

### Шаг 6.1. Физический порядок до CLUSTER

```sql
-- Смотрим текущий физический порядок
SELECT ctid, date_id, equipment_id
FROM fact_production
ORDER BY ctid
LIMIT 15;
```

### Шаг 6.2. Применяем CLUSTER

```sql
-- Кластеризуем по date_id
CLUSTER fact_production USING idx_fact_production_date;

-- Обновляем статистику
ANALYZE fact_production;

-- Проверяем физический порядок после CLUSTER
SELECT ctid, date_id, equipment_id
FROM fact_production
ORDER BY ctid
LIMIT 15;
```

**Что изменилось?** Теперь строки физически расположены в порядке date_id. Это улучшает производительность диапазонных запросов по дате.

---

## Часть 7. Очистка

```sql
-- Удаляем созданные в ходе практики индексы
DROP INDEX IF EXISTS idx_telemetry_alarm;
DROP INDEX IF EXISTS idx_prod_year_month;
DROP INDEX IF EXISTS idx_prod_date_covering;
DROP INDEX IF EXISTS idx_prod_equip_date;
DROP INDEX IF EXISTS idx_prod_date_equip;
```

---

## Выводы

1. **EXPLAIN ANALYZE** — главный инструмент для анализа производительности запросов
2. **Seq Scan** для маленьких таблиц может быть эффективнее Index Scan
3. **Частичные индексы** экономят место, если нужно индексировать только подмножество строк
4. **Покрывающие индексы** (INCLUDE) позволяют избежать обращения к heap
5. **Порядок столбцов** в композитном индексе критически важен — правило левого префикса
6. **CLUSTER** полезен для аналитических таблиц с пакетной загрузкой
