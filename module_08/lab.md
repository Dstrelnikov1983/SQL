# Лабораторная работа — Модуль 8

## Проектирование стратегий оптимизированных индексов

**Продолжительность:** 60 минут
**Формат:** самостоятельная работа
**Инструменты:** PostgreSQL (Yandex Managed Service for PostgreSQL)
**База данных:** «Руда+» (MES-система горнодобывающего предприятия)

### Подключение к базе данных

```
Сервер: rc1a-3fapmhnjrbfd3ve5.mdb.yandexcloud.net
Порт: 6432
База: db1
Пользователь: user1
Пароль: TtN7geNhE
Сертификат: root.crt
```

---

## Общие указания

- Сохраняйте все запросы и результаты в файл `lab08_solutions.sql`
- Для каждого задания фиксируйте результаты в виде комментариев или скриншотов
- Задания расположены по возрастанию сложности
- Максимальный балл — **100**
- При необходимости используйте `EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)` для анализа планов выполнения

---

## Темы модуля

- **8.1** Общие подходы к проектированию индексов
- **8.2** Обслуживание, мониторинг индексов (fillfactor, statistics, анализ)
- **8.3** Оптимизация запросов «Руда+»

---

## Задание 1. Анализ селективности (5 баллов)

**Тема:** 8.1 — Общие подходы к проектированию индексов

**Бизнес-задача:** Перед проектированием системы индексов необходимо определить, какие столбцы таблицы `fact_production` являются хорошими кандидатами для B-tree, а какие — для BRIN-индексов.

**Требования:**

1. Убедитесь, что статистика актуальна:

```sql
ANALYZE fact_production;
```

2. Напишите запрос к `pg_stats`, который для каждого столбца таблицы `fact_production` выведет:
   - Имя столбца (`attname`)
   - Количество уникальных значений (`n_distinct`)
   - Корреляцию с физическим порядком строк (`correlation`)
   - Долю NULL-значений (`null_frac`)
   - Наиболее частые значения (`most_common_vals`) — ограничьте вывод первыми 5

<details>
<summary>Подсказка: запрос к pg_stats</summary>

```sql
SELECT
    attname AS column_name,
    n_distinct,
    correlation,
    null_frac,
    most_common_vals::text
FROM pg_stats
WHERE tablename = 'fact_production'
ORDER BY attname;
```

</details>

3. На основании результатов заполните таблицу и обоснуйте выбор типа индекса:

| Столбец | n_distinct | correlation | Рекомендуемый тип индекса | Обоснование |
|---------|-----------|-------------|--------------------------|-------------|
| date_id | | | | |
| equipment_id | | | | |
| mine_id | | | | |
| shaft_id | | | | |
| shift_id | | | | |
| tons_mined | | | | |

4. Ответьте на вопросы:
   - Для каких столбцов BRIN-индекс будет эффективнее B-tree? Почему?
   - Какие столбцы имеют высокую селективность и хорошо подходят для B-tree?
   - Для каких столбцов создание индекса нецелесообразно?

**Ожидаемый результат:** Заполненная таблица с обоснованиями. Столбцы с `correlation` близкой к +1 или -1 — кандидаты для BRIN. Столбцы с высокой селективностью (большой `n_distinct`) — кандидаты для B-tree.

---

## Задание 2. Коэффициент заполнения — fillfactor (10 баллов)

**Тема:** 8.2 — Обслуживание и мониторинг индексов

**Бизнес-задача:** Администратор БД предприятия «Руда+» должен выбрать оптимальный fillfactor для индексов на таблице `fact_production`. Необходимо понять, как fillfactor влияет на размер индекса и производительность.

**Требования:**

1. Создайте четыре индекса на столбце `date_id` с разным fillfactor:

```sql
CREATE INDEX idx_prod_date_ff100 ON fact_production(date_id) WITH (fillfactor = 100);
CREATE INDEX idx_prod_date_ff90  ON fact_production(date_id) WITH (fillfactor = 90);
CREATE INDEX idx_prod_date_ff70  ON fact_production(date_id) WITH (fillfactor = 70);
CREATE INDEX idx_prod_date_ff50  ON fact_production(date_id) WITH (fillfactor = 50);
```

2. Сравните размеры индексов:

