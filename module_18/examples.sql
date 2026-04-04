-- ============================================================
-- Модуль 18: Применение транзакций
-- Примеры кода — Предприятие «Руда+»
-- PostgreSQL (PL/pgSQL)
-- ============================================================

-- ============================================================
-- 1. Базовые операции с транзакциями
-- ============================================================

-- Пример 1.1. BEGIN / COMMIT
BEGIN;
    INSERT INTO fact_production (
        production_id, date_id, shift_id, equipment_id,
        mine_id, shaft_id, operator_id, tons_mined, trips_count, operating_hours
    )
    VALUES (800001, 20250201, 1, 1, 1, 1, 1, 120.5, 10, 7.5);

    INSERT INTO fact_production (
        production_id, date_id, shift_id, equipment_id,
        mine_id, shaft_id, operator_id, tons_mined, trips_count, operating_hours
    )
    VALUES (800002, 20250201, 1, 2, 1, 1, 2, 98.3, 8, 6.5);
COMMIT;

-- Пример 1.2. BEGIN / ROLLBACK
BEGIN;
    -- Вставляем данные
    INSERT INTO fact_production (
        production_id, date_id, shift_id, equipment_id,
        mine_id, shaft_id, operator_id, tons_mined, trips_count, operating_hours
    )
    VALUES (800003, 20250201, 2, 1, 1, 1, 1, 200.0, 15, 8.0);

    -- Обнаруживаем ошибку — 200 тонн за смену нереально
    -- Откатываем всю транзакцию
ROLLBACK;

-- Проверяем — запись 800003 НЕ существует
SELECT * FROM fact_production WHERE production_id = 800003;

-- Пример 1.3. Автоматический ROLLBACK при ошибке
BEGIN;
    INSERT INTO fact_production (
        production_id, date_id, shift_id, equipment_id,
        mine_id, shaft_id, operator_id, tons_mined, trips_count, operating_hours
    )
    VALUES (800004, 20250201, 1, 1, 1, 1, 1, 100.0, 8, 7.0);

    -- Ошибка: equipment_id = 99999 не существует
    INSERT INTO fact_production (
        production_id, date_id, shift_id, equipment_id,
        mine_id, shaft_id, operator_id, tons_mined, trips_count, operating_hours
    )
    VALUES (800005, 20250201, 1, 99999, 1, 1, 1, 50.0, 4, 3.0);

    -- Эта строка не выполнится из-за ошибки FK
COMMIT;
-- После ошибки транзакция в состоянии "aborted"
-- Нужно выполнить ROLLBACK, чтобы начать новую
ROLLBACK;

-- ============================================================
-- 2. SAVEPOINT — точки сохранения
-- ============================================================

-- Пример 2.1. SAVEPOINT и ROLLBACK TO
BEGIN;
    -- Часть 1: основные данные (гарантированно нужны)
    INSERT INTO fact_production (
        production_id, date_id, shift_id, equipment_id,
        mine_id, shaft_id, operator_id, tons_mined, trips_count, operating_hours
    )
    VALUES (800010, 20250202, 1, 1, 1, 1, 1, 110.0, 9, 7.0);

    SAVEPOINT sp_quality;

    -- Часть 2: данные о качестве (могут быть ошибки)
    INSERT INTO fact_ore_quality (
        quality_id, date_id, time_id, shift_id, mine_id, shaft_id,
        sample_number, fe_content, moisture
    )
    VALUES (900001, 20250202, 1, 1, 1, 1, 'ORE-2025-0001', 55.5, 3.2);

    -- Допустим, ошибка при вставке второго замера
    -- ROLLBACK TO sp_quality;  -- Откатываем ТОЛЬКО качество

    -- Часть 1 (production) сохранена!
    RELEASE SAVEPOINT sp_quality;
COMMIT;

