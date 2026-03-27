-- ============================================================
-- Руда+ MES: Аналитическая база данных (схема "Снежинка")
-- СУБД: PostgreSQL (Yandex Managed Service for PostgreSQL)
-- Описание: DDL для создания таблиц измерений и фактов
-- ============================================================

-- ============================================================
-- ИЗМЕРЕНИЯ (DIMENSIONS) — внешние уровни снежинки
-- ============================================================

-- Справочник типов оборудования
CREATE TABLE dim_equipment_type (
    equipment_type_id   SERIAL PRIMARY KEY,
    type_name           VARCHAR(100) NOT NULL,       -- Название типа
    type_code           VARCHAR(20)  NOT NULL UNIQUE, -- Код типа (LHD, TRUCK, CART, SKIP)
    description         TEXT,                         -- Описание
    max_payload_tons    NUMERIC(10,2),                -- Максимальная грузоподъёмность, тонн
    engine_power_kw     NUMERIC(10,2),                -- Мощность двигателя, кВт
    fuel_type           VARCHAR(50),                  -- Тип топлива / привода
    created_at          TIMESTAMP DEFAULT NOW()
);

COMMENT ON TABLE  dim_equipment_type IS 'Справочник типов горного оборудования';
COMMENT ON COLUMN dim_equipment_type.type_code IS 'Код типа: LHD — ПДМ, TRUCK — самосвал, CART — вагонетка, SKIP — скиповой подъёмник';
COMMENT ON COLUMN dim_equipment_type.max_payload_tons IS 'Максимальная грузоподъёмность в тоннах';

-- Справочник типов датчиков
CREATE TABLE dim_sensor_type (
    sensor_type_id   SERIAL PRIMARY KEY,
    type_name        VARCHAR(100) NOT NULL,       -- Название типа датчика
    type_code        VARCHAR(30)  NOT NULL UNIQUE, -- Код типа
    unit_of_measure  VARCHAR(30),                  -- Единица измерения
    min_value        NUMERIC(12,4),                -- Минимальное допустимое значение
    max_value        NUMERIC(12,4),                -- Максимальное допустимое значение
    description      TEXT
);

COMMENT ON TABLE  dim_sensor_type IS 'Справочник типов датчиков оборудования';
COMMENT ON COLUMN dim_sensor_type.unit_of_measure IS 'Единица измерения показаний датчика';

-- Справочник шахт (рудников)
CREATE TABLE dim_mine (
    mine_id        SERIAL PRIMARY KEY,
    mine_name      VARCHAR(150) NOT NULL,  -- Название шахты
    mine_code      VARCHAR(20)  NOT NULL UNIQUE,
    region         VARCHAR(100),           -- Регион
    city           VARCHAR(100),           -- Населённый пункт
    latitude       NUMERIC(9,6),           -- Широта
    longitude      NUMERIC(9,6),           -- Долгота
    opened_date    DATE,                   -- Дата начала эксплуатации
    max_depth_m    NUMERIC(8,2),           -- Максимальная глубина, м
    status         VARCHAR(30) DEFAULT 'active' -- Статус (active / suspended / closed)
);

COMMENT ON TABLE  dim_mine IS 'Справочник шахт (рудников) предприятия';
COMMENT ON COLUMN dim_mine.max_depth_m IS 'Максимальная глубина разработки в метрах';

-- Справочник стволов / горизонтов
CREATE TABLE dim_shaft (
    shaft_id     SERIAL PRIMARY KEY,
    mine_id      INT NOT NULL REFERENCES dim_mine(mine_id),
    shaft_name   VARCHAR(150) NOT NULL,  -- Название ствола/горизонта
    shaft_code   VARCHAR(20)  NOT NULL,
    shaft_type   VARCHAR(50),            -- Тип: вертикальный, наклонный, горизонт
    depth_m      NUMERIC(8,2),           -- Глубина, м
    status       VARCHAR(30) DEFAULT 'active',
    UNIQUE (mine_id, shaft_code)
);

COMMENT ON TABLE  dim_shaft IS 'Стволы и горизонты шахт';
COMMENT ON COLUMN dim_shaft.shaft_type IS 'Тип ствола: вертикальный, наклонный, горизонт';

