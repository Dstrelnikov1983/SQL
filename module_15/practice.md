# Практическая работа — Модуль 15

## Выполнение хранимых процедур

**Продолжительность:** 40 минут
**Инструменты:** Yandex Managed Service for PostgreSQL (SQL) | Power BI + DAX Studio (DAX)
**Предприятие:** «Руда+» — добыча железной руды

---

## Предварительные требования

1. База данных «Руда+» развёрнута на PostgreSQL (скрипты `01_create_schema.sql`, `02_insert_dimensions.sql`, `03_insert_facts.sql` из каталога `common/scripts/`)
2. Клиент SQL (DBeaver, pgAdmin или psql) подключён к PostgreSQL
3. Модель данных импортирована в Power BI
4. DAX Studio установлен и подключён к модели Power BI
5. Файл `examples.sql` открыт для справки

---

## Часть 1. Скалярная функция — расчёт KPI

### Шаг 1.1. Создание функции классификации руды

```sql
-- Функция определяет сорт руды по содержанию железа (Fe)
CREATE OR REPLACE FUNCTION classify_ore_quality(
    p_fe_content NUMERIC
)
RETURNS VARCHAR
LANGUAGE plpgsql
IMMUTABLE
AS $$
BEGIN
    IF p_fe_content >= 65 THEN
        RETURN 'Высший сорт (богатая руда)';
    ELSIF p_fe_content >= 55 THEN
        RETURN 'Первый сорт';
    ELSIF p_fe_content >= 45 THEN
        RETURN 'Второй сорт';
    ELSIF p_fe_content >= 30 THEN
        RETURN 'Третий сорт (бедная руда)';
    ELSE
        RETURN 'Отходы (пустая порода)';
    END IF;
END;
$$;
```

**Выполните и убедитесь:** функция создана без ошибок.

### Шаг 1.2. Тестирование функции

```sql
-- Прямой вызов
SELECT classify_ore_quality(67.5);  -- Высший сорт
SELECT classify_ore_quality(52.0);  -- Второй сорт
SELECT classify_ore_quality(15.0);  -- Отходы
```

### Шаг 1.3. Использование функции в запросе

```sql
SELECT
    oq.sample_number,
    oq.fe_content,
    classify_ore_quality(oq.fe_content) AS quality_class,
    m.mine_name,
    d.full_date
FROM fact_ore_quality oq
JOIN dim_mine m ON oq.mine_id = m.mine_id
JOIN dim_date d ON oq.date_id = d.date_id
WHERE oq.date_id BETWEEN 20250101 AND 20250131
ORDER BY oq.fe_content DESC
LIMIT 20;
```

**Что наблюдаем:** каждая проба классифицирована функцией. Изменив логику в функции, мы автоматически обновим классификацию во всех отчётах.

> **Обсуждение:** Почему мы указали `IMMUTABLE`? Может ли результат функции измениться для одного и того же значения Fe?

---

## Часть 2. Табличная функция — отчёт по добыче

### Шаг 2.1. Создание функции с RETURNS TABLE

```sql
CREATE OR REPLACE FUNCTION get_production_report(
    p_date_from INT,
    p_date_to   INT,
    p_mine_id   INT DEFAULT NULL  -- NULL = все шахты
)
RETURNS TABLE (
    mine_name      VARCHAR,
    shift_name     VARCHAR,
    total_tons     NUMERIC,
    total_trips    BIGINT,
    avg_tons_trip  NUMERIC,
    equipment_cnt  BIGINT
)
LANGUAGE plpgsql
STABLE
AS $$
BEGIN
    RETURN QUERY
    SELECT
        m.mine_name,
        s.shift_name,
        ROUND(SUM(fp.tons_mined), 2),
        SUM(fp.trips_count)::BIGINT,
        ROUND(SUM(fp.tons_mined) / NULLIF(SUM(fp.trips_count), 0), 2),
        COUNT(DISTINCT fp.equipment_id)
    FROM fact_production fp
    JOIN dim_mine m  ON fp.mine_id = m.mine_id
    JOIN dim_shift s ON fp.shift_id = s.shift_id
    WHERE fp.date_id BETWEEN p_date_from AND p_date_to
      AND (p_mine_id IS NULL OR fp.mine_id = p_mine_id)
    GROUP BY m.mine_name, s.shift_name
    ORDER BY m.mine_name, s.shift_name;
END;
$$;
```

### Шаг 2.2. Вызов функции

```sql
-- Все шахты за январь
SELECT * FROM get_production_report(20250101, 20250131);

-- Конкретная шахта
SELECT * FROM get_production_report(20250101, 20250131, 2);

-- Именованные параметры
SELECT * FROM get_production_report(
    p_date_from := 20250101,
    p_date_to   := 20250131,
    p_mine_id   := 1
);
```