-- Пример 2.2. Несколько SAVEPOINT
BEGIN;
    SAVEPOINT sp_mine_1;
    INSERT INTO fact_production (production_id, date_id, shift_id, equipment_id,
        mine_id, shaft_id, operator_id, tons_mined, trips_count, operating_hours)
    VALUES (800020, 20250203, 1, 1, 1, 1, 1, 100.0, 8, 7.0);

    SAVEPOINT sp_mine_2;
    INSERT INTO fact_production (production_id, date_id, shift_id, equipment_id,
        mine_id, shaft_id, operator_id, tons_mined, trips_count, operating_hours)
    VALUES (800021, 20250203, 1, 3, 2, 5, 3, 95.0, 7, 6.5);

    SAVEPOINT sp_mine_3;
    -- Эта вставка с ошибкой — откатим только её
    -- INSERT INTO fact_production (...)
    -- VALUES (800022, 20250203, 1, 99999, 3, 5, 80.0, 6, 5.0);
    -- ROLLBACK TO sp_mine_3;

    -- Первые два INSERT сохранены
COMMIT;

-- ============================================================
-- 3. SAVEPOINT в PL/pgSQL (через EXCEPTION)
-- ============================================================

-- Пример 3.1. Пакетная обработка с изоляцией ошибок
DO $$
DECLARE
    rec RECORD;
    v_ok  INT := 0;
    v_err INT := 0;
BEGIN
    FOR rec IN
        SELECT generate_series AS production_id,
               20250210 AS date_id,
               ((generate_series - 1) % 2 + 1) AS shift_id,
               CASE WHEN generate_series % 5 = 0 THEN 99999
                    ELSE (generate_series % 10 + 1) END AS equipment_id,
               1 AS mine_id,
               1 AS shaft_id,
               1 AS operator_id,
               (random() * 100 + 50)::NUMERIC(8,2) AS tons,
               (random() * 10 + 3)::INT AS trips,
               (random() * 4 + 4)::NUMERIC(4,1) AS hours
        FROM generate_series(850001, 850020)
    LOOP
        -- Каждая вставка в своём подблоке (неявный SAVEPOINT)
        BEGIN
            INSERT INTO fact_production (
                production_id, date_id, shift_id, equipment_id,
                mine_id, shaft_id, operator_id, tons_mined, trips_count, operating_hours
            )
            VALUES (
                rec.production_id, rec.date_id, rec.shift_id,
                rec.equipment_id, rec.mine_id, rec.shaft_id, rec.operator_id,
                rec.tons, rec.trips, rec.hours
            );
            v_ok := v_ok + 1;
        EXCEPTION WHEN OTHERS THEN
            RAISE WARNING 'Ошибка ID=%: %', rec.production_id, SQLERRM;
            v_err := v_err + 1;
        END;
    END LOOP;

    RAISE NOTICE 'Вставлено: %, ошибок: %', v_ok, v_err;
END;
$$;

-- ============================================================
-- 4. Уровни изоляции транзакций
-- ============================================================

-- Пример 4.1. READ COMMITTED (по умолчанию в PostgreSQL)
-- Сессия 1:
BEGIN;
SET TRANSACTION ISOLATION LEVEL READ COMMITTED;
SELECT SUM(tons_mined) AS total FROM fact_production WHERE date_id = 20250115;
-- Результат: X тонн

-- Сессия 2 (в другом окне):
-- BEGIN;
-- INSERT INTO fact_production (...) VALUES (...);
-- COMMIT;

-- Сессия 1 (повторный запрос):
SELECT SUM(tons_mined) AS total FROM fact_production WHERE date_id = 20250115;
-- Результат может быть другим! (non-repeatable read)
COMMIT;

-- Пример 4.2. REPEATABLE READ
-- Сессия 1:
BEGIN;
SET TRANSACTION ISOLATION LEVEL REPEATABLE READ;
SELECT SUM(tons_mined) AS total FROM fact_production WHERE date_id = 20250115;
-- Результат: X тонн

-- Сессия 2 (в другом окне):
-- BEGIN;
-- INSERT INTO fact_production (...) VALUES (...);
-- COMMIT;

