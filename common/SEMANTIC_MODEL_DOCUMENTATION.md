# Документация семантической модели "RudaPlus"

## Обзор модели

**Название модели:** RudaPlus  
**Культура:** ru-RU (Русский)  
**Уровень совместимости:** 1550 (Power BI Premium/Pro)  
**Архитектура схемы:** Снежинка (Snowflake)  
**Источник данных:** Yandex Managed Service for PostgreSQL

### Описание

Аналитическая модель данных предприятия "Руда+" для MES-системы (Manufacturing Execution System). Модель предназначена для анализа качества добываемой руды, контроля простоев оборудования и общей эффективности производственного процесса в шахтах.

---

## Архитектура модели

### Уровни таблиц

```
┌─────────────────────────────────────────────┐
│          ТАБЛИЦЫ ИЗМЕРЕНИЙ (DIMENSIONS)     │
├─────────────────────────────────────────────┤
│ • dim_date              • dim_operator       │
│ • dim_time              • dim_shift          │
│ • dim_equipment         • dim_location       │
│ • dim_equipment_type    • dim_ore_grade      │
│ • dim_mine              • dim_downtime_reason│
│ • dim_shaft             • dim_sensor         │
│ • dim_sensor_type                           │
└─────────────────────────────────────────────┘
                    ↑
        ┌───────────┴───────────┬──────────────┐
        │                       │              │
┌───────┴─────┐    ┌────────────┴──┐  ┌─────┴──────┐
│fact_production    │fact_equipment_│  │fact_ore_   │
│               │downtime        │quality        │
│               │                │              │
└───────────────┘    └────────────────┐  └─────────────┘
                                      │
                    ┌─────────────────┴──────────┐
                    │                            │
              ┌──────┴──────┐         ┌──────────┴────┐
              │fact_equipment│        │_Measures      │
              │telemetry     │        │(KPI measures) │
              └───────────────┘        └───────────────┘
```

---

## Таблицы измерений (Dimensions)

### 1. dim_date (Таблица дат)
Справочник для временного анализа по датам.

| Колонка | Тип данных | Описание |
|---------|-----------|---------|
| date_id | int64 | Уникальный идентификатор даты |
| date | date | Календарная дата |
| year | int64 | Год |
| quarter | int64 | Номер квартала |
| month | int64 | Номер месяца |
| week | int64 | Номер недели |
| day_of_month | int64 | День месяца |
| day_of_week | int64 | День недели |
| day_name | string | Название дня недели |
| month_name | string | Название месяца |

**Использование:** Связь с фактическими таблицами по дате события/записи.

---

### 2. dim_time (Таблица времени)
Справочник для временного анализа по времени суток.

| Колонка | Тип данных | Описание |
|---------|-----------|---------|
| time_id | int64 | Уникальный идентификатор времени |
| time | time | Время суток |
| hour | int64 | Час |
| minute | int64 | Минута |
| hour_name | string | Наименование часа |

**Использование:** Связь с таблицей телеметрии для анализа по часам.

---

### 3. dim_equipment (Оборудование)
Справочник всего оборудования, работающего на предприятии.

| Колонка | Тип данных | Описание |
|---------|-----------|---------|
| equipment_id | int64 | Уникальный идентификатор оборудования |
| equipment_name | string | Наименование оборудования |
| equipment_type_id | int64 | Ссылка на тип оборудования |
| mine_id | int64 | Ссылка на шахту |
| inventory_number | string | Серийный номер (инвентарный номер) |
| year_manufactured | int64 | Год выпуска |
| commissioning_date | dateTime | Дата ввода в эксплуатацию |
| status | string | Статус оборудования |

**Ключи:** equipment_id (PRIMARY)  
**Связи:**
- к dim_equipment_type (type_id)
- к dim_mine (mine_id)

**Примеры оборудования:**
- Погрузочно-доставочные машины (ПДМ)
- Шахтные самосвалы
- Вагонентки
- Скиповые подъемники

---

### 4. dim_equipment_type (Типы оборудования)
Справочник типов оборудования.

| Колонка | Тип данных | Описание |
|---------|-----------|---------|
| equipment_type_id | int64 | Уникальный идентификатор типа |
| type_name | string | Наименование типа |
| description | string | Описание типа |
| max_payload_tons | decimal | Макс. грузоподъемность (т) |
| engine_power_kw | decimal | Макс. скорость (км/ч) |

**Ключи:** equipment_type_id (PRIMARY)

---

### 5. dim_mine (Шахты)
Справочник шахт предприятия.

