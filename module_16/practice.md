# Практическая работа — Модуль 16

## Программирование при помощи SQL

**Продолжительность:** 35 минут
**Инструменты:** Yandex Managed Service for PostgreSQL
**Предприятие:** «Руда+» — добыча железной руды
**Файл с примерами:** `examples.sql`

---

## Предварительные требования

1. База данных «Руда+» развёрнута на PostgreSQL (скрипты `01_create_schema.sql`, `02_insert_dimensions.sql`, `03_insert_facts.sql` из каталога `common/scripts/`)
2. Клиент SQL (DBeaver, pgAdmin или psql) подключён к PostgreSQL
3. Файл `examples.sql` открыт для справки

---

## Часть 1. Анонимные блоки и переменные (10 мин)

### Шаг 1.1. Первый анонимный блок

Выполните простой блок для проверки подключения:

```sql
DO $$
BEGIN
    RAISE NOTICE 'Подключение к БД «Руда+» успешно!';
    RAISE NOTICE 'Сервер: %, Версия: %', current_setting('server_version'), version();
END;
$$;
```

**Что наблюдаем:** В панели сообщений (Messages) появится текст уведомления. Это основной способ вывода информации в PL/pgSQL.

### Шаг 1.2. Переменные и SELECT INTO

Объявим переменные и заполним их данными из таблиц:

```sql
DO $$
DECLARE
    v_mine_count    INT;
    v_equip_count   INT;
    v_latest_date   INT;
    v_latest_full   DATE;
BEGIN
    -- Получаем статистику
    SELECT COUNT(*) INTO v_mine_count FROM dim_mine;
    SELECT COUNT(*) INTO v_equip_count FROM dim_equipment;

    -- Последняя дата в данных
    SELECT MAX(date_id) INTO v_latest_date FROM fact_production;
    SELECT full_date INTO v_latest_full
    FROM dim_date WHERE date_id = v_latest_date;

    RAISE NOTICE '===== Статистика БД «Руда+» =====';
    RAISE NOTICE 'Шахт: %', v_mine_count;
    RAISE NOTICE 'Единиц оборудования: %', v_equip_count;
    RAISE NOTICE 'Последняя дата данных: % (%)', v_latest_date, v_latest_full;
END;
$$;
```

**Выполните и запишите результат.**

### Шаг 1.3. Типы %TYPE и %ROWTYPE

Используем типы столбцов из таблиц, чтобы избежать несоответствия типов:

```sql
DO $$
DECLARE
    -- Тип из столбца таблицы
    v_mine_name dim_mine.mine_name%TYPE;
    -- Вся строка таблицы
    v_equipment dim_equipment%ROWTYPE;
BEGIN
    -- Получаем первую шахту
    SELECT mine_name INTO v_mine_name
    FROM dim_mine WHERE mine_id = 1;

    -- Получаем первое оборудование
    SELECT * INTO v_equipment
    FROM dim_equipment WHERE equipment_id = 1;

    RAISE NOTICE 'Шахта: %', v_mine_name;
    RAISE NOTICE 'Оборудование: % (ID: %, mine_id: %)',
        v_equipment.equipment_name,
        v_equipment.equipment_id,
        v_equipment.mine_id;
END;
$$;
```

> **Обсуждение:** Почему `%TYPE` безопаснее, чем явное указание типа `VARCHAR(100)`?

---

## Часть 2. Управление потоком: IF и CASE (10 мин)

### Шаг 2.1. IF / ELSIF / ELSE для классификации

Оценим эффективность каждой шахты за январь:

