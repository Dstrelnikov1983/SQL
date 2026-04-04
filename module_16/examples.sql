-- ============================================================
-- Модуль 16: Программирование при помощи SQL
-- Примеры кода — Предприятие «Руда+»
-- PostgreSQL (PL/pgSQL)
-- ============================================================

-- ============================================================
-- 1. Анонимные блоки DO $$ ... END $$
-- ============================================================

-- Пример 1.1. Простой анонимный блок
DO $$
BEGIN
    RAISE NOTICE 'Добро пожаловать в MES-систему предприятия «Руда+»!';
    RAISE NOTICE 'Текущая дата: %', CURRENT_DATE;
    RAISE NOTICE 'Текущее время: %', CURRENT_TIME;
END;
$$;

-- Пример 1.2. Анонимный блок с переменными
DO $$
DECLARE
    v_total_mines   INT;
    v_total_equip   INT;
    v_total_sensors INT;
BEGIN
    SELECT COUNT(*) INTO v_total_mines   FROM dim_mine;
    SELECT COUNT(*) INTO v_total_equip   FROM dim_equipment;
    SELECT COUNT(*) INTO v_total_sensors FROM dim_sensor;

    RAISE NOTICE 'Статистика «Руда+»:';
    RAISE NOTICE '  Шахт: %', v_total_mines;
    RAISE NOTICE '  Оборудования: %', v_total_equip;
    RAISE NOTICE '  Датчиков: %', v_total_sensors;
END;
$$;

-- Пример 1.3. Анонимный блок с вычислениями
DO $$
DECLARE
    v_avg_production NUMERIC;
    v_max_production NUMERIC;
    v_min_production NUMERIC;
BEGIN
    SELECT
        ROUND(AVG(tons_mined), 2),
        MAX(tons_mined),
        MIN(tons_mined)
    INTO v_avg_production, v_max_production, v_min_production
    FROM fact_production
    WHERE date_id BETWEEN 20250101 AND 20250131;

    RAISE NOTICE 'Добыча за январь 2025:';
    RAISE NOTICE '  Средняя: % т', v_avg_production;
    RAISE NOTICE '  Максимальная: % т', v_max_production;
    RAISE NOTICE '  Минимальная: % т', v_min_production;
END;
$$;

-- ============================================================
-- 2. Переменные: DECLARE, присваивание
-- ============================================================

-- Пример 2.1. Различные типы переменных
DO $$
DECLARE
    v_mine_name    VARCHAR(100) := 'Шахта Северная';
    v_shift_count  INT          := 3;
    v_target_tons  NUMERIC(10,2) DEFAULT 500.00;
    v_is_active    BOOLEAN      := TRUE;
    v_report_date  DATE         := CURRENT_DATE;
    v_start_time   TIMESTAMP    := NOW();
    v_description  TEXT;
BEGIN
    v_description := format(
        'Шахта: %s, Смен: %s, Цель: %s т',
        v_mine_name, v_shift_count, v_target_tons
    );
    RAISE NOTICE '%', v_description;
END;
$$;

-- Пример 2.2. Использование %TYPE для типов на основе столбцов
DO $$
DECLARE
    v_equipment_name dim_equipment.equipment_name%TYPE;
    v_mine_id        dim_mine.mine_id%TYPE;
    v_row            dim_equipment%ROWTYPE;
BEGIN
    SELECT * INTO v_row
    FROM dim_equipment
    WHERE equipment_id = 1;

    RAISE NOTICE 'Оборудование: % (ID шахты: %)',
        v_row.equipment_name, v_row.mine_id;
END;
$$;

-- Пример 2.3. Присваивание через SELECT INTO
DO $$
DECLARE
    v_total_tons    NUMERIC;
    v_total_trips   INT;
    v_mine_name     VARCHAR;
BEGIN
    SELECT m.mine_name, SUM(fp.tons_mined), SUM(fp.trips_count)
    INTO v_mine_name, v_total_tons, v_total_trips
    FROM fact_production fp
    JOIN dim_mine m ON fp.mine_id = m.mine_id
    WHERE fp.mine_id = 1
      AND fp.date_id BETWEEN 20250101 AND 20250131
    GROUP BY m.mine_name;

    RAISE NOTICE 'Шахта «%»: добыто % т за % рейсов',
        v_mine_name, v_total_tons, v_total_trips;