-- Сессия 1 (повторный запрос):
SELECT SUM(tons_mined) AS total FROM fact_production WHERE date_id = 20250115;
-- Результат: X тонн (ТОЖЕ САМОЕ — repeatable read!)
COMMIT;

-- Пример 4.3. SERIALIZABLE
-- Сессия 1:
BEGIN;
SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;
SELECT SUM(tons_mined) AS total FROM fact_production
WHERE date_id = 20250115 AND mine_id = 1;
-- Запоминаем total

UPDATE fact_production SET tons_mined = tons_mined * 1.1
WHERE date_id = 20250115 AND mine_id = 1;
COMMIT;

-- Сессия 2 (параллельно):
-- BEGIN;
-- SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;
-- SELECT SUM(tons_mined) AS total FROM fact_production
-- WHERE date_id = 20250115 AND mine_id = 1;
-- UPDATE fact_production SET tons_mined = tons_mined * 1.05
-- WHERE date_id = 20250115 AND mine_id = 1;
-- COMMIT;  -- Может получить ошибку serialization_failure!

-- ============================================================
-- 5. Демонстрация проблем конкурентного доступа
-- ============================================================

-- Пример 5.1. Dirty Read (НЕ возможен в PostgreSQL)
-- PostgreSQL всегда обеспечивает минимум READ COMMITTED
-- Даже при SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED
-- фактически будет READ COMMITTED

-- Пример 5.2. Non-Repeatable Read (демонстрация)
-- Подготовка: создадим тестовую таблицу
CREATE TABLE IF NOT EXISTS test_isolation (
    id    INT PRIMARY KEY,
    value NUMERIC
);
INSERT INTO test_isolation VALUES (1, 100) ON CONFLICT DO NOTHING;

-- Сессия 1 (READ COMMITTED):
BEGIN;
SELECT value FROM test_isolation WHERE id = 1;  -- 100

-- Сессия 2: UPDATE test_isolation SET value = 200 WHERE id = 1; COMMIT;

-- Сессия 1:
SELECT value FROM test_isolation WHERE id = 1;  -- 200 (значение изменилось!)
COMMIT;

-- Пример 5.3. Phantom Read (демонстрация)
-- Сессия 1 (READ COMMITTED):
BEGIN;
SELECT COUNT(*) FROM fact_production WHERE date_id = 20250115;  -- N

-- Сессия 2: INSERT INTO fact_production (...) VALUES (...date_id=20250115...); COMMIT;

-- Сессия 1:
SELECT COUNT(*) FROM fact_production WHERE date_id = 20250115;  -- N+1 (фантом!)
COMMIT;

-- ============================================================
-- 6. MVCC в PostgreSQL
-- ============================================================

-- Пример 6.1. Просмотр системных столбцов MVCC
SELECT
    ctid,           -- Физическое расположение кортежа
    xmin,           -- ID транзакции, создавшей запись
    xmax,           -- ID транзакции, удалившей/обновившей запись (0 = актуальна)
    mine_id,
    mine_name
FROM dim_mine
LIMIT 5;

-- Пример 6.2. Наблюдение за xmin/xmax при UPDATE
BEGIN;
SELECT txid_current();  -- ID текущей транзакции

-- Смотрим до обновления
SELECT ctid, xmin, xmax, mine_name
FROM dim_mine WHERE mine_id = 1;

-- Обновляем
UPDATE dim_mine SET mine_name = mine_name || ' (обновлено)' WHERE mine_id = 1;

-- Смотрим после обновления
SELECT ctid, xmin, xmax, mine_name
FROM dim_mine WHERE mine_id = 1;
-- ctid изменился (новый кортеж), xmin = текущая транзакция

ROLLBACK;  -- Откатываем изменение

-- Пример 6.3. Просмотр активных транзакций
SELECT
    pid,
    usename,
    state,
    query_start,
    xact_start,
    now() - xact_start AS duration,
    LEFT(query, 80) AS query
FROM pg_stat_activity
WHERE state != 'idle'
  AND pid != pg_backend_pid()