```sql
DO $$
DECLARE
    rec RECORD;
    v_status VARCHAR;
    v_target NUMERIC := 5000;  -- Целевая добыча на шахту за месяц
BEGIN
    RAISE NOTICE '===== Оценка шахт за январь 2025 =====';

    FOR rec IN
        SELECT
            m.mine_name,
            COALESCE(SUM(fp.tons_mined), 0) AS total_tons
        FROM dim_mine m
        LEFT JOIN fact_production fp ON fp.mine_id = m.mine_id
            AND fp.date_id BETWEEN 20250101 AND 20250131
        GROUP BY m.mine_name
        ORDER BY total_tons DESC
    LOOP
        IF rec.total_tons >= v_target THEN
            v_status := 'ПЛАН ВЫПОЛНЕН';
        ELSIF rec.total_tons >= v_target * 0.8 THEN
            v_status := 'БЛИЗКО К ПЛАНУ';
        ELSIF rec.total_tons >= v_target * 0.5 THEN
            v_status := 'ОТСТАВАНИЕ';
        ELSIF rec.total_tons > 0 THEN
            v_status := 'КРИТИЧНО';
        ELSE
            v_status := 'НЕТ ДАННЫХ';
        END IF;

        RAISE NOTICE '  % — % т [%]',
            rec.mine_name, rec.total_tons, v_status;
    END LOOP;
END;
$$;
```

**Выполните.** Обратите внимание на порядок проверки условий — от большего к меньшему.

### Шаг 2.2. CASE для определения типа оборудования

```sql
DO $$
DECLARE
    rec RECORD;
    v_role VARCHAR;
BEGIN
    FOR rec IN
        SELECT e.equipment_name, et.equipment_type_name
        FROM dim_equipment e
        JOIN dim_equipment_type et ON e.equipment_type_id = et.equipment_type_id
        LIMIT 10
    LOOP
        CASE rec.equipment_type_name
            WHEN 'ПДМ' THEN
                v_role := 'Погрузка руды в забое';
            WHEN 'Самосвал' THEN
                v_role := 'Транспортировка по горизонтам';
            WHEN 'Вагонетка' THEN
                v_role := 'Откатка по рельсам';
            WHEN 'Скиповый подъёмник' THEN
                v_role := 'Подъём руды на поверхность';
            ELSE
                v_role := 'Прочее оборудование';
        END CASE;

        RAISE NOTICE '% [%]: %', rec.equipment_name, rec.equipment_type_name, v_role;
    END LOOP;
END;
$$;
```

---

## Часть 3. Циклы (10 мин)

### Шаг 3.1. FOR — числовой диапазон

Посчитаем добычу по дням первой недели января:

```sql
DO $$
DECLARE
    v_day_prod NUMERIC;
    v_running_total NUMERIC := 0;
BEGIN
    RAISE NOTICE '===== Добыча по дням (01-07 января 2025) =====';

    FOR v_day IN 1..7 LOOP
        SELECT COALESCE(SUM(tons_mined), 0)
        INTO v_day_prod
        FROM fact_production
        WHERE date_id = 20250100 + v_day;

        v_running_total := v_running_total + v_day_prod;

        RAISE NOTICE '  День %: % т (нарастающий итог: % т)',
            LPAD(v_day::TEXT, 2, '0'), v_day_prod, v_running_total;
    END LOOP;

    RAISE NOTICE 'Итого за неделю: % т', v_running_total;
END;
$$;
```

### Шаг 3.2. WHILE — поиск дня выполнения плана

```sql
DO $$
DECLARE
    v_date_id       INT := 20250101;
    v_accumulated   NUMERIC := 0;
    v_target        NUMERIC := 10000;
    v_daily         NUMERIC;
    v_days          INT := 0;
BEGIN
    WHILE v_accumulated < v_target AND v_date_id <= 20250131
    LOOP
        SELECT COALESCE(SUM(tons_mined), 0)
        INTO v_daily
        FROM fact_production
        WHERE date_id = v_date_id;

        v_accumulated := v_accumulated + v_daily;
        v_days := v_days + 1;
        v_date_id := v_date_id + 1;
    END LOOP;

    IF v_accumulated >= v_target THEN
        RAISE NOTICE 'План % т выполнен за % дней (к дате %)',
            v_target, v_days, v_date_id - 1;
    ELSE
        RAISE NOTICE 'План НЕ выполнен: % т из % т за % дней',
            v_accumulated, v_target, v_days;
    END IF;
END;
$$;
```

