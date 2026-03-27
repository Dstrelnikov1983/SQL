# Результаты лабораторной работы — Модуль 9

## Колоночное хранение и оптимизация аналитических запросов

> Результаты выполнения SQL-запросов из лабораторной работы.
> **Примечание:** Задания 1, 4, 6 требуют расширения Citus Columnar и секционирования,
> результаты которых зависят от конфигурации сервера. Ниже приведены результаты базовых запросов.

---

### Задание 1: Размер таблицы fact_production

```sql
SELECT 'fact_production' AS table_name,
       pg_size_pretty(pg_total_relation_size('fact_production')) AS total_size,
       pg_size_pretty(pg_relation_size('fact_production')) AS data_size
```

**Результат:**

| table_name | total_size | data_size |
| --- | --- | --- |
| fact_production | 1664 kB | 1024 kB |

*(1 строк)*

### Задание 2: Корреляция date_id в fact_equipment_downtime

```sql
SELECT attname, correlation, n_distinct
FROM pg_stats
WHERE tablename = 'fact_equipment_downtime'
  AND attname = 'date_id'
  AND schemaname = 'public'
```

**Результат:**

| attname | correlation | n_distinct |
| --- | --- | --- |
| date_id | 0.5724239 | -0.18731989 |

*(1 строк)*

### Задание 2: Простои по причинам (февраль 2024)

```sql
SELECT d.equipment_id,
       r.reason_name,
       SUM(d.duration_min) AS total_downtime
FROM fact_equipment_downtime d
JOIN dim_downtime_reason r ON d.reason_id = r.reason_id
WHERE d.date_id BETWEEN 20240201 AND 20240228
GROUP BY d.equipment_id, r.reason_name
ORDER BY total_downtime DESC
```

**Результат:**

| equipment_id | reason_name | total_downtime |
| --- | --- | --- |
| 4 | Ожидание транспорта | 592.33 |
| 4 | Плановое техническое обслуживание | 480.00 |
| 1 | Аварийный ремонт | 480.00 |
| 1 | Плановое техническое обслуживание | 480.00 |
| 3 | Плановое техническое обслуживание | 480.00 |
| 10 | Плановое техническое обслуживание | 480.00 |
| 7 | Плановое техническое обслуживание | 480.00 |
| 6 | Плановое техническое обслуживание | 480.00 |
| 8 | Плановое техническое обслуживание | 480.00 |
| 2 | Плановое техническое обслуживание | 480.00 |
| 8 | Заправка топливом | 240.00 |
| 4 | Заправка топливом | 240.00 |
| 1 | Заправка топливом | 240.00 |
| 2 | Заправка топливом | 240.00 |
| 6 | Заправка топливом | 240.00 |

*... (показаны первые 15 строк из 29)*

### Задание 3: Распределение проб качества по шахтам

```sql
SELECT m.mine_name,
       COUNT(*) AS row_count
FROM fact_ore_quality q
JOIN dim_mine m ON q.mine_id = m.mine_id
GROUP BY m.mine_name
ORDER BY m.mine_name
```

**Результат:**

| mine_name | row_count |
| --- | --- |
| Шахта "Северная" | 3310 |
| Шахта "Южная" | 2015 |

*(2 строк)*

### Задание 4: Средние показатели телеметрии (Q1 2024)

```sql
SELECT equipment_id,
       ROUND(AVG(sensor_value)::numeric, 2) AS avg_value,
       ROUND(MIN(sensor_value)::numeric, 2) AS min_value,
       ROUND(MAX(sensor_value)::numeric, 2) AS max_value
FROM fact_equipment_telemetry
WHERE date_id BETWEEN 20240215 AND 20240315
GROUP BY equipment_id
ORDER BY avg_value DESC
```

**Результат:**

| equipment_id | avg_value | min_value | max_value |
| --- | --- | --- | --- |

*(0 строк)*

### Задание 5: Количество строк в основных таблицах

```sql
SELECT 'fact_equipment_telemetry' AS table_name, COUNT(*) AS row_count FROM fact_equipment_telemetry
UNION ALL
SELECT 'fact_production', COUNT(*) FROM fact_production
UNION ALL
SELECT 'fact_ore_quality', COUNT(*) FROM fact_ore_quality
UNION ALL
SELECT 'dim_equipment', COUNT(*) FROM dim_equipment
ORDER BY row_count DESC
```

**Результат:**

| table_name | row_count |
| --- | --- |
| fact_equipment_telemetry | 18864 |
| fact_production | 8384 |
| fact_ore_quality | 5325 |
| dim_equipment | 18 |

*(4 строк)*

### Задание 6: Средняя температура по оборудованию (Q1 2024)

```sql
SELECT t.equipment_id,
       ROUND(AVG(t.sensor_value)::numeric, 2) AS avg_temp
FROM fact_equipment_telemetry t
WHERE t.date_id BETWEEN 20240101 AND 20240331
  AND t.sensor_id IN (SELECT sensor_id FROM dim_sensor WHERE sensor_type_id = 1)
GROUP BY t.equipment_id
ORDER BY t.equipment_id
```

**Результат:**

| equipment_id | avg_temp |
| --- | --- |
| 1 | 89.75 |

*(1 строк)*
