-- ============================================================
-- Руда+ MES: Заполнение таблиц измерений (dimensions)
-- ============================================================

-- ============================================================
-- 1. Типы оборудования
-- ============================================================
INSERT INTO dim_equipment_type (type_name, type_code, description, max_payload_tons, engine_power_kw, fuel_type) VALUES
('Погрузочно-доставочная машина', 'LHD',   'ПДМ для погрузки и доставки руды от забоя до рудоспуска', 14.00, 220.00, 'Дизельное топливо'),
('Шахтный самосвал',             'TRUCK', 'Подземный самосвал для транспортировки руды по горизонтам',  30.00, 350.00, 'Дизельное топливо'),
('Вагонетка',                    'CART',  'Шахтная вагонетка для рельсовой откатки руды',              5.00,  NULL,   'Электротяга (контактная сеть)'),
('Скиповой подъёмник',           'SKIP',  'Подъёмная установка для выдачи руды на поверхность',        20.00, 500.00, 'Электропривод');

-- ============================================================
-- 2. Типы датчиков
-- ============================================================
INSERT INTO dim_sensor_type (type_name, type_code, unit_of_measure, min_value, max_value, description) VALUES
('Датчик температуры двигателя',  'TEMP_ENGINE',  '°C',     -40, 150,   'Контроль температуры двигателя'),
('Датчик температуры гидравлики', 'TEMP_HYDR',    '°C',     -20, 120,   'Контроль температуры гидравлической жидкости'),
('Датчик вибрации',               'VIBRATION',    'мм/с',   0,   50,    'Виброскорость корпуса'),
('Датчик скорости движения',      'SPEED',        'км/ч',   0,   40,    'Скорость передвижения машины'),
('Датчик массы груза',            'LOAD_WEIGHT',  'т',      0,   35,    'Масса груза в ковше / кузове'),
('Датчик уровня топлива',         'FUEL_LEVEL',   '%',      0,   100,   'Уровень топлива в баке'),
('GPS-координаты (X)',            'NAV_X',        'м',      0,   10000, 'Координата X навигационной системы'),
('GPS-координаты (Y)',            'NAV_Y',        'м',      0,   10000, 'Координата Y навигационной системы'),
('Датчик давления масла',         'OIL_PRESS',    'бар',    0,   10,    'Давление масла в двигателе'),
('Датчик оборотов двигателя',     'RPM',          'об/мин', 0,   3000,  'Обороты коленчатого вала');

-- ============================================================
-- 3. Шахты
-- ============================================================
INSERT INTO dim_mine (mine_name, mine_code, region, city, latitude, longitude, opened_date, max_depth_m, status) VALUES
('Шахта "Северная"', 'MINE_N', 'Курская область',     'г. Железногорск', 52.3425, 35.3517, '1985-06-01', 620.00, 'active'),
('Шахта "Южная"',    'MINE_S', 'Белгородская область', 'г. Губкин',       51.2833, 37.5500, '1992-03-15', 540.00, 'active');

-- ============================================================
-- 4. Стволы и горизонты
-- ============================================================
-- Шахта "Северная" — 4 ствола
INSERT INTO dim_shaft (mine_id, shaft_name, shaft_code, shaft_type, depth_m, status) VALUES
(1, 'Ствол №1 Главный',       'N_MAIN',   'вертикальный', 620.00, 'active'),
(1, 'Ствол №2 Вентиляционный','N_VENT',   'вертикальный', 580.00, 'active'),
(1, 'Горизонт -480 м',        'N_H480',   'горизонт',     480.00, 'active'),
(1, 'Горизонт -620 м',        'N_H620',   'горизонт',     620.00, 'active');

-- Шахта "Южная" — 3 ствола
INSERT INTO dim_shaft (mine_id, shaft_name, shaft_code, shaft_type, depth_m, status) VALUES
(2, 'Ствол №1 Главный',       'S_MAIN',   'вертикальный', 540.00, 'active'),
(2, 'Ствол №2 Вспомогательный','S_AUX',   'вертикальный', 520.00, 'active'),
(2, 'Горизонт -420 м',        'S_H420',   'горизонт',     420.00, 'active');

