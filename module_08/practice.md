# Практическая работа -- Модуль 8

## Проектирование стратегий оптимизированных индексов

**Продолжительность:** 45 минут
**Инструменты:** Yandex Managed Service for PostgreSQL (psql / DBeaver / pgAdmin)
**Предприятие:** «Руда+» -- MES-система горнодобывающего предприятия

**Темы модуля:**
- 8.1. Общие подходы к проектированию индексов
- 8.2. Обслуживание, мониторинг индексов (fillfactor, pad, statistics, viewing/analyzing)
- 8.3. Оптимизация запросов «Руда+»

---

## Предварительные требования

1. База данных «Руда+» развёрнута на PostgreSQL (скрипты `01_create_schema.sql`, `02_insert_dimensions.sql`, `03_insert_facts.sql` из каталога `common/scripts/`)
2. Клиент SQL (DBeaver, pgAdmin или psql) подключён к PostgreSQL
3. Открыт файл `examples.sql` из каталога `module_08/` -- примеры кода можно копировать оттуда
4. Параметры подключения:
   - Сервер: `rc1a-3fapmhnjrbfd3ve5.mdb.yandexcloud.net`
   - Порт: `6432`
   - База: `db1`
   - Пользователь: `user1`
   - Сертификат: `root.crt`

---

## Часть 1. Анализ существующих индексов (~8 мин)

### Шаг 1.1. Просмотр всех индексов базы данных

Получим полный список индексов в схеме `public` с указанием размеров:

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

Представление `pg_stat_user_indexes` показывает, насколько активно оптимизатор использует каждый индекс:

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

**Обратите внимание:**
- `idx_scan` -- количество раз, когда индекс использовался для сканирования
- `idx_tup_read` -- сколько записей было прочитано через индекс
- `idx_tup_fetch` -- сколько записей было реально извлечено из таблицы (heap)

### Шаг 1.3. Размеры таблиц vs размеры индексов

Сравним, какую долю общего размера таблицы занимают индексы:

```sql
SELECT
    relname AS table_name,
    pg_size_pretty(pg_total_relation_size(relid)) AS total_size,
    pg_size_pretty(pg_relation_size(relid)) AS table_size,
    pg_size_pretty(pg_total_relation_size(relid) - pg_relation_size(relid)) AS indexes_size,
    CASE
        WHEN pg_relation_size(relid) > 0
        THEN ROUND(
            (pg_total_relation_size(relid) - pg_relation_size(relid))::numeric
            / pg_relation_size(relid)::numeric * 100, 1
        )
        ELSE 0
    END AS index_ratio_pct
FROM pg_catalog.pg_statio_user_tables
WHERE schemaname = 'public'
ORDER BY pg_total_relation_size(relid) DESC;
```

**Обратите внимание:** Суммарный размер индексов может превышать размер самой таблицы! Колонка `index_ratio_pct` показывает процент размера индексов относительно данных.

> **Вопрос для обсуждения:** Если вы видите индексы с `idx_scan = 0`, что это означает? Стоит ли их сразу удалять? Какие факторы нужно учитывать перед удалением? (Подсказка: статистика могла быть сброшена, индекс мог использоваться для поддержки UNIQUE-ограничения, или запросы, для которых он создан, выполняются только в конце отчётного периода.)

---

## Часть 2. Коэффициент заполнения (fillfactor) (~8 мин)

Параметр `fillfactor` определяет, какой процент каждой страницы индекса заполняется данными при создании. Оставшееся место резервируется для будущих обновлений (HOT updates).

### Шаг 2.1. Создание индекса с fillfactor по умолчанию (90%)

Для B-tree индексов значение по умолчанию -- 90%.

```sql
CREATE INDEX idx_prod_date_default_ff
    ON fact_production(date_id)
    WITH (fillfactor = 90);
```

Проверим текущий fillfactor:

```sql
SELECT
    c.relname AS index_name,
    am.amname AS index_type,
    array_to_string(c.reloptions, ', ') AS options
FROM pg_class c
JOIN pg_am am ON am.oid = c.relam
WHERE c.relname = 'idx_prod_date_default_ff';
```

### Шаг 2.2. Создание индекса с fillfactor = 70

Для таблиц с интенсивной записью рекомендуется снижать fillfactor:

```sql
CREATE INDEX idx_prod_date_low_ff
    ON fact_production(date_id)
    WITH (fillfactor = 70);
```

### Шаг 2.3. Сравнение размеров обоих индексов

