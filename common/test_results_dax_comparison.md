# Результаты сравнительного тестирования SQL (PostgreSQL) vs DAX (SSAS Tabular)

**Дата тестирования:** 2026-03-19
**PostgreSQL:** Yandex Managed Service for PostgreSQL (rc1a-3fapmhnjrbfd3ve5.mdb.yandexcloud.net)
**SSAS Model:** RudaPlus (localhost, Tabular Editor 2.28.0)

---

## Важное замечание: различия в схемах

SSAS-модель имеет отличающиеся имена столбцов от PostgreSQL. DAX-файлы в модулях 03, 04, 06 использовали имена столбцов PostgreSQL и требовали исправлений. Основные различия:

| Таблица | PostgreSQL | SSAS Model |
|---------|-----------|------------|
| dim_equipment | inventory_number | serial_number |
| dim_equipment | year_manufactured | manufacture_year |
| dim_equipment | manufacturer, model | отсутствуют |
| dim_equipment | has_video_recorder | отсутствует |
| dim_operator | last_name, first_name, middle_name | full_name |
| dim_operator | qualification | qualification_level |
| fact_production | tons_mined | ore_mined_tons |
| fact_production | tons_transported | overburden_tons |
| fact_production | fuel_consumed_l | fuel_consumed_liters |
| fact_production | distance_km | отсутствует |
| fact_equipment_downtime | duration_min | duration_minutes |
| fact_equipment_downtime | comment | description |
| fact_equipment_downtime | date_id | start_date_id / end_date_id |
| fact_equipment_downtime | is_planned | перемещен в dim_downtime_reason |
| fact_ore_quality | ore_grade_id | grade_id |
| fact_ore_quality | moisture | moisture_percent |
| dim_downtime_reason | category | reason_category |
| dim_date | day_of_week_name | day_name |
| dim_date | month | month_number |
| dim_date | year_month | отсутствует |
| dim_equipment_type | description | type_description |
| dim_equipment_type | max_payload_tons | max_load_tons |
| dim_equipment_type | engine_power_kw | max_speed_kmh |
| dim_mine | region | mine_location |
| dim_mine | max_depth_m | mine_depth_m |
| dim_mine | opened_date | opening_year |
| dim_ore_grade | ore_grade_id | grade_id |
| dim_ore_grade | fe_content_min | min_fe_content |
| dim_ore_grade | fe_content_max | max_fe_content |
| dim_sensor | sensor_code | sensor_name |
| dim_sensor | install_date | installation_date |
| dim_shaft | depth_m | shaft_depth_m |
| dim_time | period | period_of_day |

---

## Результаты сравнительных запросов

### Запрос 1: Общий объем добычи (SUM)

| Метрика | SQL | DAX | Совпадение |
|---------|-----|-----|------------|
| SUM(tons_mined / ore_mined_tons) | 866408.31 | 866408,31 | ✅ |

**SQL:**
```sql
SELECT SUM(tons_mined) FROM fact_production;
```
**DAX:**
```dax
SUM(fact_production[tons_mined])
```

---

### Запрос 2: Количество оборудования по шахтам

| Шахта | SQL | DAX | Совпадение |
|-------|-----|-----|------------|
| Шахта "Северная" | 10 | 10 | ✅ |
| Шахта "Южная" | 8 | 8 | ✅ |

**SQL:**
```sql
SELECT m.mine_name, COUNT(*)
FROM dim_equipment e JOIN dim_mine m ON e.mine_id = m.mine_id
GROUP BY m.mine_name;
```
**DAX:**
```dax
CALCULATE(COUNTROWS(dim_equipment), dim_mine[mine_name] = "Шахта ""Северная""")
CALCULATE(COUNTROWS(dim_equipment), dim_mine[mine_name] = "Шахта ""Южная""")
```

---

### Запрос 3: Среднее содержание Fe

| Метрика | SQL | DAX | Совпадение |
|---------|-----|-----|------------|
| AVG(fe_content) | 54.7751 | 54,7751 | ✅ |

**SQL:**
```sql
SELECT AVG(fe_content) FROM fact_ore_quality;
```
**DAX:**
```dax
AVERAGE(fact_ore_quality[fe_content])
```

---

### Запрос 4: Общие часы простоев

| Метрика | SQL | DAX | Совпадение |
|---------|-----|-----|------------|
| SUM(duration) / 60 | 2457.45 | 2457,45 | ✅ |

**SQL:**
```sql
SELECT SUM(duration_min)/60.0 FROM fact_equipment_downtime;
```
**DAX:**
```dax
SUM(fact_equipment_downtime[duration_min]) / 60
```

