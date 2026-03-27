# Практическая работа — Модуль 17

## Применение обработки ошибок

**Продолжительность:** 25 минут
**Инструменты:** Yandex Managed Service for PostgreSQL
**Предприятие:** «Руда+» — добыча железной руды
**Файл с примерами:** `examples.sql`

---

## Предварительные требования

1. База данных «Руда+» развёрнута на PostgreSQL
2. Клиент SQL (DBeaver, pgAdmin или psql) подключён к PostgreSQL
3. Файл `examples.sql` открыт для справки

---

## Часть 1. Базовый блок EXCEPTION (8 мин)

### Шаг 1.1. Обработка деления на ноль

Выполните блок, который демонстрирует перехват ошибки:

```sql
DO $$
DECLARE
    v_hours    NUMERIC := 0;
    v_tons     NUMERIC := 150;
    v_per_hour NUMERIC;
BEGIN
    -- Это вызовет ошибку division_by_zero
    v_per_hour := v_tons / v_hours;
    RAISE NOTICE 'Производительность: % т/ч', v_per_hour;
EXCEPTION
    WHEN division_by_zero THEN
        RAISE NOTICE 'Ошибка: деление на ноль! Рабочие часы = 0';
        RAISE NOTICE 'Код ошибки: %', SQLSTATE;
END;
$$;
```

**Что наблюдаем:** Вместо аварийного завершения блок перехватывает ошибку и выводит понятное сообщение.

### Шаг 1.2. Обработка нескольких типов ошибок

```sql
DO $$
DECLARE
    v_mine_id INT;
BEGIN
    -- Попытка вставить дублирующую запись
    INSERT INTO dim_mine (mine_id, mine_name, location, depth_meters, status)
    VALUES (1, 'Тестовая шахта', 'Тест', 100, 'active');

    RAISE NOTICE 'Запись добавлена успешно';
EXCEPTION
    WHEN unique_violation THEN
        RAISE NOTICE 'Ошибка: запись с таким ID уже существует!';
        RAISE NOTICE 'SQLSTATE: %', SQLSTATE;
        RAISE NOTICE 'Сообщение: %', SQLERRM;
    WHEN not_null_violation THEN
        RAISE NOTICE 'Ошибка: обязательное поле не заполнено!';
    WHEN OTHERS THEN
        RAISE NOTICE 'Неожиданная ошибка: % [%]', SQLERRM, SQLSTATE;
END;
$$;
```

**Запишите:** какой код SQLSTATE был выведен?

### Шаг 1.3. WHEN OTHERS с полной диагностикой

```sql
DO $$
DECLARE
    v_result NUMERIC;
    v_sqlstate TEXT;
    v_message  TEXT;
    v_detail   TEXT;
    v_context  TEXT;
BEGIN
    -- Некорректное преобразование типа
    v_result := 'не_число'::NUMERIC;
EXCEPTION
    WHEN OTHERS THEN
        GET STACKED DIAGNOSTICS
            v_sqlstate = RETURNED_SQLSTATE,
            v_message  = MESSAGE_TEXT,
            v_detail   = PG_EXCEPTION_DETAIL,
            v_context  = PG_EXCEPTION_CONTEXT;

        RAISE NOTICE '=== Диагностика ошибки ===';
        RAISE NOTICE 'SQLSTATE: %', v_sqlstate;
        RAISE NOTICE 'Сообщение: %', v_message;
        RAISE NOTICE 'Детали: %', v_detail;
        RAISE NOTICE 'Контекст: %', v_context;
END;
$$;
```

> **Обсуждение:** В чём преимущество `GET STACKED DIAGNOSTICS` перед простыми `SQLSTATE` и `SQLERRM`?

---

## Часть 2. RAISE EXCEPTION и валидация (8 мин)

### Шаг 2.1. Функция валидации с пользовательскими ошибками

```sql
CREATE OR REPLACE FUNCTION validate_ore_sample(
    p_fe_content    NUMERIC,
    p_sample_weight NUMERIC,
    p_mine_id       INT
)
RETURNS VARCHAR
LANGUAGE plpgsql
AS $$
DECLARE
    v_mine_exists BOOLEAN;
BEGIN
    -- Проверка 1: диапазон Fe
    IF p_fe_content < 0 OR p_fe_content > 100 THEN
        RAISE EXCEPTION 'Содержание Fe (%) вне диапазона [0-100]', p_fe_content
            USING ERRCODE = 'R0001',
                  HINT = 'Проверьте данные лабораторного анализа';
    END IF;

    -- Проверка 2: вес пробы
    IF p_sample_weight <= 0 THEN
        RAISE EXCEPTION 'Вес пробы (%) должен быть положительным', p_sample_weight
            USING ERRCODE = 'R0002';
    END IF;

    -- Проверка 3: существование шахты
    SELECT EXISTS(SELECT 1 FROM dim_mine WHERE mine_id = p_mine_id)
    INTO v_mine_exists;

    IF NOT v_mine_exists THEN
        RAISE EXCEPTION 'Шахта с ID=% не существует', p_mine_id
            USING ERRCODE = 'R0003',
                  HINT = 'Проверьте справочник dim_mine';
    END IF;

    RETURN 'Валидация пройдена';
END;
$$;
```

### Шаг 2.2. Тестирование валидации

