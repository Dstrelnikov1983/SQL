# Лабораторная работа -- Модуль 7

## Введение в индексы

**Продолжительность:** 60 минут
**Формат:** самостоятельная работа
**Инструменты:** PostgreSQL (psql / DBeaver / pgAdmin)
**База данных:** «Руда+» (MES-система горнодобывающего предприятия)

---

## Структура модуля

| # | Тема |
|---|------|
| 7.1 | Планы выполнения запросов |
| 7.2 | Зачем нужны индексы? Избирательность, плотность, глубина |
| 7.3 | Как PostgreSQL хранит данные |
| 7.4 | Типы индексов в PostgreSQL |
| 7.5 | B-tree индекс (все подразделы) |
| 7.6 | Влияние индексов на INSERT/UPDATE/DELETE |

---

## Общие указания

- Каждое задание требует анализа плана запроса через `EXPLAIN ANALYZE`.
- Сохраняйте все запросы и результаты в файл `lab_solutions.sql`.
- Для каждого задания фиксируйте:
  - План запроса **до** создания индекса
  - План запроса **после** создания индекса
  - Тип сканирования и время выполнения
- Задания расположены по возрастанию сложности.
- При выполнении `EXPLAIN ANALYZE` обращайте внимание на:
  - `Seq Scan` vs `Index Scan` vs `Index Only Scan` vs `Bitmap Index Scan`
  - `actual time` -- реальное время выполнения (мс)
  - `rows` -- количество строк
  - `Buffers: shared hit / read` -- количество прочитанных страниц

### Подключение к базе данных

```
Сервер: rc1a-3fapmhnjrbfd3ve5.mdb.yandexcloud.net
Порт:   6432
База:   db1
Пользователь: user1
Пароль: TtN7geNhE
Сертификат: root.crt
```

---

## Задание 1. Анализ существующих индексов

**Тема модуля:** 7.3 -- Как PostgreSQL хранит данные

**Бизнес-задача:** Администратору БД предприятия «Руда+» необходимо провести аудит индексов аналитической базы: понять, какие индексы уже существуют, насколько они велики и как часто используются. Это первый шаг перед оптимизацией.

**Требования:**

1. Выведите список всех индексов для таблиц `fact_production`, `fact_equipment_telemetry`, `fact_equipment_downtime` и `fact_ore_quality`. Для каждого индекса покажите: имя таблицы, имя индекса, определение (`indexdef`).

2. Для таблицы `fact_production` выведите размер каждого индекса и статистику использования (количество сканирований, количество прочитанных кортежей).

3. Подсчитайте суммарный размер всех индексов для каждой факт-таблицы. Сравните с размером самих таблиц.

<details>
<summary>Подсказка: запрос для пункта 1</summary>

```sql
SELECT tablename, indexname, indexdef
FROM pg_indexes
WHERE tablename IN (
    'fact_production',
    'fact_equipment_telemetry',
    'fact_equipment_downtime',
    'fact_ore_quality'
)
ORDER BY tablename, indexname;
```

</details>

<details>
<summary>Подсказка: запрос для пункта 2</summary>

```sql
SELECT indexrelname AS index_name,
       pg_size_pretty(pg_relation_size(indexrelid)) AS index_size,
       idx_scan AS times_used,
       idx_tup_read AS tuples_read,
       idx_tup_fetch AS tuples_fetched
FROM pg_stat_user_indexes
WHERE relname = 'fact_production'
ORDER BY pg_relation_size(indexrelid) DESC;
```

</details>

<details>
<summary>Подсказка: запрос для пункта 3</summary>

```sql
SELECT relname AS table_name,
       pg_size_pretty(pg_table_size(relid)) AS table_size,
       pg_size_pretty(pg_indexes_size(relid)) AS indexes_size,
       pg_size_pretty(pg_total_relation_size(relid)) AS total_size,
       ROUND(
           pg_indexes_size(relid)::numeric /
           NULLIF(pg_table_size(relid), 0) * 100, 1
       ) AS index_pct
FROM pg_stat_user_tables
WHERE relname IN (
    'fact_production',
    'fact_equipment_telemetry',
    'fact_equipment_downtime',
    'fact_ore_quality'
)
ORDER BY pg_total_relation_size(relid) DESC;
```

</details>