END;
$$;

-- ============================================================
-- 3. Управление потоком: IF / ELSIF / ELSE
-- ============================================================

-- Пример 3.1. Оценка качества руды
DO $$
DECLARE
    v_fe_content NUMERIC := 58.5;
    v_grade      VARCHAR;
BEGIN
    IF v_fe_content >= 65 THEN
        v_grade := 'Высший сорт (богатая руда)';
    ELSIF v_fe_content >= 55 THEN
        v_grade := 'Первый сорт';
    ELSIF v_fe_content >= 45 THEN
        v_grade := 'Второй сорт';
    ELSIF v_fe_content >= 30 THEN
        v_grade := 'Третий сорт (бедная руда)';
    ELSE
        v_grade := 'Пустая порода';
    END IF;

    RAISE NOTICE 'Содержание Fe: %, Сорт: %', v_fe_content, v_grade;
END;
$$;

-- Пример 3.2. Оценка эффективности смены
DO $$
DECLARE
    v_shift_id       INT := 1;
    v_actual_tons    NUMERIC;
    v_target_tons    NUMERIC := 800.0;
    v_efficiency     NUMERIC;
    v_status         VARCHAR;
BEGIN
    SELECT COALESCE(SUM(tons_mined), 0)
    INTO v_actual_tons
    FROM fact_production
    WHERE shift_id = v_shift_id
      AND date_id = 20250115;

    v_efficiency := ROUND(v_actual_tons / NULLIF(v_target_tons, 0) * 100, 1);

    IF v_efficiency IS NULL THEN
        v_status := 'Нет данных';
    ELSIF v_efficiency >= 100 THEN
        v_status := 'План выполнен';
    ELSIF v_efficiency >= 80 THEN
        v_status := 'Удовлетворительно';
    ELSIF v_efficiency >= 50 THEN
        v_status := 'Ниже нормы';
    ELSE
        v_status := 'Критическое отставание';
    END IF;

    RAISE NOTICE 'Смена %: добыто % т из % т (% %%), статус: %',
        v_shift_id, v_actual_tons, v_target_tons, v_efficiency, v_status;
END;
$$;

-- ============================================================
-- 4. Оператор CASE в PL/pgSQL
-- ============================================================

-- Пример 4.1. Простой CASE
DO $$
DECLARE
    v_equipment_type_id INT := 1;
    v_category VARCHAR;
BEGIN
    SELECT type_name INTO v_category
    FROM dim_equipment_type
    WHERE equipment_type_id = v_equipment_type_id;

    CASE v_category
        WHEN 'ПДМ' THEN
            RAISE NOTICE 'Погрузочно-доставочная машина — категория: погрузка';
        WHEN 'Самосвал' THEN
            RAISE NOTICE 'Шахтный самосвал — категория: транспортировка';
        WHEN 'Вагонетка' THEN
            RAISE NOTICE 'Вагонетка — категория: откатка';
        WHEN 'Скиповый подъёмник' THEN
            RAISE NOTICE 'Скиповый подъёмник — категория: подъём';
        ELSE
            RAISE NOTICE 'Неизвестный тип: %', v_category;
    END CASE;
END;
$$;

-- Пример 4.2. Поисковый CASE (searched CASE)
DO $$
DECLARE
    v_downtime_hours NUMERIC;
    v_severity       VARCHAR;
    rec RECORD;
BEGIN
    FOR rec IN
        SELECT
            e.equipment_name,
            SUM(fd.duration_min) / 60.0 AS hours
        FROM fact_equipment_downtime fd
        JOIN dim_equipment e ON fd.equipment_id = e.equipment_id
        WHERE fd.date_id BETWEEN 20250101 AND 20250131
        GROUP BY e.equipment_name
        ORDER BY hours DESC
        LIMIT 5
    LOOP
        CASE
            WHEN rec.hours > 100 THEN v_severity := 'КРИТИЧНО';
            WHEN rec.hours > 50  THEN v_severity := 'ВЫСОКАЯ';
            WHEN rec.hours > 20  THEN v_severity := 'СРЕДНЯЯ';
            ELSE                      v_severity := 'НИЗКАЯ';
        END CASE;

        RAISE NOTICE '% — простой: % ч, серьёзность: %',
            rec.equipment_name, ROUND(rec.hours, 1), v_severity;
    END LOOP;