ORDER BY xact_start;

-- ============================================================
-- 7. Блокировки и Deadlocks
-- ============================================================

-- Пример 7.1. Просмотр текущих блокировок
SELECT
    l.locktype,
    l.relation::regclass AS table_name,
    l.mode,
    l.granted,
    a.pid,
    a.usename,
    LEFT(a.query, 60) AS query
FROM pg_locks l
JOIN pg_stat_activity a ON l.pid = a.pid
WHERE l.relation IS NOT NULL
  AND a.pid != pg_backend_pid()
ORDER BY l.relation, l.mode;

-- Пример 7.2. Демонстрация взаимной блокировки (deadlock)
-- !! ВЫПОЛНЯТЬ ТОЛЬКО В УЧЕБНЫХ ЦЕЛЯХ !!

-- Подготовка
CREATE TABLE IF NOT EXISTS test_deadlock (
    id     INT PRIMARY KEY,
    amount NUMERIC DEFAULT 0
);
INSERT INTO test_deadlock VALUES (1, 1000), (2, 2000)
ON CONFLICT DO NOTHING;

-- Сессия 1:
-- BEGIN;
-- UPDATE test_deadlock SET amount = amount - 100 WHERE id = 1;
-- -- Ждём 5 секунд, затем:
-- UPDATE test_deadlock SET amount = amount + 100 WHERE id = 2;
-- COMMIT;

-- Сессия 2 (одновременно):
-- BEGIN;
-- UPDATE test_deadlock SET amount = amount - 200 WHERE id = 2;
-- -- Ждём 5 секунд, затем:
-- UPDATE test_deadlock SET amount = amount + 200 WHERE id = 1;
-- COMMIT;
-- -- PostgreSQL обнаружит deadlock и отменит одну из транзакций!

-- Пример 7.3. Предотвращение deadlock — единый порядок блокировки
-- Правило: всегда блокировать ресурсы в одном порядке (по ID)
DO $$
DECLARE
    v_ids INT[] := ARRAY[2, 1];  -- Неупорядоченные
    v_sorted INT[];
BEGIN
    -- Сортируем ID для единого порядка блокировки
    SELECT ARRAY_AGG(id ORDER BY id)
    INTO v_sorted
    FROM UNNEST(v_ids) AS id;

    RAISE NOTICE 'Порядок блокировки: %', v_sorted;
    -- Теперь блокируем в порядке: 1, 2
END;
$$;

-- Пример 7.4. Обработка deadlock с повтором
CREATE OR REPLACE FUNCTION transfer_production_data(
    p_from_equipment INT,
    p_to_equipment   INT,
    p_date_id        INT,
    p_tons           NUMERIC
)
RETURNS VARCHAR
LANGUAGE plpgsql
AS $$
DECLARE
    v_retries    INT := 3;
    v_attempt    INT := 0;
    v_first_id   INT;
    v_second_id  INT;
BEGIN
    -- Упорядочиваем для предотвращения deadlock
    IF p_from_equipment < p_to_equipment THEN
        v_first_id := p_from_equipment;
        v_second_id := p_to_equipment;
    ELSE
        v_first_id := p_to_equipment;
        v_second_id := p_from_equipment;
    END IF;

    LOOP
        v_attempt := v_attempt + 1;

        BEGIN
            -- Блокируем в упорядоченном порядке
            PERFORM 1 FROM fact_production
            WHERE equipment_id = v_first_id AND date_id = p_date_id
            FOR UPDATE;

            PERFORM 1 FROM fact_production
            WHERE equipment_id = v_second_id AND date_id = p_date_id
            FOR UPDATE;

            -- Переносим тонны
            UPDATE fact_production
            SET tons_mined = tons_mined - p_tons
            WHERE equipment_id = p_from_equipment AND date_id = p_date_id;

            UPDATE fact_production
            SET tons_mined = tons_mined + p_tons
            WHERE equipment_id = p_to_equipment AND date_id = p_date_id;

            RETURN format('OK: перенесено %s т (попытка %s)', p_tons, v_attempt);

        EXCEPTION
            WHEN deadlock_detected THEN
                IF v_attempt >= v_retries THEN
                    RAISE EXCEPTION 'Deadlock не разрешён после % попыток', v_retries;
                END IF;
                RAISE NOTICE 'Deadlock на попытке %, повтор...', v_attempt;
                PERFORM pg_sleep(random());  -- Случайная задержка
        END;
    END LOOP;