**Ожидаемый результат:** Таблица со всеми индексами, их размерами и статистикой использования. Вы должны увидеть индексы, созданные при развертывании схемы (`idx_fact_production_date`, `idx_fact_production_shift` и т.д.), и оценить долю индексов относительно данных.

---

## Задание 2. Анализ плана выполнения

**Тема модуля:** 7.1 -- Планы выполнения запросов

**Бизнес-задача:** Начальник участка жалуется, что отчет по добыче за месяц с группировкой по оборудованию работает медленно. Необходимо проанализировать план выполнения запроса и выявить узкое место.

**Требования:**

1. Выполните запрос с `EXPLAIN` и изучите оценочный план (запрос НЕ выполняется):

```sql
EXPLAIN
SELECT e.equipment_name,
       SUM(p.tons_mined) AS total_tons,
       SUM(p.fuel_consumed_l) AS total_fuel,
       SUM(p.operating_hours) AS total_hours
FROM fact_production p
JOIN dim_equipment e ON p.equipment_id = e.equipment_id
WHERE p.date_id BETWEEN 20240301 AND 20240331
GROUP BY e.equipment_name
ORDER BY total_tons DESC;
```

2. Выполните тот же запрос с `EXPLAIN ANALYZE` и зафиксируйте реальное время:

```sql
EXPLAIN ANALYZE
SELECT e.equipment_name,
       SUM(p.tons_mined) AS total_tons,
       SUM(p.fuel_consumed_l) AS total_fuel,
       SUM(p.operating_hours) AS total_hours
FROM fact_production p
JOIN dim_equipment e ON p.equipment_id = e.equipment_id
WHERE p.date_id BETWEEN 20240301 AND 20240331
GROUP BY e.equipment_name
ORDER BY total_tons DESC;
```

3. Выполните тот же запрос с `EXPLAIN (ANALYZE, BUFFERS)` для анализа ввода/вывода:

```sql
EXPLAIN (ANALYZE, BUFFERS)
SELECT e.equipment_name,
       SUM(p.tons_mined) AS total_tons,
       SUM(p.fuel_consumed_l) AS total_fuel,
       SUM(p.operating_hours) AS total_hours
FROM fact_production p
JOIN dim_equipment e ON p.equipment_id = e.equipment_id
WHERE p.date_id BETWEEN 20240301 AND 20240331
GROUP BY e.equipment_name
ORDER BY total_tons DESC;
```

4. Определите узкое место запроса. Ответьте на вопросы:
   - Какой тип сканирования используется для `fact_production`?
   - Какой тип соединения (Join) выбран планировщиком?
   - Где тратится больше всего времени?
   - Сколько страниц (buffers) прочитано?

<details>
<summary>Подсказка: на что обращать внимание</summary>

- Ищите узел с наибольшим `actual time`
- `Buffers: shared hit` -- страницы из кеша; `shared read` -- страницы с диска
- Если `Seq Scan` на `fact_production` -- это потенциальное место для индекса
- Сравните `rows` (оценку) и `actual rows` (реальность) -- большое расхождение говорит о неактуальной статистике

</details>

**Ожидаемый результат:** Три варианта плана выполнения с нарастающей детализацией. Основное узкое место -- сканирование `fact_production` с фильтрацией по `date_id`.

---

## Задание 3. Оптимизация поиска по расходу топлива

**Тема модуля:** 7.2 -- Избирательность; 7.5 -- B-tree индекс

**Бизнес-задача:** Диспетчер хочет быстро находить смены с аномально высоким расходом топлива (более 80 литров) для расследования причин перерасхода. Такие смены составляют небольшую долю от общего числа.

**Требования:**

1. Зафиксируйте план запроса **до** создания индекса:

```sql
EXPLAIN ANALYZE
SELECT p.date_id, e.equipment_name, o.last_name, p.fuel_consumed_l
FROM fact_production p
JOIN dim_equipment e ON p.equipment_id = e.equipment_id
JOIN dim_operator o ON p.operator_id = o.operator_id
WHERE p.fuel_consumed_l > 80
ORDER BY p.fuel_consumed_l DESC;
```

2. Оцените избирательность (selectivity) условия `fuel_consumed_l > 80`:

```sql
SELECT
    COUNT(*) AS total_rows,
    COUNT(*) FILTER (WHERE fuel_consumed_l > 80) AS matching_rows,
    ROUND(
        COUNT(*) FILTER (WHERE fuel_consumed_l > 80)::numeric /
        COUNT(*) * 100, 2
    ) AS selectivity_pct
FROM fact_production;
```