END;
$$;

-- ============================================================
-- 5. Циклы: LOOP, WHILE, FOR, FOREACH
-- ============================================================

-- Пример 5.1. Простой LOOP с EXIT
DO $$
DECLARE
    v_counter INT := 0;
    v_total   NUMERIC := 0;
    v_daily_production NUMERIC;
BEGIN
    LOOP
        v_counter := v_counter + 1;
        EXIT WHEN v_counter > 10;

        SELECT COALESCE(SUM(tons_mined), 0)
        INTO v_daily_production
        FROM fact_production
        WHERE date_id = 20250100 + v_counter;

        v_total := v_total + v_daily_production;

        RAISE NOTICE 'День %: % т (нарастающий: % т)',
            v_counter, v_daily_production, v_total;
    END LOOP;

    RAISE NOTICE 'Итого за первые 10 дней января: % т', v_total;
END;
$$;

-- Пример 5.2. LOOP с CONTINUE
DO $$
DECLARE
    v_day INT := 0;
    v_prod NUMERIC;
BEGIN
    LOOP
        v_day := v_day + 1;
        EXIT WHEN v_day > 31;

        -- Пропускаем выходные (упрощённо: каждый 7-й день)
        CONTINUE WHEN v_day % 7 = 0;

        SELECT COALESCE(SUM(tons_mined), 0)
        INTO v_prod
        FROM fact_production
        WHERE date_id = 20250100 + v_day;

        IF v_prod > 0 THEN
            RAISE NOTICE 'День %: % т', v_day, v_prod;
        END IF;
    END LOOP;
END;
$$;

-- Пример 5.3. WHILE — ожидание выполнения плана
DO $$
DECLARE
    v_date_id      INT := 20250101;
    v_accumulated   NUMERIC := 0;
    v_monthly_target NUMERIC := 50000;
    v_daily_prod    NUMERIC;
BEGIN
    WHILE v_accumulated < v_monthly_target AND v_date_id <= 20250131
    LOOP
        SELECT COALESCE(SUM(tons_mined), 0)
        INTO v_daily_prod
        FROM fact_production
        WHERE date_id = v_date_id;

        v_accumulated := v_accumulated + v_daily_prod;
        v_date_id := v_date_id + 1;
    END LOOP;

    IF v_accumulated >= v_monthly_target THEN
        RAISE NOTICE 'План % т выполнен к дате %',
            v_monthly_target, v_date_id - 1;
    ELSE
        RAISE NOTICE 'План не выполнен. Добыто: % т из % т',
            v_accumulated, v_monthly_target;
    END IF;
END;
$$;

-- Пример 5.4. FOR — числовой диапазон
DO $$
DECLARE
    v_month INT;
    v_prod  NUMERIC;
BEGIN
    RAISE NOTICE 'Добыча по месяцам 2025:';
    FOR v_month IN 1..12 LOOP
        SELECT COALESCE(SUM(tons_mined), 0)
        INTO v_prod
        FROM fact_production
        WHERE date_id BETWEEN (20250000 + v_month * 100 + 1)
                         AND (20250000 + v_month * 100 + 31);

        RAISE NOTICE '  Месяц %: % т', LPAD(v_month::TEXT, 2, '0'), v_prod;
    END LOOP;
END;
$$;

-- Пример 5.5. FOR — итерация по результату запроса
DO $$
DECLARE
    rec RECORD;
    v_rank INT := 0;
BEGIN
    RAISE NOTICE 'ТОП-5 шахт по добыче за январь 2025:';

    FOR rec IN
        SELECT
            m.mine_name,
            SUM(fp.tons_mined) AS total_tons,
            COUNT(DISTINCT fp.equipment_id) AS equipment_used
        FROM fact_production fp
        JOIN dim_mine m ON fp.mine_id = m.mine_id
        WHERE fp.date_id BETWEEN 20250101 AND 20250131
        GROUP BY m.mine_name
        ORDER BY total_tons DESC
        LIMIT 5
    LOOP
        v_rank := v_rank + 1;
        RAISE NOTICE '  #%: % — % т (оборудование: % ед.)',
            v_rank, rec.mine_name, rec.total_tons, rec.equipment_used;
    END LOOP;
END;
$$;