-- ============================================================
-- 5. Подземные локации
-- ============================================================
INSERT INTO dim_location (shaft_id, location_name, location_code, location_type, level_m, x_coord, y_coord, z_coord) VALUES
-- Горизонт -480, шахта Северная
(3, 'Забой 1-С',            'N480_Z1',  'забой',              -480.00, 1200.0, 800.0,  -480.0),
(3, 'Забой 2-С',            'N480_Z2',  'забой',              -480.00, 1500.0, 900.0,  -480.0),
(3, 'Штрек транспортный',   'N480_SH1', 'штрек',             -480.00, 1000.0, 850.0,  -480.0),
(3, 'Рудоспуск №1',         'N480_RS1', 'рудоспуск',         -480.00, 800.0,  850.0,  -480.0),
(3, 'Околоствольный двор',  'N480_OD',  'околоствольный двор',-480.00, 500.0,  500.0,  -480.0),
-- Горизонт -620, шахта Северная
(4, 'Забой 3-С',            'N620_Z3',  'забой',              -620.00, 1300.0, 700.0,  -620.0),
(4, 'Забой 4-С',            'N620_Z4',  'забой',              -620.00, 1600.0, 750.0,  -620.0),
(4, 'Штрек откаточный',     'N620_SH2', 'штрек',             -620.00, 1100.0, 720.0,  -620.0),
(4, 'Рудоспуск №2',         'N620_RS2', 'рудоспуск',         -620.00, 900.0,  700.0,  -620.0),
-- Горизонт -420, шахта Южная
(7, 'Забой 1-Ю',            'S420_Z1',  'забой',              -420.00, 1100.0, 600.0,  -420.0),
(7, 'Забой 2-Ю',            'S420_Z2',  'забой',              -420.00, 1400.0, 650.0,  -420.0),
(7, 'Штрек магистральный',  'S420_SH1', 'штрек',             -420.00, 900.0,  620.0,  -420.0),
(7, 'Рудоспуск №1 Южный',   'S420_RS1', 'рудоспуск',         -420.00, 700.0,  600.0,  -420.0),
(7, 'Камера ожидания',      'S420_KO',  'камера',            -420.00, 750.0,  580.0,  -420.0);

-- ============================================================
-- 6. Оборудование (18 единиц)
-- ============================================================
INSERT INTO dim_equipment (equipment_type_id, mine_id, equipment_name, inventory_number, manufacturer, model, year_manufactured, commissioning_date, status, has_video_recorder, has_navigation) VALUES
-- ПДМ (LHD) — 6 машин
(1, 1, 'ПДМ-001',  'INV-LHD-001', 'Sandvik',     'LH514',     2019, '2019-08-15', 'active',      TRUE,  TRUE),
(1, 1, 'ПДМ-002',  'INV-LHD-002', 'Sandvik',     'LH514',     2020, '2020-03-10', 'active',      TRUE,  TRUE),
(1, 1, 'ПДМ-003',  'INV-LHD-003', 'Caterpillar', 'R1700',     2018, '2018-11-20', 'active',      TRUE,  TRUE),
(1, 2, 'ПДМ-004',  'INV-LHD-004', 'Sandvik',     'LH517i',    2021, '2021-05-01', 'active',      TRUE,  TRUE),
(1, 2, 'ПДМ-005',  'INV-LHD-005', 'Caterpillar', 'R1700',     2017, '2017-09-12', 'maintenance', TRUE,  TRUE),
(1, 2, 'ПДМ-006',  'INV-LHD-006', 'Epiroc',      'ST14',      2022, '2022-01-20', 'active',      TRUE,  TRUE),
-- Самосвалы (TRUCK) — 5 машин
(2, 1, 'Самосвал-001', 'INV-TRK-001', 'Sandvik',     'TH663i', 2020, '2020-06-01', 'active',      TRUE,  TRUE),
(2, 1, 'Самосвал-002', 'INV-TRK-002', 'Sandvik',     'TH663i', 2020, '2020-06-01', 'active',      TRUE,  TRUE),
(2, 1, 'Самосвал-003', 'INV-TRK-003', 'Caterpillar', 'AD30',   2019, '2019-04-15', 'active',      TRUE,  TRUE),
(2, 2, 'Самосвал-004', 'INV-TRK-004', 'Sandvik',     'TH551i', 2021, '2021-08-10', 'active',      TRUE,  TRUE),
(2, 2, 'Самосвал-005', 'INV-TRK-005', 'Caterpillar', 'AD30',   2018, '2018-12-01', 'active',      FALSE, TRUE),
-- Вагонетки (CART) — 4 штуки
(3, 1, 'Вагонетка-001', 'INV-CRT-001', 'НКМЗ',    'ВГ-5.0',  2016, '2016-03-20', 'active',      FALSE, FALSE),
(3, 1, 'Вагонетка-002', 'INV-CRT-002', 'НКМЗ',    'ВГ-5.0',  2016, '2016-03-20', 'active',      FALSE, FALSE),
(3, 2, 'Вагонетка-003', 'INV-CRT-003', 'НКМЗ',    'ВГ-5.0',  2017, '2017-07-01', 'active',      FALSE, FALSE),
(3, 2, 'Вагонетка-004', 'INV-CRT-004', 'НКМЗ',    'ВГ-5.0',  2017, '2017-07-01', 'active',      FALSE, FALSE),
-- Скиповые подъёмники (SKIP) — 3 штуки
(4, 1, 'Скип-001', 'INV-SKP-001', 'НКМЗ',         'СН-20',   2010, '2010-09-01', 'active',      TRUE,  FALSE),
(4, 1, 'Скип-002', 'INV-SKP-002', 'Siemag Tecberg','BMR-20',  2015, '2015-04-10', 'active',      TRUE,  FALSE),
(4, 2, 'Скип-003', 'INV-SKP-003', 'НКМЗ',         'СН-20',   2012, '2012-11-15', 'active',      TRUE,  FALSE);