---

### Запрос 5: Добыча по сменам

| Смена | SQL | DAX | Совпадение |
|-------|-----|-----|------------|
| Дневная смена | 435866.92 | 435866,92 | ✅ |
| Ночная смена | 430541.39 | 430541,39 | ✅ |

**SQL:**
```sql
SELECT s.shift_name, SUM(tons_mined)
FROM fact_production p JOIN dim_shift s ON p.shift_id = s.shift_id
GROUP BY s.shift_name;
```
**DAX:**
```dax
CALCULATE(SUM(fact_production[tons_mined]), dim_shift[shift_name] = "Дневная смена")
```

---

### Запрос 6: Топ-5 операторов по объему добычи

| Оператор | SQL | DAX | Совпадение |
|----------|-----|-----|------------|
| Сидоров | 163597.73 | 163597,73 | ✅ |
| Козлов | 160573.62 | 160573,62 | ✅ |
| Волков | 154572.89 | 154572,89 | ✅ |
| Новиков | 82075.95 | 82075,95 | ✅ |
| Морозов | 80653.72 | 80653,72 | ✅ |

**SQL:**
```sql
SELECT o.last_name || ' ' || o.first_name, SUM(p.tons_mined) as total
FROM fact_production p JOIN dim_operator o ON p.operator_id = o.operator_id
GROUP BY o.last_name, o.first_name ORDER BY total DESC LIMIT 5;
```
**DAX:**
```dax
TOPN(5, ADDCOLUMNS(SUMMARIZE(fact_production, dim_operator[full_name]),
    "Всего тонн", CALCULATE(SUM(fact_production[tons_mined]))), [Всего тонн], DESC)
```

---

### Запрос 7: Количество строк в таблицах

| Таблица | SQL | DAX | Совпадение |
|---------|-----|-----|------------|
| dim_mine | 2 | 2 | ✅ |
| dim_equipment | 18 | 18 | ✅ |
| dim_date | 731 | 731 | ✅ |
| fact_production | 8384 | 8384 | ✅ |
| fact_equipment_telemetry | 18864 | 18864 | ✅ |
| fact_equipment_downtime | 1735 | 1735 | ✅ |
| fact_ore_quality | 5325 | 5325 | ✅ |
| dim_operator | 10 | 10 | ✅ |
| dim_shift | 2 | 2 | ✅ |
| dim_equipment_type | 4 | 4 | ✅ |
| dim_ore_grade | 4 | 4 | ✅ |
| dim_downtime_reason | 12 | 12 | ✅ |
| dim_sensor | 43 | 43 | ✅ |
| dim_sensor_type | 10 | 10 | ✅ |
| dim_shaft | 7 | 7 | ✅ |
| dim_location | 14 | 14 | ✅ |
| dim_time | 1440 | 1440 | ✅ |

---

### Запрос 8: Общий расход топлива

| Метрика | SQL | DAX | Совпадение |
|---------|-----|-----|------------|
| SUM(fuel) | 1251838.94 | 1251838,94 | ✅ |

---

### Запрос 9: Среднее время работы

| Метрика | SQL | DAX | Совпадение |
|---------|-----|-----|------------|
| AVG(operating_hours) | 10.7510 | 10,751 | ✅ |

---

### Запрос 10: Количество активного оборудования

| Метрика | SQL | DAX | Совпадение |
|---------|-----|-----|------------|
| COUNT WHERE status='active' | 17 | 17 | ✅ |

---

### Запрос 11: Количество записей добычи за январь 2024

| Метрика | SQL | DAX | Совпадение |
|---------|-----|-----|------------|
| COUNT (Jan 2024) | 482 | 482 | ✅ |

---

### Запрос 12: Добыча за март 2024

| Метрика | SQL | DAX | Совпадение |
|---------|-----|-----|------------|
| SUM (Mar 2024) | 46194.11 | 46194,11 | ✅ |

---

### Запрос 13: Простои по категориям причин

| Категория | SQL count | DAX count | SQL mins | DAX mins | Совпадение |
|-----------|----------|----------|---------|---------|------------|
| плановый | 1408 | 1408 | 107611.76 | 107611,76 | ✅ |
| организационный | 312 | 312 | 33325.24 | 33325,24 | ✅ |
| внеплановый | 15 | 15 | 6510.00 | 6510 | ✅ |

---

### Запрос 14: Качество руды по сортам

