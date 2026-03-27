# Лабораторная работа — Модуль 7

## Введение в индексы

**Продолжительность:** 60 минут
**Формат:** самостоятельная работа
**Инструменты:** PostgreSQL (psql / DBeaver / pgAdmin)
**База данных:** «Руда+» (MES-система горнодобывающего предприятия)

---

## Общие указания

- Каждое задание требует создания индекса и демонстрации его эффективности через `EXPLAIN ANALYZE`.
- Сохраняйте все запросы в файл `lab_solutions.sql`.
- Для каждого задания фиксируйте:
  - План запроса **до** создания индекса
  - План запроса **после** создания индекса
  - Тип сканирования и время выполнения
- Задания расположены по возрастанию сложности.

---

## Задание 1. Анализ существующих индексов

**Бизнес-задача:** Администратору БД нужен обзор всех индексов в аналитической базе «Руда+».

**Требования:**

1. Выведите список всех индексов для таблиц `fact_production`, `fact_equipment_telemetry`, `fact_equipment_downtime` и `fact_ore_quality`. Для каждого индекса покажите: имя таблицы, имя индекса, определение (indexdef).

2. Для таблицы `fact_production` выведите размер каждого индекса и количество раз, когда он использовался.

3. Подсчитайте суммарный размер всех индексов для каждой факт-таблицы.

**Подсказка:**
```sql
SELECT tablename, indexname, indexdef
FROM pg_indexes
WHERE tablename IN ('fact_production', ...)
ORDER BY tablename, indexname;
```

**Ожидаемый результат:** Таблица со всеми индексами и их характеристиками.

---

## Задание 2. Оптимизация поиска по расходу топлива

**Бизнес-задача:** Диспетчер хочет быстро находить смены с аномально высоким расходом топлива (более 80 литров) для расследования причин.

**Требования:**

1. Выполните запрос и зафиксируйте план выполнения (EXPLAIN ANALYZE):
```sql
SELECT p.date_id, e.equipment_name, o.last_name, p.fuel_consumed_l
FROM fact_production p
JOIN dim_equipment e ON p.equipment_id = e.equipment_id
JOIN dim_operator o ON p.operator_id = o.operator_id
WHERE p.fuel_consumed_l > 80
ORDER BY p.fuel_consumed_l DESC;
```

2. Создайте подходящий индекс для ускорения этого запроса.

3. Повторите запрос и сравните планы выполнения.

**Вопрос:** Почему PostgreSQL может продолжить использовать Seq Scan даже после создания индекса? (Подсказка: подумайте о селективности.)

---

## Задание 3. Частичный индекс для аварийной телеметрии

**Бизнес-задача:** Система мониторинга должна мгновенно показывать аварийные показания датчиков за текущий день. Аварийные показания составляют менее 2% от всех данных.

**Требования:**

1. Зафиксируйте план для запроса:
```sql
SELECT t.telemetry_id, t.date_id, t.equipment_id,
       t.sensor_id, t.sensor_value
FROM fact_equipment_telemetry t
WHERE t.date_id = 20240315
  AND t.is_alarm = TRUE;
```

2. Создайте **частичный индекс**, который будет оптимален для этого запроса.

3. Повторите запрос и убедитесь, что используется ваш частичный индекс.

4. Сравните размер вашего частичного индекса с размером полного индекса `idx_fact_telemetry_date`.

**Ожидаемый результат:** Частичный индекс значительно меньше полного.

---

## Задание 4. Композитный индекс для отчёта по добыче

**Бизнес-задача:** Начальник участка ежедневно запрашивает данные о добыче конкретного оборудования за определённый период.

**Требования:**

1. Зафиксируйте план для запроса:
```sql
SELECT date_id, tons_mined, tons_transported,
       trips_count, operating_hours
FROM fact_production
WHERE equipment_id = 5
  AND date_id BETWEEN 20240301 AND 20240331;
```