-- ============================================================
-- 7. Датчики (по 3-5 на единицу основного оборудования)
-- ============================================================
-- Датчики для ПДМ-001
INSERT INTO dim_sensor (sensor_type_id, equipment_id, sensor_code, install_date, calibration_date, status) VALUES
(1, 1, 'S-LHD001-TEMP',  '2019-08-15', '2024-06-01', 'active'),
(3, 1, 'S-LHD001-VIB',   '2019-08-15', '2024-06-01', 'active'),
(4, 1, 'S-LHD001-SPD',   '2019-08-15', '2024-06-01', 'active'),
(5, 1, 'S-LHD001-LOAD',  '2019-08-15', '2024-06-01', 'active'),
(6, 1, 'S-LHD001-FUEL',  '2019-08-15', '2024-06-01', 'active');

-- Датчики для ПДМ-002
INSERT INTO dim_sensor (sensor_type_id, equipment_id, sensor_code, install_date, calibration_date, status) VALUES
(1, 2, 'S-LHD002-TEMP',  '2020-03-10', '2024-06-01', 'active'),
(3, 2, 'S-LHD002-VIB',   '2020-03-10', '2024-06-01', 'active'),
(4, 2, 'S-LHD002-SPD',   '2020-03-10', '2024-06-01', 'active'),
(5, 2, 'S-LHD002-LOAD',  '2020-03-10', '2024-06-01', 'active'),
(6, 2, 'S-LHD002-FUEL',  '2020-03-10', '2024-06-01', 'active');

-- Датчики для ПДМ-003
INSERT INTO dim_sensor (sensor_type_id, equipment_id, sensor_code, install_date, calibration_date, status) VALUES
(1, 3, 'S-LHD003-TEMP',  '2018-11-20', '2024-05-15', 'active'),
(3, 3, 'S-LHD003-VIB',   '2018-11-20', '2024-05-15', 'active'),
(5, 3, 'S-LHD003-LOAD',  '2018-11-20', '2024-05-15', 'active'),
(6, 3, 'S-LHD003-FUEL',  '2018-11-20', '2024-05-15', 'active');

-- Датчики для ПДМ-004
INSERT INTO dim_sensor (sensor_type_id, equipment_id, sensor_code, install_date, calibration_date, status) VALUES
(1, 4, 'S-LHD004-TEMP',  '2021-05-01', '2024-07-01', 'active'),
(3, 4, 'S-LHD004-VIB',   '2021-05-01', '2024-07-01', 'active'),
(4, 4, 'S-LHD004-SPD',   '2021-05-01', '2024-07-01', 'active'),
(5, 4, 'S-LHD004-LOAD',  '2021-05-01', '2024-07-01', 'active'),
(6, 4, 'S-LHD004-FUEL',  '2021-05-01', '2024-07-01', 'active');

