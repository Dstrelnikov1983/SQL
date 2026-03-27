-- ============================================================
-- Модуль 17: Применение обработки ошибок
-- Примеры кода — Предприятие «Руда+»
-- PostgreSQL (PL/pgSQL)
-- ============================================================

-- ============================================================
-- 1. Базовый блок EXCEPTION
-- ============================================================

-- Пример 1.1. Простая обработка ошибки
DO $$
DECLARE
    v_tons NUMERIC;
BEGIN
    -- Попытка деления на ноль
    v_tons := 100 / 0;
    RAISE NOTICE 'Результат: %', v_tons;
EXCEPTION
    WHEN division_by_zero THEN
        RAISE NOTICE 'Ошибка: деление на ноль!';
END;
$$;

-- Пример 1.2. Обработка нескольких типов ошибок
DO $$
DECLARE
    v_mine_name VARCHAR(5);  -- Короткая строка для демонстрации
    v_tons      NUMERIC;
BEGIN
    -- Попытка вставить длинную строку
    v_mine_name := 'Шахта Северная Глубокая';
    RAISE NOTICE 'Имя: %', v_mine_name;
EXCEPTION
    WHEN string_data_right_truncation THEN
        RAISE NOTICE 'Ошибка: строка слишком длинная!';
    WHEN division_by_zero THEN
        RAISE NOTICE 'Ошибка: деление на ноль!';
    WHEN OTHERS THEN
        RAISE NOTICE 'Неизвестная ошибка: %', SQLERRM;
END;
$$;

-- Пример 1.3. WHEN OTHERS — универсальный обработчик
DO $$
DECLARE
    v_result NUMERIC;
BEGIN
    -- Некорректное преобразование типа
    v_result := 'abc'::NUMERIC;
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'Код ошибки: %', SQLSTATE;
        RAISE NOTICE 'Сообщение: %', SQLERRM;
END;
$$;

-- ============================================================
-- 2. Предопределённые условия ошибок (SQLSTATE)
-- ============================================================

-- Пример 2.1. Основные коды ошибок
DO $$
BEGIN
    RAISE NOTICE 'Основные классы SQLSTATE:';
    RAISE NOTICE '  00 — Успешное завершение';
    RAISE NOTICE '  02 — Нет данных (NO_DATA_FOUND)';
    RAISE NOTICE '  22 — Ошибка данных (деление на 0, переполнение)';
    RAISE NOTICE '  23 — Нарушение целостности (unique, FK, NOT NULL)';
    RAISE NOTICE '  25 — Ошибка транзакции';
    RAISE NOTICE '  40 — Откат транзакции (deadlock, сериализация)';
    RAISE NOTICE '  42 — Синтаксическая ошибка / нарушение прав';
    RAISE NOTICE '  P0 — PL/pgSQL ошибки';
END;
$$;

-- Пример 2.2. Обработка нарушения уникальности
DO $$
BEGIN
    -- Попытка вставить дублирующую шахту
    INSERT INTO dim_mine (mine_id, mine_name, location, depth_meters, status)
    VALUES (1, 'Дублирующая шахта', 'Тест', 100, 'active');

    RAISE NOTICE 'Шахта добавлена успешно';
EXCEPTION
    WHEN unique_violation THEN
        RAISE NOTICE 'Ошибка: шахта с ID=1 уже существует!';
        RAISE NOTICE 'SQLSTATE: %, Сообщение: %', SQLSTATE, SQLERRM;
    WHEN OTHERS THEN
        RAISE NOTICE 'Другая ошибка: % (%)', SQLERRM, SQLSTATE;
END;
$$;

-- Пример 2.3. Обработка нарушения NOT NULL
DO $$
BEGIN
    INSERT INTO dim_equipment (equipment_id, equipment_name, equipment_type_id, mine_id)
    VALUES (9999, NULL, 1, 1);
EXCEPTION
    WHEN not_null_violation THEN
        RAISE NOTICE 'Ошибка: обязательное поле не заполнено!';
        RAISE NOTICE 'Детали: %', SQLERRM;
END;
$$;