-- Справочник подземных локаций (зоны навигации)
CREATE TABLE dim_location (
    location_id    SERIAL PRIMARY KEY,
    shaft_id       INT NOT NULL REFERENCES dim_shaft(shaft_id),
    location_name  VARCHAR(200) NOT NULL,  -- Название зоны
    location_code  VARCHAR(30)  NOT NULL,
    location_type  VARCHAR(50),            -- Тип: забой, штрек, камера, рудоспуск
    level_m        NUMERIC(8,2),           -- Отметка уровня, м
    x_coord        NUMERIC(12,4),          -- Координата X навигации
    y_coord        NUMERIC(12,4),          -- Координата Y навигации
    z_coord        NUMERIC(12,4)           -- Координата Z навигации
);

COMMENT ON TABLE  dim_location IS 'Подземные локации (зоны навигационной системы)';
COMMENT ON COLUMN dim_location.location_type IS 'Тип зоны: забой, штрек, камера, рудоспуск, околоствольный двор';

-- Справочник оборудования (снежинка: ссылается на тип и шахту)
CREATE TABLE dim_equipment (
    equipment_id       SERIAL PRIMARY KEY,
    equipment_type_id  INT NOT NULL REFERENCES dim_equipment_type(equipment_type_id),
    mine_id            INT NOT NULL REFERENCES dim_mine(mine_id),
    equipment_name     VARCHAR(150) NOT NULL,   -- Название / бортовой номер
    inventory_number   VARCHAR(50)  NOT NULL UNIQUE, -- Инвентарный номер
    manufacturer       VARCHAR(150),             -- Производитель
    model              VARCHAR(100),             -- Модель
    year_manufactured  INT,                      -- Год выпуска
    commissioning_date DATE,                     -- Дата ввода в эксплуатацию
    status             VARCHAR(30) DEFAULT 'active', -- active / maintenance / decommissioned
    has_video_recorder BOOLEAN DEFAULT FALSE,    -- Наличие видеорегистратора
    has_navigation     BOOLEAN DEFAULT FALSE     -- Подключение к навигации
);

COMMENT ON TABLE  dim_equipment IS 'Справочник горного оборудования';
COMMENT ON COLUMN dim_equipment.inventory_number IS 'Уникальный инвентарный номер единицы оборудования';
COMMENT ON COLUMN dim_equipment.has_video_recorder IS 'Наличие видеорегистратора на борту';
COMMENT ON COLUMN dim_equipment.has_navigation IS 'Подключение к подземной навигационной системе';

-- Справочник датчиков (снежинка: ссылается на тип датчика и оборудование)
CREATE TABLE dim_sensor (
    sensor_id        SERIAL PRIMARY KEY,
    sensor_type_id   INT NOT NULL REFERENCES dim_sensor_type(sensor_type_id),
    equipment_id     INT NOT NULL REFERENCES dim_equipment(equipment_id),
    sensor_code      VARCHAR(50) NOT NULL UNIQUE,  -- Уникальный код датчика
    install_date     DATE,                          -- Дата установки
    calibration_date DATE,                          -- Дата последней калибровки
    status           VARCHAR(30) DEFAULT 'active'   -- active / faulty / replaced
);

COMMENT ON TABLE  dim_sensor IS 'Справочник датчиков, установленных на оборудовании';
COMMENT ON COLUMN dim_sensor.calibration_date IS 'Дата последней поверки / калибровки';

-- Справочник операторов
CREATE TABLE dim_operator (
    operator_id    SERIAL PRIMARY KEY,
    tab_number     VARCHAR(20) NOT NULL UNIQUE,  -- Табельный номер
    last_name      VARCHAR(100) NOT NULL,         -- Фамилия
    first_name     VARCHAR(100) NOT NULL,         -- Имя
    middle_name    VARCHAR(100),                   -- Отчество
    position       VARCHAR(100),                   -- Должность
    qualification  VARCHAR(50),                    -- Разряд / квалификация
    hire_date      DATE,                           -- Дата приёма на работу
    mine_id        INT REFERENCES dim_mine(mine_id), -- Основная шахта
    status         VARCHAR(30) DEFAULT 'active'    -- active / on_leave / dismissed
);