-- Датчики для Самосвал-001
INSERT INTO dim_sensor (sensor_type_id, equipment_id, sensor_code, install_date, calibration_date, status) VALUES
(1,  7, 'S-TRK001-TEMP',  '2020-06-01', '2024-06-01', 'active'),
(3,  7, 'S-TRK001-VIB',   '2020-06-01', '2024-06-01', 'active'),
(4,  7, 'S-TRK001-SPD',   '2020-06-01', '2024-06-01', 'active'),
(5,  7, 'S-TRK001-LOAD',  '2020-06-01', '2024-06-01', 'active'),
(6,  7, 'S-TRK001-FUEL',  '2020-06-01', '2024-06-01', 'active'),
(9,  7, 'S-TRK001-OIL',   '2020-06-01', '2024-06-01', 'active'),
(10, 7, 'S-TRK001-RPM',   '2020-06-01', '2024-06-01', 'active');

-- Датчики для Самосвал-002
INSERT INTO dim_sensor (sensor_type_id, equipment_id, sensor_code, install_date, calibration_date, status) VALUES
(1, 8, 'S-TRK002-TEMP',  '2020-06-01', '2024-06-01', 'active'),
(3, 8, 'S-TRK002-VIB',   '2020-06-01', '2024-06-01', 'active'),
(4, 8, 'S-TRK002-SPD',   '2020-06-01', '2024-06-01', 'active'),
(5, 8, 'S-TRK002-LOAD',  '2020-06-01', '2024-06-01', 'active'),
(6, 8, 'S-TRK002-FUEL',  '2020-06-01', '2024-06-01', 'active');

-- Датчики для Самосвал-004
INSERT INTO dim_sensor (sensor_type_id, equipment_id, sensor_code, install_date, calibration_date, status) VALUES
(1,  10, 'S-TRK004-TEMP', '2021-08-10', '2024-07-01', 'active'),
(3,  10, 'S-TRK004-VIB',  '2021-08-10', '2024-07-01', 'active'),
(4,  10, 'S-TRK004-SPD',  '2021-08-10', '2024-07-01', 'active'),
(5,  10, 'S-TRK004-LOAD', '2021-08-10', '2024-07-01', 'active'),
(10, 10, 'S-TRK004-RPM',  '2021-08-10', '2024-07-01', 'active');

-- Датчики для Скип-001
INSERT INTO dim_sensor (sensor_type_id, equipment_id, sensor_code, install_date, calibration_date, status) VALUES
(1, 16, 'S-SKP001-TEMP',  '2010-09-01', '2024-04-01', 'active'),
(3, 16, 'S-SKP001-VIB',   '2010-09-01', '2024-04-01', 'active'),
(5, 16, 'S-SKP001-LOAD',  '2010-09-01', '2024-04-01', 'active'),
(10,16, 'S-SKP001-RPM',   '2010-09-01', '2024-04-01', 'active');

-- Датчики для Скип-003
INSERT INTO dim_sensor (sensor_type_id, equipment_id, sensor_code, install_date, calibration_date, status) VALUES
(1, 18, 'S-SKP003-TEMP',  '2012-11-15', '2024-05-01', 'active'),
(3, 18, 'S-SKP003-VIB',   '2012-11-15', '2024-05-01', 'active'),
(5, 18, 'S-SKP003-LOAD',  '2012-11-15', '2024-05-01', 'active');

-- ============================================================
-- 8. Операторы (10 человек)
-- ============================================================
INSERT INTO dim_operator (tab_number, last_name, first_name, middle_name, position, qualification, hire_date, mine_id, status) VALUES
('ТН-001', 'Иванов',    'Алексей',   'Петрович',    'Машинист ПДМ',       '5 разряд', '2015-03-01', 1, 'active'),
('ТН-002', 'Петров',    'Сергей',    'Николаевич',  'Машинист ПДМ',       '5 разряд', '2016-07-15', 1, 'active'),
('ТН-003', 'Сидоров',   'Дмитрий',   'Александрович','Машинист самосвала', '4 разряд', '2018-01-10', 1, 'active'),
('ТН-004', 'Козлов',    'Андрей',    'Викторович',  'Машинист самосвала', '5 разряд', '2014-09-20', 1, 'active'),
('ТН-005', 'Новиков',   'Михаил',    'Сергеевич',   'Машинист ПДМ',       '4 разряд', '2019-04-05', 2, 'active'),
('ТН-006', 'Морозов',   'Владимир',  'Иванович',    'Машинист ПДМ',       '5 разряд', '2013-11-12', 2, 'active'),
('ТН-007', 'Волков',    'Николай',   'Дмитриевич',  'Машинист самосвала', '4 разряд', '2020-02-01', 2, 'active'),
('ТН-008', 'Соловьёв',  'Павел',     'Андреевич',   'Оператор подъёма',   '5 разряд', '2012-06-01', 1, 'active'),
('ТН-009', 'Лебедев',   'Евгений',   'Михайлович',  'Оператор подъёма',   '4 разряд', '2017-08-20', 2, 'active'),
('ТН-010', 'Кузнецов',  'Игорь',     'Олегович',    'Машинист ПДМ',       '3 разряд', '2022-01-15', 1, 'active');