| Колонка | Тип данных | Описание |
|---------|-----------|---------|
| mine_id | int64 | Уникальный идентификатор шахты |
| mine_name | string | Наименование шахты |
| location | string | Местоположение |
| depth_meters | int64 | Глубина шахты (м) |

**Ключи:** mine_id (PRIMARY)

---

### 6. dim_shaft (Стволы шахт)
Справочник стволов (вертикальных выработок) в шахтах.

| Колонка | Тип данных | Описание |
|---------|-----------|---------|
| shaft_id | int64 | Уникальный идентификатор ствола |
| mine_id | int64 | Ссылка на шахту |
| shaft_name | string | Наименование ствола |
| depth_meters | int64 | Глубина ствола (м) |

**Связь:** к dim_mine (mine_id) - **неактивна по умолчанию**

---

### 7. dim_location (Локации/Участки)
Справочник рабочих участков и локаций.

| Колонка | Тип данных | Описание |
|---------|-----------|---------|
| location_id | int64 | Уникальный идентификатор локации |
| shaft_id | int64 | Ссылка на ствол шахты |
| location_name | string | Наименование участка |
| section | string | Номер секции |

**Связь:** к dim_shaft (shaft_id)

---

### 8. dim_operator (Операторы)
Справочник операторов оборудования.

| Колонка | Тип данных | Описание |
|---------|-----------|---------|
| operator_id | int64 | Уникальный идентификатор оператора |
| operator_name | string | ФИО оператора |
| department | string | Подразделение |
| qualification_level | string | Уровень квалификации |

**Ключи:** operator_id (PRIMARY)

---

### 9. dim_shift (Смены)
Справочник рабочих смен.

| Колонка | Тип данных | Описание |
|---------|-----------|---------|
| shift_id | int64 | Уникальный идентификатор смены |
| shift_name | string | Наименование смены (День/Ночь) |
| start_time | time | Время начала смены |
| end_time | time | Время окончания смены |
| duration_hours | int64 | Длительность смены (ч) |

**Ключи:** shift_id (PRIMARY)

---

### 10. dim_ore_grade (Сорта руды)
Справочник сортов (категорий) добываемой руды.

| Колонка | Тип данных | Описание |
|---------|-----------|---------|
| ore_grade_id | int64 | Уникальный идентификатор сорта |
| grade_name | string | Наименование сорта |
| min_fe_content | decimal | Минимальное содержание Fe (%) |
| max_fe_content | decimal | Максимальное содержание Fe (%) |

**Ключи:** ore_grade_id (PRIMARY)

---

### 11. dim_downtime_reason (Причины простоев)
Справочник причин остановки оборудования.

| Колонка | Тип данных | Описание |
|---------|-----------|---------|
| reason_id | int64 | Уникальный идентификатор причины |
| reason_name | string | Наименование причины |
| reason_category | string | Категория (техническая/плановая/прочее) |
| is_planned | boolean | Является ли планируемым простоем |

**Ключи:** reason_id (PRIMARY)

---

### 12. dim_sensor_type (Типы датчиков)
Справочник типов установленных датчиков.

| Колонка | Тип данных | Описание |
|---------|-----------|---------|
| sensor_type_id | int64 | Уникальный идентификатор типа датчика |
| type_name | string | Наименование типа (температура, давление и т.д.) |
| unit_of_measurement | string | Единица измерения |
| min_value | decimal | Минимальное значение (норма) |
| max_value | decimal | Максимальное значение (норма) |

**Ключи:** sensor_type_id (PRIMARY)

---

### 13. dim_sensor (Датчики)
Справочник физических датчиков, установленных на оборудовании.

| Колонка | Тип данных | Описание |
|---------|-----------|---------|
| sensor_id | int64 | Уникальный идентификатор датчика |
| equipment_id | int64 | Ссылка на оборудование |
| sensor_type_id | int64 | Ссылка на тип датчика |
| serial_number | string | Серийный номер датчика |
| installation_date | dateTime | Дата установки |

**Связи:**
- к dim_equipment (equipment_id)
- к dim_sensor_type (sensor_type_id)

---

## Таблицы фактов (Facts)

### 1. fact_production (Факт добычи руды)
Основная таблица фактов, содержит записи о добыче руды по сменам.

