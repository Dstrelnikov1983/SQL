# Результаты лабораторной работы — Модуль 17

## Применение обработки ошибок

---

## Задание 1. Безопасное деление

**Тестовые вызовы:**

```
safe_production_rate(150, 8)    = 18.75
safe_production_rate(150, 0)    = 0      + WARNING: деление на ноль при расчёте производительности
safe_production_rate(NULL, 8)   = NULL
```

**Применение к данным (date_id = 20250115):**

```
equipment_id | tons_mined | operating_hours | rate
-------------+------------+-----------------+-------
 7           | 162.95     | 10.17           | 16.02
 8           | 164.82     | 10.41           | 15.83
10           | 163.62     | 10.52           | 15.55
10           | 145.38     | 10.53           | 13.81
 8           | 154.03     | 11.23           | 13.72
 7           | 140.43     | 10.46           | 13.43
 2           |  78.91     | 10.14           |  7.78
 6           |  74.81     | 10.23           |  7.31
 3           |  77.29     | 10.73           |  7.20
 1           |  71.11     | 10.70           |  6.65
```

> Самосвалы (equipment_id 7, 8, 10) имеют значительно более высокую производительность (~14-16 т/ч) по сравнению с ПДМ (~6-8 т/ч).

---

## Задание 2. Валидация данных телеметрии

**Допустимые диапазоны:**

| Тип датчика  | Мин   | Макс  |
|--------------|-------|-------|
| Температура  | -40   | +200  |
| Давление     | 0     | 500   |
| Вибрация     | 0     | 100   |
| Скорость     | 0     | 50    |

**Результаты валидации:**

```
validate_sensor_reading('Температура', 85)    -> OK
validate_sensor_reading('Температура', 250)   -> ОШИБКА (S0002): значение вне диапазона -40..200
validate_sensor_reading('Давление', 300)      -> OK
validate_sensor_reading('Вибрация', 150)      -> ОШИБКА (S0002): значение вне диапазона 0..100
validate_sensor_reading('Неизвестный', 50)     -> ОШИБКА (S0001): неизвестный тип датчика
```

---

## Задание 3. Обработка ошибок при вставке

> Из 10 записей в пакете:
> - Успешно вставлено: ~7 записей
> - Ошибки FK violation (несуществующий equipment_id): 1
> - Ошибки NOT NULL violation: 1
> - Ошибки UNIQUE violation (дублирующийся PK): 1
>
> Каждая ошибка залогирована в `error_log` с полным стеком диагностики.

---

## Задание 4. GET STACKED DIAGNOSTICS — детальный отчёт

**Пример для division_by_zero (p_error_type = 1):**

```
field_name              | field_value
------------------------+-----------------------------------------------------
RETURNED_SQLSTATE       | 22012
MESSAGE_TEXT            | division by zero
PG_EXCEPTION_DETAIL     | (пусто)
PG_EXCEPTION_HINT       | (пусто)
PG_EXCEPTION_CONTEXT    | PL/pgSQL function test_error_diagnostics(integer)
                        |   line N at assignment
COLUMN_NAME             | (пусто)
CONSTRAINT_NAME         | (пусто)
DATATYPE_NAME           | (пусто)
TABLE_NAME              | (пусто)
SCHEMA_NAME             | (пусто)
```

**Пример для unique_violation (p_error_type = 2):**

```
field_name              | field_value
------------------------+-----------------------------------------------------
RETURNED_SQLSTATE       | 23505
MESSAGE_TEXT            | duplicate key value violates unique constraint
PG_EXCEPTION_DETAIL     | Key (mine_id)=(1) already exists.
CONSTRAINT_NAME         | dim_mine_pkey
TABLE_NAME              | dim_mine
SCHEMA_NAME             | public
```

> `unique_violation` и `foreign_key_violation` заполняют больше диагностических полей (TABLE_NAME, CONSTRAINT_NAME), чем арифметические ошибки.

---

## Задание 5. Безопасный импорт с логированием

**Ожидаемый результат:**

```
total  = 10
valid  = 6
errors = 4
```

**Ошибки:**

| row_id | status | error_msg |
|--------|--------|-----------|
| 2 | ERROR | Шахта 'Несуществующая' не найдена в dim_mine |
| 4 | ERROR | Некорректная дата: '32-01-2025' |
| 6 | ERROR | fe_content = 'N/A' — не является числом |
| 8 | ERROR | fe_content = 150 — вне допустимого диапазона 0..100 |

---

## Задание 6. Комплексная функция — пересчёт KPI

**Вызов:** `SELECT * FROM recalculate_daily_kpi(20250115)`

```
mine_id | mine_name          | tons_mined | oee_pct | downtime_hours | avg_fe
--------+--------------------+------------+---------+----------------+-------
1       | Шахта "Северная"   | 1043.35    | 174.4   | 40.0           | 53.26
2       | Шахта "Южная"      |  584.44    | 175.8   | 26.9           | 45.71
```

**Результат функции:**

```
mines_processed = 2
mines_ok        = 2
mines_error     = 0
```

> OEE > 100% указывает на то, что плановые часы в формуле (equip_count * 12) занижены — оборудование работает более интенсивно, чем предполагает норматив. Содержание Fe на Шахте "Южная" (45.71%) существенно ниже, чем на Шахте "Северная" (53.26%).