3. Создайте B-tree индекс на столбец `fuel_consumed_l`.

4. Повторите запрос из п.1 с `EXPLAIN ANALYZE` и сравните планы.

5. Ответьте на вопрос: если избирательность составляет более 20-30%, почему PostgreSQL может продолжить использовать `Seq Scan` даже после создания индекса?

<details>
<summary>Подсказка: создание индекса</summary>

```sql
CREATE INDEX idx_prod_fuel
ON fact_production(fuel_consumed_l);
```

</details>

<details>
<summary>Подсказка: ответ на вопрос</summary>

Планировщик PostgreSQL оценивает стоимость `Index Scan` и `Seq Scan`. Если условие `fuel_consumed_l > 80` возвращает значительную долю строк (низкая избирательность), то `Seq Scan` последовательно читает страницы, что может быть быстрее, чем множество случайных обращений через индекс (random I/O). Эмпирическое правило: индекс эффективен, когда возвращается менее ~10-15% строк таблицы.

</details>

**Ожидаемый результат:** При высокой избирательности (малая доля строк) -- переключение на `Index Scan` или `Bitmap Index Scan`. При низкой избирательности -- планировщик может оставить `Seq Scan`.

---

## Задание 4. Частичный индекс для аварийной телеметрии

**Тема модуля:** 7.5 -- B-tree индекс (частичные индексы)

**Бизнес-задача:** Система мониторинга MES должна мгновенно показывать аварийные показания датчиков. Аварийные показания (`is_alarm = TRUE`) составляют менее 2% от всех данных телеметрии. Полный индекс будет неоправданно большим.

**Требования:**

1. Зафиксируйте план для запроса:

```sql
EXPLAIN ANALYZE
SELECT t.telemetry_id, t.date_id, t.equipment_id,
       t.sensor_id, t.sensor_value
FROM fact_equipment_telemetry t
WHERE t.date_id = 20240315
  AND t.is_alarm = TRUE;
```

2. Создайте **частичный индекс** (partial index), оптимальный для этого запроса.

3. Создайте **полный индекс** на те же столбцы (без `WHERE`) для сравнения.

4. Сравните размеры частичного и полного индексов:

```sql
SELECT indexrelname,
       pg_size_pretty(pg_relation_size(indexrelid)) AS size
FROM pg_stat_user_indexes
WHERE indexrelname IN ('idx_telemetry_alarm_partial', 'idx_telemetry_alarm_full')
ORDER BY pg_relation_size(indexrelid);
```

5. Повторите запрос из п.1 и убедитесь, что используется частичный индекс.

<details>
<summary>Подсказка: частичный индекс</summary>

```sql
-- Частичный индекс -- только для строк с is_alarm = TRUE
CREATE INDEX idx_telemetry_alarm_partial
ON fact_equipment_telemetry(date_id)
WHERE is_alarm = TRUE;

-- Полный индекс для сравнения
CREATE INDEX idx_telemetry_alarm_full
ON fact_equipment_telemetry(date_id, is_alarm);
```

</details>

<details>
<summary>Подсказка: почему частичный индекс лучше</summary>

Частичный индекс содержит только строки, удовлетворяющие условию `WHERE is_alarm = TRUE`. Поскольку аварийных показаний менее 2%, индекс будет в ~50 раз меньше полного. Это экономит дисковое пространство, память (буферный кеш), и ускоряет операции INSERT (обновляется только при вставке аварийных строк).

</details>

**Ожидаемый результат:** Частичный индекс значительно меньше полного. В плане запроса виден `Index Scan using idx_telemetry_alarm_partial`.

---

## Задание 5. Композитный индекс для отчета по добыче

**Тема модуля:** 7.5 -- B-tree индекс (композитные индексы, правило левого префикса)

**Бизнес-задача:** Начальник участка ежедневно запрашивает данные о добыче конкретного оборудования за определенный период. Запрос фильтрует по `equipment_id` (равенство) и `date_id` (диапазон).

**Требования:**

1. Зафиксируйте план для запроса:

```sql
EXPLAIN ANALYZE
SELECT date_id, tons_mined, tons_transported,
       trips_count, operating_hours
FROM fact_production
WHERE equipment_id = 5
  AND date_id BETWEEN 20240301 AND 20240331;
```