```sql
-- Корректные данные
SELECT validate_ore_sample(55.5, 2.5, 1);

-- Ошибка: Fe вне диапазона
DO $$
BEGIN
    PERFORM validate_ore_sample(150.0, 2.5, 1);
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'Перехвачено: [%] %', SQLSTATE, SQLERRM;
END;
$$;

-- Ошибка: отрицательный вес
DO $$
BEGIN
    PERFORM validate_ore_sample(55.5, -1.0, 1);
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'Перехвачено: [%] %', SQLSTATE, SQLERRM;
END;
$$;

-- Ошибка: несуществующая шахта
DO $$
BEGIN
    PERFORM validate_ore_sample(55.5, 2.5, 9999);
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'Перехвачено: [%] %', SQLSTATE, SQLERRM;
END;
$$;
```

**Что наблюдаем:** Каждая ошибка имеет свой код (R0001, R0002, R0003) и понятное сообщение.

---

## Часть 3. Логирование ошибок (5 мин)

### Шаг 3.1. Создание таблицы логов

```sql
CREATE TABLE IF NOT EXISTS error_log (
    log_id      SERIAL PRIMARY KEY,
    log_time    TIMESTAMP DEFAULT NOW(),
    severity    VARCHAR(20),
    source      VARCHAR(100),
    sqlstate    VARCHAR(5),
    message     TEXT,
    detail      TEXT,
    hint        TEXT,
    context     TEXT,
    username    VARCHAR(100) DEFAULT CURRENT_USER,
    parameters  JSONB
);
```

### Шаг 3.2. Функция логирования

```sql
CREATE OR REPLACE FUNCTION log_error(
    p_severity   VARCHAR,
    p_source     VARCHAR,
    p_sqlstate   VARCHAR DEFAULT NULL,
    p_message    TEXT DEFAULT NULL,
    p_detail     TEXT DEFAULT NULL,
    p_hint       TEXT DEFAULT NULL,
    p_context    TEXT DEFAULT NULL,
    p_parameters JSONB DEFAULT NULL
)
RETURNS INT
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_log_id INT;
BEGIN
    INSERT INTO error_log (severity, source, sqlstate, message, detail, hint, context, parameters)
    VALUES (p_severity, p_source, p_sqlstate, p_message, p_detail, p_hint, p_context, p_parameters)
    RETURNING log_id INTO v_log_id;
    RETURN v_log_id;
END;
$$;
```

### Шаг 3.3. Использование логирования

```sql
DO $$
DECLARE
    rec RECORD;
    v_sqlstate TEXT;
    v_message  TEXT;
BEGIN
    FOR rec IN SELECT equipment_id, equipment_name FROM dim_equipment LIMIT 5
    LOOP
        BEGIN
            -- Симуляция ошибки для каждого 2-го
            IF rec.equipment_id % 2 = 0 THEN
                RAISE EXCEPTION 'Ошибка обработки для %', rec.equipment_name;
            END IF;
            RAISE NOTICE 'OK: %', rec.equipment_name;
        EXCEPTION WHEN OTHERS THEN
            GET STACKED DIAGNOSTICS
                v_sqlstate = RETURNED_SQLSTATE,
                v_message  = MESSAGE_TEXT;

            PERFORM log_error('ERROR', 'batch_process',
                v_sqlstate, v_message, NULL, NULL, NULL,
                jsonb_build_object('equipment_id', rec.equipment_id));

            RAISE WARNING 'Пропущено: %', rec.equipment_name;
        END;
    END LOOP;
END;
$$;

-- Проверяем лог
SELECT log_id, log_time, severity, source, message, parameters
FROM error_log ORDER BY log_id DESC LIMIT 10;
```

---

## Часть 4. ASSERT (4 мин)

### Шаг 4.1. Использование ASSERT для проверки инвариантов

```sql
DO $$
DECLARE
    v_mine_count INT;
    v_equip_count INT;
BEGIN
    SELECT COUNT(*) INTO v_mine_count FROM dim_mine;
    SELECT COUNT(*) INTO v_equip_count FROM dim_equipment;

    -- Проверяем базовые инварианты
    ASSERT v_mine_count > 0, 'Справочник шахт пуст!';
    ASSERT v_equip_count > 0, 'Справочник оборудования пуст!';
    ASSERT v_equip_count > v_mine_count,
        format('Оборудования (%s) должно быть больше, чем шахт (%s)',
               v_equip_count, v_mine_count);

    RAISE NOTICE 'Все проверки пройдены: % шахт, % ед. оборудования',
        v_mine_count, v_equip_count;
END;
$$;
```

> **Обсуждение:** Чем ASSERT отличается от IF + RAISE EXCEPTION? Когда использовать каждый подход?

---

## Итоги практической работы

В ходе работы мы:

1. Освоили блок **EXCEPTION** для перехвата ошибок различных типов
2. Научились использовать **GET STACKED DIAGNOSTICS** для детальной информации
3. Создали **пользовательские ошибки** с RAISE EXCEPTION и кодами USING
4. Реализовали **логирование ошибок** в таблицу для анализа
5. Применили **ASSERT** для проверки инвариантов

> **Для продвинутых:** Создайте функцию, которая принимает массив JSON-записей, валидирует каждую, записывает ошибки в лог, и возвращает статистику обработки.