COMMENT ON TABLE  dim_operator IS 'Справочник операторов (машинистов) горного оборудования';
COMMENT ON COLUMN dim_operator.tab_number IS 'Табельный номер сотрудника';
COMMENT ON COLUMN dim_operator.qualification IS 'Квалификационный разряд';

-- Справочник смен
CREATE TABLE dim_shift (
    shift_id    SERIAL PRIMARY KEY,
    shift_name  VARCHAR(50) NOT NULL,   -- Название смены
    shift_code  VARCHAR(10) NOT NULL UNIQUE,
    start_time  TIME NOT NULL,          -- Время начала смены
    end_time    TIME NOT NULL,          -- Время окончания смены
    duration_h  NUMERIC(4,2) NOT NULL   -- Продолжительность, часов
);

COMMENT ON TABLE  dim_shift IS 'Справочник рабочих смен';
COMMENT ON COLUMN dim_shift.duration_h IS 'Продолжительность смены в часах';

-- Справочник сортов руды
CREATE TABLE dim_ore_grade (
    ore_grade_id    SERIAL PRIMARY KEY,
    grade_name      VARCHAR(50) NOT NULL,   -- Название сорта
    grade_code      VARCHAR(10) NOT NULL UNIQUE,
    fe_content_min  NUMERIC(5,2),           -- Мин. содержание Fe, %
    fe_content_max  NUMERIC(5,2),           -- Макс. содержание Fe, %
    description     TEXT
);

COMMENT ON TABLE  dim_ore_grade IS 'Справочник сортов (марок) железной руды';
COMMENT ON COLUMN dim_ore_grade.fe_content_min IS 'Минимальное содержание железа (Fe) в процентах';

-- Справочник причин простоев
CREATE TABLE dim_downtime_reason (
    reason_id    SERIAL PRIMARY KEY,
    reason_name  VARCHAR(200) NOT NULL,   -- Название причины
    reason_code  VARCHAR(20)  NOT NULL UNIQUE,
    category     VARCHAR(50)  NOT NULL,   -- Категория: плановый / внеплановый
    description  TEXT
);

COMMENT ON TABLE  dim_downtime_reason IS 'Справочник причин простоев оборудования';
COMMENT ON COLUMN dim_downtime_reason.category IS 'Категория: плановый, внеплановый, организационный';

-- ============================================================
-- ИЗМЕРЕНИЕ ДАТЫ
-- ============================================================
CREATE TABLE dim_date (
    date_id         INT PRIMARY KEY,          -- Суррогатный ключ YYYYMMDD
    full_date       DATE NOT NULL UNIQUE,     -- Полная дата
    year            INT NOT NULL,             -- Год
    quarter         INT NOT NULL,             -- Квартал (1-4)
    month           INT NOT NULL,             -- Месяц (1-12)
    month_name      VARCHAR(20) NOT NULL,     -- Название месяца (русское)
    month_name_short VARCHAR(10) NOT NULL,    -- Сокр. название месяца
    week_of_year    INT NOT NULL,             -- Номер недели в году
    day_of_month    INT NOT NULL,             -- День месяца
    day_of_week     INT NOT NULL,             -- День недели (1=Пн, 7=Вс)
    day_of_week_name VARCHAR(20) NOT NULL,    -- Название дня недели
    day_of_year     INT NOT NULL,             -- День года
    is_weekend      BOOLEAN NOT NULL,         -- Признак выходного
    is_holiday      BOOLEAN DEFAULT FALSE,    -- Признак праздника
    fiscal_year     INT,                      -- Финансовый год
    fiscal_quarter  INT,                      -- Финансовый квартал
    year_month      VARCHAR(7) NOT NULL,      -- YYYY-MM
    year_quarter    VARCHAR(7) NOT NULL       -- YYYY-QN
);

COMMENT ON TABLE  dim_date IS 'Измерение даты — календарь';
COMMENT ON COLUMN dim_date.date_id IS 'Суррогатный ключ в формате YYYYMMDD';
COMMENT ON COLUMN dim_date.is_weekend IS 'TRUE для субботы и воскресенья';