END;
$$;

-- ============================================================
-- 8. Advisory Locks (Рекомендательные блокировки)
-- ============================================================

-- Пример 8.1. Эксклюзивная рекомендательная блокировка
DO $$
DECLARE
    v_lock_id BIGINT := 12345;  -- Уникальный ID блокировки
    v_acquired BOOLEAN;
BEGIN
    -- Попытка захватить блокировку (неблокирующая)
    v_acquired := pg_try_advisory_lock(v_lock_id);

    IF v_acquired THEN
        RAISE NOTICE 'Блокировка захвачена, выполняем ETL...';

        -- Имитация ETL-процесса
        PERFORM pg_sleep(2);

        -- Освобождаем блокировку
        PERFORM pg_advisory_unlock(v_lock_id);
        RAISE NOTICE 'ETL завершён, блокировка освобождена';
    ELSE
        RAISE NOTICE 'ETL уже выполняется другим процессом!';
    END IF;
END;
$$;

-- Пример 8.2. Advisory lock для предотвращения дублирования ETL
CREATE OR REPLACE FUNCTION run_daily_etl(p_date_id INT)
RETURNS VARCHAR
LANGUAGE plpgsql
AS $$
DECLARE
    v_lock_id BIGINT;
    v_acquired BOOLEAN;
    v_result VARCHAR;
BEGIN
    -- Уникальный ID блокировки на основе даты
    v_lock_id := p_date_id::BIGINT;

    -- Пытаемся захватить блокировку
    v_acquired := pg_try_advisory_lock(v_lock_id);

    IF NOT v_acquired THEN
        RETURN format('ETL для даты %s уже выполняется', p_date_id);
    END IF;

    BEGIN
        -- Проверяем, не обработана ли дата
        IF EXISTS(
            SELECT 1 FROM report_daily_production
            WHERE report_date = (
                SELECT full_date FROM dim_date WHERE date_id = p_date_id
            )
        ) THEN
            v_result := format('Дата %s уже обработана', p_date_id);
        ELSE
            -- Выполняем ETL
            INSERT INTO report_daily_production (
                report_date, mine_id, mine_name,
                total_tons, total_trips, avg_tons_per_trip
            )
            SELECT d.full_date, m.mine_id, m.mine_name,
                SUM(fp.tons_mined), SUM(fp.trips_count),
                ROUND(SUM(fp.tons_mined) / NULLIF(SUM(fp.trips_count), 0), 2)
            FROM fact_production fp
            JOIN dim_mine m ON fp.mine_id = m.mine_id
            JOIN dim_date d ON fp.date_id = d.date_id
            WHERE fp.date_id = p_date_id
            GROUP BY d.full_date, m.mine_id, m.mine_name;

            GET DIAGNOSTICS v_result = ROW_COUNT;
            v_result := format('ETL завершён: %s записей', v_result);
        END IF;

        -- Освобождаем блокировку
        PERFORM pg_advisory_unlock(v_lock_id);
        RETURN v_result;

    EXCEPTION WHEN OTHERS THEN
        -- В случае ошибки тоже освобождаем блокировку
        PERFORM pg_advisory_unlock(v_lock_id);
        RAISE;
    END;
END;
$$;

-- Тест
SELECT run_daily_etl(20250120);

-- ============================================================
-- 9. Транзакция в процедуре (COMMIT внутри процедуры)
-- ============================================================