2. Создайте композитный индекс `(equipment_id, date_id)`:

```sql
CREATE INDEX idx_prod_equip_date
ON fact_production(equipment_id, date_id);
```

3. Создайте композитный индекс с **обратным порядком** `(date_id, equipment_id)`:

```sql
CREATE INDEX idx_prod_date_equip
ON fact_production(date_id, equipment_id);
```

4. Выполните запрос из п.1 и определите, какой индекс PostgreSQL выбирает.

5. Проверьте, будет ли индекс `(equipment_id, date_id)` использован для запроса, фильтрующего **только** по `date_id`:

```sql
EXPLAIN ANALYZE
SELECT * FROM fact_production
WHERE date_id = 20240315;
```

6. Объясните правило левого префикса и удалите менее эффективный индекс.

<details>
<summary>Подсказка: правило левого префикса</summary>

Композитный индекс `(A, B)` эффективен для запросов:
- `WHERE A = ?` -- да (левый префикс)
- `WHERE A = ? AND B = ?` -- да
- `WHERE A = ? AND B > ?` -- да (сначала равенство, потом диапазон)
- `WHERE B = ?` -- **нет** (B не является левым префиксом)

Для запроса `WHERE equipment_id = 5 AND date_id BETWEEN ...`:
- Индекс `(equipment_id, date_id)` -- оптимален: сначала находит equipment_id=5, потом сканирует диапазон date_id
- Индекс `(date_id, equipment_id)` -- менее эффективен: сканирует весь диапазон дат, фильтруя по equipment_id

</details>

**Ожидаемый результат:** Индекс `(equipment_id, date_id)` эффективнее для данного запроса. Индекс `(date_id, equipment_id)` не используется для запроса только по `date_id` без указания `equipment_id` в `WHERE`, но индекс `(equipment_id, date_id)` также не используется для запроса только по `date_id`.

---

## Задание 6. Индекс по выражению для поиска операторов

**Тема модуля:** 7.5 -- B-tree индекс (индексы по выражению)

**Бизнес-задача:** Кадровая служба ищет операторов по фамилии. Пользователи вводят фамилии в произвольном регистре (например, «петров», «ПЕТРОВ», «Петров»). Поиск должен быть нечувствителен к регистру.

**Требования:**

1. Выполните запрос и зафиксируйте план:

```sql
EXPLAIN ANALYZE
SELECT operator_id, last_name, first_name,
       middle_name, position, qualification
FROM dim_operator
WHERE LOWER(last_name) = 'петров';
```

2. Создайте индекс по выражению `LOWER(last_name)`.

3. Повторите запрос и убедитесь, что индекс используется.

4. Проверьте: будет ли индекс использован для запроса **без** `LOWER`?

```sql
EXPLAIN ANALYZE
SELECT operator_id, last_name, first_name
FROM dim_operator
WHERE last_name = 'Петров';
```

5. Проверьте: будет ли индекс использован для запроса с `UPPER`?

```sql
EXPLAIN ANALYZE
SELECT operator_id, last_name, first_name
FROM dim_operator
WHERE UPPER(last_name) = 'ПЕТРОВ';
```

<details>
<summary>Подсказка: создание индекса</summary>

```sql
CREATE INDEX idx_operator_lower_lastname
ON dim_operator (LOWER(last_name));
```

</details>

<details>
<summary>Подсказка: ответы на вопросы п.4 и п.5</summary>

- **п.4:** Нет. Индекс по выражению `LOWER(last_name)` используется только когда выражение в запросе **точно совпадает** с выражением индекса. Запрос `WHERE last_name = 'Петров'` -- это другое выражение.
- **п.5:** Нет. `UPPER(last_name)` -- это другое выражение, не `LOWER(last_name)`. Для него нужен отдельный индекс.

</details>

**Ожидаемый результат:** Индекс по выражению используется строго при совпадении выражения в запросе и в определении индекса. Запросы без `LOWER` или с `UPPER` его не задействуют.

---

## Задание 7. Покрывающий индекс для дашборда

**Тема модуля:** 7.5 -- B-tree индекс (покрывающие индексы, INCLUDE)