```sql
SELECT
    indexname,
    pg_size_pretty(pg_relation_size(indexname::regclass)) AS index_size,
    pg_relation_size(indexname::regclass) AS size_bytes
FROM pg_indexes
WHERE indexname LIKE 'idx_prod_date_ff%'
ORDER BY size_bytes;
```

3. Заполните таблицу:

| fillfactor | Размер индекса | % от fillfactor=100 | Свободное место на странице |
|-----------|---------------|--------------------|-----------------------------|
| 100 | | 100% | 0% |
| 90 | | | 10% |
| 70 | | | 30% |
| 50 | | | 50% |

4. Ответьте на вопросы:
   - Какой fillfactor рекомендуется для OLAP-нагрузки (аналитические запросы, редкие обновления)?
   - Какой fillfactor рекомендуется для OLTP-нагрузки (частые INSERT/UPDATE)?
   - Какой fillfactor вы бы рекомендовали для таблицы `fact_production` предприятия «Руда+» и почему?

<details>
<summary>Подсказка: рекомендации по fillfactor</summary>

- **OLAP (аналитика):** fillfactor = 100, так как данные редко обновляются, а компактный индекс уменьшает количество операций чтения.
- **OLTP (транзакционная):** fillfactor = 70–90, чтобы оставить место для HOT-обновлений (Heap Only Tuple) и избежать разделения страниц.
- **fact_production:** данные загружаются пакетно (ETL), обновления редки — fillfactor = 100 или 90.

</details>

5. Удалите все созданные индексы:

```sql
DROP INDEX IF EXISTS idx_prod_date_ff100;
DROP INDEX IF EXISTS idx_prod_date_ff90;
DROP INDEX IF EXISTS idx_prod_date_ff70;
DROP INDEX IF EXISTS idx_prod_date_ff50;
```

**Ожидаемый результат:** Индексы с меньшим fillfactor занимают больше места. Для аналитической базы «Руда+» оптимален fillfactor 90–100.

---

## Задание 3. Управление статистикой (10 баллов)

**Тема:** 8.2 — Обслуживание и мониторинг индексов

**Бизнес-задача:** Планировщик PostgreSQL неточно оценивает количество строк для запроса по коррелированным столбцам `mine_id` и `shaft_id`. Необходимо улучшить оценки с помощью настройки статистики.

**Требования:**

1. Посмотрите текущий уровень статистики для столбцов таблицы `fact_production`:

```sql
SELECT
    attname,
    attstattarget
FROM pg_attribute
WHERE attrelid = 'fact_production'::regclass
  AND attnum > 0
  AND NOT attisdropped
ORDER BY attnum;
```

2. Выполните запрос и зафиксируйте оценку планировщика (`rows` vs `actual rows`):

```sql
EXPLAIN ANALYZE
SELECT *
FROM fact_production
WHERE mine_id = 1
  AND shaft_id = 1
  AND date_id BETWEEN 20240101 AND 20240131;
```

Запишите: `estimated rows = ___`, `actual rows = ___`, разница = ___ раз.

3. Увеличьте точность статистики для ключевых столбцов:

```sql
ALTER TABLE fact_production ALTER COLUMN mine_id SET STATISTICS 1000;
ALTER TABLE fact_production ALTER COLUMN shaft_id SET STATISTICS 1000;
ALTER TABLE fact_production ALTER COLUMN date_id SET STATISTICS 1000;
ANALYZE fact_production;
```

4. Создайте расширенную статистику для коррелированных столбцов:

```sql
CREATE STATISTICS stat_prod_mine_shaft (dependencies, ndistinct)
    ON mine_id, shaft_id FROM fact_production;

ANALYZE fact_production;
```

5. Повторите EXPLAIN ANALYZE из пункта 2. Зафиксируйте новую оценку.

Запишите: `estimated rows = ___`, `actual rows = ___`, разница = ___ раз.

6. Просмотрите созданную расширенную статистику:

```sql
SELECT
    stxname,
    stxkeys,
    stxkind,
    stxdndistinct,
    stxddependencies
FROM pg_statistic_ext
JOIN pg_statistic_ext_data ON pg_statistic_ext.oid = pg_statistic_ext_data.stxoid
WHERE stxname = 'stat_prod_mine_shaft';
```

7. Ответьте: насколько улучшилась оценка строк? Почему расширенная статистика помогает при коррелированных столбцах?

<details>
<summary>Подсказка: почему оценки неточны</summary>

