# Практическая работа — Модуль 7

## Введение в индексы

**Продолжительность:** 45 минут
**Инструменты:** Yandex Managed Service for PostgreSQL (psql / DBeaver / pgAdmin)
**Предприятие:** «Руда+» — MES-система горнодобывающего предприятия

---

## Содержание

| Часть | Тема | Время |
|-------|------|-------|
| 1 | Планы выполнения запросов | ~12 мин |
| 2 | Sequential Scan vs Index Scan | ~5 мин |
| 3 | Избирательность и статистика | ~5 мин |
| 4 | Просмотр существующих индексов | ~5 мин |
| 5 | Создание различных типов индексов | ~8 мин |
| 6 | Композитные индексы и порядок столбцов | ~5 мин |
| 7 | Команда CLUSTER | ~5 мин |

---

## Предварительные требования

1. База данных «Руда+» развёрнута на PostgreSQL (скрипты `01_create_schema.sql`, `02_insert_dimensions.sql`, `03_insert_facts.sql` из каталога `common/scripts/`)
2. Клиент SQL (DBeaver, pgAdmin или psql) подключён к PostgreSQL
3. Файл `examples.sql` из каталога `module_07/` открыт для справки

**Параметры подключения:**

| Параметр | Значение |
|----------|----------|
| Сервер | `rc1a-3fapmhnjrbfd3ve5.mdb.yandexcloud.net` |
| Порт | `6432` |
| База данных | `db1` |
| Пользователь | `user1` |
| Пароль | `TtN7geNhE` |
| SSL-сертификат | `root.crt` |

---

## Часть 1. Планы выполнения запросов (~12 мин)

> **Цель:** Освоить основной инструмент диагностики производительности — команду EXPLAIN и её варианты.

### Шаг 1.1. Базовый EXPLAIN — оценочный план

Выполните запрос и изучите план:

```sql
EXPLAIN
SELECT * FROM fact_production
WHERE date_id = 20240315;
```

**Что наблюдаем:**

- `EXPLAIN` без `ANALYZE` показывает **оценочный план** — запрос **не выполняется**
- Обратите внимание на тип узла (Seq Scan, Index Scan и т.д.)
- `cost=X..Y` — оценка стоимости (X — стартовая, Y — полная)
- `rows` — оценка количества возвращаемых строк
- `width` — средний размер строки в байтах

**Вопрос для обсуждения:** Почему важно, что запрос не выполняется? В каких случаях это критично?

### Шаг 1.2. EXPLAIN ANALYZE — реальное выполнение

```sql
EXPLAIN ANALYZE
SELECT * FROM fact_production
WHERE date_id = 20240315;
```

**Что наблюдаем:**

- `actual time=X..Y` — реальное время выполнения узла (мс)
- `actual rows` — реальное количество возвращённых строк
- `loops` — сколько раз узел был выполнен
- `Planning Time` — время построения плана
- `Execution Time` — время выполнения запроса

**Задание:** Сравните оценочные `rows` с `actual rows`. Совпадают ли они? Запишите оба значения.

| Параметр | Оценка (EXPLAIN) | Факт (ANALYZE) |
|----------|-------------------|----------------|
| rows | ? | ? |
| cost / time | ? | ? |

### Шаг 1.3. EXPLAIN (ANALYZE, BUFFERS) — детализация ввода-вывода

```sql
EXPLAIN (ANALYZE, BUFFERS)
SELECT * FROM fact_production
WHERE date_id = 20240315;
```

**Дополнительная информация:**

- `Buffers: shared hit=N` — страницы, прочитанные **из кэша** (быстро)
- `Buffers: shared read=N` — страницы, прочитанные **с диска** (медленно)
- Чем больше `shared hit` относительно `shared read`, тем лучше

**Запишите:** Сколько страниц было прочитано из кэша? Сколько с диска?

### Шаг 1.4. Повторный запуск — эффект кэширования

Выполните тот же запрос ещё раз:

```sql
EXPLAIN (ANALYZE, BUFFERS)
SELECT * FROM fact_production
WHERE date_id = 20240315;
```

**Что изменилось?** Сравните значения `shared hit` и `shared read` с предыдущим запуском. При повторном выполнении данные уже в кэше, поэтому `shared read` должен уменьшиться.