-- Пример 2.4. Обработка нарушения внешнего ключа
DO $$
BEGIN
    INSERT INTO fact_production (
        production_id, date_id, shift_id, equipment_id, mine_id,
        operator_id, tons_mined, trips_count, operating_hours
    )
    VALUES (999999, 20250101, 1, 99999, 1, 1, 100, 10, 8);
EXCEPTION
    WHEN foreign_key_violation THEN
        RAISE NOTICE 'Ошибка: ссылка на несуществующий объект!';
        RAISE NOTICE 'Детали: %', SQLERRM;
END;
$$;

-- ============================================================
-- 3. RAISE EXCEPTION — генерация ошибок
-- ============================================================

-- Пример 3.1. Простой RAISE EXCEPTION
DO $$
DECLARE
    v_fe_content NUMERIC := 5.0;
BEGIN
    IF v_fe_content < 10 THEN
        RAISE EXCEPTION 'Критически низкое содержание Fe: % %%', v_fe_content;
    END IF;

    RAISE NOTICE 'Проверка пройдена';
EXCEPTION
    WHEN raise_exception THEN
        RAISE NOTICE 'Перехвачено исключение: %', SQLERRM;
END;
$$;

-- Пример 3.2. RAISE EXCEPTION с параметрами USING
DO $$
DECLARE
    v_equipment_id INT := 999;
    v_mine_id      INT;
BEGIN
    SELECT mine_id INTO STRICT v_mine_id
    FROM dim_equipment
    WHERE equipment_id = v_equipment_id;

    RAISE NOTICE 'Оборудование % принадлежит шахте %', v_equipment_id, v_mine_id;
EXCEPTION
    WHEN no_data_found THEN
        RAISE EXCEPTION 'Оборудование ID=% не найдено в справочнике', v_equipment_id
            USING HINT = 'Проверьте справочник dim_equipment',
                  ERRCODE = 'P0002',
                  DETAIL = format('Запрос к dim_equipment с equipment_id = %s вернул 0 строк', v_equipment_id);
END;
$$;