По умолчанию PostgreSQL считает столбцы в WHERE независимыми и перемножает их селективности. Если `mine_id` и `shaft_id` коррелированы (в шахте 1 есть только определённые стволы), фактическое количество строк сильно отличается от оценки. Расширенная статистика `dependencies` учитывает эту корреляцию.

</details>

**Ожидаемый результат:** После создания расширенной статистики оценка `rows` планировщика существенно приблизится к `actual rows`.

---

## Задание 4. Дублирующиеся индексы (10 баллов)

**Тема:** 8.2 — Обслуживание и мониторинг индексов

**Бизнес-задача:** За время эксплуатации MES-системы «Руда+» разные разработчики создавали индексы независимо. Необходимо провести аудит и найти дублирующиеся и перекрывающиеся индексы.

**Требования:**

1. Создайте намеренно дублирующиеся индексы для теста:

```sql
-- Создаём «дубликаты» для демонстрации
CREATE INDEX idx_prod_equip_date_v1 ON fact_production(equipment_id, date_id);
CREATE INDEX idx_prod_equip_date_v2 ON fact_production(equipment_id, date_id);

-- Создаём перекрывающийся индекс (один является префиксом другого)
CREATE INDEX idx_prod_equip_only ON fact_production(equipment_id);
```

2. Напишите запрос для поиска **точных дубликатов** (одинаковые столбцы, одна таблица):

<details>
<summary>Подсказка: поиск дубликатов</summary>

```sql
SELECT
    a.indexrelid::regclass AS index_1,
    b.indexrelid::regclass AS index_2,
    a.indrelid::regclass AS table_name,
    pg_size_pretty(pg_relation_size(a.indexrelid)) AS index_size
FROM pg_index a
JOIN pg_index b
    ON a.indrelid = b.indrelid
   AND a.indexrelid < b.indexrelid
   AND a.indkey::text = b.indkey::text
WHERE a.indrelid::regclass::text NOT LIKE 'pg_%';
```

</details>

3. Напишите запрос для поиска **перекрывающихся индексов** (один индекс является префиксом другого):

<details>
<summary>Подсказка: поиск перекрывающихся индексов</summary>

```sql
SELECT
    a.indexrelid::regclass AS shorter_index,
    b.indexrelid::regclass AS longer_index,
    a.indrelid::regclass AS table_name,
    pg_size_pretty(pg_relation_size(a.indexrelid)) AS shorter_size,
    pg_size_pretty(pg_relation_size(b.indexrelid)) AS longer_size
FROM pg_index a
JOIN pg_index b
    ON a.indrelid = b.indrelid
   AND a.indexrelid <> b.indexrelid
   AND a.indnkeyatts < b.indnkeyatts
   AND a.indkey::text = (
       SELECT string_agg(x, ' ')
       FROM unnest(string_to_array(b.indkey::text, ' ')) WITH ORDINALITY AS t(x, ord)
       WHERE ord <= a.indnkeyatts
   )
WHERE a.indrelid::regclass::text NOT LIKE 'pg_%';
```

</details>

4. Оцените потенциальную экономию дискового пространства при удалении дубликатов:

```sql
-- Суммарный размер дублирующихся индексов
SELECT
    pg_size_pretty(SUM(pg_relation_size(b.indexrelid))) AS wasted_space
FROM pg_index a
JOIN pg_index b
    ON a.indrelid = b.indrelid
   AND a.indexrelid < b.indexrelid
   AND a.indkey::text = b.indkey::text
WHERE a.indrelid::regclass::text NOT LIKE 'pg_%';
```

5. Удалите тестовые индексы:

```sql
DROP INDEX IF EXISTS idx_prod_equip_date_v1;
DROP INDEX IF EXISTS idx_prod_equip_date_v2;
DROP INDEX IF EXISTS idx_prod_equip_only;
```

**Ожидаемый результат:** Найдены дубликаты и перекрывающиеся индексы, подсчитана потенциальная экономия пространства.

---

## Задание 5. Мониторинг неиспользуемых индексов (10 баллов)

**Тема:** 8.2 — Обслуживание и мониторинг индексов

**Бизнес-задача:** Администратор БД «Руда+» должен выявить неиспользуемые индексы, которые замедляют операции INSERT/UPDATE и занимают место на диске.

**Требования:**