### Шаг 1.5. EXPLAIN в формате JSON — машиночитаемый вывод

```sql
EXPLAIN (ANALYZE, BUFFERS, FORMAT JSON)
SELECT fp.equipment_id,
       de.equipment_name,
       SUM(fp.tons_mined) AS total_tons
FROM fact_production fp
JOIN dim_equipment de ON fp.equipment_id = de.equipment_id
WHERE fp.date_id BETWEEN 20240301 AND 20240331
GROUP BY fp.equipment_id, de.equipment_name
ORDER BY total_tons DESC;
```

**Что наблюдаем:**

- JSON-формат удобен для автоматического анализа планов
- Структура вложенная: каждый узел содержит `Plans` с дочерними узлами
- Обратите внимание на узлы `Hash Join`, `Sort`, `Aggregate`

**Вопрос для обсуждения:** В каких случаях формат JSON предпочтительнее текстового? Знаете ли вы инструменты для визуализации планов (например, explain.dalibo.com)?

### Шаг 1.6. План сложного аналитического запроса

```sql
EXPLAIN (ANALYZE, BUFFERS)
SELECT dd.month_name,
       dm.mine_name,
       COUNT(*) AS downtimes,
       SUM(fd.duration_min) AS total_downtime_min
FROM fact_equipment_downtime fd
JOIN dim_date dd ON fd.date_id = dd.date_id
JOIN dim_mine dm ON fd.equipment_id IN (
    SELECT equipment_id FROM dim_equipment WHERE mine_id = dm.mine_id
)
WHERE dd.year = 2024
GROUP BY dd.month_name, dm.mine_name
ORDER BY total_downtime_min DESC;
```

**Задание:** Найдите в плане:
1. Какой тип соединения использует PostgreSQL (Nested Loop, Hash Join, Merge Join)?
2. Какой узел занимает больше всего времени?
3. Есть ли узлы с большим расхождением между оценочными и фактическими rows?

---

## Часть 2. Sequential Scan vs Index Scan (~5 мин)

> **Цель:** Увидеть на практике разницу между полным сканированием таблицы и поиском по индексу.

### Шаг 2.1. Запрос без подходящего индекса

```sql
-- Поиск по расходу топлива — индекса на этом столбце нет
EXPLAIN ANALYZE
SELECT equipment_id, date_id, fuel_consumed_l
FROM fact_production
WHERE fuel_consumed_l > 50;
```

**Ожидаемый результат:**

- `Seq Scan on fact_production` — полное последовательное сканирование таблицы
- `Filter: (fuel_consumed_l > 50)` — фильтрация **после** чтения каждой строки
- `Rows Removed by Filter: N` — сколько строк было прочитано, но отброшено

Запишите время выполнения: _______ мс

### Шаг 2.2. Создаём индекс и сравниваем

```sql
-- Создаём B-tree индекс
CREATE INDEX idx_prod_fuel ON fact_production(fuel_consumed_l);

-- Повторяем тот же запрос
EXPLAIN ANALYZE
SELECT equipment_id, date_id, fuel_consumed_l
FROM fact_production
WHERE fuel_consumed_l > 50;
```

**Что изменилось?**

- Тип сканирования: `Index Scan` или `Bitmap Index Scan`
- Время выполнения уменьшилось (или нет?)

> **Важно:** PostgreSQL может всё равно выбрать Seq Scan, если таблица маленькая или условие отбирает большую долю строк. Оптимизатор считает, что последовательное чтение дешевле случайного доступа.

### Шаг 2.3. Убираем индекс

```sql
DROP INDEX idx_prod_fuel;
```

---

## Часть 3. Избирательность и статистика (~5 мин)

> **Цель:** Понять, как PostgreSQL оценивает количество строк, и что такое избирательность (selectivity).

### Шаг 3.1. Просмотр статистики столбца

```sql
-- Статистика по столбцу equipment_id таблицы fact_production
SELECT attname,
       null_frac,
       n_distinct,
       most_common_vals,
       most_common_freqs,
       correlation
FROM pg_stats
WHERE tablename = 'fact_production'
  AND attname = 'equipment_id';
```

**Разбираем результат:**