-- Пример 5.6. FOREACH — итерация по массиву
DO $$
DECLARE
    v_mine_ids INT[] := ARRAY[1, 2, 3, 4, 5];
    v_mine_id  INT;
    v_name     VARCHAR;
    v_tons     NUMERIC;
BEGIN
    FOREACH v_mine_id IN ARRAY v_mine_ids
    LOOP
        SELECT m.mine_name, COALESCE(SUM(fp.tons_mined), 0)
        INTO v_name, v_tons
        FROM dim_mine m
        LEFT JOIN fact_production fp ON fp.mine_id = m.mine_id
            AND fp.date_id BETWEEN 20250101 AND 20250131
        WHERE m.mine_id = v_mine_id
        GROUP BY m.mine_name;

        RAISE NOTICE 'Шахта «%» (ID=%): % т', v_name, v_mine_id, v_tons;
    END LOOP;
END;
$$;

-- Пример 5.7. Обратный FOR (REVERSE)
DO $$
BEGIN
    RAISE NOTICE 'Обратный отсчёт дней:';
    FOR i IN REVERSE 10..1 LOOP
        RAISE NOTICE '  День %', i;
    END LOOP;
END;
$$;

-- ============================================================
-- 6. RAISE — уровни сообщений
-- ============================================================

-- Пример 6.1. Различные уровни RAISE
DO $$
DECLARE
    v_fe_content NUMERIC := 25.0;
BEGIN
    -- DEBUG — только при debug уровне клиента
    RAISE DEBUG 'Проверка Fe содержания: %', v_fe_content;

    -- LOG — серверный лог
    RAISE LOG 'Анализ пробы: Fe = % %%', v_fe_content;

    -- INFO — информационное сообщение
    RAISE INFO 'Начинаем проверку качества руды';

    -- NOTICE — по умолчанию видно клиенту
    RAISE NOTICE 'Содержание Fe: % %%', v_fe_content;

    -- WARNING — предупреждение
    IF v_fe_content < 30 THEN
        RAISE WARNING 'Содержание Fe (% %%) ниже минимального порога (30 %%)', v_fe_content;
    END IF;

    -- EXCEPTION — ошибка (прерывает выполнение)
    IF v_fe_content < 10 THEN
        RAISE EXCEPTION 'Критически низкое содержание Fe: % %%', v_fe_content
            USING HINT = 'Проверьте точку отбора пробы',
                  ERRCODE = 'P0001';
    END IF;
END;
$$;

-- Пример 6.2. Форматирование сообщений с %
DO $$
DECLARE
    v_mine     VARCHAR := 'Северная';
    v_tons     NUMERIC := 1234.56;
    v_target   NUMERIC := 1500.00;
    v_percent  NUMERIC;
BEGIN
    v_percent := ROUND(v_tons / v_target * 100, 1);
    RAISE NOTICE 'Шахта «%»: добыто % т из % т (% %%)',
        v_mine, v_tons, v_target, v_percent;
END;
$$;

-- ============================================================
-- 7. RETURN, RETURN NEXT, RETURN QUERY
-- ============================================================

-- Пример 7.1. Простой RETURN
CREATE OR REPLACE FUNCTION get_mine_production_total(
    p_mine_id INT,
    p_date_from INT,
    p_date_to INT
)
RETURNS NUMERIC
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
    v_total NUMERIC;
BEGIN
    SELECT COALESCE(SUM(tons_mined), 0)
    INTO v_total
    FROM fact_production
    WHERE mine_id = p_mine_id
      AND date_id BETWEEN p_date_from AND p_date_to;

    RETURN v_total;
END;
$$;

-- Тест
SELECT get_mine_production_total(1, 20250101, 20250131);

-- Пример 7.2. RETURN NEXT — построчный возврат
CREATE OR REPLACE FUNCTION get_monthly_production_report(
    p_year INT
)
RETURNS TABLE (
    month_num    INT,
    month_name   VARCHAR,
    total_tons   NUMERIC,
    total_trips  INT,
    avg_per_day  NUMERIC
)
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
    v_month_names VARCHAR[] := ARRAY[
        'Январь','Февраль','Март','Апрель','Май','Июнь',
        'Июль','Август','Сентябрь','Октябрь','Ноябрь','Декабрь'
    ];
    v_date_from INT;
    v_date_to   INT;
    v_days      INT;