1. Напишите запрос, который находит все индексы с `idx_scan = 0` (ни одного сканирования с момента последнего сброса статистики):

```sql
SELECT
    schemaname || '.' || relname AS table_name,
    indexrelname AS index_name,
    idx_scan,
    idx_tup_read,
    pg_size_pretty(pg_relation_size(indexrelid)) AS index_size,
    pg_relation_size(indexrelid) AS size_bytes
FROM pg_stat_user_indexes
WHERE idx_scan = 0
  AND schemaname = 'public'
ORDER BY pg_relation_size(indexrelid) DESC;
```

2. Вычислите суммарный объём, занимаемый неиспользуемыми индексами:

```sql
SELECT
    pg_size_pretty(SUM(pg_relation_size(indexrelid))) AS total_wasted_space,
    COUNT(*) AS unused_index_count
FROM pg_stat_user_indexes
WHERE idx_scan = 0
  AND schemaname = 'public';
```

3. Определите, какие из найденных индексов можно безопасно удалить. Напишите запрос, исключающий первичные ключи и уникальные индексы:

<details>
<summary>Подсказка: фильтрация безопасных для удаления</summary>

```sql
SELECT
    sui.relname AS table_name,
    sui.indexrelname AS index_name,
    sui.idx_scan,
    pg_size_pretty(pg_relation_size(sui.indexrelid)) AS index_size,
    i.indisunique,
    i.indisprimary
FROM pg_stat_user_indexes sui
JOIN pg_index i ON sui.indexrelid = i.indexrelid
WHERE sui.idx_scan = 0
  AND sui.schemaname = 'public'
  AND i.indisunique = false
  AND i.indisprimary = false
ORDER BY pg_relation_size(sui.indexrelid) DESC;
```

</details>

4. Проверьте, когда последний раз сбрасывалась статистика (чтобы понять, насколько можно доверять `idx_scan = 0`):

```sql
SELECT
    stats_reset
FROM pg_stat_bgwriter;
```

5. Ответьте на вопросы:
   - Почему нельзя удалять индексы, обеспечивающие PK и UNIQUE-ограничения?
   - Какой минимальный период наблюдения рекомендуется перед удалением неиспользуемого индекса?
   - Как сезонность запросов может повлиять на решение об удалении индекса?

**Ожидаемый результат:** Список неиспользуемых индексов с размерами, отфильтрованный от PK/UNIQUE, оценка суммарной экономии пространства.

---

## Задание 6. REINDEX и обслуживание (10 баллов)

**Тема:** 8.2 — Обслуживание и мониторинг индексов

**Бизнес-задача:** После массовых операций обновления и удаления данных в таблице `fact_production` индексы могут быть «раздуты» (bloated). Необходимо обнаружить и устранить проблему.

**Требования:**

1. Создайте индекс для эксперимента:

```sql
CREATE INDEX idx_prod_bloat_test ON fact_production(equipment_id, date_id);
```

2. Зафиксируйте начальный размер индекса:

```sql
SELECT pg_size_pretty(pg_relation_size('idx_prod_bloat_test')) AS initial_size;
```

3. Симулируйте раздувание — выполните массовое обновление проиндексированных столбцов:

```sql
-- Обновление значений для создания мёртвых кортежей
UPDATE fact_production
SET equipment_id = equipment_id
WHERE date_id BETWEEN 20240101 AND 20240115;

-- Повторить несколько раз для усиления эффекта
UPDATE fact_production
SET equipment_id = equipment_id
WHERE date_id BETWEEN 20240116 AND 20240131;
```

4. Проверьте размер индекса после обновлений:

```sql
SELECT pg_size_pretty(pg_relation_size('idx_prod_bloat_test')) AS bloated_size;
```

5. Оцените степень раздувания индекса с помощью расширения `pgstattuple` (если доступно):

<details>
<summary>Подсказка: проверка раздувания</summary>

```sql
-- Если pgstattuple доступен:
SELECT * FROM pgstattuple('idx_prod_bloat_test');

-- Альтернатива — сравнить текущий размер с ожидаемым:
-- После REINDEX размер = «нормальный». Разница = bloat.
```

</details>

6. Выполните REINDEX и зафиксируйте время:

```sql
\timing on

-- Обычный REINDEX (блокирует таблицу)
REINDEX INDEX idx_prod_bloat_test;

\timing off
```