2. Создайте композитный индекс `(equipment_id, date_id)`.

3. Создайте композитный индекс с обратным порядком `(date_id, equipment_id)`.

4. Выполните запрос и определите, какой индекс PostgreSQL выбирает. Объясните почему.

5. Удалите менее эффективный индекс.

---

## Задание 5. Индекс по выражению для поиска операторов

**Бизнес-задача:** Кадровая служба ищет операторов по фамилии, но пользователи вводят фамилии в разном регистре.

**Требования:**

1. Выполните запрос и зафиксируйте план:
```sql
SELECT operator_id, last_name, first_name,
       middle_name, position, qualification
FROM dim_operator
WHERE LOWER(last_name) = 'петров';
```

2. Создайте индекс по выражению `LOWER(last_name)`.

3. Повторите запрос и убедитесь, что индекс используется.

4. Проверьте: будет ли индекс использован для запроса `WHERE last_name = 'Петров'` (без LOWER)?

**Ожидаемый ответ на п. 4:** Нет, индекс по выражению используется только когда выражение в запросе точно совпадает.

---

## Задание 6. Покрывающий индекс для дашборда

**Бизнес-задача:** На дашборде MES-системы отображается сводка добычи за дату: дата, оборудование, тоннаж. Этот запрос выполняется каждые 30 секунд.

**Требования:**

1. Зафиксируйте план для запроса:
```sql
SELECT date_id, equipment_id, tons_mined
FROM fact_production
WHERE date_id = 20240315;
```

2. Создайте **покрывающий индекс** (с INCLUDE), чтобы запрос выполнялся через `Index Only Scan`.

3. Повторите запрос и убедитесь в `Index Only Scan`.

4. Добавьте в SELECT столбец `fuel_consumed_l` и проверьте: сохранится ли `Index Only Scan`?

**Объяснение:** Index Only Scan возможен, только если все запрашиваемые столбцы есть в индексе.

---

## Задание 7. BRIN-индекс для телеметрии

**Бизнес-задача:** Таблица телеметрии содержит миллионы строк. Данные вставляются последовательно по датам. Нужен компактный индекс для фильтрации по дате.

**Требования:**

1. Проверьте текущий B-tree индекс `idx_fact_telemetry_date`:
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

3. Сравните размеры B-tree и BRIN индексов.

4. Выполните запрос с фильтрацией по диапазону дат и сравните планы выполнения при использовании B-tree и BRIN:
```sql
-- Подсказка: чтобы заставить PostgreSQL использовать конкретный индекс:
SET enable_indexscan = off;  -- отключить Index Scan
SET enable_bitmapscan = on;  -- оставить Bitmap Scan

EXPLAIN ANALYZE
SELECT * FROM fact_equipment_telemetry
WHERE date_id BETWEEN 20240301 AND 20240331;

-- Верните настройки обратно:
RESET enable_indexscan;
RESET enable_bitmapscan;
```

**Ожидаемый результат:** BRIN-индекс значительно компактнее, но чуть медленнее при запросах.

---

## Задание 8. Оптимизация запроса по простоям

**Бизнес-задача:** Инженер по надёжности регулярно анализирует внеплановые простои конкретного оборудования за период, чтобы выявить закономерности.

**Требования:**

1. Зафиксируйте план для запроса:
```sql
SELECT d.date_id, e.equipment_name,
       r.reason_name, r.category,
       dt.duration_min, dt.comment
FROM fact_equipment_downtime dt
JOIN dim_date d ON dt.date_id = d.date_id
JOIN dim_equipment e ON dt.equipment_id = e.equipment_id
JOIN dim_downtime_reason r ON dt.reason_id = r.reason_id
WHERE dt.equipment_id = 3
  AND dt.date_id BETWEEN 20240101 AND 20240331
  AND dt.is_planned = FALSE
ORDER BY dt.duration_min DESC;
```