-- Пример 3.3. Пользовательские коды ошибок
CREATE OR REPLACE FUNCTION validate_ore_sample(
    p_fe_content   NUMERIC,
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
        RAISE EXCEPTION 'Содержание Fe (%) вне допустимого диапазона [0-100]', p_fe_content
            USING ERRCODE = 'R0001',  -- Пользовательский код
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

    RETURN 'Валидация пройдена успешно';
END;
$$;

-- Тест: корректные данные
SELECT validate_ore_sample(55.5, 2.5, 1);

-- Тест: ошибка Fe
-- SELECT validate_ore_sample(150.0, 2.5, 1);  -- Ошибка R0001

-- Тест: ошибка веса
-- SELECT validate_ore_sample(55.5, -1.0, 1);  -- Ошибка R0002

-- ============================================================
-- 4. GET STACKED DIAGNOSTICS
-- ============================================================

-- Пример 4.1. Получение детальной информации об ошибке
DO $$
DECLARE
    v_sqlstate    TEXT;
    v_message     TEXT;
    v_detail      TEXT;
    v_hint        TEXT;
    v_context     TEXT;
    v_schema      TEXT;
    v_table       TEXT;
    v_column      TEXT;
    v_constraint  TEXT;
BEGIN
    -- Генерируем ошибку
    INSERT INTO dim_mine (mine_id, mine_name, location, depth_meters, status)
    VALUES (1, 'Дубль', 'Тест', 100, 'active');

EXCEPTION WHEN OTHERS THEN
    GET STACKED DIAGNOSTICS
        v_sqlstate   = RETURNED_SQLSTATE,
        v_message    = MESSAGE_TEXT,
        v_detail     = PG_EXCEPTION_DETAIL,
        v_hint       = PG_EXCEPTION_HINT,
        v_context    = PG_EXCEPTION_CONTEXT,
        v_schema     = SCHEMA_NAME,
        v_table      = TABLE_NAME,
        v_column     = COLUMN_NAME,
        v_constraint = CONSTRAINT_NAME;

    RAISE NOTICE '=== Диагностика ошибки ===';
    RAISE NOTICE 'SQLSTATE:    %', v_sqlstate;
    RAISE NOTICE 'Сообщение:   %', v_message;
    RAISE NOTICE 'Детали:      %', v_detail;
    RAISE NOTICE 'Подсказка:   %', v_hint;
    RAISE NOTICE 'Контекст:    %', v_context;
    RAISE NOTICE 'Схема:       %', v_schema;
    RAISE NOTICE 'Таблица:     %', v_table;
    RAISE NOTICE 'Столбец:     %', v_column;
    RAISE NOTICE 'Ограничение: %', v_constraint;
END;
$$;

-- ============================================================
-- 5. Логирование ошибок в таблицу
-- ============================================================

-- Пример 5.1. Создание таблицы логов
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

-- Пример 5.2. Функция логирования
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
    INSERT INTO error_log (
        severity, source, sqlstate, message,
        detail, hint, context, parameters
    )
    VALUES (
        p_severity, p_source, p_sqlstate, p_message,
        p_detail, p_hint, p_context, p_parameters
    )
    RETURNING log_id INTO v_log_id;

    RETURN v_log_id;
END;
$$;

-- Пример 5.3. Использование логирования при импорте данных
CREATE OR REPLACE FUNCTION import_production_data(
    p_data JSONB
)
RETURNS TABLE (
    status     VARCHAR,
    processed  INT,
    errors     INT,
    log_ids    INT[]
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_record    JSONB;
    v_processed INT := 0;
    v_errors    INT := 0;
    v_log_ids   INT[] := ARRAY[]::INT[];
    v_log_id    INT;

    v_sqlstate  TEXT;
    v_message   TEXT;
    v_detail    TEXT;
    v_context   TEXT;
BEGIN
    FOR v_record IN SELECT jsonb_array_elements(p_data)
    LOOP
        BEGIN
            INSERT INTO fact_production (
                production_id, date_id, shift_id, equipment_id,
                mine_id, operator_id, tons_mined, trips_count, operating_hours
            )
            VALUES (
                (v_record->>'production_id')::INT,
                (v_record->>'date_id')::INT,
                (v_record->>'shift_id')::INT,
                (v_record->>'equipment_id')::INT,
                (v_record->>'mine_id')::INT,
                (v_record->>'operator_id')::INT,
                (v_record->>'tons_mined')::NUMERIC,
                (v_record->>'trips_count')::INT,
                (v_record->>'operating_hours')::NUMERIC
            );

            v_processed := v_processed + 1;

        EXCEPTION WHEN OTHERS THEN
            GET STACKED DIAGNOSTICS
                v_sqlstate = RETURNED_SQLSTATE,
                v_message  = MESSAGE_TEXT,
                v_detail   = PG_EXCEPTION_DETAIL,
                v_context  = PG_EXCEPTION_CONTEXT;

            v_log_id := log_error(
                'ERROR',
                'import_production_data',
                v_sqlstate,
                v_message,
                v_detail,
                NULL,
                v_context,
                v_record
            );

            v_errors := v_errors + 1;
            v_log_ids := v_log_ids || v_log_id;
        END;
    END LOOP;

    -- Возвращаем итоги
    status := CASE
        WHEN v_errors = 0 THEN 'SUCCESS'
        WHEN v_processed > 0 THEN 'PARTIAL'
        ELSE 'FAILED'
    END;
    processed := v_processed;
    errors := v_errors;
    log_ids := v_log_ids;
    RETURN NEXT;
END;
$$;

-- Тест с корректными и некорректными данными
SELECT * FROM import_production_data('[
    {"production_id": 900001, "date_id": 20250101, "shift_id": 1,
     "equipment_id": 1, "mine_id": 1, "operator_id": 1,
     "tons_mined": 150.5, "trips_count": 12, "operating_hours": 7.5},
    {"production_id": 900002, "date_id": 20250101, "shift_id": 1,
     "equipment_id": 99999, "mine_id": 1, "operator_id": 1,
     "tons_mined": 100.0, "trips_count": 8, "operating_hours": 6.0}
]'::JSONB);

-- Проверяем лог ошибок
SELECT * FROM error_log ORDER BY log_id DESC LIMIT 5;

-- ============================================================
-- 6. ASSERT — утверждения для отладки
-- ============================================================

-- Пример 6.1. Простой ASSERT
DO $$
DECLARE
    v_mine_count INT;
BEGIN
    SELECT COUNT(*) INTO v_mine_count FROM dim_mine;

    -- Проверяем, что шахты существуют
    ASSERT v_mine_count > 0, 'Справочник шахт пуст! Необходимо выполнить загрузку данных.';

    RAISE NOTICE 'Проверка пройдена: % шахт в справочнике', v_mine_count;
END;
$$;

-- Пример 6.2. ASSERT для проверки инвариантов
CREATE OR REPLACE FUNCTION safe_divide(
    p_numerator   NUMERIC,
    p_denominator NUMERIC
)
RETURNS NUMERIC
LANGUAGE plpgsql
IMMUTABLE
AS $$
BEGIN
    ASSERT p_denominator IS NOT NULL, 'Делитель не может быть NULL';
    ASSERT p_denominator != 0, 'Делитель не может быть нулём';

    RETURN ROUND(p_numerator / p_denominator, 4);
END;
$$;

-- Тест
SELECT safe_divide(100, 3);    -- OK: 33.3333
-- SELECT safe_divide(100, 0);  -- ASSERT failed

-- Пример 6.3. ASSERT в функции валидации
CREATE OR REPLACE FUNCTION calc_equipment_oee(
    p_operating_hours   NUMERIC,
    p_planned_hours     NUMERIC,
    p_actual_tons       NUMERIC,
    p_target_tons       NUMERIC
)
RETURNS NUMERIC
LANGUAGE plpgsql
IMMUTABLE
AS $$
DECLARE
    v_availability NUMERIC;
    v_performance  NUMERIC;
    v_oee          NUMERIC;
BEGIN
    -- Проверки с ASSERT
    ASSERT p_operating_hours >= 0, format('operating_hours (%s) не может быть отрицательным', p_operating_hours);
    ASSERT p_planned_hours > 0, format('planned_hours (%s) должен быть положительным', p_planned_hours);
    ASSERT p_actual_tons >= 0, format('actual_tons (%s) не может быть отрицательным', p_actual_tons);
    ASSERT p_target_tons > 0, format('target_tons (%s) должен быть положительным', p_target_tons);

    v_availability := p_operating_hours / p_planned_hours;
    v_performance  := p_actual_tons / p_target_tons;
    v_oee := ROUND(v_availability * v_performance * 100, 1);

    RETURN v_oee;
END;
$$;

SELECT calc_equipment_oee(10, 12, 80, 100);  -- ~66.7

-- ============================================================
-- 7. Вложенные блоки EXCEPTION
-- ============================================================

-- Пример 7.1. Вложенные блоки для изоляции ошибок
DO $$
DECLARE
    v_total_processed INT := 0;
    v_total_errors    INT := 0;
    rec RECORD;
BEGIN
    FOR rec IN
        SELECT equipment_id, equipment_name FROM dim_equipment LIMIT 5
    LOOP
        -- Каждая итерация в своём блоке
        BEGIN
            -- Симуляция обработки данных
            IF rec.equipment_id % 3 = 0 THEN
                -- Искусственная ошибка для каждого 3-го оборудования
                RAISE EXCEPTION 'Ошибка обработки для ID=%', rec.equipment_id;
            END IF;

            RAISE NOTICE 'Обработано: % (ID=%)', rec.equipment_name, rec.equipment_id;
            v_total_processed := v_total_processed + 1;

        EXCEPTION WHEN OTHERS THEN
            RAISE WARNING 'Пропущено: % — %', rec.equipment_name, SQLERRM;
            v_total_errors := v_total_errors + 1;
        END;
    END LOOP;

    RAISE NOTICE '=== Итого: обработано %, ошибок % ===',
        v_total_processed, v_total_errors;
END;
$$;

-- ============================================================
-- 8. Комплексный пример: безопасный импорт проб руды
-- ============================================================

-- Таблица для временных данных импорта
CREATE TABLE IF NOT EXISTS staging_ore_samples (
    row_num        INT,
    mine_name      TEXT,
    sample_date    TEXT,
    fe_content     TEXT,
    moisture       TEXT,
    sample_weight  TEXT,
    is_valid       BOOLEAN DEFAULT NULL,
    error_message  TEXT DEFAULT NULL
);

-- Функция валидации и импорта
CREATE OR REPLACE FUNCTION process_ore_samples_import()
RETURNS TABLE (
    total_rows    INT,
    valid_rows    INT,
    invalid_rows  INT,
    imported_rows INT
)
LANGUAGE plpgsql
AS $$
DECLARE
    rec           RECORD;
    v_total       INT := 0;
    v_valid       INT := 0;
    v_invalid     INT := 0;
    v_imported    INT := 0;
    v_mine_id     INT;
    v_date_id     INT;
    v_fe          NUMERIC;
    v_moisture    NUMERIC;
    v_weight      NUMERIC;
    v_error       TEXT;

    v_sqlstate    TEXT;
    v_message     TEXT;
BEGIN
    FOR rec IN SELECT * FROM staging_ore_samples ORDER BY row_num
    LOOP
        v_total := v_total + 1;
        v_error := NULL;

        -- Блок валидации
        BEGIN
            -- 1. Проверка числовых полей
            BEGIN
                v_fe := rec.fe_content::NUMERIC;
            EXCEPTION WHEN invalid_text_representation THEN
                RAISE EXCEPTION 'Fe содержание «%» не является числом', rec.fe_content;
            END;

            BEGIN
                v_moisture := rec.moisture::NUMERIC;
            EXCEPTION WHEN invalid_text_representation THEN
                RAISE EXCEPTION 'Влажность «%» не является числом', rec.moisture;
            END;

            BEGIN
                v_weight := rec.sample_weight::NUMERIC;
            EXCEPTION WHEN invalid_text_representation THEN
                RAISE EXCEPTION 'Вес «%» не является числом', rec.sample_weight;
            END;

            -- 2. Проверка диапазонов
            IF v_fe < 0 OR v_fe > 100 THEN
                RAISE EXCEPTION 'Fe содержание (%) вне диапазона [0, 100]', v_fe;
            END IF;

            IF v_weight <= 0 THEN
                RAISE EXCEPTION 'Вес пробы (%) должен быть положительным', v_weight;
            END IF;

            -- 3. Проверка шахты
            SELECT mine_id INTO v_mine_id
            FROM dim_mine WHERE mine_name = rec.mine_name;

            IF v_mine_id IS NULL THEN
                RAISE EXCEPTION 'Шахта «%» не найдена в справочнике', rec.mine_name;
            END IF;

            -- 4. Проверка даты
            BEGIN
                v_date_id := TO_CHAR(rec.sample_date::DATE, 'YYYYMMDD')::INT;
            EXCEPTION WHEN OTHERS THEN
                RAISE EXCEPTION 'Некорректная дата «%»', rec.sample_date;
            END;

            -- Валидация пройдена
            UPDATE staging_ore_samples SET is_valid = TRUE WHERE row_num = rec.row_num;
            v_valid := v_valid + 1;

        EXCEPTION WHEN OTHERS THEN
            GET STACKED DIAGNOSTICS
                v_sqlstate = RETURNED_SQLSTATE,
                v_message  = MESSAGE_TEXT;

            UPDATE staging_ore_samples
            SET is_valid = FALSE,
                error_message = format('[%s] %s', v_sqlstate, v_message)
            WHERE row_num = rec.row_num;

            v_invalid := v_invalid + 1;

            -- Логируем ошибку
            PERFORM log_error('WARNING', 'process_ore_samples_import',
                v_sqlstate, v_message, NULL, NULL, NULL,
                jsonb_build_object('row_num', rec.row_num, 'mine_name', rec.mine_name));
        END;
    END LOOP;

    -- Возвращаем итоги
    total_rows := v_total;
    valid_rows := v_valid;
    invalid_rows := v_invalid;
    imported_rows := v_imported;
    RETURN NEXT;
END;
$$;

-- ============================================================
-- 9. Best practices: функция с полной обработкой ошибок
-- ============================================================

CREATE OR REPLACE FUNCTION upsert_equipment_telemetry(
    p_equipment_id  INT,
    p_sensor_id     INT,
    p_date_id       INT,
    p_time_id       INT,
    p_value         NUMERIC,
    p_location_id   INT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
AS $$
DECLARE
    v_result     JSONB;
    v_telemetry_id BIGINT;
    v_action     VARCHAR;

    v_sqlstate   TEXT;
    v_message    TEXT;
    v_detail     TEXT;
    v_hint       TEXT;
    v_context    TEXT;
BEGIN
    -- Валидация входных параметров
    IF p_equipment_id IS NULL THEN
        RAISE EXCEPTION 'equipment_id обязателен'
            USING ERRCODE = 'P0001';
    END IF;

    IF p_value IS NULL THEN
        RAISE EXCEPTION 'value обязательно'
            USING ERRCODE = 'P0001';
    END IF;

    -- Проверяем существование оборудования
    IF NOT EXISTS(SELECT 1 FROM dim_equipment WHERE equipment_id = p_equipment_id) THEN
        RAISE EXCEPTION 'Оборудование ID=% не найдено', p_equipment_id
            USING ERRCODE = 'P0002',
                  HINT = 'Проверьте справочник dim_equipment';
    END IF;

    -- Проверяем существование датчика
    IF NOT EXISTS(SELECT 1 FROM dim_sensor WHERE sensor_id = p_sensor_id) THEN
        RAISE EXCEPTION 'Датчик ID=% не найден', p_sensor_id
            USING ERRCODE = 'P0002',
                  HINT = 'Проверьте справочник dim_sensor';
    END IF;

    -- Upsert данных телеметрии
    INSERT INTO fact_equipment_telemetry (
        equipment_id, sensor_id, date_id, time_id,
        sensor_value, location_id
    )
    VALUES (
        p_equipment_id, p_sensor_id, p_date_id, p_time_id,
        p_value, p_location_id
    )
    ON CONFLICT (equipment_id, sensor_id, date_id, time_id)
    DO UPDATE SET
        sensor_value = EXCLUDED.sensor_value,
        location_id  = COALESCE(EXCLUDED.location_id, fact_equipment_telemetry.location_id)
    RETURNING telemetry_id INTO v_telemetry_id;

    v_action := CASE WHEN xmax = 0 THEN 'INSERT' ELSE 'UPDATE' END;

    v_result := jsonb_build_object(
        'status', 'ok',
        'action', v_action,
        'telemetry_id', v_telemetry_id
    );

    RETURN v_result;

EXCEPTION
    WHEN raise_exception THEN
        -- Пользовательские ошибки — пробрасываем дальше
        RAISE;

    WHEN foreign_key_violation THEN
        GET STACKED DIAGNOSTICS
            v_message = MESSAGE_TEXT,
            v_detail  = PG_EXCEPTION_DETAIL;

        PERFORM log_error('ERROR', 'upsert_equipment_telemetry',
            SQLSTATE, v_message, v_detail);

        RETURN jsonb_build_object(
            'status', 'error',
            'code', SQLSTATE,
            'message', 'Нарушение ссылочной целостности',
            'detail', v_detail
        );

    WHEN OTHERS THEN
        GET STACKED DIAGNOSTICS
            v_sqlstate = RETURNED_SQLSTATE,
            v_message  = MESSAGE_TEXT,
            v_detail   = PG_EXCEPTION_DETAIL,
            v_context  = PG_EXCEPTION_CONTEXT;

        PERFORM log_error('ERROR', 'upsert_equipment_telemetry',
            v_sqlstate, v_message, v_detail, NULL, v_context,
            jsonb_build_object(
                'equipment_id', p_equipment_id,
                'sensor_id', p_sensor_id,
                'date_id', p_date_id,
                'value', p_value
            ));

        RETURN jsonb_build_object(
            'status', 'error',
            'code', v_sqlstate,
            'message', v_message
        );
END;
$$;

-- ============================================================
-- Очистка тестовых объектов
-- ============================================================

-- DROP TABLE IF EXISTS error_log;
-- DROP TABLE IF EXISTS staging_ore_samples;
-- DROP FUNCTION IF EXISTS validate_ore_sample;
-- DROP FUNCTION IF EXISTS safe_divide;
-- DROP FUNCTION IF EXISTS calc_equipment_oee;
-- DROP FUNCTION IF EXISTS log_error;
-- DROP FUNCTION IF EXISTS import_production_data;
-- DROP FUNCTION IF EXISTS process_ore_samples_import;
-- DROP FUNCTION IF EXISTS upsert_equipment_telemetry;