```sql
SELECT
    indexname,
    pg_size_pretty(pg_relation_size(indexname::regclass)) AS index_size,
    pg_relation_size(indexname::regclass) AS size_bytes
FROM pg_indexes
WHERE indexname IN ('idx_prod_date_default_ff', 'idx_prod_date_low_ff')
ORDER BY indexname;
```

**Запишите:**
- Размер индекса с fillfactor = 90: ________
- Размер индекса с fillfactor = 70: ________
- Разница в процентах: ________

### Шаг 2.4. Обсуждение: когда использовать пониженный fillfactor

> **Вопрос для обсуждения:** В каких ситуациях на предприятии «Руда+» стоит использовать пониженный fillfactor?

**Рекомендации:**
| Тип таблицы | Рекомендуемый fillfactor | Пример из «Руда+» |
|---|---|---|
| Только INSERT (факты) | 90--100 | `fact_production` (данные не обновляются) |
| Частые UPDATE | 70--80 | `dim_equipment` (статус меняется) |
| Очень частые UPDATE | 50--70 | Таблицы с текущим состоянием датчиков |

**Важно:** Пониженный fillfactor увеличивает размер индекса, но уменьшает вероятность расщепления страниц (page splits) при обновлениях, что положительно влияет на производительность записи.

---

## Часть 3. Управление статистикой (~8 мин)

PostgreSQL использует статистику о распределении данных в столбцах для выбора оптимальных планов выполнения.

### Шаг 3.1. Просмотр статистики столбцов из pg_stats

Изучим ключевые характеристики распределения данных:

```sql
SELECT
    attname AS column_name,
    n_distinct,
    null_frac,
    correlation,
    most_common_vals::text AS common_values,
    most_common_freqs::text AS common_freqs
FROM pg_stats
WHERE tablename = 'fact_production'
  AND attname IN ('equipment_id', 'mine_id', 'date_id', 'shift_id')
ORDER BY attname;
```

**Расшифровка полей:**
- `n_distinct` -- оценка количества уникальных значений (отрицательное число = доля от общего количества строк)
- `null_frac` -- доля NULL-значений (0.0 = нет NULL)
- `correlation` -- степень корреляции физического и логического порядка (1.0 = идеально упорядочены)
- `most_common_vals` -- самые частые значения
- `most_common_freqs` -- частоты соответствующих значений

**Запишите:**
- `correlation` для `date_id`: ________ (близка ли к 1? Значит, данные физически упорядочены)
- `n_distinct` для `mine_id`: ________ (подтверждает ли низкую кардинальность?)

### Шаг 3.2. Обновление статистики командой ANALYZE и сравнение

```sql
-- Запомните текущие значения n_distinct и correlation для date_id
SELECT attname, n_distinct, correlation
FROM pg_stats
WHERE tablename = 'fact_production'
  AND attname = 'date_id';

-- Обновляем статистику
ANALYZE fact_production;

-- Повторяем запрос и сравниваем
SELECT attname, n_distinct, correlation
FROM pg_stats
WHERE tablename = 'fact_production'
  AND attname = 'date_id';
```

**Обратите внимание:** Значения могут незначительно измениться, поскольку ANALYZE собирает данные на основе случайной выборки строк.

### Шаг 3.3. Увеличение детализации статистики

По умолчанию PostgreSQL собирает статистику по 100 наиболее частым значениям (`default_statistics_target = 100`). Для столбцов с высокой кардинальностью этого может быть недостаточно:

```sql
-- Увеличиваем глубину сбора статистики до 500
ALTER TABLE fact_equipment_telemetry
    ALTER COLUMN sensor_id SET STATISTICS 500;

-- Пересобираем статистику для этого столбца
ANALYZE fact_equipment_telemetry(sensor_id);

-- Проверяем: теперь массив most_common_vals содержит больше значений
SELECT
    attname,
    n_distinct,
    array_length(most_common_vals::text::text[], 1) AS num_common_vals
FROM pg_stats
WHERE tablename = 'fact_equipment_telemetry'
  AND attname = 'sensor_id';
```

**Вопрос:** Когда имеет смысл увеличивать `STATISTICS`? Ответ: когда данные имеют неравномерное распределение и оптимизатор ошибается в оценке количества строк.

### Шаг 3.4. Расширенная статистика для коррелированных столбцов

Стандартная статистика собирается по отдельным столбцам. Но если столбцы коррелированы (например, `mine_id` и `shaft_id` -- в каждой шахте свои стволы), оптимизатор может ошибаться:

```sql
-- Создаём расширенную статистику зависимостей
CREATE STATISTICS stat_prod_mine_shaft (dependencies)
    ON mine_id, shaft_id FROM fact_production;

-- Пересобираем
ANALYZE fact_production;

-- Проверяем, что статистика создана
SELECT
    stxname AS stat_name,
    stxkeys AS column_ids,
    stxkind AS stat_types
FROM pg_statistic_ext
WHERE stxrelid = 'fact_production'::regclass;
```

**Обратите внимание:** Тип `dependencies` (d) помогает оптимизатору учитывать функциональные зависимости между столбцами. Это особенно важно для аналитических баз данных со схемой «звезда» / «снежинка», где ключи измерений часто коррелированы.

---

## Часть 4. Мониторинг и обслуживание индексов (~8 мин)

### Шаг 4.1. Поиск неиспользуемых индексов (idx_scan = 0)

Неиспользуемые индексы -- это «мёртвый груз»: они занимают место и замедляют операции INSERT/UPDATE/DELETE:

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

**Важно:** Прежде чем удалять индекс с `idx_scan = 0`, проверьте:
1. Когда последний раз сбрасывалась статистика? (`SELECT pg_stat_reset()` обнуляет счётчики)
2. Не поддерживает ли индекс ограничение UNIQUE или FK?
3. Не используется ли он в запросах, которые выполняются только в конце месяца/квартала?

### Шаг 4.2. Поиск дубликатов индексов

Дублирующие индексы -- частая проблема. Найдём индексы с одинаковым определением:

```sql
SELECT
    a.indexrelid::regclass AS index_1,
    b.indexrelid::regclass AS index_2,
    a.indrelid::regclass AS table_name,
    pg_size_pretty(pg_relation_size(a.indexrelid)) AS index_1_size
FROM pg_index a
JOIN pg_index b
    ON a.indrelid = b.indrelid
   AND a.indexrelid <> b.indexrelid
   AND a.indkey::text = b.indkey::text
   AND a.indclass::text = b.indclass::text
WHERE a.indexrelid > b.indexrelid
ORDER BY a.indrelid::regclass::text;
```

**Обратите внимание:** Даже если дубликатов не найдено -- это хороший результат. Запрос полезно выполнять периодически на рабочих базах данных.

### Шаг 4.3. Пересоздание индекса (REINDEX)

Со временем индексы «раздуваются» из-за обновлений и удалений. Команда `REINDEX` пересоздаёт индекс:

```sql
-- Создадим индекс для демонстрации
CREATE INDEX idx_prod_reindex_demo
    ON fact_production(equipment_id, date_id);

-- Посмотрим размер до REINDEX
SELECT pg_size_pretty(pg_relation_size('idx_prod_reindex_demo')) AS size_before;

-- Пересоздание индекса
REINDEX INDEX idx_prod_reindex_demo;

-- Посмотрим размер после REINDEX
SELECT pg_size_pretty(pg_relation_size('idx_prod_reindex_demo')) AS size_after;
```

> **Примечание:** На рабочих системах с высокой нагрузкой используйте `REINDEX INDEX CONCURRENTLY`, чтобы не блокировать другие операции.

### Шаг 4.4. Проверка валидности индексов (pg_index.indisvalid)

Индекс может оказаться невалидным, если, например, `CREATE INDEX CONCURRENTLY` завершился с ошибкой:

```sql
SELECT
    indexrelid::regclass AS index_name,
    indrelid::regclass AS table_name,
    indisvalid AS is_valid,
    indisready AS is_ready
FROM pg_index
WHERE NOT indisvalid;
```

Если найдены невалидные индексы, их необходимо пересоздать:

```sql
-- Пример пересоздания невалидного индекса
-- REINDEX INDEX CONCURRENTLY <имя_невалидного_индекса>;
```

**Результат:** Если запрос вернул пустой результат -- все индексы валидны. Это хорошо!

---

## Часть 5. Оптимизация запроса «Руда+» (~13 мин)

### Сценарий

Диспетчер предприятия «Руда+» ежеквартально формирует отчёт о добыче по шахтам с детализацией по дням. Запрос работает медленно -- необходимо его оптимизировать.

### Шаг 5.1. Запуск сложного квартального отчёта и анализ плана

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
- Общее время выполнения (Execution Time): ________
- Тип сканирования `fact_production`: ________ (Seq Scan? Index Scan?)
- Тип соединения: ________ (Hash Join? Nested Loop? Merge Join?)
- Количество `shared hit` / `shared read`: ________

### Шаг 5.2. Определение узкого места

