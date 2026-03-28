-- ============================================================
-- Модуль 3. Сравнение простейших запросов SQL и DAX
-- Примеры на языке SQL (PostgreSQL)
-- Предприятие «Руда+»
-- ============================================================

-- ============================================================
-- 1. ПРОСТОЙ SELECT
-- ============================================================

-- 1.1 Выбрать все столбцы из таблицы оборудования
SELECT *
FROM dim_equipment;

-- 1.2 Выбрать определённые столбцы
SELECT equipment_name,
       inventory_number,
       manufacturer,
       model,
       status
FROM dim_equipment;

-- 1.3 Выбрать уникальных производителей оборудования
SELECT DISTINCT manufacturer
FROM dim_equipment;

-- 1.4 Выбрать уникальные комбинации производитель + модель
SELECT DISTINCT manufacturer, model
FROM dim_equipment;

-- 1.5 Подсчитать количество единиц оборудования
SELECT COUNT(*) AS total_equipment
FROM dim_equipment;

-- ============================================================
-- 2. ФИЛЬТРАЦИЯ (WHERE)
-- ============================================================

-- 2.1 Оборудование шахты «Северная» (mine_id = 1)
SELECT equipment_name,
       inventory_number,
       manufacturer,
       model,
       status
FROM dim_equipment
WHERE mine_id = 1;

-- 2.2 Активное оборудование
SELECT equipment_name, manufacturer, model
FROM dim_equipment
WHERE status = 'active';

-- 2.3 ПДМ (equipment_type_id = 1) на шахте «Северная»
SELECT equipment_name, manufacturer, model, year_manufactured
FROM dim_equipment
WHERE equipment_type_id = 1
  AND mine_id = 1;

-- 2.4 Оборудование выпуска после 2020 года
SELECT equipment_name, manufacturer, model, year_manufactured
FROM dim_equipment
WHERE year_manufactured > 2020;

-- 2.5 Оборудование с видеорегистратором
SELECT equipment_name, manufacturer, model
FROM dim_equipment
WHERE has_video_recorder = TRUE;

-- 2.6 Добыча более 100 тонн за смену
SELECT production_id, date_id, equipment_id, operator_id,
       tons_mined, tons_transported
FROM fact_production
WHERE tons_mined > 100;

-- 2.7 Использование BETWEEN: добыча за январь 2024
SELECT date_id, equipment_id, operator_id,
       tons_mined, trips_count
FROM fact_production
WHERE date_id BETWEEN 20240101 AND 20240131;

-- 2.8 Использование IN: оборудование определённых производителей
SELECT equipment_name, manufacturer, model
FROM dim_equipment
WHERE manufacturer IN ('Sandvik', 'Caterpillar');

-- 2.9 Использование LIKE: поиск по названию
SELECT equipment_name, inventory_number
FROM dim_equipment
WHERE equipment_name LIKE 'ПДМ%';

-- ============================================================
-- 3. СОРТИРОВКА (ORDER BY)
-- ============================================================

-- 3.1 Оборудование, отсортированное по году выпуска (от нового к старому)
SELECT equipment_name, manufacturer, model, year_manufactured
FROM dim_equipment
ORDER BY year_manufactured DESC;

-- 3.2 Добыча за январь 2024, сортировка по объёму (убывание)
SELECT date_id, equipment_id, operator_id,
       tons_mined, trips_count
FROM fact_production
WHERE date_id BETWEEN 20240101 AND 20240131
ORDER BY tons_mined DESC;

-- 3.3 Топ-5 записей добычи по объёму
SELECT date_id, equipment_id, operator_id,
       tons_mined, trips_count
FROM fact_production
ORDER BY tons_mined DESC
LIMIT 5;

-- 3.4 Сортировка по нескольким столбцам
SELECT equipment_name, manufacturer, model, year_manufactured
FROM dim_equipment
ORDER BY manufacturer ASC, year_manufactured DESC;

-- ============================================================
-- 4. СОЕДИНЕНИЕ ТАБЛИЦ (JOIN)
-- ============================================================

-- 4.1 Оборудование с названием типа и названием шахты
SELECT e.equipment_name,
       et.type_name    AS equipment_type,
       m.mine_name
FROM dim_equipment e
INNER JOIN dim_equipment_type et ON e.equipment_type_id = et.equipment_type_id
INNER JOIN dim_mine m            ON e.mine_id = m.mine_id;

-- 4.2 Оборудование шахты «Северная» с типом
SELECT e.equipment_name,
       et.type_name AS equipment_type,
       e.manufacturer,
       e.model