### Шаг 3.3. FOREACH — работа с массивами

```sql
DO $$
DECLARE
    v_mine_ids INT[] := ARRAY[1, 2, 3];
    v_mid INT;
    v_name VARCHAR;
    v_tons NUMERIC;
BEGIN
    FOREACH v_mid IN ARRAY v_mine_ids
    LOOP
        SELECT m.mine_name, COALESCE(SUM(fp.tons_mined), 0)
        INTO v_name, v_tons
        FROM dim_mine m
        LEFT JOIN fact_production fp ON fp.mine_id = m.mine_id
            AND fp.date_id BETWEEN 20250101 AND 20250131
        WHERE m.mine_id = v_mid
        GROUP BY m.mine_name;

        RAISE NOTICE 'Шахта «%»: % т', v_name, v_tons;
    END LOOP;
END;
$$;
```

> **Обсуждение:** В каком случае FOREACH по массиву удобнее, чем FOR по запросу?

---

## Часть 4. Курсоры (5 мин)

### Шаг 4.1. Курсор для пакетного формирования отчёта

```sql
-- Таблица для отчёта
CREATE TABLE IF NOT EXISTS report_daily_production (
    report_date       DATE,
    mine_id           INT,
    mine_name         VARCHAR(100),
    total_tons        NUMERIC(12,2),
    total_trips       INT,
    avg_tons_per_trip NUMERIC(10,2),
    created_at        TIMESTAMP DEFAULT NOW()
);

DO $$
DECLARE
    cur_dates CURSOR FOR
        SELECT DISTINCT date_id
        FROM fact_production
        WHERE date_id BETWEEN 20250101 AND 20250107
        ORDER BY date_id;
    v_rows INT;
    v_total_rows INT := 0;
BEGIN
    -- Очищаем старые данные
    DELETE FROM report_daily_production
    WHERE report_date BETWEEN '2025-01-01' AND '2025-01-07';

    FOR rec IN cur_dates LOOP
        INSERT INTO report_daily_production (
            report_date, mine_id, mine_name,
            total_tons, total_trips, avg_tons_per_trip
        )
        SELECT
            d.full_date, m.mine_id, m.mine_name,
            SUM(fp.tons_mined),
            SUM(fp.trips_count),
            ROUND(SUM(fp.tons_mined) / NULLIF(SUM(fp.trips_count), 0), 2)
        FROM fact_production fp
        JOIN dim_mine m ON fp.mine_id = m.mine_id
        JOIN dim_date d ON fp.date_id = d.date_id
        WHERE fp.date_id = rec.date_id
        GROUP BY d.full_date, m.mine_id, m.mine_name;

        GET DIAGNOSTICS v_rows = ROW_COUNT;
        v_total_rows := v_total_rows + v_rows;
        RAISE NOTICE 'Дата %: вставлено % записей', rec.date_id, v_rows;
    END LOOP;

    RAISE NOTICE 'Всего вставлено: % записей', v_total_rows;
END;
$$;

-- Проверяем результат
SELECT * FROM report_daily_production ORDER BY report_date, mine_id;
```

**Что наблюдаем:** Курсор обрабатывает каждую дату последовательно, позволяя выводить прогресс.

---

## Итоги практической работы

В ходе работы мы:

1. Освоили создание **анонимных блоков** DO $$ ... END $$
2. Работали с **переменными** различных типов, включая `%TYPE` и `%ROWTYPE`
3. Применили **условные конструкции** IF/ELSIF/ELSE и CASE для бизнес-логики
4. Использовали **циклы** FOR, WHILE и FOREACH для итеративной обработки
5. Применили **курсоры** для пакетного формирования отчётов

> **Для продвинутых:** Попробуйте объединить все части — создайте анонимный блок, который с помощью курсора обходит все шахты, для каждой вычисляет KPI через IF/CASE, и выводит итоговый отчёт через RAISE NOTICE.