| Поле | Описание |
|------|----------|
| `null_frac` | Доля NULL-значений (0.0 = нет NULL) |
| `n_distinct` | Количество уникальных значений (отрицательное = доля от числа строк) |
| `most_common_vals` | Наиболее частые значения |
| `most_common_freqs` | Частоты этих значений |
| `correlation` | Корреляция между физическим и логическим порядком (от -1 до 1) |

### Шаг 3.2. Расчёт избирательности вручную

```sql
-- Сколько всего строк в таблице?
SELECT COUNT(*) AS total_rows FROM fact_production;

-- Сколько строк с equipment_id = 5?
SELECT COUNT(*) AS matching_rows
FROM fact_production
WHERE equipment_id = 5;
```

**Задание:** Рассчитайте избирательность (selectivity):

```
selectivity = matching_rows / total_rows = ? / ? = ?
```

**Вопрос для обсуждения:** Если избирательность близка к 1 (например, 0.8), имеет ли смысл создавать индекс по этому столбцу? Почему?

### Шаг 3.3. Сравнение столбцов с разной избирательностью

```sql
-- Статистика по нескольким столбцам
SELECT attname, n_distinct,
       CASE
           WHEN n_distinct > 0 THEN ROUND(1.0 / n_distinct, 4)
           ELSE ROUND(-1.0 / n_distinct, 4)
       END AS approx_selectivity
FROM pg_stats
WHERE tablename = 'fact_production'
  AND attname IN ('equipment_id', 'date_id', 'shift_id', 'mine_id')
ORDER BY n_distinct DESC;
```

**Запишите результаты:**

| Столбец | n_distinct | Приблизительная избирательность |
|---------|------------|-------------------------------|
| equipment_id | ? | ? |
| date_id | ? | ? |
| shift_id | ? | ? |
| mine_id | ? | ? |

**Вопрос:** По какому из столбцов индекс будет наиболее полезен? Почему?

---

## Часть 4. Просмотр существующих индексов (~5 мин)

> **Цель:** Научиться инспектировать существующие индексы и оценивать их размер.

### Шаг 4.1. Системный каталог pg_indexes

```sql
-- Все индексы таблицы fact_production
SELECT indexname, indexdef
FROM pg_indexes
WHERE tablename = 'fact_production'
ORDER BY indexname;
```

**Запишите:** Сколько индексов уже существует? Какие столбцы они покрывают?

### Шаг 4.2. Размеры индексов и статистика использования

```sql
SELECT indexrelname AS index_name,
       pg_size_pretty(pg_relation_size(indexrelid)) AS index_size,
       idx_scan AS times_used,
       idx_tup_read AS tuples_read
FROM pg_stat_user_indexes
WHERE relname = 'fact_production'
ORDER BY pg_relation_size(indexrelid) DESC;
```

### Шаг 4.3. Соотношение размеров: таблица vs индексы

```sql
SELECT pg_size_pretty(pg_table_size('fact_production')) AS table_size,
       pg_size_pretty(pg_indexes_size('fact_production')) AS indexes_size,
       pg_size_pretty(pg_total_relation_size('fact_production')) AS total_size,
       ROUND(100.0 * pg_indexes_size('fact_production') /
             NULLIF(pg_total_relation_size('fact_production'), 0), 1) AS indexes_pct
FROM pg_class
WHERE relname = 'fact_production';
```

**Вопрос для обсуждения:** Какую долю от общего размера занимают индексы? Что произойдёт, если добавить ещё 10 индексов?

---

## Часть 5. Создание различных типов индексов (~8 мин)

> **Цель:** Освоить создание частичных, индексов по выражению и покрывающих индексов.

### Шаг 5.1. Частичный индекс (Partial Index)

**Бизнес-контекст:** В MES-системе «Руда+» аварийные показания телеметрии (is_alarm = TRUE) составляют малую долю данных, но запрашиваются очень часто.

```sql
-- Частичный индекс: только аварийные показания
CREATE INDEX idx_telemetry_alarm
ON fact_equipment_telemetry(date_id, equipment_id)
WHERE is_alarm = TRUE;

-- Запрос 1: с условием is_alarm = TRUE (индекс используется)
EXPLAIN ANALYZE
SELECT * FROM fact_equipment_telemetry
WHERE date_id = 20240315
  AND equipment_id = 3
  AND is_alarm = TRUE;

-- Запрос 2: БЕЗ условия is_alarm (индекс НЕ используется)
EXPLAIN ANALYZE
SELECT * FROM fact_equipment_telemetry
WHERE date_id = 20240315
  AND equipment_id = 3;
```