BEGIN
    FOR i IN 1..12 LOOP
        month_num := i;
        month_name := v_month_names[i];
        v_date_from := p_year * 10000 + i * 100 + 1;
        v_date_to   := p_year * 10000 + i * 100 + 31;

        SELECT
            COALESCE(SUM(fp.tons_mined), 0),
            COALESCE(SUM(fp.trips_count), 0)
        INTO total_tons, total_trips
        FROM fact_production fp
        WHERE fp.date_id BETWEEN v_date_from AND v_date_to;

        -- Количество рабочих дней
        SELECT COUNT(DISTINCT date_id)
        INTO v_days
        FROM fact_production
        WHERE date_id BETWEEN v_date_from AND v_date_to;

        avg_per_day := CASE
            WHEN v_days > 0 THEN ROUND(total_tons / v_days, 1)
            ELSE 0
        END;

        RETURN NEXT;  -- Возвращаем текущую строку
    END LOOP;
END;
$$;

-- Тест
SELECT * FROM get_monthly_production_report(2025);

-- Пример 7.3. RETURN QUERY
CREATE OR REPLACE FUNCTION get_equipment_downtime_summary(
    p_mine_id    INT,
    p_date_from  INT,
    p_date_to    INT
)
RETURNS TABLE (
    equipment_name   VARCHAR,
    downtime_hours   NUMERIC,
    incident_count   BIGINT,
    top_reason       VARCHAR
)
LANGUAGE plpgsql
STABLE
AS $$
BEGIN
    RETURN QUERY
    SELECT
        e.equipment_name,
        ROUND(SUM(fd.duration_min) / 60.0, 1),
        COUNT(*),
        (
            SELECT dr.reason_name
            FROM fact_equipment_downtime fd2
            JOIN dim_downtime_reason dr ON fd2.reason_id = dr.reason_id
            WHERE fd2.equipment_id = e.equipment_id
              AND fd2.date_id BETWEEN p_date_from AND p_date_to
            GROUP BY dr.reason_name
            ORDER BY COUNT(*) DESC
            LIMIT 1
        )
    FROM fact_equipment_downtime fd
    JOIN dim_equipment e ON fd.equipment_id = e.equipment_id
    WHERE fd.date_id BETWEEN p_date_from AND p_date_to
      AND e.mine_id = p_mine_id
    GROUP BY e.equipment_id, e.equipment_name
    ORDER BY SUM(fd.duration_min) DESC;
END;
$$;

-- Тест
SELECT * FROM get_equipment_downtime_summary(1, 20250101, 20250131);

-- ============================================================
-- 8. Курсоры
-- ============================================================

-- Пример 8.1. Простой курсор
DO $$
DECLARE
    cur_equipment CURSOR FOR
        SELECT e.equipment_id, e.equipment_name, et.type_name
        FROM dim_equipment e
        JOIN dim_equipment_type et ON e.equipment_type_id = et.equipment_type_id
        ORDER BY e.equipment_id;
    rec RECORD;
    v_count INT := 0;
BEGIN
    OPEN cur_equipment;

    LOOP
        FETCH cur_equipment INTO rec;
        EXIT WHEN NOT FOUND;

        v_count := v_count + 1;
        RAISE NOTICE '#%: % [%]',
            v_count, rec.equipment_name, rec.type_name;
    END LOOP;

    CLOSE cur_equipment;
    RAISE NOTICE 'Всего единиц оборудования: %', v_count;
END;
$$;

-- Пример 8.2. Курсор с параметрами
DO $$
DECLARE
    cur_production CURSOR (p_mine_id INT, p_date INT) FOR
        SELECT
            e.equipment_name,
            fp.tons_mined,
            fp.trips_count
        FROM fact_production fp
        JOIN dim_equipment e ON fp.equipment_id = e.equipment_id
        WHERE fp.mine_id = p_mine_id
          AND fp.date_id = p_date
        ORDER BY fp.tons_mined DESC;
    rec RECORD;
BEGIN
    RAISE NOTICE '=== Добыча по оборудованию (шахта 1, 15.01.2025) ===';

    OPEN cur_production(1, 20250115);

    LOOP
        FETCH cur_production INTO rec;
        EXIT WHEN NOT FOUND;

        RAISE NOTICE '  % — % т, % рейсов',
            rec.equipment_name, rec.tons_mined, rec.trips_count;
    END LOOP;

    CLOSE cur_production;