-- ============================================================
-- ИЗМЕРЕНИЕ ВРЕМЕНИ (гранулярность — 1 минута)
-- ============================================================
CREATE TABLE dim_time (
    time_id     INT PRIMARY KEY,          -- Суррогатный ключ HHMM
    full_time   TIME NOT NULL UNIQUE,     -- Полное время
    hour        INT NOT NULL,             -- Час (0-23)
    minute      INT NOT NULL,             -- Минута (0-59)
    hour_minute VARCHAR(5) NOT NULL,      -- HH:MM
    period      VARCHAR(10) NOT NULL,     -- Период дня: утро, день, вечер, ночь
    shift_code  VARCHAR(10)               -- Код смены (для быстрого определения)
);

COMMENT ON TABLE  dim_time IS 'Измерение времени (с точностью до минуты)';
COMMENT ON COLUMN dim_time.period IS 'Период дня: утро (06-12), день (12-18), вечер (18-22), ночь (22-06)';

-- ============================================================
-- ФАКТ-ТАБЛИЦЫ
-- ============================================================

-- Факт: добыча руды за смену
CREATE TABLE fact_production (
    production_id    BIGSERIAL PRIMARY KEY,
    date_id          INT NOT NULL REFERENCES dim_date(date_id),
    shift_id         INT NOT NULL REFERENCES dim_shift(shift_id),
    mine_id          INT NOT NULL REFERENCES dim_mine(mine_id),
    shaft_id         INT NOT NULL REFERENCES dim_shaft(shaft_id),
    equipment_id     INT NOT NULL REFERENCES dim_equipment(equipment_id),
    operator_id      INT NOT NULL REFERENCES dim_operator(operator_id),
    location_id      INT REFERENCES dim_location(location_id),
    ore_grade_id     INT REFERENCES dim_ore_grade(ore_grade_id),
    -- Меры (measures)
    tons_mined       NUMERIC(10,2) NOT NULL,  -- Добыто руды, тонн
    tons_transported NUMERIC(10,2),            -- Перевезено руды, тонн
    trips_count      INT,                      -- Количество рейсов
    distance_km      NUMERIC(8,2),             -- Пройдено расстояние, км
    fuel_consumed_l  NUMERIC(8,2),             -- Расход топлива, л
    operating_hours  NUMERIC(6,2),             -- Отработано часов
    loaded_at        TIMESTAMP DEFAULT NOW()
);

COMMENT ON TABLE  fact_production IS 'Факт-таблица добычи руды (одна запись — один оператор за смену)';
COMMENT ON COLUMN fact_production.tons_mined IS 'Объём добытой руды в тоннах';
COMMENT ON COLUMN fact_production.trips_count IS 'Количество рейсов (циклов погрузки-доставки)';

CREATE INDEX idx_fact_production_date ON fact_production(date_id);
CREATE INDEX idx_fact_production_shift ON fact_production(shift_id);
CREATE INDEX idx_fact_production_mine ON fact_production(mine_id);
CREATE INDEX idx_fact_production_equip ON fact_production(equipment_id);
CREATE INDEX idx_fact_production_operator ON fact_production(operator_id);

-- Факт: телеметрия оборудования (показания датчиков)
CREATE TABLE fact_equipment_telemetry (
    telemetry_id   BIGSERIAL PRIMARY KEY,
    date_id        INT NOT NULL REFERENCES dim_date(date_id),
    time_id        INT NOT NULL REFERENCES dim_time(time_id),
    equipment_id   INT NOT NULL REFERENCES dim_equipment(equipment_id),
    sensor_id      INT NOT NULL REFERENCES dim_sensor(sensor_id),
    location_id    INT REFERENCES dim_location(location_id),
    -- Меры
    sensor_value   NUMERIC(14,4) NOT NULL,    -- Значение показания
    is_alarm       BOOLEAN DEFAULT FALSE,      -- Признак тревоги (выход за пределы)
    quality_flag   VARCHAR(10) DEFAULT 'OK',   -- Флаг качества данных
    loaded_at      TIMESTAMP DEFAULT NOW()
);