**Что наблюдаем:** Частичный индекс используется только когда условие WHERE запроса включает `is_alarm = TRUE`. Он значительно меньше полного индекса, потому что содержит только подмножество строк.

### Шаг 5.2. Индекс по выражению (Expression Index)

**Бизнес-контекст:** Аналитики часто строят отчёты за месяц, извлекая год и месяц из числового date_id.

```sql
-- Индекс по выражению: год-месяц из date_id
CREATE INDEX idx_prod_year_month
ON fact_production ((date_id / 100));

-- Запрос 1: выражение совпадает — индекс используется
EXPLAIN ANALYZE
SELECT * FROM fact_production
WHERE date_id / 100 = 202403;

-- Запрос 2: выражение другое — индекс НЕ используется
EXPLAIN ANALYZE
SELECT * FROM fact_production
WHERE date_id BETWEEN 20240301 AND 20240399;
```

**Важно:** Выражение в запросе должно **точно совпадать** с выражением в определении индекса. Второй запрос, хотя и логически эквивалентен, не может использовать этот индекс.

### Шаг 5.3. Покрывающий индекс (Covering Index)

**Бизнес-контекст:** Дашборд MES-системы часто показывает объём добычи по оборудованию за день. Нужны только три столбца.

```sql
-- Покрывающий индекс: ключ date_id + дополнительные столбцы в INCLUDE
CREATE INDEX idx_prod_date_covering
ON fact_production(date_id)
INCLUDE (equipment_id, tons_mined);

-- Запрос 1: все столбцы есть в индексе — Index Only Scan
EXPLAIN ANALYZE
SELECT date_id, equipment_id, tons_mined
FROM fact_production
WHERE date_id = 20240315;

-- Запрос 2: нужен дополнительный столбец — уже НЕ Index Only Scan
EXPLAIN ANALYZE
SELECT date_id, equipment_id, tons_mined, fuel_consumed_l
FROM fact_production
WHERE date_id = 20240315;
```

**Что наблюдаем:**

- `Index Only Scan` — PostgreSQL берёт **все данные из индекса**, не обращаясь к таблице (heap)
- Как только запрашивается столбец, отсутствующий в индексе, требуется обращение к таблице

**Вопрос для обсуждения:** Почему бы не включить все столбцы в INCLUDE? Какие минусы у такого подхода?

---

## Часть 6. Композитные индексы и порядок столбцов (~5 мин)

> **Цель:** Понять правило левого префикса и влияние порядка столбцов в композитном индексе.

### Шаг 6.1. Создание и тестирование композитного индекса

```sql
-- Композитный индекс: equipment_id + date_id
CREATE INDEX idx_prod_equip_date
ON fact_production(equipment_id, date_id);
```

Протестируйте три запроса:

```sql
-- Запрос 1: оба столбца (оптимально)
EXPLAIN ANALYZE
SELECT * FROM fact_production
WHERE equipment_id = 5
  AND date_id BETWEEN 20240301 AND 20240331;

-- Запрос 2: только ведущий столбец (работает)
EXPLAIN ANALYZE
SELECT * FROM fact_production
WHERE equipment_id = 5;

-- Запрос 3: только второй столбец (индекс НЕ используется)
EXPLAIN ANALYZE
SELECT * FROM fact_production
WHERE date_id = 20240315;
```

**Зафиксируйте результаты:**

| Запрос | Тип сканирования | Время (мс) | Использован ли idx_prod_equip_date? |
|--------|------------------|------------|-------------------------------------|
| equipment_id = 5 AND date_id BETWEEN ... | ? | ? | ? |
| equipment_id = 5 | ? | ? | ? |
| date_id = 20240315 | ? | ? | ? |

**Правило левого префикса:** Композитный индекс `(A, B)` эффективен для фильтрации по `A` или по `A + B`, но **не** для фильтрации только по `B`.

### Шаг 6.2. Обратный порядок столбцов — эксперимент