**Что наблюдаем:** функция работает как виртуальная таблица, параметры фильтруют данные.

### Шаг 2.3. Использование функции в JOIN

```sql
-- Соединяем результат функции с другими данными
SELECT
    pr.mine_name,
    pr.shift_name,
    pr.total_tons,
    pr.equipment_cnt,
    ROUND(pr.total_tons / NULLIF(pr.equipment_cnt, 0), 2) AS tons_per_equip
FROM get_production_report(20250101, 20250131) pr
WHERE pr.total_tons > 100
ORDER BY tons_per_equip DESC;
```

> **Обсуждение:** В каких случаях табличные функции удобнее, чем представления (VIEW)?

---

## Часть 3. Процедура с управлением транзакциями

### Шаг 3.1. Подготовка staging-таблицы

```sql
-- Создаём staging-таблицу для демонстрации
CREATE TABLE IF NOT EXISTS staging_production (
    LIKE fact_production INCLUDING DEFAULTS
);

-- Добавляем тестовые данные
INSERT INTO staging_production
SELECT * FROM fact_production
WHERE date_id = 20250115
LIMIT 10;
```

### Шаг 3.2. Создание процедуры загрузки

```sql
CREATE OR REPLACE PROCEDURE load_daily_production(
    p_date_id   INT,
    OUT p_deleted  INT,
    OUT p_inserted INT
)
LANGUAGE plpgsql
AS $$
BEGIN
    -- Шаг 1: Удаляем старые данные за дату
    DELETE FROM staging_production WHERE date_id = p_date_id;
    GET DIAGNOSTICS p_deleted = ROW_COUNT;
    RAISE NOTICE 'Удалено из staging: % строк', p_deleted;

    -- Фиксируем удаление
    COMMIT;

    -- Шаг 2: Копируем свежие данные
    INSERT INTO staging_production
    SELECT * FROM fact_production
    WHERE date_id = p_date_id;

    GET DIAGNOSTICS p_inserted = ROW_COUNT;
    RAISE NOTICE 'Загружено в staging: % строк', p_inserted;

    -- Фиксируем вставку
    COMMIT;
END;
$$;
```

### Шаг 3.3. Вызов процедуры

```sql
-- Вызов с получением OUT-параметров
CALL load_daily_production(20250115, NULL, NULL);
```

**Что наблюдаем:** процедура выполняет два COMMIT — промежуточную и финальную фиксацию. Если вставка провалится, удаление уже зафиксировано.

### Шаг 3.4. Сравнение с попыткой COMMIT в функции

```sql
-- Эта функция НЕ создастся (ошибка при вызове)
CREATE OR REPLACE FUNCTION test_commit_in_function()
RETURNS VOID LANGUAGE plpgsql AS $$
BEGIN
    INSERT INTO staging_production
    SELECT * FROM fact_production LIMIT 1;
    COMMIT;  -- ОШИБКА!
END;
$$;

-- Попытка вызова
SELECT test_commit_in_function();
-- ERROR: invalid transaction termination
```

**Что наблюдаем:** COMMIT запрещён в функциях — это ключевое отличие от процедур.

---

## Часть 4. Динамический SQL

### Шаг 4.1. Базовый EXECUTE

```sql
CREATE OR REPLACE FUNCTION count_rows(p_table_name TEXT)
RETURNS BIGINT
LANGUAGE plpgsql
AS $$
DECLARE
    v_count BIGINT;
BEGIN
    -- Безопасный динамический SQL: %I для идентификатора
    EXECUTE format('SELECT COUNT(*) FROM %I', p_table_name)
    INTO v_count;
    RETURN v_count;
END;
$$;
```

```sql
-- Проверяем
SELECT count_rows('fact_production');
SELECT count_rows('dim_mine');
SELECT count_rows('fact_equipment_telemetry');
```

### Шаг 4.2. Универсальная группировка

```sql
CREATE OR REPLACE FUNCTION production_by_dimension(
    p_dimension VARCHAR,  -- 'mine', 'shift', 'operator'
    p_date_from INT,
    p_date_to   INT
)
RETURNS TABLE (dimension_value VARCHAR, total_tons NUMERIC, avg_trips NUMERIC)
LANGUAGE plpgsql
AS $$
DECLARE
    v_join  TEXT;
    v_field TEXT;
BEGIN
    CASE p_dimension
        WHEN 'mine' THEN
            v_join  := 'JOIN dim_mine d ON fp.mine_id = d.mine_id';
            v_field := 'd.mine_name';
        WHEN 'shift' THEN
            v_join  := 'JOIN dim_shift d ON fp.shift_id = d.shift_id';
            v_field := 'd.shift_name';
        WHEN 'operator' THEN
            v_join  := 'JOIN dim_operator d ON fp.operator_id = d.operator_id';
            v_field := 'd.last_name || '' '' || d.first_name';
        ELSE
            RAISE EXCEPTION 'Неизвестное измерение: %. Допустимые: mine, shift, operator', p_dimension;
    END CASE;

    RETURN QUERY EXECUTE format(
        'SELECT %s::VARCHAR AS dimension_value,
                ROUND(SUM(fp.tons_mined), 2) AS total_tons,
                ROUND(AVG(fp.trips_count), 2) AS avg_trips
         FROM fact_production fp %s
         WHERE fp.date_id BETWEEN $1 AND $2
         GROUP BY 1 ORDER BY 2 DESC',
        v_field, v_join
    ) USING p_date_from, p_date_to;
END;
$$;
```