COMMENT ON TABLE  fact_equipment_telemetry IS 'Факт-таблица показаний датчиков оборудования';
COMMENT ON COLUMN fact_equipment_telemetry.sensor_value IS 'Числовое значение показания датчика';
COMMENT ON COLUMN fact_equipment_telemetry.is_alarm IS 'TRUE — показание вышло за допустимые пределы';

CREATE INDEX idx_fact_telemetry_date ON fact_equipment_telemetry(date_id);
CREATE INDEX idx_fact_telemetry_time ON fact_equipment_telemetry(time_id);
CREATE INDEX idx_fact_telemetry_equip ON fact_equipment_telemetry(equipment_id);
CREATE INDEX idx_fact_telemetry_sensor ON fact_equipment_telemetry(sensor_id);

-- Факт: простои оборудования
CREATE TABLE fact_equipment_downtime (
    downtime_id     BIGSERIAL PRIMARY KEY,
    date_id         INT NOT NULL REFERENCES dim_date(date_id),
    shift_id        INT NOT NULL REFERENCES dim_shift(shift_id),
    equipment_id    INT NOT NULL REFERENCES dim_equipment(equipment_id),
    reason_id       INT NOT NULL REFERENCES dim_downtime_reason(reason_id),
    operator_id     INT REFERENCES dim_operator(operator_id),
    location_id     INT REFERENCES dim_location(location_id),
    -- Меры
    start_time      TIMESTAMP NOT NULL,        -- Начало простоя
    end_time        TIMESTAMP,                 -- Окончание простоя (NULL = продолжается)
    duration_min    NUMERIC(8,2),              -- Длительность простоя, мин
    is_planned      BOOLEAN NOT NULL,          -- Плановый / внеплановый
    comment         TEXT,                      -- Комментарий
    loaded_at       TIMESTAMP DEFAULT NOW()
);

COMMENT ON TABLE  fact_equipment_downtime IS 'Факт-таблица простоев оборудования';
COMMENT ON COLUMN fact_equipment_downtime.duration_min IS 'Продолжительность простоя в минутах';
COMMENT ON COLUMN fact_equipment_downtime.is_planned IS 'TRUE — плановый простой, FALSE — внеплановый';

CREATE INDEX idx_fact_downtime_date ON fact_equipment_downtime(date_id);
CREATE INDEX idx_fact_downtime_equip ON fact_equipment_downtime(equipment_id);
CREATE INDEX idx_fact_downtime_reason ON fact_equipment_downtime(reason_id);

-- Факт: результаты анализа качества руды
CREATE TABLE fact_ore_quality (
    quality_id     BIGSERIAL PRIMARY KEY,
    date_id        INT NOT NULL REFERENCES dim_date(date_id),
    time_id        INT NOT NULL REFERENCES dim_time(time_id),
    shift_id       INT NOT NULL REFERENCES dim_shift(shift_id),
    mine_id        INT NOT NULL REFERENCES dim_mine(mine_id),
    shaft_id       INT NOT NULL REFERENCES dim_shaft(shaft_id),
    location_id    INT REFERENCES dim_location(location_id),
    ore_grade_id   INT REFERENCES dim_ore_grade(ore_grade_id),
    -- Меры
    sample_number  VARCHAR(30),                -- Номер пробы
    fe_content     NUMERIC(5,2) NOT NULL,      -- Содержание Fe, %
    sio2_content   NUMERIC(5,2),               -- Содержание SiO2, %
    al2o3_content  NUMERIC(5,2),               -- Содержание Al2O3, %
    moisture       NUMERIC(5,2),               -- Влажность, %
    density        NUMERIC(6,3),               -- Плотность, г/см³
    sample_weight_kg NUMERIC(8,2),             -- Масса пробы, кг
    loaded_at      TIMESTAMP DEFAULT NOW()
);

COMMENT ON TABLE  fact_ore_quality IS 'Факт-таблица результатов лабораторного анализа качества руды';
COMMENT ON COLUMN fact_ore_quality.fe_content IS 'Содержание железа (Fe) в процентах';
COMMENT ON COLUMN fact_ore_quality.sio2_content IS 'Содержание кремнезёма (SiO2) в процентах';
COMMENT ON COLUMN fact_ore_quality.sample_number IS 'Уникальный номер лабораторной пробы';