-- ============================================================
-- 9. Смены
-- ============================================================
INSERT INTO dim_shift (shift_name, shift_code, start_time, end_time, duration_h) VALUES
('Дневная смена',  'DAY',   '08:00', '20:00', 12.00),
('Ночная смена',   'NIGHT', '20:00', '08:00', 12.00);

-- ============================================================
-- 10. Сорта руды
-- ============================================================
INSERT INTO dim_ore_grade (grade_name, grade_code, fe_content_min, fe_content_max, description) VALUES
('Высший сорт',  'GRADE_A', 60.00, 100.00, 'Богатая руда с высоким содержанием железа'),
('Первый сорт',  'GRADE_1', 45.00,  59.99, 'Руда среднего качества'),
('Второй сорт',  'GRADE_2', 30.00,  44.99, 'Руда пониженного качества, требует обогащения'),
('Третий сорт',  'GRADE_3',  0.00,  29.99, 'Бедная руда, требует глубокого обогащения');

-- ============================================================
-- 11. Причины простоев
-- ============================================================
INSERT INTO dim_downtime_reason (reason_name, reason_code, category, description) VALUES
('Плановое техническое обслуживание', 'MAINT_PLAN',  'плановый',        'Регламентное ТО по графику'),
('Аварийный ремонт',                  'REPAIR_EMRG', 'внеплановый',     'Отказ узла или агрегата'),
('Замена шин / гусениц',             'TIRE_CHANGE', 'плановый',        'Плановая замена ходовой части'),
('Отсутствие оператора',              'NO_OPERATOR', 'организационный', 'Оператор не вышел на смену'),
('Ожидание погрузки',                 'WAIT_LOAD',   'организационный', 'Простой в ожидании погрузки'),
('Ожидание транспорта',               'WAIT_TRANS',  'организационный', 'Простой в ожидании самосвала'),
('Заправка топливом',                 'REFUELING',   'плановый',        'Заправка машины дизтопливом'),
('Перегрев двигателя',                'OVERHEAT',    'внеплановый',     'Остановка из-за перегрева'),
('Обрушение породы',                  'ROCK_FALL',   'внеплановый',     'Остановка из-за геологических условий'),
('Проветривание забоя',               'VENTILATION', 'плановый',        'Ожидание проветривания после взрывных работ'),
('Электроснабжение',                  'POWER_OUT',   'внеплановый',     'Перебои в электроснабжении'),
('Диагностика и калибровка',          'DIAGNOSTICS', 'плановый',        'Диагностика и настройка оборудования');