| Колонка | Тип данных | Описание | Суммирование |
|---------|-----------|---------|------------|
| production_id | int64 | Уникальный идентификатор записи | Нет |
| date_id | int64 | Ссылка на дату | Нет |
| shift_id | int64 | Ссылка на смену | Нет |
| equipment_id | int64 | Ссылка на оборудование | Нет |
| operator_id | int64 | Ссылка на оператора | Нет |
| location_id | int64 | Ссылка на локацию | Нет |
| tons_mined | decimal | **Добыто руды (т)** | **SUM** |
| tons_transported | decimal | Вскрыша (т) | SUM |
| operating_hours | decimal | Часы работы | SUM |
| fuel_consumed_l | decimal | Расход топлива (л) | SUM |
| trips_count | int64 | Количество рейсов | SUM |

**Ключи:** production_id (PRIMARY)  
**Связи:**
- к dim_date (date_id)
- к dim_shift (shift_id)
- к dim_equipment (equipment_id)
- к dim_operator (operator_id)
- к dim_location (location_id)

**Гранулярность:** Одна запись = один день + одна смена + одно оборудование + один оператор

---

### 2. fact_equipment_downtime (Факт простоев оборудования)
Таблица событий остановки оборудования.

| Колонка | Тип данных | Описание | Суммирование |
|---------|-----------|---------|------------|
| downtime_id | int64 | Уникальный идентификатор события | Нет |
| equipment_id | int64 | Ссылка на оборудование | Нет |
| reason_id | int64 | Ссылка на причину простоя | Нет |
| start_date_id | int64 | Ссылка на дату начала | Нет |
| start_time_id | int64 | Ссылка на время начала | Нет |
| end_date_id | int64 | Ссылка на дату окончания (неактивна) | Нет |
| end_time_id | int64 | Ссылка на время окончания (неактивна) | Нет |
| duration_min | int64 | **Длительность простоя (мин)** | **SUM** |

**Ключи:** downtime_id (PRIMARY)  
**Активные связи:**
- к dim_equipment (equipment_id)
- к dim_downtime_reason (reason_id)
- к dim_date (start_date_id) - дата начала
- к dim_time (start_time_id) - время начала

**Неактивные связи:**
- к dim_date (end_date_id) - дата окончания
- к dim_time (end_time_id) - время окончания

**Гранулярность:** Одна запись = один инцидент простоя

---

### 3. fact_equipment_telemetry (Телеметрия оборудования)
Таблица высокочастотных данных датчиков.

| Колонка | Тип данных | Описание | Суммирование |
|---------|-----------|---------|------------|
| telemetry_id | int64 | Уникальный идентификатор записи | Нет |
| equipment_id | int64 | Ссылка на оборудование (неактивна) | Нет |
| sensor_id | int64 | Ссылка на датчик | Нет |
| date_id | int64 | Ссылка на дату | Нет |
| time_id | int64 | Ссылка на время | Нет |
| reading_value | decimal | **Показание датчика** | AVG/MIN/MAX |
| is_alarm | boolean | Признак аномалии/тревоги | COUNT |
| alarm_type | string | Тип аномалии | Нет |

**Ключи:** telemetry_id (PRIMARY)  
**Активные связи:**
- к dim_sensor (sensor_id)
- к dim_date (date_id)
- к dim_time (time_id)

**Неактивная связь:**
- к dim_equipment (equipment_id)

**Гранулярность:** Одна запись = одно показание датчика в определенный момент времени

---

### 4. fact_ore_quality (Факт качества руды)
Таблица фактов с результатами анализа качества добытой руды.

| Колонка | Тип данных | Описание | Суммирование |
|---------|-----------|---------|------------|
| quality_id | int64 | Уникальный идентификатор анализа | Нет |
| date_id | int64 | Ссылка на дату отбора пробы | Нет |
| shift_id | int64 | Ссылка на смену | Нет |
| equipment_id | int64 | Ссылка на оборудование (неактивна) | Нет |
| location_id | int64 | Ссылка на локацию добычи | Нет |
| ore_grade_id | int64 | Ссылка на сорт руды | Нет |
| sample_weight_kg | decimal | Вес пробы (кг) | SUM |
| fe_content | decimal | **Содержание железа (%)** | AVG |
| si_content | decimal | Содержание кремния (%) | AVG |
| al_content | decimal | Содержание алюминия (%) | AVG |
| moisture_percent | decimal | Влажность (%) | AVG |

**Ключи:** quality_id (PRIMARY)  
**Активные связи:**
- к dim_date (date_id)
- к dim_shift (shift_id)
- к dim_location (location_id)
- к dim_ore_grade (ore_grade_id)

**Неактивная связь:**
- к dim_equipment (equipment_id)

**Гранулярность:** Одна запись = один анализ пробы руды

---

## Таблица мер (_Measures)

Таблица содержит определенные вычисляемые меры и ключевые показатели эффективности (KPI) предприятия.