2. Создайте **один оптимальный индекс** для этого запроса. Обоснуйте выбор:
   - Тип индекса (B-tree, Hash, и т.д.)
   - Столбцы и их порядок
   - Использование WHERE (частичный индекс)

3. Повторите запрос и сравните планы.

**Подсказка:** Подумайте о правиле «сначала равенство, потом диапазон» и о частичном индексе для `is_planned = FALSE`.

---

## Задание 9. Анализ влияния индексов на INSERT

**Бизнес-задача:** ETL-процесс загружает данные о добыче. Нужно понять, как индексы влияют на скорость загрузки.

**Требования:**

1. Подсчитайте количество индексов на таблице `fact_production`:
```sql
SELECT COUNT(*) FROM pg_indexes
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

3. Создайте ещё 3 дополнительных индекса на `fact_production` (на любые столбцы).

4. Повторите INSERT и сравните время.

5. Удалите добавленные строки и индексы.

**Вопрос:** Как бы вы организовали массовую загрузку данных (10 000+ строк) для минимизации времени? (Подсказка: удалить индексы → загрузить → пересоздать.)

---

## Задание 10. Комплексная оптимизация: кейс «Руда+»

**Бизнес-задача:** Вам поручено оптимизировать пять наиболее частых запросов аналитической системы «Руда+». Предложите стратегию индексирования.

**Запросы:**

1. Суммарная добыча по шахте за месяц:
```sql
SELECT m.mine_name,
       SUM(p.tons_mined) AS total_tons,
       SUM(p.operating_hours) AS total_hours
FROM fact_production p
JOIN dim_mine m ON p.mine_id = m.mine_id
WHERE p.date_id BETWEEN 20240301 AND 20240331
GROUP BY m.mine_name;
```

2. Средний показатель качества руды по сорту за квартал:
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

3. Топ-5 оборудования по длительности внеплановых простоев:
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

4. Последние аварийные показания по оборудованию:
```sql
SELECT t.date_id, t.time_id, t.sensor_id,
       t.sensor_value, t.quality_flag
FROM fact_equipment_telemetry t
WHERE t.equipment_id = 5
  AND t.is_alarm = TRUE
ORDER BY t.date_id DESC, t.time_id DESC
LIMIT 20;
```

5. Добыча конкретного оператора за неделю:
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

1. Для каждого запроса зафиксируйте текущий план выполнения.
2. Предложите индексы (не более 7 новых индексов на все 5 запросов).
3. Создайте предложенные индексы.
4. Повторите запросы и зафиксируйте улучшение.
5. Заполните итоговую таблицу:

| Запрос | Время до (мс) | Время после (мс) | Созданный индекс | Тип сканирования |
|--------|---------------|-------------------|-------------------|-----------------|
| 1 | ? | ? | ? | ? |
| 2 | ? | ? | ? | ? |
| 3 | ? | ? | ? | ? |
| 4 | ? | ? | ? | ? |
| 5 | ? | ? | ? | ? |

**Подсказка по индексам:**
- Используйте частичные индексы, где это уместно
- Помните о правиле левого префикса
- Один индекс может быть полезен для нескольких запросов
- Не создавайте избыточные индексы

---

## Очистка после лабораторной

```sql
-- Удалите все индексы, созданные в ходе лабораторной работы
-- (кроме стандартных, созданных при создании схемы)

-- Пример:
-- DROP INDEX IF EXISTS idx_...;

-- Удалите тестовые строки, если вставляли
DELETE FROM fact_production
WHERE date_id = 20240401
  AND tons_mined = 120.50;
```

---

## Критерии оценки

| Критерий | Баллы |
|----------|-------|
| Задания 1–3 выполнены корректно | 3 |
| Задания 4–6 выполнены с правильным обоснованием | 3 |
| Задания 7–8 с анализом BRIN и частичных индексов | 2 |
| Задание 9 с выводами о влиянии на INSERT | 1 |
| Задание 10 с комплексной стратегией индексирования | 3 |
| **Итого** | **12** |