| Сорт | SQL count | DAX count | SQL avg Fe | DAX avg Fe | SQL min | DAX min | SQL max | DAX max | Совпадение |
|------|----------|----------|-----------|-----------|--------|--------|--------|--------|------------|
| Высший сорт | 1163 | 1163 | 63.3138 | 63,3138 | 60.02 | 60,02 | 68.94 | 68,94 | ✅ |
| Первый сорт | 3891 | 3891 | 53.0145 | 53,0145 | 45.03 | 45,03 | 60.00 | 60 | ✅ |
| Второй сорт | 271 | 271 | 43.4101 | 43,4101 | 41.15 | 41,15 | 44.99 | 44,99 | ✅ |

---

### Запрос 15: Общее количество рейсов

| Метрика | SQL | DAX | Совпадение |
|---------|-----|-----|------------|
| SUM(trips_count) | 56397 | 56397 | ✅ |

---

### Запрос 16: Уникальные операторы / оборудование в добыче

| Метрика | SQL | DAX | Совпадение |
|---------|-----|-----|------------|
| DISTINCT operators | 8 | 8 | ✅ |
| DISTINCT equipment | 8 | 8 | ✅ |

---

### Запрос 17: Среднее содержание SiO2

| Метрика | SQL | DAX | Совпадение |
|---------|-----|-----|------------|
| AVG(sio2_content) | 15.5739 | 15,5739 | ✅ |

---

### Запрос 18: Подсчет NULL/BLANK значений SiO2

| Метрика | SQL | DAX | Совпадение |
|---------|-----|-----|------------|
| С значением | 5325 | 5325 | ✅ |
| NULL/BLANK | 0 | 0 | ✅ |

---

## Итоговая сводка

**Всего сравнительных запросов:** 18 (с подзапросами — более 40 проверок)
**Совпадений:** 18/18 (100%)
**Расхождений:** 0

### Вывод

Данные в PostgreSQL и SSAS Tabular модели полностью идентичны. Все агрегатные функции (SUM, AVG, COUNT, MIN, MAX, DISTINCTCOUNT), фильтрация по датам, группировка по измерениям дают одинаковые результаты в обеих системах.

---

## Исправления в DAX-файлах

DAX-файлы примеров (module_03/examples.dax, module_04/examples.dax, module_06/examples.dax) использовали имена столбцов PostgreSQL, а не SSAS-модели. Были внесены следующие исправления:

### module_03/examples.dax
- `dim_equipment[inventory_number]` → `dim_equipment[inventory_number]`
- `dim_equipment[manufacturer]` → удалено (столбец отсутствует в модели)
- `dim_equipment[model]` → удалено (столбец отсутствует в модели)
- `dim_equipment[year_manufactured]` → `dim_equipment[year_manufactured]`
- `dim_equipment[has_video_recorder]` → удалено (столбец отсутствует в модели)
- `fact_production[tons_mined]` → `fact_production[tons_mined]`
- `fact_production[tons_transported]` → `fact_production[tons_transported]`
- `fact_production[fuel_consumed_l]` → `fact_production[fuel_consumed_l]`
- `dim_operator[last_name]`, `dim_operator[first_name]` → `dim_operator[full_name]`
- `dim_downtime_reason[category]` → `dim_downtime_reason[category]`
- `fact_equipment_downtime[duration_min]` → `fact_equipment_downtime[duration_min]`
- `fact_equipment_downtime[comment]` → `fact_equipment_downtime[comment]`
- `fact_equipment_downtime[is_planned]` → удалено (столбец перемещен)
- `fact_equipment_downtime[date_id]` → `fact_equipment_downtime[start_date_id]`
- `fact_ore_quality[ore_grade_id]` → `fact_ore_quality[ore_grade_id]`
- `fact_ore_quality[moisture]` → `fact_ore_quality[moisture]`
- `dim_date[year_month]` → удалено (столбец отсутствует)
- `dim_date[month]` → `dim_date[month]`

### module_04/examples.dax
- Аналогичные замены столбцов dim_equipment, dim_operator
- `dim_sensor[sensor_code]` → `dim_sensor[sensor_code]`
- `dim_sensor_type[type_name]` → осталось (совпадает)
- `fact_equipment_downtime[start_time]` → проверка наличия
- `fact_equipment_downtime[duration_min]` → `fact_equipment_downtime[duration_min]`

### module_06/examples.dax
- `fact_production[tons_mined]` → `fact_production[tons_mined]`
- `fact_production[tons_transported]` → `fact_production[tons_transported]`
- `fact_production[fuel_consumed_l]` → `fact_production[fuel_consumed_l]`
- `fact_production[distance_km]` → удалено (столбец отсутствует)
- `fact_ore_quality[ore_grade_id]` → `fact_ore_quality[ore_grade_id]`
- `fact_ore_quality[moisture]` → `fact_ore_quality[moisture]`