FROM dim_equipment e
INNER JOIN dim_equipment_type et ON e.equipment_type_id = et.equipment_type_id
INNER JOIN dim_mine m            ON e.mine_id = m.mine_id
WHERE m.mine_name = 'Шахта "Северная"';

-- 4.3 Добыча с расшифровкой оборудования, оператора и смены
SELECT d.full_date,
       sh.shift_name,
       e.equipment_name,
       op.last_name || ' ' || op.first_name AS operator_name,
       fp.tons_mined,
       fp.trips_count
FROM fact_production fp
INNER JOIN dim_date d      ON fp.date_id = d.date_id
INNER JOIN dim_shift sh    ON fp.shift_id = sh.shift_id
INNER JOIN dim_equipment e ON fp.equipment_id = e.equipment_id
INNER JOIN dim_operator op ON fp.operator_id = op.operator_id
WHERE d.full_date = '2024-01-15'
ORDER BY fp.tons_mined DESC;

-- 4.4 Простои с причинами и названием оборудования
SELECT e.equipment_name,
       dr.reason_name,
       dr.category,
       fd.duration_min,
       fd.is_planned,
       fd.comment
FROM fact_equipment_downtime fd
INNER JOIN dim_equipment e        ON fd.equipment_id = e.equipment_id
INNER JOIN dim_downtime_reason dr ON fd.reason_id = dr.reason_id
WHERE fd.date_id BETWEEN 20240101 AND 20240131
ORDER BY fd.duration_min DESC;

-- 4.5 Соединение трёх уровней «снежинки»: оборудование → тип → шахта → ствол
SELECT m.mine_name,
       sh.shaft_name,
       sh.shaft_type,
       e.equipment_name,
       et.type_name AS equipment_type
FROM dim_equipment e
INNER JOIN dim_equipment_type et ON e.equipment_type_id = et.equipment_type_id
INNER JOIN dim_mine m            ON e.mine_id = m.mine_id
INNER JOIN dim_shaft sh          ON sh.mine_id = m.mine_id
ORDER BY m.mine_name, sh.shaft_name, e.equipment_name;

-- 4.6 Обратная навигация: количество оборудования на каждой шахте
-- (аналог RELATEDTABLE в DAX)
SELECT m.mine_name,
       COUNT(e.equipment_id) AS equipment_count
FROM dim_mine m
LEFT JOIN dim_equipment e ON m.mine_id = e.mine_id
GROUP BY m.mine_name;

-- 4.7 Обратная навигация: общая добыча по каждой шахте
-- (аналог RELATEDTABLE + SUMX в DAX)
SELECT m.mine_name,
       COALESCE(SUM(fp.tons_mined), 0) AS total_tons
FROM dim_mine m
LEFT JOIN fact_production fp ON m.mine_id = fp.mine_id
GROUP BY m.mine_name;

-- 4.8 Скалярный подзапрос (аналог CALCULATE в DAX)
SELECT (SELECT SUM(tons_mined)
        FROM fact_production fp
        INNER JOIN dim_mine m ON fp.mine_id = m.mine_id
        WHERE m.mine_name = 'Шахта "Северная"') AS total_tons_north;

-- 4.9 Коррелированный подзапрос (CALCULATE внутри ADDCOLUMNS)
SELECT m.mine_name,
       (SELECT SUM(fp.tons_mined)
        FROM fact_production fp
        WHERE fp.mine_id = m.mine_id) AS total_tons
FROM dim_mine m;

-- 4.10 «Ручное» соединение по общему столбцу (аналог NATURALLEFTOUTERJOIN)
SELECT e.equipment_name,
       e.inventory_number,
       et.type_name AS equipment_type
FROM dim_equipment e
LEFT JOIN dim_equipment_type et
    ON e.equipment_type_id = et.equipment_type_id;

-- ============================================================
-- 5. ГРУППИРОВКА И АГРЕГИРОВАНИЕ (GROUP BY)
-- ============================================================

-- 5.1 Общая добыча по каждой шахте
SELECT m.mine_name,
       SUM(fp.tons_mined)        AS total_tons,
       AVG(fp.tons_mined)        AS avg_tons_per_shift,
       COUNT(*)                  AS total_shifts
FROM fact_production fp
INNER JOIN dim_mine m ON fp.mine_id = m.mine_id
GROUP BY m.mine_name;

-- 5.2 Добыча по месяцам за 2024 год
SELECT d.year_month,
       SUM(fp.tons_mined)  AS total_tons,
       AVG(fp.tons_mined)  AS avg_tons,
       COUNT(*)             AS shifts_count