**Бизнес-задача:** На дашборде MES-системы отображается сводка добычи за дату: дата, оборудование, тоннаж. Этот запрос выполняется каждые 30 секунд и должен работать максимально быстро. Цель -- добиться `Index Only Scan`, когда данные читаются только из индекса, без обращения к таблице.

**Требования:**

1. Зафиксируйте план для запроса:

```sql
EXPLAIN ANALYZE
SELECT date_id, equipment_id, tons_mined
FROM fact_production
WHERE date_id = 20240315;
```

2. Создайте **покрывающий индекс** (с `INCLUDE`), чтобы запрос выполнялся через `Index Only Scan`:

```sql
CREATE INDEX idx_prod_date_cover
ON fact_production(date_id)
INCLUDE (equipment_id, tons_mined);
```

3. Выполните `VACUUM fact_production;` (для обновления карты видимости -- Visibility Map).

4. Повторите запрос и убедитесь в `Index Only Scan`.

5. Добавьте в `SELECT` столбец `fuel_consumed_l` и проверьте -- сохранится ли `Index Only Scan`?

```sql
EXPLAIN ANALYZE
SELECT date_id, equipment_id, tons_mined, fuel_consumed_l
FROM fact_production
WHERE date_id = 20240315;
```

6. Создайте расширенный покрывающий индекс и проверьте снова.

<details>
<summary>Подсказка: расширенный покрывающий индекс</summary>

```sql
CREATE INDEX idx_prod_date_cover_ext
ON fact_production(date_id)
INCLUDE (equipment_id, tons_mined, fuel_consumed_l);
```

После создания выполните `VACUUM fact_production;` и повторите запрос.

</details>

<details>
<summary>Подсказка: почему нужен VACUUM</summary>

`Index Only Scan` возможен только когда PostgreSQL уверен, что данные в индексе актуальны. Для этого используется **Visibility Map** -- битовая карта, показывающая, какие страницы таблицы полностью видимы для всех транзакций. `VACUUM` обновляет эту карту. Без `VACUUM` PostgreSQL будет вынужден обращаться к таблице для проверки видимости (Heap Fetches > 0).

</details>

**Ожидаемый результат:** Покрывающий индекс обеспечивает `Index Only Scan` -- данные читаются исключительно из индекса. При добавлении столбца, не входящего в `INCLUDE`, происходит переход на `Index Scan` (с обращением к таблице).

---

## Задание 8. BRIN-индекс для телеметрии

**Тема модуля:** 7.4 -- Типы индексов в PostgreSQL

**Бизнес-задача:** Таблица телеметрии содержит большой объем данных. Данные вставляются последовательно по датам (физический порядок коррелирует с `date_id`). Нужен компактный индекс для фильтрации по диапазону дат, который занимает минимум места.

**Требования:**

1. Проверьте размер существующего B-tree индекса `idx_fact_telemetry_date`:

```sql
SELECT indexrelname,
       pg_size_pretty(pg_relation_size(indexrelid)) AS size
FROM pg_stat_user_indexes
WHERE indexrelname = 'idx_fact_telemetry_date';
```

2. Создайте BRIN-индекс на столбец `date_id`:

```sql
CREATE INDEX idx_telemetry_date_brin
ON fact_equipment_telemetry USING brin (date_id)
WITH (pages_per_range = 128);
```

3. Сравните размеры B-tree и BRIN индексов:

```sql
SELECT indexrelname,
       pg_size_pretty(pg_relation_size(indexrelid)) AS size
FROM pg_stat_user_indexes
WHERE indexrelname IN ('idx_fact_telemetry_date', 'idx_telemetry_date_brin')
ORDER BY pg_relation_size(indexrelid) DESC;
```

4. Сравните производительность B-tree и BRIN на запросе с диапазоном дат:

```sql
-- Тест с B-tree (отключаем Bitmap Scan для чистоты эксперимента)
SET enable_bitmapscan = off;
EXPLAIN (ANALYZE, BUFFERS)
SELECT * FROM fact_equipment_telemetry
WHERE date_id BETWEEN 20240301 AND 20240331;
RESET enable_bitmapscan;

-- Тест с BRIN (отключаем Index Scan)
SET enable_indexscan = off;
EXPLAIN (ANALYZE, BUFFERS)
SELECT * FROM fact_equipment_telemetry
WHERE date_id BETWEEN 20240301 AND 20240331;
RESET enable_indexscan;
```