```sql
-- Создаём индекс с обратным порядком
CREATE INDEX idx_prod_date_equip
ON fact_production(date_id, equipment_id);

-- Тот же запрос — какой индекс выберет PostgreSQL?
EXPLAIN ANALYZE
SELECT * FROM fact_production
WHERE equipment_id = 5
  AND date_id BETWEEN 20240301 AND 20240331;
```

**Вопрос для обсуждения:** Какой из двух индексов выбрал оптимизатор? Почему? Подсказка: подумайте о количестве уникальных значений в каждом столбце.

---

## Часть 7. Команда CLUSTER (~5 мин)

> **Цель:** Понять, как физический порядок строк влияет на производительность, и как CLUSTER позволяет его упорядочить.

### Шаг 7.1. Физический порядок строк до CLUSTER

```sql
-- Смотрим текущий физический порядок (ctid = физический адрес строки)
SELECT ctid, date_id, equipment_id, tons_mined
FROM fact_production
ORDER BY ctid
LIMIT 20;
```

**Обратите внимание:** ctid имеет формат `(страница, смещение)`. Строки с разными date_id могут находиться на одной странице — данные хранятся в порядке вставки, а не в логическом порядке.

### Шаг 7.2. Проверяем корреляцию до CLUSTER

```sql
SELECT attname, correlation
FROM pg_stats
WHERE tablename = 'fact_production'
  AND attname = 'date_id';
```

**correlation** показывает степень совпадения физического и логического порядка:
- `1.0` — идеальная корреляция (физический порядок совпадает с логическим)
- `0.0` — нет корреляции (случайный порядок)
- `-1.0` — обратная корреляция

### Шаг 7.3. Применяем CLUSTER

```sql
-- Кластеризуем таблицу по индексу на date_id
-- ВНИМАНИЕ: CLUSTER блокирует таблицу на время выполнения!
CLUSTER fact_production USING idx_fact_production_date;

-- Обновляем статистику
ANALYZE fact_production;
```

### Шаг 7.4. Проверяем результат

```sql
-- Физический порядок после CLUSTER
SELECT ctid, date_id, equipment_id, tons_mined
FROM fact_production
ORDER BY ctid
LIMIT 20;

-- Проверяем корреляцию
SELECT attname, correlation
FROM pg_stats
WHERE tablename = 'fact_production'
  AND attname = 'date_id';
```

**Что изменилось?**

- Строки теперь физически расположены в порядке date_id
- `correlation` стала близка к 1.0
- Диапазонные запросы по date_id будут читать меньше страниц с диска

**Вопрос для обсуждения:** Почему CLUSTER не поддерживается автоматически при INSERT/UPDATE? Когда имеет смысл запускать CLUSTER на продакшене?

---

## Очистка

Удалите индексы, созданные в ходе практики:

```sql
-- Удаляем созданные индексы
DROP INDEX IF EXISTS idx_prod_fuel;
DROP INDEX IF EXISTS idx_telemetry_alarm;
DROP INDEX IF EXISTS idx_prod_year_month;
DROP INDEX IF EXISTS idx_prod_date_covering;
DROP INDEX IF EXISTS idx_prod_equip_date;
DROP INDEX IF EXISTS idx_prod_date_equip;
```

---

## Выводы

1. **EXPLAIN ANALYZE** — главный инструмент для анализа производительности запросов. Варианты `BUFFERS` и `FORMAT JSON` дают дополнительную информацию для диагностики.
2. **Sequential Scan vs Index Scan** — оптимизатор сам выбирает стратегию на основе статистики. Для маленьких таблиц Seq Scan может быть быстрее.
3. **Избирательность** определяет эффективность индекса: чем выше избирательность (ближе к 0), тем полезнее индекс.
4. **pg_stats и pg_indexes** — системные каталоги для мониторинга статистики и состояния индексов.
5. **Частичные индексы** экономят место, индексируя только подмножество строк (например, аварийные показания).
6. **Индексы по выражению** полезны, когда запросы содержат вычисляемые условия, но выражение должно совпадать точно.
7. **Покрывающие индексы** (INCLUDE) позволяют выполнить Index Only Scan, избегая обращения к heap.
8. **Порядок столбцов** в композитном индексе критически важен — работает правило левого префикса.
9. **CLUSTER** упорядочивает физическое расположение строк, улучшая производительность диапазонных запросов, но требует эксклюзивной блокировки.