```sql
-- Группировка по разным измерениям
SELECT * FROM production_by_dimension('mine', 20250101, 20250131);
SELECT * FROM production_by_dimension('shift', 20250101, 20250131);
SELECT * FROM production_by_dimension('operator', 20250101, 20250131);
```

**Что наблюдаем:** одна функция формирует отчёт по любому измерению. Имена таблиц и столбцов подставляются безопасно через CASE (не из пользовательского ввода).

### Шаг 4.3. Демонстрация SQL-инъекции

```sql
-- ОПАСНЫЙ пример (для демонстрации):
CREATE OR REPLACE FUNCTION unsafe_count(p_table TEXT)
RETURNS BIGINT LANGUAGE plpgsql AS $$
DECLARE v_count BIGINT;
BEGIN
    -- НЕ ДЕЛАЙТЕ ТАК! Прямая конкатенация
    EXECUTE 'SELECT COUNT(*) FROM ' || p_table INTO v_count;
    RETURN v_count;
END;
$$;

-- Нормальный вызов
SELECT unsafe_count('dim_mine');

-- Попытка инъекции (не выполняйте на реальных данных!)
-- SELECT unsafe_count('dim_mine; DROP TABLE staging_production; --');
```

> **Обсуждение:** Какие данные на предприятии «Руда+» были бы наиболее критичными при SQL-инъекции? Как это может повлиять на производственный процесс?

---

## Часть 5. Сравнение с DAX (Power BI)

### Шаг 5.1. Мера — аналог скалярной функции

Откройте DAX Studio и выполните:

```dax
// Мера для классификации руды (аналог classify_ore_quality)
EVALUATE
ADDCOLUMNS(
    TOPN(20,
        fact_ore_quality,
        fact_ore_quality[fe_content], DESC
    ),
    "QualityClass",
        SWITCH(
            TRUE(),
            fact_ore_quality[fe_content] >= 65, "Высший сорт (богатая руда)",
            fact_ore_quality[fe_content] >= 55, "Первый сорт",
            fact_ore_quality[fe_content] >= 45, "Второй сорт",
            fact_ore_quality[fe_content] >= 30, "Третий сорт (бедная руда)",
            "Отходы (пустая порода)"
        )
)
```

### Шаг 5.2. Вычисляемая таблица — аналог табличной функции

```dax
// Аналог get_production_report()
// В DAX параметризация — через контекст фильтра
EVALUATE
ADDCOLUMNS(
    SUMMARIZE(
        fact_production,
        dim_mine[mine_name],
        dim_shift[shift_name]
    ),
    "TotalTons",
        CALCULATE(SUM(fact_production[tons_mined])),
    "TotalTrips",
        CALCULATE(SUM(fact_production[trips_count])),
    "AvgTonsPerTrip",
        DIVIDE(
            CALCULATE(SUM(fact_production[tons_mined])),
            CALCULATE(SUM(fact_production[trips_count])),
            0
        ),
    "EquipmentCount",
        CALCULATE(DISTINCTCOUNT(fact_production[equipment_id]))
)
ORDER BY [TotalTons] DESC
```

**Что наблюдаем:** В DAX нет параметров в привычном понимании — вместо них используются слайсеры (фильтры) в отчёте Power BI. Для программной параметризации используются What-If параметры.

> **Обсуждение:** Какие преимущества и недостатки у каждого подхода (SQL-функции vs DAX-меры)?

---

## Часть 6. Очистка

```sql
-- Удаляем тестовые объекты (при необходимости)
DROP TABLE IF EXISTS staging_production;
DROP FUNCTION IF EXISTS unsafe_count(TEXT);
DROP FUNCTION IF EXISTS test_commit_in_function();
```

---

## Контрольные вопросы

1. В чём главное отличие FUNCTION от PROCEDURE в PostgreSQL?
2. Когда следует использовать RETURNS TABLE, а когда RETURNS SETOF?
3. Почему `format('%I', ...)` безопаснее, чем конкатенация строк?
4. Что такое волатильность функции и как она влияет на производительность?
5. Как реализовать параметризованный отчёт в DAX, если нет хранимых процедур?