END;
$$;

-- Пример 8.3. Курсор с FOR (автоматическое открытие/закрытие)
DO $$
DECLARE
    cur_mines CURSOR FOR
        SELECT mine_id, mine_name FROM dim_mine ORDER BY mine_id;
BEGIN
    FOR rec IN cur_mines LOOP
        RAISE NOTICE 'Шахта: % (ID: %)', rec.mine_name, rec.mine_id;
    END LOOP;
    -- Курсор автоматически закрывается
END;
$$;

-- Пример 8.4. Курсор для пакетной обработки данных
-- Создадим таблицу для отчётов
CREATE TABLE IF NOT EXISTS report_daily_production (
    report_date   DATE,
    mine_id       INT,
    mine_name     VARCHAR(100),
    total_tons    NUMERIC(12,2),
    total_trips   INT,
    avg_tons_per_trip NUMERIC(10,2),
    created_at    TIMESTAMP DEFAULT NOW()
);

DO $$
DECLARE
    cur_dates CURSOR FOR
        SELECT DISTINCT date_id
        FROM fact_production
        WHERE date_id BETWEEN 20250101 AND 20250107
        ORDER BY date_id;
    v_date_id    INT;
    v_inserted   INT := 0;
BEGIN
    FOR rec_date IN cur_dates LOOP
        INSERT INTO report_daily_production (
            report_date, mine_id, mine_name,
            total_tons, total_trips, avg_tons_per_trip
        )
        SELECT
            d.full_date,
            m.mine_id,
            m.mine_name,
            SUM(fp.tons_mined),
            SUM(fp.trips_count),
            ROUND(SUM(fp.tons_mined) / NULLIF(SUM(fp.trips_count), 0), 2)
        FROM fact_production fp
        JOIN dim_mine m ON fp.mine_id = m.mine_id
        JOIN dim_date d ON fp.date_id = d.date_id
        WHERE fp.date_id = rec_date.date_id
        GROUP BY d.full_date, m.mine_id, m.mine_name;

        GET DIAGNOSTICS v_inserted = ROW_COUNT;
        RAISE NOTICE 'Дата %: вставлено % записей', rec_date.date_id, v_inserted;
    END LOOP;
END;
$$;

-- Проверка результата
SELECT * FROM report_daily_production ORDER BY report_date, mine_id;

-- ============================================================
-- 9. Комплексный пример: генерация аналитического отчёта
-- ============================================================

CREATE OR REPLACE FUNCTION generate_shift_report(
    p_date_id   INT,
    p_mine_id   INT DEFAULT NULL
)
RETURNS TABLE (
    mine_name       VARCHAR,
    shift_name      VARCHAR,
    equipment_count BIGINT,
    total_tons      NUMERIC,
    total_trips     BIGINT,
    downtime_hours  NUMERIC,
    oee_percent     NUMERIC,
    status          VARCHAR
)
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
    v_target_tons NUMERIC := 200;  -- Целевая добыча на смену
BEGIN
    RETURN QUERY
    WITH production AS (
        SELECT
            fp.mine_id,
            fp.shift_id,
            COUNT(DISTINCT fp.equipment_id) AS eq_count,
            SUM(fp.tons_mined) AS tons,
            SUM(fp.trips_count) AS trips,
            SUM(fp.operating_hours) AS op_hours
        FROM fact_production fp
        WHERE fp.date_id = p_date_id
          AND (p_mine_id IS NULL OR fp.mine_id = p_mine_id)
        GROUP BY fp.mine_id, fp.shift_id
    ),
    downtime AS (
        SELECT
            e.mine_id,
            fd.shift_id,
            SUM(fd.duration_min) / 60.0 AS dt_hours
        FROM fact_equipment_downtime fd
        JOIN dim_equipment e ON fd.equipment_id = e.equipment_id
        WHERE fd.date_id = p_date_id
          AND (p_mine_id IS NULL OR e.mine_id = p_mine_id)
        GROUP BY e.mine_id, fd.shift_id
    )
    SELECT
        m.mine_name,
        s.shift_name,
        p.eq_count,
        ROUND(p.tons, 1),
        p.trips,
        ROUND(COALESCE(dt.dt_hours, 0), 1),
        ROUND(p.op_hours / NULLIF(p.eq_count * 8.0, 0) * 100, 1),
        (CASE
            WHEN p.tons >= v_target_tons THEN 'План выполнен'
            WHEN p.tons >= v_target_tons * 0.8 THEN 'Близко к плану'
            WHEN p.tons >= v_target_tons * 0.5 THEN 'Отставание'
            ELSE 'Критично'
        END)::VARCHAR
    FROM production p
    JOIN dim_mine m ON p.mine_id = m.mine_id
    JOIN dim_shift s ON p.shift_id = s.shift_id
    LEFT JOIN downtime dt ON dt.mine_id = p.mine_id AND dt.shift_id = p.shift_id
    ORDER BY m.mine_name, s.shift_name;
