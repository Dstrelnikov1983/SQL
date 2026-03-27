-- ============================================================
-- Модуль 4. Работа с типами данных PostgreSQL
-- Примеры на языке SQL (PostgreSQL)
-- Предприятие «Руда+»
-- ============================================================

-- ============================================================
-- 1. ТИПЫ ДАННЫХ: ПРИВЕДЕНИЕ И ПРОВЕРКА
-- ============================================================

-- 1.1 Приведение типов (CAST и ::)
SELECT CAST('2024-03-15' AS DATE);
SELECT CAST(42 AS TEXT);
SELECT CAST('123.45' AS NUMERIC(10,2));

-- Синтаксис PostgreSQL
SELECT '2024-03-15'::DATE;
SELECT 42::TEXT;
SELECT '123.45'::NUMERIC(10,2);

-- 1.2 Приведение date_id (INTEGER) в строку
SELECT 'Отчёт за дату: ' || date_id::TEXT AS report_header
FROM fact_production
LIMIT 5;

-- 1.3 Определение типа данных выражения
SELECT pg_typeof(42),
       pg_typeof('hello'),
       pg_typeof(3.14),
       pg_typeof(NOW()),
       pg_typeof(TRUE);

-- ============================================================
-- 2. СТРОКОВЫЕ ФУНКЦИИ
-- ============================================================

-- 2.1 Длина строки
SELECT equipment_name,
       LENGTH(equipment_name) AS name_length,
       LENGTH(inventory_number) AS inv_length
FROM dim_equipment;

-- 2.2 Регистр
SELECT equipment_name,
       UPPER(equipment_name) AS upper_name,
       LOWER(manufacturer) AS lower_manufacturer,
       INITCAP('погрузочно-доставочная машина') AS initcap_example
FROM dim_equipment;

-- 2.3 Конкатенация
-- Оператор ||
SELECT last_name || ' ' || first_name || ' ' || COALESCE(middle_name, '')
       AS full_name
FROM dim_operator;

-- Функция CONCAT (игнорирует NULL)
SELECT CONCAT(last_name, ' ', first_name, ' ', middle_name) AS full_name
FROM dim_operator;

-- CONCAT_WS (с разделителем)
SELECT CONCAT_WS(' ', last_name, first_name, middle_name) AS full_name
FROM dim_operator;

-- 2.4 Подстрока
SELECT inventory_number,
       SUBSTRING(inventory_number, 1, 3) AS prefix,       -- INV
       SUBSTRING(inventory_number FROM 5 FOR 3) AS type_part -- LHD или TRU
FROM dim_equipment;

-- LEFT и RIGHT
SELECT inventory_number,
       LEFT(inventory_number, 3) AS left_3,
       RIGHT(inventory_number, 3) AS right_3
FROM dim_equipment;

-- 2.5 Позиция подстроки
SELECT inventory_number,
       POSITION('-' IN inventory_number) AS first_dash_pos,
       STRPOS(inventory_number, '-') AS strpos_result -- аналог POSITION
FROM dim_equipment;

-- 2.6 SPLIT_PART — разбор по разделителю
SELECT inventory_number,
       SPLIT_PART(inventory_number, '-', 1) AS prefix,
       SPLIT_PART(inventory_number, '-', 2) AS type_code,
       SPLIT_PART(inventory_number, '-', 3) AS serial_no,
       CAST(SPLIT_PART(inventory_number, '-', 3) AS INTEGER) AS serial_int
FROM dim_equipment;

-- 2.7 TRIM — удаление символов
SELECT TRIM('   Руда+   ') AS trimmed,
       LTRIM('   Руда+') AS left_trimmed,
       RTRIM('Руда+   ') AS right_trimmed,
       TRIM(BOTH '-' FROM '--INV-LHD-001--') AS dash_trimmed;

-- 2.8 REPLACE и TRANSLATE
SELECT inventory_number,
       REPLACE(inventory_number, 'INV', 'EQ') AS replaced,
       TRANSLATE(inventory_number, '-', '/') AS translated
FROM dim_equipment;

