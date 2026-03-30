-- ============================================================
-- Модуль 5. Использование DML для изменения данных
-- Примеры на языке SQL (PostgreSQL)
-- Предприятие «Руда+»
-- ============================================================
-- ВАЖНО: Все примеры работают с practice_* таблицами.
-- Перед началом выполните scripts/create_practice_tables.sql
-- ============================================================

-- ============================================================
-- 1. INSERT — Добавление данных
-- ============================================================

-- 1.1 Вставка одной строки
-- Добавить новую причину простоя
INSERT INTO practice_dim_downtime_reason (
    reason_id, reason_name, reason_code, category, description
)
VALUES (
    100,
    'Замена конвейерной ленты',
    'CONV_BELT',
    'плановый',
    'Плановая замена изношенной конвейерной ленты'
);

-- Проверяем результат
SELECT * FROM practice_dim_downtime_reason
WHERE reason_code = 'CONV_BELT';

-- 1.2 Вставка нескольких строк
-- Добавить новые сорта руды
INSERT INTO practice_dim_ore_grade (
    ore_grade_id, grade_name, grade_code,
    fe_content_min, fe_content_max, description
)
VALUES
    (100, 'Премиум',      'PREM', 65.00, 72.00, 'Руда высшего качества'),
    (101, 'Стандарт',     'STD2', 55.00, 64.99, 'Руда стандартного качества'),
    (102, 'Низкосортная', 'LOW2', 40.00, 54.99, 'Руда пониженного качества');

-- Проверяем
SELECT * FROM practice_dim_ore_grade
ORDER BY ore_grade_id;

-- 1.3 INSERT ... SELECT — копирование данных из запроса
-- Скопировать валидированные записи из staging в факт-таблицу
INSERT INTO practice_fact_production (
    production_id, date_id, shift_id, mine_id, shaft_id,
    equipment_id, operator_id, location_id, ore_grade_id,
    tons_mined, tons_transported, trips_count,
    distance_km, fuel_consumed_l, operating_hours
)
SELECT
    1000 + staging_id,  -- генерация ID
    date_id, shift_id, mine_id, shaft_id,
    equipment_id, operator_id, location_id, ore_grade_id,
    tons_mined, tons_transported, trips_count,
    distance_km, fuel_consumed_l, operating_hours
FROM staging_production
WHERE is_validated = TRUE;

-- Проверяем: должно появиться 4 новых записи (5-я невалидирована)
SELECT COUNT(*) AS total_rows,
       COUNT(*) FILTER (WHERE date_id = 20240320) AS new_rows
FROM practice_fact_production;

-- 1.4 INSERT с DEFAULT
-- Вставка с использованием значений по умолчанию
INSERT INTO practice_dim_equipment (
    equipment_id, equipment_type_id, mine_id,
    equipment_name, inventory_number
    -- status не указан → будет 'active' (DEFAULT)
    -- has_video_recorder → FALSE (DEFAULT)
    -- has_navigation → FALSE (DEFAULT)
)
VALUES (
    100, 1, 1, 'ПДМ-21 «Новая»', 'INV-LHD-021'
);

SELECT equipment_id, equipment_name, status,
       has_video_recorder, has_navigation
FROM practice_dim_equipment
WHERE equipment_id = 100;

-- 1.5 INSERT ... RETURNING
-- Вставить оператора и получить присвоенный ID
INSERT INTO practice_dim_operator (
    operator_id, tab_number, last_name, first_name, middle_name,
    position, qualification, hire_date, mine_id
)
VALUES (
    100, 'TAB-042', 'Козлов', 'Андрей', 'Петрович',
    'Машинист ПДМ', '5 разряд', '2025-01-15', 1
)
RETURNING operator_id, tab_number, last_name, first_name;


-- ============================================================
-- 2. UPDATE — Изменение данных
-- ============================================================

-- 2.1 Базовый UPDATE
-- Перевести оборудование с ID=5 на техобслуживание
UPDATE practice_dim_equipment
SET status = 'maintenance'
WHERE equipment_id = 5;

-- Проверяем
SELECT equipment_id, equipment_name, status
FROM practice_dim_equipment
WHERE equipment_id = 5;

-- 2.2 UPDATE нескольких столбцов
-- Обновить оборудование: установить навигацию и видеорегистратор
UPDATE practice_dim_equipment
SET has_navigation = TRUE,
    has_video_recorder = TRUE