5. Заполните таблицу сравнения:

| Характеристика | B-tree | BRIN |
|----------------|--------|------|
| Размер индекса | ? | ? |
| Время выполнения (мс) | ? | ? |
| Buffers прочитано | ? | ? |
| Тип сканирования | ? | ? |

<details>
<summary>Подсказка: когда BRIN эффективен</summary>

BRIN (Block Range Index) хранит минимум и максимум значений для группы физических страниц (block range). Он эффективен, когда:
- Данные физически упорядочены по индексируемому столбцу (корреляция близка к 1.0)
- Таблица очень большая
- Нужен компактный индекс для диапазонных запросов

Проверить корреляцию можно:
```sql
SELECT attname, correlation
FROM pg_stats
WHERE tablename = 'fact_equipment_telemetry'
  AND attname = 'date_id';
```

Значение `correlation` близкое к 1.0 или -1.0 означает сильную физическую упорядоченность.

</details>

**Ожидаемый результат:** BRIN-индекс в десятки раз меньше B-tree, но при запросах может быть несколько медленнее (читает лишние страницы). Идеален для больших таблиц с естественной сортировкой.

---

## Задание 9. Анализ влияния индексов на INSERT

**Тема модуля:** 7.6 -- Влияние индексов на INSERT/UPDATE/DELETE

**Бизнес-задача:** ETL-процесс загружает данные о добыче каждую смену. Администратор хочет понять, как количество индексов влияет на скорость загрузки данных, чтобы оптимизировать окно ETL.

**Требования:**

1. Подсчитайте текущее количество индексов на таблице `fact_production`:

```sql
SELECT COUNT(*) AS index_count
FROM pg_indexes
WHERE tablename = 'fact_production';
```

2. Замерьте время INSERT с текущими индексами:

```sql
EXPLAIN ANALYZE
INSERT INTO fact_production
    (date_id, shift_id, mine_id, shaft_id, equipment_id,
     operator_id, location_id, ore_grade_id,
     tons_mined, tons_transported, trips_count,
     distance_km, fuel_consumed_l, operating_hours)
VALUES
    (20240401, 1, 1, 1, 1, 1, 1, 1,
     120.50, 115.00, 8, 12.5, 45.2, 7.5);
```

3. Создайте 3 дополнительных индекса на `fact_production`:

```sql
CREATE INDEX idx_test_1 ON fact_production(tons_mined);
CREATE INDEX idx_test_2 ON fact_production(fuel_consumed_l, operating_hours);
CREATE INDEX idx_test_3 ON fact_production(date_id, shift_id, mine_id);
```

4. Подсчитайте новое количество индексов и повторите INSERT:

```sql
SELECT COUNT(*) AS index_count
FROM pg_indexes
WHERE tablename = 'fact_production';

EXPLAIN ANALYZE
INSERT INTO fact_production
    (date_id, shift_id, mine_id, shaft_id, equipment_id,
     operator_id, location_id, ore_grade_id,
     tons_mined, tons_transported, trips_count,
     distance_km, fuel_consumed_l, operating_hours)
VALUES
    (20240401, 1, 1, 1, 1, 1, 1, 1,
     130.00, 125.00, 9, 14.0, 50.1, 8.0);
```

5. Сравните время выполнения INSERT и заполните таблицу:

| Метрика | До (N индексов) | После (N+3 индекса) |
|---------|-----------------|----------------------|
| Кол-во индексов | ? | ? |
| Время INSERT (мс) | ? | ? |

6. Ответьте на вопрос: как бы вы организовали массовую загрузку 10 000+ строк для минимизации времени?

<details>
<summary>Подсказка: стратегия массовой загрузки</summary>

Оптимальная стратегия для массовой загрузки данных:

1. **Удалить индексы** (кроме PRIMARY KEY и UNIQUE, если нужна проверка уникальности)
2. **Загрузить данные** через `COPY` или пакетный `INSERT`
3. **Пересоздать индексы** (PostgreSQL строит индекс одним проходом -- быстрее, чем инкрементальные вставки)
4. **Выполнить `ANALYZE`** для обновления статистики

Дополнительные приемы:
- Использовать `COPY ... FROM` вместо `INSERT`
- Увеличить `maintenance_work_mem` перед пересозданием индексов
- Отключить `fsync` на время загрузки (только для некритичных сред)

</details>