### Меры производства

#### Общий объем добычи
```dax
Общий объем добычи = SUM('fact_production'[tons_mined])
```
**Формат:** #,##0.00 (тонны)  
**Описание:** Суммарный объем добытой руды в тоннах.

#### Средняя добыча за смену
```dax
Средняя добыча за смену = AVERAGE('fact_production'[tons_mined])
```
**Формат:** #,##0.00 (тонны)  
**Описание:** Средний объем добычи руды за одну смену.

---

### Меры простоев

#### Общее время простоя
```dax
Общее время простоя = SUM('fact_equipment_downtime'[duration_min])
```
**Формат:** #,##0 (минуты)  
**Описание:** Суммарное время простоев оборудования в минутах.

#### Общее время простоя (часы)
```dax
Общее время простоя (часы) = DIVIDE(SUM('fact_equipment_downtime'[duration_min]), 60)
```
**Формат:** #,##0.0 (часы)  
**Описание:** Суммарное время простоев оборудования в часах.

---

### Меры качества

#### Среднее содержание Fe
```dax
Среднее содержание Fe = AVERAGE(fact_ore_quality[fe_content])
```
**Формат:** 0.00% 
**Описание:** Среднее содержание железа в пробах руды.

---

### Меры телеметрии

#### Количество аномалий
```dax
Количество аномалий = COUNTROWS(FILTER(fact_equipment_telemetry, 'fact_equipment_telemetry'[is_alarm] = TRUE()))
```
**Формат:** #,##0  
**Описание:** Общее количество зафиксированных аномалий датчиков.

---

### Эффективность и KPI

#### КТГ (Коэффициент технической готовности)
```dax
КТГ = 
    VAR _TotalScheduledMinutes =
        CALCULATE(COUNTROWS(fact_production) * 720)
    VAR _UnplannedDowntimeMinutes =
        CALCULATE(
            SUM('fact_equipment_downtime'[duration_min]),
            RELATEDTABLE(dim_downtime_reason),
            dim_downtime_reason[is_planned] = FALSE()
        )
    RETURN
        DIVIDE(
            _TotalScheduledMinutes - _UnplannedDowntimeMinutes,
            _TotalScheduledMinutes
        )
```
**Формат:** 0.00%  
**Описание:** Коэффициент технической готовности = (Общее время - Время незапланированных простоев) / Общее время. Рассчитывается на основе рабочих часов за смену (12ч = 720 мин) и незапланированных простоев.  
**Интерпретация:** Доля времени, когда оборудование было в состоянии готовности к работе.

#### OEE (Overall Equipment Effectiveness)
```dax
OEE = 
    VAR _TotalScheduledMinutes = CALCULATE(COUNTROWS(fact_production) * 720)
    VAR _TotalDowntimeMinutes = CALCULATE(SUM('fact_equipment_downtime'[duration_min]))
    VAR _Availability = DIVIDE(_TotalScheduledMinutes - _TotalDowntimeMinutes, _TotalScheduledMinutes)
    VAR _ActualProduction = SUM('fact_production'[tons_mined])
    VAR _OperatingHours = SUM(fact_production[operating_hours])
    VAR _NominalCapacityPerHour = 25
    VAR _Performance = DIVIDE(_ActualProduction, _OperatingHours * _NominalCapacityPerHour)
    VAR _TotalSamples = COUNTROWS(fact_ore_quality)
    VAR _QualitySamples = CALCULATE(COUNTROWS(fact_ore_quality), fact_ore_quality[fe_content] >= 30)
    VAR _Quality = DIVIDE(_QualitySamples, _TotalSamples)
    RETURN _Availability * _Performance * _Quality
```
**Формат:** 0.00%  
**Описание:** Overall Equipment Effectiveness (Общая эффективность оборудования) = Доступность × Производительность × Качество.
- **Доступность:** (Плановое время - Простои) / Плановое время
- **Производительность:** Фактическая добыча / Нормативная добыча (25 т/ч)
- **Качество:** Доля руды с содержанием Fe ≥ 30%

**Интерпретация:** Комплексный показатель эффективности оборудования. Целевое значение ≥ 80%.

---

## Связи между таблицами (Relationships)

### Активные связи (основной путь фильтрации)