END;
$$;

-- Тест: отчёт за день по всем шахтам
SELECT * FROM generate_shift_report(20250115);

-- Тест: отчёт по конкретной шахте
SELECT * FROM generate_shift_report(20250115, 1);

-- ============================================================
-- 10. Пакетная валидация данных
-- ============================================================

CREATE OR REPLACE FUNCTION validate_production_data(
    p_date_from INT,
    p_date_to   INT
)
RETURNS TABLE (
    check_name   VARCHAR,
    status       VARCHAR,
    details      TEXT
)
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
    v_count      INT;
    v_total      NUMERIC;
BEGIN
    -- Проверка 1: Отрицательные значения добычи
    check_name := 'Отрицательная добыча';
    SELECT COUNT(*)
    INTO v_count
    FROM fact_production
    WHERE tons_mined < 0
      AND date_id BETWEEN p_date_from AND p_date_to;

    IF v_count > 0 THEN
        status := 'ОШИБКА';
        details := format('Найдено %s записей с отрицательной добычей', v_count);
    ELSE
        status := 'ОК';
        details := 'Отрицательных значений нет';
    END IF;
    RETURN NEXT;

    -- Проверка 2: Аномально высокая добыча
    check_name := 'Аномальная добыча (>500 т)';
    SELECT COUNT(*)
    INTO v_count
    FROM fact_production
    WHERE tons_mined > 500
      AND date_id BETWEEN p_date_from AND p_date_to;

    IF v_count > 0 THEN
        status := 'ПРЕДУПРЕЖДЕНИЕ';
        details := format('Найдено %s записей с добычей >500 т — требуется проверка', v_count);
    ELSE
        status := 'ОК';
        details := 'Аномальных значений нет';
    END IF;
    RETURN NEXT;

    -- Проверка 3: Нулевые рабочие часы при ненулевой добыче
    check_name := 'Нулевые часы с добычей';
    SELECT COUNT(*)
    INTO v_count
    FROM fact_production
    WHERE operating_hours = 0 AND tons_mined > 0
      AND date_id BETWEEN p_date_from AND p_date_to;

    IF v_count > 0 THEN
        status := 'ОШИБКА';
        details := format('Найдено %s записей: добыча >0 при 0 рабочих часах', v_count);
    ELSE
        status := 'ОК';
        details := 'Несоответствий нет';
    END IF;
    RETURN NEXT;

    -- Проверка 4: Пропущенные даты
    check_name := 'Пропущенные даты';
    SELECT COUNT(*)
    INTO v_count
    FROM dim_date d
    WHERE d.date_id BETWEEN p_date_from AND p_date_to
      AND d.is_weekend = FALSE
      AND NOT EXISTS (
          SELECT 1 FROM fact_production fp WHERE fp.date_id = d.date_id
      );

    IF v_count > 0 THEN
        status := 'ПРЕДУПРЕЖДЕНИЕ';
        details := format('Найдено %s рабочих дней без данных о добыче', v_count);
    ELSE
        status := 'ОК';
        details := 'Все рабочие дни имеют данные';
    END IF;
    RETURN NEXT;
END;
$$;

-- Тест
SELECT * FROM validate_production_data(20250101, 20250131);

-- ============================================================
-- Очистка тестовых объектов
-- ============================================================

-- DROP TABLE IF EXISTS report_daily_production;
-- DROP FUNCTION IF EXISTS get_mine_production_total;
-- DROP FUNCTION IF EXISTS get_monthly_production_report;
-- DROP FUNCTION IF EXISTS get_equipment_downtime_summary;
-- DROP FUNCTION IF EXISTS generate_shift_report;
-- DROP FUNCTION IF EXISTS validate_production_data;