-- 2.9 LPAD и RPAD — дополнение символами
SELECT equipment_id,
       LPAD(equipment_id::TEXT, 5, '0') AS padded_id,
       RPAD(equipment_name, 30, '.') AS padded_name
FROM dim_equipment;

-- 2.10 REPEAT и REVERSE
SELECT REPEAT('=-', 20) AS separator,
       REVERSE('Руда+') AS reversed;

-- 2.11 STRING_AGG — агрегация строк
SELECT m.mine_name,
       STRING_AGG(e.equipment_name, ', ' ORDER BY e.equipment_name)
           AS equipment_list,
       STRING_AGG(DISTINCT e.manufacturer, '; ' ORDER BY e.manufacturer)
           AS manufacturers
FROM dim_equipment e
JOIN dim_mine m ON e.mine_id = m.mine_id
GROUP BY m.mine_name;

-- 2.12 Формирование краткого имени оператора
SELECT CONCAT(
           last_name, ' ',
           LEFT(first_name, 1), '.',
           CASE
               WHEN middle_name IS NOT NULL
               THEN LEFT(middle_name, 1) || '.'
               ELSE ''
           END
       ) AS short_name
FROM dim_operator;

-- ============================================================
-- 3. ШАБЛОННЫЙ ПОИСК
-- ============================================================

-- 3.1 LIKE — простые шаблоны
-- % = любое количество символов, _ = ровно один символ
SELECT equipment_name FROM dim_equipment
WHERE equipment_name LIKE 'ПДМ%';

SELECT mine_name FROM dim_mine
WHERE mine_name LIKE '%Северная%';

SELECT inventory_number FROM dim_equipment
WHERE inventory_number LIKE 'INV-___-001';

-- 3.2 ILIKE — без учёта регистра (расширение PostgreSQL)
SELECT mine_name FROM dim_mine
WHERE mine_name ILIKE '%северная%';

SELECT manufacturer FROM dim_equipment
WHERE manufacturer ILIKE 's%';

-- 3.3 SIMILAR TO — SQL-стандарт regex
SELECT inventory_number, equipment_name
FROM dim_equipment
WHERE inventory_number SIMILAR TO 'INV-(LHD|TRUCK)-%';

SELECT type_name FROM dim_equipment_type
WHERE type_name SIMILAR TO '%(машина|самосвал)%';

-- 3.4 POSIX регулярные выражения
-- ~ = совпадение (с учётом регистра)
-- ~* = совпадение (без учёта регистра)
-- !~ = не совпадает
SELECT inventory_number FROM dim_equipment
WHERE inventory_number ~ '^INV-LHD-\d{3}$';

-- 3.5 REGEXP_MATCH — извлечение групп
SELECT inventory_number,
       (REGEXP_MATCH(inventory_number, '^INV-([A-Z]+)-(\d+)$'))[1] AS type_code,
       (REGEXP_MATCH(inventory_number, '^INV-([A-Z]+)-(\d+)$'))[2] AS serial_no
FROM dim_equipment;

-- 3.6 REGEXP_REPLACE — замена по шаблону
SELECT comment,
       REGEXP_REPLACE(comment, '\s+', ' ', 'g') AS normalized
FROM fact_equipment_downtime
WHERE comment IS NOT NULL
LIMIT 5;

-- ============================================================
-- 4. ДАТА И ВРЕМЯ
-- ============================================================

-- 4.1 Текущая дата и время
SELECT CURRENT_DATE        AS today,
       CURRENT_TIME        AS now_time,
       NOW()               AS now_timestamp,
       CURRENT_TIMESTAMP(0) AS now_no_frac;

-- 4.2 EXTRACT — извлечение компонентов
SELECT equipment_name,
       commissioning_date,
       EXTRACT(YEAR    FROM commissioning_date) AS comm_year,
       EXTRACT(MONTH   FROM commissioning_date) AS comm_month,
       EXTRACT(DAY     FROM commissioning_date) AS comm_day,
       EXTRACT(DOW     FROM commissioning_date) AS day_of_week,   -- 0=Вс, 1=Пн..6=Сб
       EXTRACT(QUARTER FROM commissioning_date) AS comm_quarter,
       EXTRACT(WEEK    FROM commissioning_date) AS comm_week,
       EXTRACT(DOY     FROM commissioning_date) AS day_of_year