Запишите: время REINDEX = ___ мс, размер после = ___.

7. Повторите раздувание (пункт 3) и выполните REINDEX CONCURRENTLY:

```sql
\timing on

REINDEX INDEX CONCURRENTLY idx_prod_bloat_test;

\timing off
```

Запишите: время REINDEX CONCURRENTLY = ___ мс.

8. Заполните таблицу:

| Операция | Время (мс) | Блокирует записи? | Когда использовать |
|----------|-----------|--------------------|--------------------|
| REINDEX | | Да | |
| REINDEX CONCURRENTLY | | Нет | |

9. Удалите тестовый индекс:

```sql
DROP INDEX IF EXISTS idx_prod_bloat_test;
```

**Ожидаемый результат:** После массовых UPDATE индекс увеличился в размере. REINDEX вернул его к нормальному размеру. CONCURRENTLY работает дольше, но не блокирует запись.

---

## Задание 7. Покрывающий индекс для отчёта (10 баллов)

**Тема:** 8.3 — Оптимизация запросов «Руда+»

**Бизнес-задача:** Начальник смены ежедневно запрашивает сводку по работе оборудования: количество добытых тонн, число рейсов и часы работы за каждый день. Необходимо обеспечить максимальную скорость этого отчёта.

**Целевой запрос:**

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

1. Выполните `EXPLAIN (ANALYZE, BUFFERS)` без дополнительных индексов. Зафиксируйте:
   - Тип сканирования
   - Execution Time
   - Heap Fetches (если есть)

2. Создайте покрывающий индекс с `INCLUDE`:

<details>
<summary>Подсказка: структура покрывающего индекса</summary>

```sql
CREATE INDEX idx_prod_equip_date_covering
    ON fact_production(equipment_id, date_id)
    INCLUDE (tons_mined, trips_count, operating_hours);
```

</details>

3. Выполните `VACUUM fact_production` для обновления карты видимости.

4. Повторите `EXPLAIN (ANALYZE, BUFFERS)`. Убедитесь:
   - Тип сканирования = **Index Only Scan**
   - **Heap Fetches = 0**

5. Заполните таблицу:

| Метрика | До оптимизации | После оптимизации |
|---------|---------------|-------------------|
| Тип сканирования | | Index Only Scan |
| Execution Time (мс) | | |
| Heap Fetches | N/A | 0 |
| Shared Blocks | | |

6. Ответьте: почему `INCLUDE`-столбцы не добавляются в ключ индекса? Какие преимущества это даёт?

7. Удалите индекс:

```sql
DROP INDEX IF EXISTS idx_prod_equip_date_covering;
```

**Ожидаемый результат:** Переход от Seq Scan / Index Scan к Index Only Scan с Heap Fetches = 0.

---

## Задание 8. Комплексная оптимизация отчёта OEE (15 баллов)

**Тема:** 8.3 — Оптимизация запросов «Руда+»

**Бизнес-задача:** MES-система формирует ежемесячный отчёт OEE (Overall Equipment Effectiveness) по каждой единице оборудования. Этот отчёт критически важен для оценки эффективности горнодобывающего предприятия. Необходимо оптимизировать его выполнение, создав **не более 3 индексов**.

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

1. Выполните `EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)` и сохраните полный план выполнения.

2. Определите узкие места:
   - Какие узлы занимают больше всего времени?
   - Какие таблицы сканируются полностью (Seq Scan)?
   - Сколько буферных блоков читается?

3. Предложите и создайте **не более 3 индексов** для оптимизации:

<details>
<summary>Подсказка: рекомендуемые индексы</summary>

```sql
-- Индекс 1: CTE production_data — фильтрация по date_id, группировка по equipment_id
CREATE INDEX idx_oee_prod ON fact_production(date_id)
    INCLUDE (equipment_id, operating_hours, tons_mined);

-- Индекс 2: CTE downtime_data — фильтрация по date_id, группировка по equipment_id
CREATE INDEX idx_oee_downtime ON fact_equipment_downtime(date_id)
    INCLUDE (equipment_id, duration_min, is_planned);

-- Индекс 3: dim_equipment — фильтрация по status
CREATE INDEX idx_equip_status ON dim_equipment(status)
    INCLUDE (equipment_id, equipment_name, equipment_type_id);
```

</details>

4. Выполните `VACUUM` на затронутых таблицах.