WHERE equipment_id IN (1, 2, 3)
  AND has_navigation = FALSE;

-- 2.3 UPDATE с подзапросом
-- Перевести в 'maintenance' оборудование с внеплановыми простоями > 120 мин
UPDATE practice_dim_equipment
SET status = 'maintenance'
WHERE equipment_id IN (
    SELECT DISTINCT d.equipment_id
    FROM practice_fact_downtime d
    WHERE d.is_planned = FALSE
      AND d.duration_min > 120
);

-- Смотрим, какое оборудование затронуто
SELECT equipment_id, equipment_name, status
FROM practice_dim_equipment
WHERE status = 'maintenance';

-- 2.4 UPDATE ... FROM (PostgreSQL-специфика)
-- Обновить статусы оборудования из staging-таблицы
UPDATE practice_dim_equipment e
SET status = s.new_status
FROM staging_equipment_status s
WHERE e.inventory_number = s.inventory_number
  AND s.new_status IS NOT NULL
  AND e.status != s.new_status;

-- 2.5 UPDATE ... RETURNING
-- Обновить и вернуть изменённые строки
UPDATE practice_dim_equipment
SET status = 'active'
WHERE status = 'maintenance'
  AND equipment_id <= 5
RETURNING equipment_id, equipment_name, status AS new_status;


-- ============================================================
-- 3. DELETE — Удаление данных
-- ============================================================

-- 3.1 Базовый DELETE
-- Удалить ошибочные записи телеметрии
DELETE FROM practice_fact_telemetry
WHERE quality_flag = 'ERROR';

-- 3.2 DELETE с подзапросом
-- Удалить записи о добыче за выходные дни
DELETE FROM practice_fact_production
WHERE date_id IN (
    SELECT date_id
    FROM dim_date
    WHERE is_weekend = TRUE
      AND year = 2024
      AND month = 3
);

-- 3.3 DELETE ... USING (PostgreSQL)
-- Удалить телеметрию от неисправных датчиков
DELETE FROM practice_fact_telemetry t
USING dim_sensor s
WHERE t.sensor_id = s.sensor_id
  AND s.status = 'faulty';

-- 3.4 DELETE ... RETURNING
-- Удалить и сохранить удалённые записи для аудита
DELETE FROM practice_fact_telemetry
WHERE date_id = 20240315
  AND is_alarm = TRUE
RETURNING telemetry_id, equipment_id, sensor_id, sensor_value;

-- 3.5 Архивирование через CTE + DELETE ... RETURNING
WITH deleted AS (
    DELETE FROM practice_fact_telemetry
    WHERE quality_flag = 'ERROR'
    RETURNING *
)
INSERT INTO practice_archive_telemetry (
    telemetry_id, date_id, time_id, equipment_id, sensor_id,
    location_id, sensor_value, is_alarm, quality_flag, loaded_at
)
SELECT telemetry_id, date_id, time_id, equipment_id, sensor_id,
       location_id, sensor_value, is_alarm, quality_flag, loaded_at
FROM deleted;

-- 3.6 TRUNCATE
-- Очистить staging-таблицу после загрузки
-- (не выполняйте до завершения остальных примеров!)
-- TRUNCATE TABLE staging_production RESTART IDENTITY;


-- ============================================================
-- 4. MERGE — Слияние данных (PostgreSQL 15+)
-- ============================================================

-- 4.1 MERGE: синхронизация справочника причин простоев
MERGE INTO practice_dim_downtime_reason AS target
USING staging_downtime_reasons AS source
    ON target.reason_code = source.reason_code

WHEN MATCHED THEN
    UPDATE SET
        reason_name = source.reason_name,
        category    = source.category,
        description = source.description

WHEN NOT MATCHED THEN
    INSERT (reason_id, reason_name, reason_code, category, description)
    VALUES (
        (SELECT COALESCE(MAX(reason_id), 0) + 1
         FROM practice_dim_downtime_reason),
        source.reason_name,
        source.reason_code,
        source.category,
        source.description
    );

-- Проверяем результат
SELECT * FROM practice_dim_downtime_reason
ORDER BY reason_id;

-- 4.2 MERGE: загрузка телеметрии с обработкой дубликатов
MERGE INTO practice_fact_telemetry AS target
USING (
    SELECT date_id, time_id, equipment_id, sensor_id,
           location_id, sensor_value, is_alarm, quality_flag
    FROM staging_telemetry
    WHERE quality_flag = 'OK'  -- только валидные данные
) AS source
ON target.date_id = source.date_id
   AND target.time_id = source.time_id
   AND target.equipment_id = source.equipment_id
   AND target.sensor_id = source.sensor_id