FROM dim_equipment
WHERE commissioning_date IS NOT NULL;

-- 4.3 DATE_TRUNC — усечение
-- Усечение до месяца
SELECT DATE_TRUNC('month', d.full_date) AS month_start,
       SUM(fp.tons_mined) AS total_tons,
       COUNT(*) AS records
FROM fact_production fp
JOIN dim_date d ON fp.date_id = d.date_id
WHERE d.year = 2024
GROUP BY DATE_TRUNC('month', d.full_date)
ORDER BY month_start;

-- Усечение временных меток до часа
SELECT DATE_TRUNC('hour', start_time) AS hour_bucket,
       COUNT(*) AS downtime_count
FROM fact_equipment_downtime
GROUP BY DATE_TRUNC('hour', start_time)
ORDER BY downtime_count DESC
LIMIT 10;

-- 4.4 Арифметика дат
-- Дата +/- интервал
SELECT CURRENT_DATE + INTERVAL '30 days'  AS in_30_days,
       CURRENT_DATE - INTERVAL '1 year'   AS year_ago,
       CURRENT_DATE + INTERVAL '2 months' AS in_2_months;

-- Дата следующего ТО (каждые 90 дней)
SELECT equipment_name,
       commissioning_date,
       commissioning_date + INTERVAL '90 days'  AS first_to,
       commissioning_date + INTERVAL '180 days' AS second_to,
       commissioning_date + INTERVAL '365 days' AS annual_to
FROM dim_equipment
WHERE commissioning_date IS NOT NULL;

-- 4.5 Разница дат
SELECT equipment_name,
       commissioning_date,
       CURRENT_DATE - commissioning_date AS days_in_service,
       AGE(CURRENT_DATE, commissioning_date) AS age_full
FROM dim_equipment
WHERE commissioning_date IS NOT NULL
ORDER BY days_in_service DESC;

-- 4.6 EXTRACT(EPOCH ...) — разница в секундах/минутах
SELECT e.equipment_name,
       dt.start_time,
       dt.end_time,
       EXTRACT(EPOCH FROM (dt.end_time - dt.start_time)) AS diff_seconds,
       ROUND(EXTRACT(EPOCH FROM (dt.end_time - dt.start_time)) / 60, 1)
           AS diff_minutes,
       dt.duration_min
FROM fact_equipment_downtime dt
JOIN dim_equipment e ON dt.equipment_id = e.equipment_id
WHERE dt.end_time IS NOT NULL
ORDER BY diff_minutes DESC
LIMIT 10;

-- 4.7 TO_CHAR — форматирование дат
SELECT equipment_name,
       commissioning_date,
       TO_CHAR(commissioning_date, 'DD.MM.YYYY')      AS russian_format,
       TO_CHAR(commissioning_date, 'DD Month YYYY')    AS full_month,
       TO_CHAR(commissioning_date, 'YYYY-"Q"Q')        AS year_quarter,
       TO_CHAR(commissioning_date, 'Day')               AS day_name,
       TO_CHAR(commissioning_date, 'YYYY-MM')           AS year_month,
       TO_CHAR(commissioning_date, 'HH24:MI:SS')        AS time_part
FROM dim_equipment
WHERE commissioning_date IS NOT NULL;

-- 4.8 TO_DATE и TO_TIMESTAMP — парсинг строк
SELECT TO_DATE('15.03.2024', 'DD.MM.YYYY') AS parsed_date;
SELECT TO_TIMESTAMP('15-03-2024 14:30', 'DD-MM-YYYY HH24:MI') AS parsed_ts;

-- Парсинг date_id (INTEGER → DATE)
SELECT date_id,
       TO_DATE(date_id::TEXT, 'YYYYMMDD') AS parsed_date
FROM dim_date
WHERE year = 2024 AND month = 1
LIMIT 5;