**Ожидаемый результат:** Время INSERT увеличивается с ростом числа индексов, так как каждый индекс обновляется при вставке.

---

## Задание 10. Комплексная оптимизация: кейс «Руда+»

**Тема модуля:** все темы модуля 7

**Бизнес-задача:** Вам поручено оптимизировать пять наиболее частых запросов аналитической системы «Руда+». Необходимо предложить стратегию индексирования -- не более 7 новых индексов на все 5 запросов. Каждый индекс должен быть обоснован.

**Запросы:**

**Запрос 1.** Суммарная добыча по шахте за месяц:

```sql
SELECT m.mine_name,
       SUM(p.tons_mined) AS total_tons,
       SUM(p.operating_hours) AS total_hours
FROM fact_production p
JOIN dim_mine m ON p.mine_id = m.mine_id
WHERE p.date_id BETWEEN 20240301 AND 20240331
GROUP BY m.mine_name;
```

**Запрос 2.** Средний показатель качества руды по сорту за квартал:

```sql
SELECT g.grade_name,
       AVG(q.fe_content) AS avg_fe,
       AVG(q.sio2_content) AS avg_sio2,
       COUNT(*) AS samples
FROM fact_ore_quality q
JOIN dim_ore_grade g ON q.ore_grade_id = g.ore_grade_id
WHERE q.date_id BETWEEN 20240101 AND 20240331
GROUP BY g.grade_name;
```

**Запрос 3.** Топ-5 оборудования по длительности внеплановых простоев:

```sql
SELECT e.equipment_name,
       SUM(dt.duration_min) AS total_downtime_min,
       COUNT(*) AS incidents
FROM fact_equipment_downtime dt
JOIN dim_equipment e ON dt.equipment_id = e.equipment_id
WHERE dt.is_planned = FALSE
  AND dt.date_id BETWEEN 20240301 AND 20240331
GROUP BY e.equipment_name
ORDER BY total_downtime_min DESC
LIMIT 5;
```

**Запрос 4.** Последние аварийные показания по оборудованию:

```sql
SELECT t.date_id, t.time_id, t.sensor_id,
       t.sensor_value, t.quality_flag
FROM fact_equipment_telemetry t
WHERE t.equipment_id = 5
  AND t.is_alarm = TRUE
ORDER BY t.date_id DESC, t.time_id DESC
LIMIT 20;
```

**Запрос 5.** Добыча конкретного оператора за неделю:

```sql
SELECT p.date_id, e.equipment_name,
       p.tons_mined, p.trips_count, p.operating_hours
FROM fact_production p
JOIN dim_equipment e ON p.equipment_id = e.equipment_id
WHERE p.operator_id = 3
  AND p.date_id BETWEEN 20240311 AND 20240317
ORDER BY p.date_id;
```

**Требования:**

1. Для каждого запроса зафиксируйте текущий план выполнения (`EXPLAIN ANALYZE`).

2. Предложите индексы (не более 7 новых индексов на все 5 запросов). Для каждого индекса укажите:
   - Какой запрос (или запросы) он ускоряет
   - Тип индекса (B-tree, частичный, покрывающий и т.д.)
   - Обоснование выбора столбцов и их порядка

3. Создайте предложенные индексы.

4. Повторите запросы и зафиксируйте улучшение.

5. Заполните итоговую таблицу:

| Запрос | Время до (мс) | Время после (мс) | Созданный индекс | Тип сканирования до | Тип сканирования после |
|--------|---------------|-------------------|-------------------|---------------------|----------------------|
| 1 | ? | ? | ? | ? | ? |
| 2 | ? | ? | ? | ? | ? |
| 3 | ? | ? | ? | ? | ? |
| 4 | ? | ? | ? | ? | ? |
| 5 | ? | ? | ? | ? | ? |

<details>
<summary>Подсказка: рекомендуемые индексы</summary>

```sql
-- Для запроса 1: диапазон по date_id + join по mine_id
CREATE INDEX idx_prod_date_mine
ON fact_production(date_id, mine_id);

-- Для запроса 2: диапазон по date_id в fact_ore_quality
CREATE INDEX idx_quality_date
ON fact_ore_quality(date_id);

-- Для запроса 3: частичный индекс для внеплановых простоев
CREATE INDEX idx_downtime_unplanned
ON fact_equipment_downtime(date_id, equipment_id)
WHERE is_planned = FALSE;

-- Для запроса 4: композитный + частичный для аварий
CREATE INDEX idx_telemetry_equip_alarm
ON fact_equipment_telemetry(equipment_id, date_id DESC, time_id DESC)
WHERE is_alarm = TRUE;

-- Для запроса 5: оператор + дата (сначала равенство, потом диапазон)
CREATE INDEX idx_prod_operator_date
ON fact_production(operator_id, date_id);
```