WHEN MATCHED THEN
    UPDATE SET
        sensor_value = source.sensor_value,
        is_alarm     = source.is_alarm,
        quality_flag = source.quality_flag

WHEN NOT MATCHED THEN
    INSERT (telemetry_id, date_id, time_id, equipment_id, sensor_id,
            location_id, sensor_value, is_alarm, quality_flag)
    VALUES (
        (SELECT COALESCE(MAX(telemetry_id), 0) + 1
         FROM practice_fact_telemetry),
        source.date_id, source.time_id, source.equipment_id,
        source.sensor_id, source.location_id, source.sensor_value,
        source.is_alarm, source.quality_flag
    );


-- 4.3 Полная синхронизация справочника с удалением «устаревших» записей
-- ============================================================
-- WHEN NOT MATCHED BY SOURCE THEN DELETE — доступно с PostgreSQL 17.
-- На PostgreSQL 15–16 эмулируем через DELETE + MERGE в одной транзакции.
-- ============================================================

-- Сценарий: из мастер-системы пришёл актуальный список причин простоев.
-- Всё, чего нет в этом списке, считается устаревшим и должно быть удалено.

-- -------- Подготовка staging-таблицы --------
DROP TABLE IF EXISTS staging_downtime_reasons_full;
CREATE TABLE staging_downtime_reasons_full (
    reason_code  VARCHAR(20)  NOT NULL,
    reason_name  VARCHAR(200) NOT NULL,
    category     VARCHAR(50)  NOT NULL,
    description  TEXT
);

INSERT INTO staging_downtime_reasons_full
    (reason_code, reason_name, category, description)
VALUES
    ('MAINT_PLAN',  'Плановое техническое обслуживание', 'плановый',        'Регламентное ТО по графику'),
    ('REPAIR_EMRG', 'Аварийный ремонт',                 'внеплановый',     'Отказ узла или агрегата'),
    ('NO_OPERATOR', 'Отсутствие оператора',              'организационный', 'Оператор не вышел на смену'),
    ('OVERHEAT',    'Перегрев двигателя',                'внеплановый',     'Остановка из-за перегрева'),
    ('POWER_OUT',   'Электроснабжение',                  'внеплановый',     'Перебои в электроснабжении');

-- ======== Вариант A: PostgreSQL 17+ (WHEN NOT MATCHED BY SOURCE) ========

-- MERGE INTO practice_dim_downtime_reason AS target
-- USING staging_downtime_reasons_full AS source
--     ON target.reason_code = source.reason_code
--
-- WHEN MATCHED THEN
--     UPDATE SET
--         reason_name = source.reason_name,
--         category    = source.category,
--         description = source.description
--
-- WHEN NOT MATCHED BY TARGET THEN
--     INSERT (reason_id, reason_name, reason_code, category, description)
--     VALUES (
--         source.new_reason_id,
--         source.reason_name,
--         source.reason_code,
--         source.category,
--         source.description
--     )
--
-- WHEN NOT MATCHED BY SOURCE THEN
--     DELETE;

-- ======== Вариант B: PostgreSQL 15–16 (DELETE + MERGE в транзакции) ========

BEGIN;

-- Шаг 1: Удаляем из target записи, которых нет в source
-- (эмуляция WHEN NOT MATCHED BY SOURCE THEN DELETE)
DELETE FROM practice_dim_downtime_reason AS target
WHERE NOT EXISTS (
    SELECT 1
    FROM staging_downtime_reasons_full AS source
    WHERE source.reason_code = target.reason_code
);

-- Шаг 2: MERGE — обновляем совпавшие, вставляем новые
MERGE INTO practice_dim_downtime_reason AS target
USING (
    SELECT reason_code, reason_name, category, description,
           (SELECT COALESCE(MAX(reason_id), 0)
            FROM practice_dim_downtime_reason)
           + ROW_NUMBER() OVER (ORDER BY reason_code) AS new_reason_id
    FROM staging_downtime_reasons_full
) AS source
    ON target.reason_code = source.reason_code

WHEN MATCHED THEN
    UPDATE SET
        reason_name = source.reason_name,
        category    = source.category,
        description = source.description