5. Повторите `EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)`.

6. Заполните таблицу сравнения:

| Метрика | До оптимизации | После оптимизации |
|---------|---------------|-------------------|
| Execution Time (мс) | | |
| Тип скана fact_production | | |
| Тип скана fact_equipment_downtime | | |
| Тип скана dim_equipment | | |
| Shared Hit Blocks (суммарно) | | |

7. Удалите созданные индексы:

```sql
DROP INDEX IF EXISTS idx_oee_prod;
DROP INDEX IF EXISTS idx_oee_downtime;
DROP INDEX IF EXISTS idx_equip_status;
```

**Ожидаемый результат:** Значительное сокращение времени выполнения за счёт перехода от Seq Scan к Index (Only) Scan на фактовых таблицах.

---

## Задание 9. Оптимизация пакета запросов (15 баллов)

**Тема:** 8.3 — Оптимизация запросов «Руда+»

**Бизнес-задача:** Аналитик MES-системы «Руда+» регулярно выполняет набор из 5 типовых запросов. Необходимо предложить **минимальный набор индексов (не более 5)**, который улучшит производительность **всех** запросов.

**Запрос 1 — Ежедневная добыча по шахте:**

```sql
-- Q1: Добыча за день по конкретной шахте
SELECT p.date_id, SUM(p.tons_mined) AS daily_tons
FROM fact_production p
WHERE p.mine_id = 1
  AND p.date_id BETWEEN 20240301 AND 20240331
GROUP BY p.date_id
ORDER BY p.date_id;
```

**Запрос 2 — Простои оборудования за период:**

```sql
-- Q2: Все простои конкретного оборудования за месяц
SELECT fd.date_id, fd.start_time, fd.duration_min, dr.reason_name
FROM fact_equipment_downtime fd
JOIN dim_downtime_reason dr ON dr.reason_id = fd.reason_id
WHERE fd.equipment_id = 3
  AND fd.date_id BETWEEN 20240301 AND 20240331
ORDER BY fd.date_id, fd.start_time;
```

**Запрос 3 — Тревожная телеметрия:**

```sql
-- Q3: Тревожные показания датчиков за день
SELECT t.time_id, s.sensor_code, t.sensor_value
FROM fact_equipment_telemetry t
JOIN dim_sensor s ON s.sensor_id = t.sensor_id
WHERE t.date_id = 20240315
  AND t.is_alarm = TRUE
ORDER BY t.time_id;
```

**Запрос 4 — Качество руды по шахте:**

```sql
-- Q4: Среднее качество руды за месяц по шахте
SELECT oq.date_id, AVG(oq.fe_content) AS avg_fe, AVG(oq.moisture_pct) AS avg_moisture
FROM fact_ore_quality oq
WHERE oq.mine_id = 2
  AND oq.date_id BETWEEN 20240301 AND 20240331
GROUP BY oq.date_id
ORDER BY oq.date_id;
```

**Запрос 5 — Топ-10 самых длительных простоев:**

```sql
-- Q5: Топ-10 самых длительных незапланированных простоев
SELECT fd.date_id, e.equipment_name, dr.reason_name, fd.duration_min
FROM fact_equipment_downtime fd
JOIN dim_equipment e ON e.equipment_id = fd.equipment_id
JOIN dim_downtime_reason dr ON dr.reason_id = fd.reason_id
WHERE fd.is_planned = FALSE
  AND fd.date_id BETWEEN 20240301 AND 20240331
ORDER BY fd.duration_min DESC
LIMIT 10;
```

**Требования:**

1. Для каждого запроса выполните `EXPLAIN (ANALYZE, BUFFERS)` **без** дополнительных индексов. Заполните таблицу «До»:

| Запрос | Execution Time (мс) | Тип сканирования | Shared Blocks |
|--------|---------------------|-------------------|---------------|
| Q1 | | | |
| Q2 | | | |
| Q3 | | | |
| Q4 | | | |
| Q5 | | | |

2. Проанализируйте запросы и предложите **не более 5 индексов**, которые покроют все запросы. Учтите:
   - Q2 и Q5 обращаются к одной таблице — можно ли обойтись одним индексом?
   - Какие индексы могут быть покрывающими?

<details>
<summary>Подсказка: один из возможных вариантов</summary>