-- Пример 9.1. Процедура с управлением транзакциями
CREATE OR REPLACE PROCEDURE batch_load_production(
    p_date_from INT,
    p_date_to   INT,
    p_batch_size INT DEFAULT 1000
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_date_id    INT;
    v_batch_count INT := 0;
    v_total_rows  INT := 0;
    v_batch_rows  INT;
BEGIN
    FOR v_date_id IN p_date_from..p_date_to
    LOOP
        -- Обработка одного дня
        INSERT INTO report_daily_production (
            report_date, mine_id, mine_name,
            total_tons, total_trips, avg_tons_per_trip
        )
        SELECT d.full_date, m.mine_id, m.mine_name,
            SUM(fp.tons_mined), SUM(fp.trips_count),
            ROUND(SUM(fp.tons_mined) / NULLIF(SUM(fp.trips_count), 0), 2)
        FROM fact_production fp
        JOIN dim_mine m ON fp.mine_id = m.mine_id
        JOIN dim_date d ON fp.date_id = d.date_id
        WHERE fp.date_id = v_date_id
        GROUP BY d.full_date, m.mine_id, m.mine_name;

        GET DIAGNOSTICS v_batch_rows = ROW_COUNT;
        v_total_rows := v_total_rows + v_batch_rows;
        v_batch_count := v_batch_count + 1;

        -- Фиксируем каждые N дней
        IF v_batch_count % p_batch_size = 0 THEN
            COMMIT;  -- Доступно только в PROCEDURE (не в FUNCTION!)
            RAISE NOTICE 'Зафиксировано % дней, % строк', v_batch_count, v_total_rows;
        END IF;
    END LOOP;

    COMMIT;  -- Финальная фиксация
    RAISE NOTICE 'Загрузка завершена: % дней, % строк', v_batch_count, v_total_rows;
END;
$$;

-- Вызов процедуры
-- CALL batch_load_production(20250101, 20250131, 7);

-- ============================================================
-- 10. Мониторинг транзакций
-- ============================================================

-- Пример 10.1. Просмотр длительных транзакций
SELECT
    pid,
    usename,
    state,
    now() - xact_start AS transaction_duration,
    now() - query_start AS query_duration,
    wait_event_type,
    wait_event,
    LEFT(query, 100) AS query
FROM pg_stat_activity
WHERE xact_start IS NOT NULL
  AND state != 'idle'
  AND pid != pg_backend_pid()
ORDER BY xact_start;

-- Пример 10.2. Просмотр ожидающих блокировок
SELECT
    blocked.pid AS blocked_pid,
    blocked.usename AS blocked_user,
    LEFT(blocked.query, 60) AS blocked_query,
    blocking.pid AS blocking_pid,
    blocking.usename AS blocking_user,
    LEFT(blocking.query, 60) AS blocking_query,
    now() - blocked.query_start AS wait_duration
FROM pg_stat_activity blocked
JOIN pg_locks blocked_locks ON blocked.pid = blocked_locks.pid
JOIN pg_locks blocking_locks ON blocked_locks.locktype = blocking_locks.locktype
    AND blocked_locks.relation = blocking_locks.relation
    AND blocked_locks.pid != blocking_locks.pid
JOIN pg_stat_activity blocking ON blocking_locks.pid = blocking.pid
WHERE NOT blocked_locks.granted
  AND blocking_locks.granted;

-- Пример 10.3. Принудительное завершение транзакции (осторожно!)
-- SELECT pg_cancel_backend(pid);     -- Отмена текущего запроса
-- SELECT pg_terminate_backend(pid);  -- Завершение всего соединения

-- ============================================================
-- Очистка тестовых объектов
-- ============================================================

-- DELETE FROM fact_production WHERE production_id BETWEEN 800001 AND 900000;
-- DROP TABLE IF EXISTS test_isolation;
-- DROP TABLE IF EXISTS test_deadlock;
-- DROP FUNCTION IF EXISTS transfer_production_data;
-- DROP FUNCTION IF EXISTS run_daily_etl;
-- DROP PROCEDURE IF EXISTS batch_load_production;