Изучите план выполнения и найдите узел с наибольшим значением `actual time`. Это «бутылочное горлышко» запроса.

**Вопросы для анализа:**
- Происходит ли полное сканирование таблицы `fact_production`?
- Эффективно ли выполняется соединение?
- Есть ли сортировка, которую можно устранить индексом?

### Шаг 5.3. Создание покрывающего индекса

На основе анализа плана создадим покрывающий индекс, который позволит выполнить Index Only Scan:

```sql
CREATE INDEX idx_prod_date_mine_covering
    ON fact_production(date_id, mine_id)
    INCLUDE (tons_mined, tons_transported);
```

Обновим Visibility Map для возможности Index Only Scan:

```sql
VACUUM fact_production;
```

### Шаг 5.4. Повторный запуск и сравнение

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

**Сравните с результатами Шага 5.1:**

| Метрика | До оптимизации | После оптимизации |
|---|---|---|
| Execution Time | ________ | ________ |
| Тип сканирования fact_production | ________ | ________ |
| Heap Fetches | ________ | ________ |
| shared hit + shared read | ________ | ________ |

**Обратите внимание:**
- Изменился ли тип сканирования на Index Only Scan?
- Если `Heap Fetches: 0` -- значит, все данные были получены из индекса без обращения к таблице
- Насколько уменьшилось время выполнения?

### Шаг 5.5. Проверка размера созданного индекса

```sql
SELECT
    indexname,
    pg_size_pretty(pg_relation_size(indexname::regclass)) AS index_size,
    pg_relation_size(indexname::regclass) AS size_bytes
FROM pg_indexes
WHERE indexname = 'idx_prod_date_mine_covering';
```

> **Вопрос для обсуждения:** Оправдан ли размер индекса с учётом выигрыша в производительности? Как вы примете решение на рабочей системе «Руда+»?

---

## Часть 6. Очистка

После выполнения практической работы удалите все созданные объекты:

```sql
-- Индексы из Части 2 (fillfactor)
DROP INDEX IF EXISTS idx_prod_date_default_ff;
DROP INDEX IF EXISTS idx_prod_date_low_ff;

-- Расширенная статистика из Части 3
DROP STATISTICS IF EXISTS stat_prod_mine_shaft;

-- Индекс из Части 4 (REINDEX)
DROP INDEX IF EXISTS idx_prod_reindex_demo;

-- Индекс из Части 5 (оптимизация запроса)
DROP INDEX IF EXISTS idx_prod_date_mine_covering;

-- Восстановим значение STATISTICS по умолчанию
ALTER TABLE fact_equipment_telemetry
    ALTER COLUMN sensor_id SET STATISTICS -1;
```

---

## Контрольные вопросы

1. **Fillfactor:** Что произойдёт с индексом, если установить `fillfactor = 100` на таблице с частыми обновлениями? Какое значение fillfactor вы бы рекомендовали для таблицы `fact_equipment_telemetry`?

2. **Статистика:** Зачем нужна команда `ANALYZE`? Что произойдёт, если статистика устарела -- как это повлияет на планы выполнения запросов?

3. **Расширенная статистика:** В каких случаях стандартной одномерной статистики недостаточно? Приведите пример из модели «Руда+», где корреляция между столбцами может ввести оптимизатор в заблуждение.

4. **Мониторинг:** Перечислите три признака того, что индекс необходимо пересоздать (REINDEX). Какая системная таблица позволяет проверить валидность индекса?

5. **Обслуживание:** Чем `REINDEX INDEX CONCURRENTLY` отличается от обычного `REINDEX INDEX`? В какой ситуации вы бы использовали каждый из вариантов на рабочей системе «Руда+»?

---

## Дополнительное задание (для продвинутых)

Самостоятельно создайте стратегию индексирования для запроса отчёта OEE (Overall Equipment Effectiveness):

```sql
-- Проанализируйте этот запрос и создайте оптимальные индексы
EXPLAIN (ANALYZE, BUFFERS)
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
    COALESCE(pd.total_tons, 0) AS tons_mined
FROM dim_equipment e
JOIN dim_equipment_type et ON et.equipment_type_id = e.equipment_type_id
LEFT JOIN production_data pd ON pd.equipment_id = e.equipment_id
LEFT JOIN downtime_data dd ON dd.equipment_id = e.equipment_id
WHERE e.status = 'active'
ORDER BY e.equipment_name;
```

**Подсказка:** Вам понадобятся покрывающие индексы для обоих CTE-подзапросов. Не забудьте выполнить `VACUUM` перед повторным анализом.