Это 5 индексов. Если один из запросов уже хорошо работает с существующими индексами -- можно обойтись меньшим числом.

Принципы:
- Один индекс может обслуживать несколько запросов (левый префикс)
- Частичные индексы -- для редких условий (`is_planned = FALSE`, `is_alarm = TRUE`)
- Порядок столбцов: сначала равенство, потом диапазон
- Не создавайте дублирующие индексы (проверьте существующие)

</details>

**Ожидаемый результат:** Комплексная стратегия индексирования с обоснованием каждого индекса. Улучшение времени выполнения для всех 5 запросов.

---

## Очистка после лабораторной

После завершения работы удалите все созданные индексы и тестовые данные:

```sql
-- ============================================================
-- Удаление индексов, созданных в ходе лабораторной работы
-- ============================================================

-- Задание 3
DROP INDEX IF EXISTS idx_prod_fuel;

-- Задание 4
DROP INDEX IF EXISTS idx_telemetry_alarm_partial;
DROP INDEX IF EXISTS idx_telemetry_alarm_full;

-- Задание 5
DROP INDEX IF EXISTS idx_prod_equip_date;
DROP INDEX IF EXISTS idx_prod_date_equip;

-- Задание 6
DROP INDEX IF EXISTS idx_operator_lower_lastname;

-- Задание 7
DROP INDEX IF EXISTS idx_prod_date_cover;
DROP INDEX IF EXISTS idx_prod_date_cover_ext;

-- Задание 8
DROP INDEX IF EXISTS idx_telemetry_date_brin;

-- Задание 9
DROP INDEX IF EXISTS idx_test_1;
DROP INDEX IF EXISTS idx_test_2;
DROP INDEX IF EXISTS idx_test_3;

-- Задание 10
DROP INDEX IF EXISTS idx_prod_date_mine;
DROP INDEX IF EXISTS idx_quality_date;
DROP INDEX IF EXISTS idx_downtime_unplanned;
DROP INDEX IF EXISTS idx_telemetry_equip_alarm;
DROP INDEX IF EXISTS idx_prod_operator_date;

-- ============================================================
-- Удаление тестовых строк
-- ============================================================
DELETE FROM fact_production
WHERE date_id = 20240401;
```

---

## Критерии оценки

| Критерий | Макс. баллы | Описание |
|----------|-------------|----------|
| Задание 1. Анализ существующих индексов | 1 | Корректный вывод списка, размеров и статистики индексов |
| Задание 2. Анализ плана выполнения | 1 | Правильная интерпретация EXPLAIN, EXPLAIN ANALYZE, EXPLAIN (ANALYZE, BUFFERS) |
| Задание 3. Оптимизация по расходу топлива | 1 | Создание индекса, сравнение планов, объяснение избирательности |
| Задание 4. Частичный индекс | 1 | Создание частичного индекса, сравнение размеров с полным |
| Задание 5. Композитный индекс | 1.5 | Два индекса с разным порядком столбцов, объяснение правила левого префикса |
| Задание 6. Индекс по выражению | 1 | Индекс на LOWER(), проверка с разными выражениями |
| Задание 7. Покрывающий индекс | 1.5 | Index Only Scan, понимание роли INCLUDE и VACUUM |
| Задание 8. BRIN-индекс | 1.5 | Сравнение B-tree и BRIN, заполненная таблица сравнения |
| Задание 9. Влияние на INSERT | 1 | Замеры времени до и после, стратегия массовой загрузки |
| Задание 10. Комплексная оптимизация | 2.5 | Не более 7 индексов, обоснование, заполненная итоговая таблица |
| **Итого** | **13** | |

### Шкала оценивания

| Баллы | Оценка |
|-------|--------|
| 11.5--13 | Отлично |
| 9--11 | Хорошо |
| 6.5--8.5 | Удовлетворительно |
| < 6.5 | Необходима доработка |