WHEN NOT MATCHED THEN
    INSERT (reason_id, reason_name, reason_code, category, description)
    VALUES (
        source.new_reason_id,
        source.reason_name,
        source.reason_code,
        source.category,
        source.description
    );

COMMIT;

-- Проверяем результат: должны остаться только 5 записей из staging
SELECT reason_id, reason_code, reason_name, category
FROM practice_dim_downtime_reason
ORDER BY reason_id;


-- 4.4 MERGE ... RETURNING — логирование всех изменений
-- ============================================================
-- MERGE ... RETURNING доступно с PostgreSQL 17.
-- На PostgreSQL 15–16 эмулируем через CTE с UPDATE/INSERT RETURNING.
-- ============================================================

-- Сценарий: обновляем статусы оборудования из staging_equipment_status
-- и записываем ВСЕ изменения (UPDATE и INSERT) в practice_equipment_log.

-- ======== Вариант A: PostgreSQL 17+ (MERGE ... RETURNING) ========

-- MERGE INTO practice_dim_equipment AS t
-- USING staging_equipment_status AS s
--     ON t.inventory_number = s.inventory_number
--
-- WHEN MATCHED AND t.status IS DISTINCT FROM s.new_status THEN
--     UPDATE SET
--         status             = s.new_status,
--         has_video_recorder = s.has_video_recorder,
--         has_navigation     = s.has_navigation
--
-- WHEN NOT MATCHED THEN
--     INSERT (equipment_id, inventory_number, status,
--             has_video_recorder, has_navigation)
--     VALUES (
--         (SELECT MAX(equipment_id) + 1 FROM practice_dim_equipment),
--         s.inventory_number, s.new_status,
--         s.has_video_recorder, s.has_navigation
--     )
--
-- RETURNING
--     merge_action()  AS action,   -- 'INSERT' или 'UPDATE'
--     t.equipment_id,
--     t.inventory_number,
--     t.status AS new_status;

-- ======== Вариант B: PostgreSQL 15–16 (CTE + RETURNING) ========

BEGIN;

-- Шаг 1: UPDATE существующего оборудования с логированием
WITH old_values AS (
    -- Фиксируем текущее состояние ДО обновления
    SELECT t.equipment_id,
           t.status             AS old_status,
           s.new_status,
           s.has_video_recorder,
           s.has_navigation
    FROM practice_dim_equipment t
    JOIN staging_equipment_status s
        ON t.inventory_number = s.inventory_number
    WHERE t.status IS DISTINCT FROM s.new_status
),
do_update AS (
    -- Выполняем UPDATE и получаем ID обновлённых строк
    UPDATE practice_dim_equipment AS t
    SET status             = o.new_status,
        has_video_recorder = o.has_video_recorder,
        has_navigation     = o.has_navigation
    FROM old_values o
    WHERE t.equipment_id = o.equipment_id
    RETURNING t.equipment_id
)
-- Записываем в лог через INSERT ... SELECT
INSERT INTO practice_equipment_log
    (equipment_id, action, old_status, new_status, details)
SELECT o.equipment_id,
       'UPDATE',
       o.old_status,
       o.new_status,
       'Статус изменён при синхронизации из staging'
FROM old_values o
JOIN do_update u ON o.equipment_id = u.equipment_id;

-- Шаг 2: INSERT нового оборудования с логированием
WITH inserted AS (
    INSERT INTO practice_dim_equipment (
        equipment_id, inventory_number, status,
        has_video_recorder, has_navigation
    )
    SELECT (SELECT COALESCE(MAX(equipment_id), 0)
            FROM practice_dim_equipment)
           + ROW_NUMBER() OVER (ORDER BY s.inventory_number),
           s.inventory_number,
           s.new_status,
           s.has_video_recorder,
           s.has_navigation
    FROM staging_equipment_status s
    WHERE NOT EXISTS (
        SELECT 1 FROM practice_dim_equipment t
        WHERE t.inventory_number = s.inventory_number
    )
    RETURNING equipment_id, status AS new_status
)
INSERT INTO practice_equipment_log
    (equipment_id, action, old_status, new_status, details)
SELECT equipment_id,
       'INSERT',
       NULL,
       new_status,
       'Новое оборудование добавлено из staging'
FROM inserted;

-- Проверяем журнал изменений
SELECT log_id, equipment_id, action,
       old_status, new_status, details, changed_at