```sql
-- Для Q1: fact_production по mine_id + date_id
CREATE INDEX idx_q1_prod_mine_date ON fact_production(mine_id, date_id)
    INCLUDE (tons_mined);

-- Для Q2 + Q5: fact_equipment_downtime по equipment_id + date_id (Q2) и date_id + is_planned (Q5)
CREATE INDEX idx_q2_downtime_equip ON fact_equipment_downtime(equipment_id, date_id)
    INCLUDE (start_time, duration_min, reason_id);

CREATE INDEX idx_q5_downtime_unplanned ON fact_equipment_downtime(date_id)
    WHERE is_planned = FALSE;

-- Для Q3: fact_equipment_telemetry частичный индекс
CREATE INDEX idx_q3_telemetry_alarm ON fact_equipment_telemetry(date_id, time_id)
    INCLUDE (sensor_id, sensor_value)
    WHERE is_alarm = TRUE;

-- Для Q4: fact_ore_quality по mine_id + date_id
CREATE INDEX idx_q4_ore_mine_date ON fact_ore_quality(mine_id, date_id)
    INCLUDE (fe_content, moisture_pct);
```

</details>

3. Создайте предложенные индексы. Выполните `VACUUM` на затронутых таблицах.

4. Повторите `EXPLAIN (ANALYZE, BUFFERS)` для каждого запроса. Заполните таблицу «После»:

| Запрос | Execution Time (мс) | Тип сканирования | Shared Blocks | Улучшение |
|--------|---------------------|-------------------|---------------|-----------|
| Q1 | | | | |
| Q2 | | | | |
| Q3 | | | | |
| Q4 | | | | |
| Q5 | | | | |

5. Ответьте:
   - Удалось ли улучшить все 5 запросов?
   - Какой запрос получил наибольшее ускорение?
   - Оцените суммарный размер созданных индексов — оправданы ли затраты?

6. Удалите все созданные индексы:

```sql
DROP INDEX IF EXISTS idx_q1_prod_mine_date;
DROP INDEX IF EXISTS idx_q2_downtime_equip;
DROP INDEX IF EXISTS idx_q5_downtime_unplanned;
DROP INDEX IF EXISTS idx_q3_telemetry_alarm;
DROP INDEX IF EXISTS idx_q4_ore_mine_date;
```

**Ожидаемый результат:** Все 5 запросов улучшены с помощью не более 5 индексов. Студент обосновал выбор каждого индекса.

---

## Задание 10. Стратегический анализ (5 баллов)

**Тема:** 8.1 — Общие подходы к проектированию индексов

**Бизнес-задача:** Руководство предприятия «Руда+» просит подготовить документ с рекомендациями по стратегии индексирования аналитической базы данных.

**Требования:**

Подготовьте аналитический документ (в виде комментариев в SQL-файле или отдельного текстового файла), который содержит:

1. **Для каждой фактовой таблицы** (`fact_production`, `fact_equipment_telemetry`, `fact_equipment_downtime`, `fact_ore_quality`) укажите:
   - Рекомендуемые индексы (тип, столбцы, обоснование)
   - Ориентировочный размер каждого индекса
   - Влияние на скорость INSERT (оценка)

2. **Общая оценка накладных расходов:**

Для расчёта используйте запрос:

```sql
SELECT
    relname AS table_name,
    pg_size_pretty(pg_relation_size(relid)) AS table_size,
    pg_size_pretty(pg_total_relation_size(relid) - pg_relation_size(relid)) AS current_indexes_size,
    ROUND(
        (pg_total_relation_size(relid) - pg_relation_size(relid))::numeric /
        NULLIF(pg_relation_size(relid), 0) * 100, 1
    ) AS index_to_table_pct
FROM pg_catalog.pg_statio_user_tables
WHERE schemaname = 'public'
  AND relname LIKE 'fact_%'
ORDER BY pg_relation_size(relid) DESC;
```

3. **Стратегическая рекомендация** — заполните шаблон:

| Аспект | Рекомендация |
|--------|-------------|
| Тип нагрузки | OLAP / пакетная загрузка (ETL) |
| Рекомендуемый fillfactor | |
| Предпочтительные типы индексов | |
| Стратегия обслуживания | |
| Частота REINDEX | |
| Мониторинг | |
| Допустимое соотношение размера индексов к данным | |