FROM fact_production fp
INNER JOIN dim_date d ON fp.date_id = d.date_id
WHERE d.year = 2024
GROUP BY d.year_month
ORDER BY d.year_month;

-- 5.3 Топ-5 операторов по общему объёму добычи
SELECT op.last_name || ' ' || op.first_name AS operator_name,
       op.position,
       SUM(fp.tons_mined)   AS total_tons,
       AVG(fp.tons_mined)   AS avg_tons,
       COUNT(*)              AS shifts_worked
FROM fact_production fp
INNER JOIN dim_operator op ON fp.operator_id = op.operator_id
GROUP BY op.operator_id, op.last_name, op.first_name, op.position
ORDER BY total_tons DESC
LIMIT 5;

-- 5.4 Анализ простоев по категориям причин
SELECT dr.category,
       dr.reason_name,
       COUNT(*)                      AS downtime_count,
       SUM(fd.duration_min)          AS total_minutes,
       ROUND(AVG(fd.duration_min), 1) AS avg_minutes
FROM fact_equipment_downtime fd
INNER JOIN dim_downtime_reason dr ON fd.reason_id = dr.reason_id
GROUP BY dr.category, dr.reason_name
ORDER BY total_minutes DESC;

-- 5.5 Среднее содержание Fe по сортам руды
SELECT og.grade_name,
       COUNT(*)                         AS samples_count,
       ROUND(AVG(fq.fe_content), 2)     AS avg_fe,
       ROUND(MIN(fq.fe_content), 2)     AS min_fe,
       ROUND(MAX(fq.fe_content), 2)     AS max_fe
FROM fact_ore_quality fq
INNER JOIN dim_ore_grade og ON fq.ore_grade_id = og.ore_grade_id
GROUP BY og.grade_name, og.grade_code
ORDER BY og.grade_code;

-- 5.6 Добыча по сменам и типам оборудования
SELECT sh.shift_name,
       et.type_name,
       SUM(fp.tons_mined)           AS total_tons,
       ROUND(AVG(fp.tons_mined), 2) AS avg_tons,
       SUM(fp.trips_count)          AS total_trips
FROM fact_production fp
INNER JOIN dim_shift sh           ON fp.shift_id = sh.shift_id
INNER JOIN dim_equipment e        ON fp.equipment_id = e.equipment_id
INNER JOIN dim_equipment_type et  ON e.equipment_type_id = et.equipment_type_id
GROUP BY sh.shift_name, et.type_name
ORDER BY sh.shift_name, total_tons DESC;

-- 5.7 HAVING: шахты с общей добычей более 50 000 тонн
SELECT m.mine_name,
       SUM(fp.tons_mined) AS total_tons
FROM fact_production fp
INNER JOIN dim_mine m ON fp.mine_id = m.mine_id
GROUP BY m.mine_name
HAVING SUM(fp.tons_mined) > 50000
ORDER BY total_tons DESC;

-- ============================================================
-- 6. КЕЙС: Анализ эффективности смен
-- ============================================================

-- 6.1 Сравнение дневной и ночной смены по добыче
SELECT sh.shift_name,
       COUNT(DISTINCT fp.date_id)   AS work_days,
       COUNT(*)                     AS total_records,
       SUM(fp.tons_mined)           AS total_tons,
       ROUND(AVG(fp.tons_mined), 2) AS avg_tons_per_record,
       SUM(fp.fuel_consumed_l)      AS total_fuel,
       ROUND(SUM(fp.fuel_consumed_l) / NULLIF(SUM(fp.tons_mined), 0), 3) AS fuel_per_ton
FROM fact_production fp
INNER JOIN dim_shift sh ON fp.shift_id = sh.shift_id
GROUP BY sh.shift_name;

-- 6.2 Эффективность операторов по сменам
SELECT op.last_name || ' ' || op.first_name AS operator_name,
       sh.shift_name,
       COUNT(*)                     AS shifts_count,
       ROUND(AVG(fp.tons_mined), 2) AS avg_tons,
       ROUND(AVG(fp.operating_hours), 2) AS avg_hours,
       ROUND(AVG(fp.tons_mined) / NULLIF(AVG(fp.operating_hours), 0), 2) AS tons_per_hour
FROM fact_production fp
INNER JOIN dim_operator op ON fp.operator_id = op.operator_id
INNER JOIN dim_shift sh    ON fp.shift_id = sh.shift_id
GROUP BY op.operator_id, op.last_name, op.first_name, sh.shift_name
ORDER BY tons_per_hour DESC;