```
dim_equipment_type ← rel_dim_equipment_dim_type ← dim_equipment
                                                      ↓
dim_mine ← rel_dim_equipment_dim_mine ← dim_equipment ← rel_fact_production_dim_equipment ← fact_production
                                                        ← rel_fact_downtime_dim_equipment ← fact_equipment_downtime
                                                        ← rel_fact_quality_dim_equipment ← fact_ore_quality (неактивна)

dim_operator ← rel_fact_production_dim_operator ← fact_production
dim_shift ← rel_fact_production_dim_shift ← fact_production
dim_location ← rel_fact_production_dim_location ← fact_production
dim_date ← rel_fact_production_dim_date ← fact_production

dim_sensor ← rel_fact_telemetry_dim_sensor ← fact_equipment_telemetry
dim_date ← rel_fact_telemetry_dim_date ← fact_equipment_telemetry
dim_time ← rel_fact_telemetry_dim_time ← fact_equipment_telemetry

dim_downtime_reason ← rel_fact_downtime_dim_reason ← fact_equipment_downtime
dim_date ← rel_fact_downtime_dim_date_start ← fact_equipment_downtime
dim_time ← rel_fact_downtime_dim_time_start ← fact_equipment_downtime

dim_ore_grade ← rel_fact_quality_dim_grade ← fact_ore_quality
dim_location ← rel_fact_quality_dim_location ← fact_ore_quality
dim_shift ← rel_fact_quality_dim_shift ← fact_ore_quality
dim_date ← rel_fact_quality_dim_date ← fact_ore_quality

dim_location ← rel_dim_location_dim_shaft ← dim_shaft
dim_mine ← rel_dim_shaft_dim_mine ← dim_shaft (неактивна)
```

### Неактивные связи
- `rel_fact_telemetry_dim_equipment` - связь между телеметрией и оборудованием
- `rel_fact_quality_dim_equipment` - связь между качеством и оборудованием
- `rel_fact_downtime_dim_date_end` - дата окончания простоя
- `rel_fact_downtime_dim_time_end` - время окончания простоя
- `rel_dim_shaft_dim_mine` - связь ствола с шахтой

**Назначение неактивных связей:** Избежать амбигуозности при фильтрации. Могут быть активированы явно в DAX-выражениях при необходимости.

---

## Источник данных

**Тип подключения:** PostgreSQL (ODBC)  
**Сервер:** rc1a-3fapmhnjrbfd3ve5.mdb.yandexcloud.net  
**Порт:** 6432  
**База данных:** db1  
**Аутентификация:** SQL (пользователь: user1)  
**Безопасность:** SSL требуется  

---

## Рекомендации по использованию

### 1. Анализ производительности
- Используйте меры **Общий объем добычи** и **Средняя добыча за смену**
- Фильтруйте по `dim_date`, `dim_equipment`, `dim_shift`
- Добавляйте в срезы `dim_equipment_type`, `dim_mine`

### 2. Контроль простоев
- Анализируйте **Общее время простоя** по причинам (`dim_downtime_reason`)
- Сегментируйте по `dim_equipment`, `dim_date`
- Выделяйте плановые vs. незапланированные простои

### 3. Качество продукции
- Отслеживайте **Среднее содержание Fe** по `dim_ore_grade`
- Анализируйте тренды по датам и локациям
- Используйте меру **Среднее содержание Fe** как индикатор качества

### 4. Мониторинг оборудования
- Отслеживайте **Количество аномалий** по датчикам (`dim_sensor`)
- Анализируйте паттерны аномалий во времени
- Коррелируйте с простоями оборудования

### 5. KPI мониторинг
- **КТГ** ≥ 85% - нормальное состояние
- **OEE** ≥ 80% - целевой показатель эффективности
- Отслеживайте динамику по неделям и месяцам

---

## Граммотность данных

### Проверки целостности
- ✓ Все foreign keys связаны с существующими записями в reference таблицах
- ✓ Все даты находятся в корректном диапазоне
- ✓ Процентные показатели (Fe, Si, Al, влажность) находятся в диапазоне 0-100%
- ✓ Физические единицы измерения корректны (тонны, часы, минуты, литры)

### Обновление данных
- Таблицы обновляются ежедневно из системы MES
- Фактические таблицы содержат данные за последние 12 месяцев
- Справочники (dimensions) содержат полный актуальный набор

---

## История изменений модели

| Версия | Дата | Описание |
|--------|------|---------|
| 1.0 | 2026-03-19 | Начальная версия. Создано 4 таблицы фактов, 13 таблиц измерений |
| - | - | Определены основные меры KPI и эффективности |
| - | - | Установлены связи между таблицами по схеме "снежинка" |

---

## Контакты и поддержка

Для вопросов по модели, обновлении структуры или добавлении новых мер обращайтесь к разработчикам курса "Анализ данных на языке SQL. Уровень 2".