FROM practice_equipment_log
ORDER BY log_id;

COMMIT;


-- ============================================================
-- 5. UPSERT — INSERT ... ON CONFLICT
-- ============================================================

-- 5.1 ON CONFLICT DO NOTHING
-- Добавить оператора; если табельный номер уже есть — пропустить
INSERT INTO practice_dim_operator (
    operator_id, tab_number, last_name, first_name,
    middle_name, position, qualification, hire_date, mine_id
)
VALUES (
    101, 'TAB-001', 'Дубликат', 'Тест', 'Тестович',
    'Тест', '1 разряд', '2025-01-01', 1
)
ON CONFLICT (tab_number) DO NOTHING;

-- Проверяем: оператор с TAB-001 не изменился
SELECT * FROM practice_dim_operator WHERE tab_number = 'TAB-001';

-- 5.2 ON CONFLICT DO UPDATE
-- Добавить или обновить сорт руды
INSERT INTO practice_dim_ore_grade (
    ore_grade_id, grade_name, grade_code,
    fe_content_min, fe_content_max, description
)
VALUES (
    100, 'Премиум-2025', 'PREM', 66.00, 73.00,
    'Обновлённый стандарт качества 2025 года'
)
ON CONFLICT (grade_code) DO UPDATE SET
    grade_name     = EXCLUDED.grade_name,
    fe_content_min = EXCLUDED.fe_content_min,
    fe_content_max = EXCLUDED.fe_content_max,
    description    = EXCLUDED.description;

-- Проверяем: значения обновились
SELECT * FROM practice_dim_ore_grade WHERE grade_code = 'PREM';


-- ============================================================
-- 6. Транзакции — безопасная работа с DML
-- ============================================================

-- 6.1 Успешная транзакция
BEGIN;

INSERT INTO practice_equipment_log (equipment_id, action, new_status, details)
VALUES (1, 'UPDATE', 'maintenance', 'Плановое ТО');

UPDATE practice_dim_equipment
SET status = 'maintenance'
WHERE equipment_id = 1;

COMMIT;

-- 6.2 Откат транзакции
BEGIN;

-- Ошибочное удаление
DELETE FROM practice_dim_equipment
WHERE mine_id = 1;

-- Ой! Не то удалили! Откатываем.
ROLLBACK;

-- Проверяем: данные на месте
SELECT COUNT(*) FROM practice_dim_equipment WHERE mine_id = 1;


-- ============================================================
-- 7. Комплексный ETL-пример
-- ============================================================

BEGIN;

-- Шаг 1: Загрузить новые записи о добыче
INSERT INTO practice_fact_production (
    production_id, date_id, shift_id, mine_id, shaft_id,
    equipment_id, operator_id, location_id, ore_grade_id,
    tons_mined, tons_transported, trips_count,
    distance_km, fuel_consumed_l, operating_hours
)
SELECT
    2000 + staging_id,
    date_id, shift_id, mine_id, shaft_id,
    equipment_id, operator_id, location_id, ore_grade_id,
    tons_mined, tons_transported, trips_count,
    distance_km, fuel_consumed_l, operating_hours
FROM staging_production sp
WHERE sp.is_validated = TRUE
  AND NOT EXISTS (
      SELECT 1 FROM practice_fact_production fp
      WHERE fp.date_id = sp.date_id
        AND fp.shift_id = sp.shift_id
        AND fp.equipment_id = sp.equipment_id
        AND fp.operator_id = sp.operator_id
  );

-- Шаг 2: Обновить статусы оборудования
UPDATE practice_dim_equipment e
SET status = s.new_status
FROM staging_equipment_status s
WHERE e.inventory_number = s.inventory_number
  AND s.new_status IS NOT NULL
  AND e.status IS DISTINCT FROM s.new_status;

-- Шаг 3: Логировать изменения
INSERT INTO practice_equipment_log (equipment_id, action, new_status, details)
SELECT e.equipment_id, 'UPDATE', s.new_status, 'ETL обновление из staging'
FROM practice_dim_equipment e
JOIN staging_equipment_status s ON e.inventory_number = s.inventory_number
WHERE s.new_status IS NOT NULL;

-- Шаг 4: Очистить staging
TRUNCATE staging_production RESTART IDENTITY;
TRUNCATE staging_equipment_status RESTART IDENTITY;

COMMIT;

-- Проверяем лог
SELECT * FROM practice_equipment_log ORDER BY log_id;