-- ============================================================
-- 5. КОМПЛЕКСНЫЕ ПРИМЕРЫ
-- ============================================================

-- 5.1 Карточка оборудования
SELECT CONCAT(
           '[', et.type_name, '] ',
           e.equipment_name,
           ' (', e.manufacturer, ' ', e.model, ')',
           ' | Шахта: ', m.mine_name,
           ' | Введён: ', TO_CHAR(e.commissioning_date, 'DD.MM.YYYY'),
           ' | Возраст: ',
               EXTRACT(YEAR FROM AGE(CURRENT_DATE, e.commissioning_date))::INT,
               ' лет',
           ' | Статус: ',
               CASE e.status
                   WHEN 'active' THEN 'АКТИВЕН'
                   WHEN 'maintenance' THEN 'НА ТО'
                   WHEN 'decommissioned' THEN 'СПИСАН'
               END,
           ' | Видеорег.: ', CASE WHEN e.has_video_recorder THEN 'ДА' ELSE 'НЕТ' END,
           ' | Навигация: ', CASE WHEN e.has_navigation THEN 'ДА' ELSE 'НЕТ' END
       ) AS equipment_card
FROM dim_equipment e
JOIN dim_equipment_type et ON e.equipment_type_id = et.equipment_type_id
JOIN dim_mine m ON e.mine_id = m.mine_id
WHERE e.commissioning_date IS NOT NULL;

-- 5.2 Анализ простоев по дню недели
SELECT
    CASE EXTRACT(DOW FROM dt.start_time)
        WHEN 0 THEN 'Воскресенье'
        WHEN 1 THEN 'Понедельник'
        WHEN 2 THEN 'Вторник'
        WHEN 3 THEN 'Среда'
        WHEN 4 THEN 'Четверг'
        WHEN 5 THEN 'Пятница'
        WHEN 6 THEN 'Суббота'
    END AS day_name,
    COUNT(*) AS downtime_count,
    ROUND(AVG(dt.duration_min), 1) AS avg_duration_min,
    ROUND(SUM(dt.duration_min), 1) AS total_duration_min
FROM fact_equipment_downtime dt
GROUP BY EXTRACT(DOW FROM dt.start_time)
ORDER BY EXTRACT(DOW FROM dt.start_time);

-- 5.3 График калибровки датчиков
SELECT s.sensor_code,
       st.type_name AS sensor_type,
       e.equipment_name,
       s.calibration_date,
       s.calibration_date + INTERVAL '180 days' AS next_calibration,
       CURRENT_DATE - s.calibration_date AS days_since_calibration,
       CASE
           WHEN CURRENT_DATE - s.calibration_date > 180 THEN 'Просрочена'
           WHEN CURRENT_DATE - s.calibration_date > 150 THEN 'Скоро'
           ELSE 'В норме'
       END AS calibration_status
FROM dim_sensor s
JOIN dim_sensor_type st ON s.sensor_type_id = st.sensor_type_id
JOIN dim_equipment e ON s.equipment_id = e.equipment_id
WHERE s.calibration_date IS NOT NULL
ORDER BY
    CASE
        WHEN CURRENT_DATE - s.calibration_date > 180 THEN 1
        WHEN CURRENT_DATE - s.calibration_date > 150 THEN 2
        ELSE 3
    END,
    s.calibration_date;

-- 5.4 Проверка качества данных: формат инвентарного номера
SELECT inventory_number,
       CASE
           WHEN inventory_number ~ '^INV-[A-Z]+-\d{3}$'
           THEN 'Корректный'
           ELSE 'ОШИБКА ФОРМАТА'
       END AS format_check,
       CASE
           WHEN commissioning_date IS NULL THEN 'Нет даты ввода'
           WHEN EXTRACT(YEAR FROM commissioning_date) < year_manufactured
           THEN 'Дата ввода раньше года выпуска!'
           WHEN commissioning_date > CURRENT_DATE
           THEN 'Дата в будущем!'
           ELSE 'OK'
       END AS date_check
FROM dim_equipment;