-- ============================================================
-- 12. Измерение даты (2024-01-01 — 2025-12-31)
-- ============================================================
INSERT INTO dim_date (
    date_id, full_date, year, quarter, month, month_name, month_name_short,
    week_of_year, day_of_month, day_of_week, day_of_week_name,
    day_of_year, is_weekend, is_holiday, fiscal_year, fiscal_quarter,
    year_month, year_quarter
)
SELECT
    TO_CHAR(d, 'YYYYMMDD')::INT                                     AS date_id,
    d                                                                 AS full_date,
    EXTRACT(YEAR FROM d)::INT                                         AS year,
    EXTRACT(QUARTER FROM d)::INT                                      AS quarter,
    EXTRACT(MONTH FROM d)::INT                                        AS month,
    CASE EXTRACT(MONTH FROM d)::INT
        WHEN 1  THEN 'Январь'   WHEN 2  THEN 'Февраль' WHEN 3  THEN 'Март'
        WHEN 4  THEN 'Апрель'   WHEN 5  THEN 'Май'     WHEN 6  THEN 'Июнь'
        WHEN 7  THEN 'Июль'     WHEN 8  THEN 'Август'  WHEN 9  THEN 'Сентябрь'
        WHEN 10 THEN 'Октябрь'  WHEN 11 THEN 'Ноябрь'  WHEN 12 THEN 'Декабрь'
    END                                                               AS month_name,
    CASE EXTRACT(MONTH FROM d)::INT
        WHEN 1  THEN 'Янв' WHEN 2  THEN 'Фев' WHEN 3  THEN 'Мар'
        WHEN 4  THEN 'Апр' WHEN 5  THEN 'Май' WHEN 6  THEN 'Июн'
        WHEN 7  THEN 'Июл' WHEN 8  THEN 'Авг' WHEN 9  THEN 'Сен'
        WHEN 10 THEN 'Окт' WHEN 11 THEN 'Ноя' WHEN 12 THEN 'Дек'
    END                                                               AS month_name_short,
    EXTRACT(WEEK FROM d)::INT                                         AS week_of_year,
    EXTRACT(DAY FROM d)::INT                                          AS day_of_month,
    EXTRACT(ISODOW FROM d)::INT                                       AS day_of_week,
    CASE EXTRACT(ISODOW FROM d)::INT
        WHEN 1 THEN 'Понедельник' WHEN 2 THEN 'Вторник'  WHEN 3 THEN 'Среда'
        WHEN 4 THEN 'Четверг'     WHEN 5 THEN 'Пятница'  WHEN 6 THEN 'Суббота'
        WHEN 7 THEN 'Воскресенье'
    END                                                               AS day_of_week_name,
    EXTRACT(DOY FROM d)::INT                                          AS day_of_year,
    EXTRACT(ISODOW FROM d)::INT IN (6, 7)                             AS is_weekend,
    FALSE                                                             AS is_holiday,
    EXTRACT(YEAR FROM d)::INT                                         AS fiscal_year,
    EXTRACT(QUARTER FROM d)::INT                                      AS fiscal_quarter,
    TO_CHAR(d, 'YYYY-MM')                                            AS year_month,
    TO_CHAR(d, 'YYYY') || '-Q' || EXTRACT(QUARTER FROM d)::INT       AS year_quarter
FROM generate_series('2024-01-01'::DATE, '2025-12-31'::DATE, '1 day'::INTERVAL) AS d;

-- Отметим российские праздники 2024-2025
UPDATE dim_date SET is_holiday = TRUE
WHERE full_date IN (
    -- 2024
    '2024-01-01','2024-01-02','2024-01-03','2024-01-04','2024-01-05',
    '2024-01-06','2024-01-07','2024-01-08',
    '2024-02-23','2024-03-08','2024-05-01','2024-05-09',
    '2024-06-12','2024-11-04',
    -- 2025
    '2025-01-01','2025-01-02','2025-01-03','2025-01-04','2025-01-05',
    '2025-01-06','2025-01-07','2025-01-08',
    '2025-02-23','2025-03-08','2025-05-01','2025-05-09',
    '2025-06-12','2025-11-04'
);

-- ============================================================
-- 13. Измерение времени (каждая минута суток = 1440 записей)
-- ============================================================
INSERT INTO dim_time (time_id, full_time, hour, minute, hour_minute, period, shift_code)
SELECT
    EXTRACT(HOUR FROM t)::INT * 100 + EXTRACT(MINUTE FROM t)::INT  AS time_id,
    t::TIME                                                          AS full_time,
    EXTRACT(HOUR FROM t)::INT                                        AS hour,
    EXTRACT(MINUTE FROM t)::INT                                      AS minute,
    TO_CHAR(t, 'HH24:MI')                                           AS hour_minute,
    CASE
        WHEN EXTRACT(HOUR FROM t)::INT >= 6  AND EXTRACT(HOUR FROM t)::INT < 12 THEN 'утро'
        WHEN EXTRACT(HOUR FROM t)::INT >= 12 AND EXTRACT(HOUR FROM t)::INT < 18 THEN 'день'
        WHEN EXTRACT(HOUR FROM t)::INT >= 18 AND EXTRACT(HOUR FROM t)::INT < 22 THEN 'вечер'
        ELSE 'ночь'
    END                                                              AS period,
    CASE
        WHEN EXTRACT(HOUR FROM t)::INT >= 8 AND EXTRACT(HOUR FROM t)::INT < 20 THEN 'DAY'
        ELSE 'NIGHT'
    END                                                              AS shift_code
FROM generate_series('2000-01-01 00:00'::TIMESTAMP, '2000-01-01 23:59'::TIMESTAMP, '1 minute'::INTERVAL) AS t;