4. Ответьте на вопрос: «Почему на предприятии "Руда+" с OLAP-нагрузкой стратегия индексирования отличается от типичной OLTP-системы?»

**Ожидаемый результат:** Структурированный документ с рекомендациями по каждой таблице и общей стратегией.

---

## Критерии оценки

| Задание | Баллы | Критерий |
|---------|-------|----------|
| 1. Анализ селективности | 5 | Корректный запрос к pg_stats, заполненная таблица, обоснованные выводы по B-tree/BRIN |
| 2. Коэффициент заполнения | 10 | Четыре индекса созданы, размеры сопоставлены, корректные рекомендации OLAP/OLTP |
| 3. Управление статистикой | 10 | Увеличен statistics target, создана расширенная статистика, зафиксировано улучшение оценок |
| 4. Дублирующиеся индексы | 10 | Запросы для точных дубликатов и перекрывающихся индексов, оценка экономии пространства |
| 5. Неиспользуемые индексы | 10 | Найдены индексы с idx_scan=0, отфильтрованы PK/UNIQUE, подсчитано wasted space |
| 6. REINDEX и обслуживание | 10 | Симуляция bloat, REINDEX vs CONCURRENTLY, заполненная таблица сравнения |
| 7. Покрывающий индекс | 10 | INCLUDE-индекс, Index Only Scan, Heap Fetches = 0, объяснение преимуществ INCLUDE |
| 8. Комплексная оптимизация OEE | 15 | Не более 3 индексов, заполненная таблица до/после, обоснование выбора |
| 9. Оптимизация пакета запросов | 15 | Не более 5 индексов для 5 запросов, все запросы улучшены, оценка суммарного размера |
| 10. Стратегический анализ | 5 | Документ с рекомендациями по каждой таблице, общая стратегия, ответ на вопрос |
| **Итого** | **100** | |

### Шкала оценивания

| Баллы | Оценка |
|-------|--------|
| 90–100 | Отлично |
| 75–89 | Хорошо |
| 60–74 | Удовлетворительно |
| < 60 | Требуется доработка |

---

## Очистка после лабораторной работы

После завершения всех заданий выполните очистку, чтобы не оставлять лишних объектов в базе:

```sql
-- Удаление индексов (на случай, если не были удалены в заданиях)
DROP INDEX IF EXISTS idx_prod_date_ff100;
DROP INDEX IF EXISTS idx_prod_date_ff90;
DROP INDEX IF EXISTS idx_prod_date_ff70;
DROP INDEX IF EXISTS idx_prod_date_ff50;
DROP INDEX IF EXISTS idx_prod_equip_date_v1;
DROP INDEX IF EXISTS idx_prod_equip_date_v2;
DROP INDEX IF EXISTS idx_prod_equip_only;
DROP INDEX IF EXISTS idx_prod_bloat_test;
DROP INDEX IF EXISTS idx_prod_equip_date_covering;
DROP INDEX IF EXISTS idx_oee_prod;
DROP INDEX IF EXISTS idx_oee_downtime;
DROP INDEX IF EXISTS idx_equip_status;
DROP INDEX IF EXISTS idx_q1_prod_mine_date;
DROP INDEX IF EXISTS idx_q2_downtime_equip;
DROP INDEX IF EXISTS idx_q5_downtime_unplanned;
DROP INDEX IF EXISTS idx_q3_telemetry_alarm;
DROP INDEX IF EXISTS idx_q4_ore_mine_date;

-- Удаление расширенной статистики
DROP STATISTICS IF EXISTS stat_prod_mine_shaft;

-- Сброс настроек статистики
ALTER TABLE fact_production ALTER COLUMN mine_id SET STATISTICS -1;
ALTER TABLE fact_production ALTER COLUMN shaft_id SET STATISTICS -1;
ALTER TABLE fact_production ALTER COLUMN date_id SET STATISTICS -1;

-- Обновление статистики
ANALYZE fact_production;
ANALYZE fact_equipment_downtime;
ANALYZE fact_equipment_telemetry;
ANALYZE fact_ore_quality;
```

---

**Информация для подключения:**

| Параметр | Значение |
|----------|---------|
| Сервер | rc1a-3fapmhnjrbfd3ve5.mdb.yandexcloud.net |
| Порт | 6432 |
| База | db1 |
| Пользователь | user1 |
| Пароль | TtN7geNhE |
| Сертификат | root.crt |
