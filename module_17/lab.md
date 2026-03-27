# Лабораторная работа — Модуль 17

## Применение обработки ошибок

**Продолжительность:** 30 минут
**Формат:** самостоятельная работа
**Инструменты:** PostgreSQL (Yandex Managed Service for PostgreSQL)
**База данных:** «Руда+» (MES-система горнодобывающего предприятия)

---

## Общие указания

- Для каждого задания напишите SQL-код и сохраните его в файл `lab_solutions.sql`
- После создания каждой функции протестируйте её на корректных и некорректных данных
- Задания расположены по возрастанию сложности
- Используйте таблицу `error_log` из практической работы (создайте, если не существует)

---

## Подготовка

Если таблица логов ещё не создана, выполните:

```sql
CREATE TABLE IF NOT EXISTS error_log (
    log_id      SERIAL PRIMARY KEY,
    log_time    TIMESTAMP DEFAULT NOW(),
    severity    VARCHAR(20),
    source      VARCHAR(100),
    sqlstate    VARCHAR(5),
    message     TEXT,
    detail      TEXT,
    hint        TEXT,
    context     TEXT,
    username    VARCHAR(100) DEFAULT CURRENT_USER,
    parameters  JSONB
);

CREATE OR REPLACE FUNCTION log_error(
    p_severity VARCHAR, p_source VARCHAR,
    p_sqlstate VARCHAR DEFAULT NULL, p_message TEXT DEFAULT NULL,
    p_detail TEXT DEFAULT NULL, p_hint TEXT DEFAULT NULL,
    p_context TEXT DEFAULT NULL, p_parameters JSONB DEFAULT NULL
)
RETURNS INT LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE v_log_id INT;
BEGIN
    INSERT INTO error_log (severity, source, sqlstate, message, detail, hint, context, parameters)
    VALUES (p_severity, p_source, p_sqlstate, p_message, p_detail, p_hint, p_context, p_parameters)
    RETURNING log_id INTO v_log_id;
    RETURN v_log_id;
END;
$$;
```

---

## Задание 1. Безопасное деление (простое)

**Бизнес-задача:** Расчёт производительности (тонн/час) часто приводит к делению на ноль, когда оборудование не работало.

**Требования:**

1. Создайте функцию `safe_production_rate(p_tons NUMERIC, p_hours NUMERIC)`:
   - Возвращает `NUMERIC`
   - Перехватывает `division_by_zero`
   - При ошибке возвращает `0` и выводит `RAISE WARNING`
   - При `NULL` параметрах возвращает `NULL`
2. Протестируйте:
   ```sql
   SELECT safe_production_rate(150, 8);    -- 18.75
   SELECT safe_production_rate(150, 0);    -- 0 + WARNING
   SELECT safe_production_rate(NULL, 8);   -- NULL
   ```
3. Примените к `fact_production`:
   ```sql
   SELECT equipment_id, tons_mined, operating_hours,
          safe_production_rate(tons_mined, operating_hours) AS rate
   FROM fact_production
   WHERE date_id = 20250115
   ORDER BY rate DESC LIMIT 10;
   ```

---

## Задание 2. Валидация данных телеметрии (простое)

**Бизнес-задача:** Данные с датчиков могут содержать ошибки. Необходимо проверять значения перед записью.

**Требования:**

1. Создайте функцию `validate_sensor_reading(p_sensor_type VARCHAR, p_value NUMERIC)`:
   - Для типа «Температура»: допустимый диапазон -40..+200 °C
   - Для типа «Давление»: допустимый диапазон 0..500 бар
   - Для типа «Вибрация»: допустимый диапазон 0..100 мм/с
   - Для типа «Скорость»: допустимый диапазон 0..50 км/ч
   - Для неизвестного типа: RAISE EXCEPTION с кодом 'S0001'
   - Если значение вне диапазона: RAISE EXCEPTION с кодом 'S0002' и HINT с допустимым диапазоном
   - Если проверка пройдена: вернуть 'OK'
2. Протестируйте все ветки (корректные данные и ошибки для каждого типа)

---

## Задание 3. Обработка ошибок при вставке (среднее)

**Бизнес-задача:** При пакетной загрузке данных о простоях нужно пропускать ошибочные записи и продолжать обработку.

**Требования:**

1. Создайте анонимный блок, который вставляет 10 записей в `fact_equipment_downtime`
2. Среди записей намеренно включите ошибочные:
   - Запись с несуществующим `equipment_id` (FK violation)
   - Запись с `NULL` в обязательном поле (NOT NULL violation)
   - Запись с дублирующимся PK (unique violation)
3. Каждая вставка должна быть в своём подблоке `BEGIN ... EXCEPTION ... END`
4. При ошибке:
   - Запишите ошибку в `error_log` через `log_error()`
   - Выведите `RAISE WARNING` с номером записи и типом ошибки
5. В конце выведите статистику: сколько вставлено, сколько ошибок

---

## Задание 4. GET STACKED DIAGNOSTICS — детальный отчёт (среднее)

**Бизнес-задача:** Для анализа причин сбоев нужна максимально подробная информация.

**Требования:**

1. Создайте функцию `test_error_diagnostics(p_error_type INT)`:
   - p_error_type = 1: вызывает `division_by_zero`
   - p_error_type = 2: вызывает `unique_violation` (вставка дубля в dim_mine)
   - p_error_type = 3: вызывает `foreign_key_violation`
   - p_error_type = 4: вызывает `invalid_text_representation` (приведение типа)
   - p_error_type = 5: вызывает пользовательскую ошибку через RAISE EXCEPTION
2. В блоке EXCEPTION используйте `GET STACKED DIAGNOSTICS` для получения ВСЕХ доступных полей
3. Функция должна возвращать `TABLE` со столбцами:
   - `field_name VARCHAR` — имя диагностического поля
   - `field_value TEXT` — значение
4. Протестируйте для каждого типа ошибки и сравните, какие поля заполняются

---

## Задание 5. Безопасный импорт с логированием (среднее)

**Бизнес-задача:** Импорт результатов лабораторного анализа руды из внешней системы.

**Требования:**

1. Создайте таблицу промежуточного хранения:
   ```sql
   CREATE TABLE staging_lab_results (
       row_id       SERIAL,
       mine_name    TEXT,
       sample_date  TEXT,
       fe_content   TEXT,
       moisture     TEXT,
       status       VARCHAR(20) DEFAULT 'NEW',
       error_msg    TEXT
   );
   ```
2. Вставьте тестовые данные (10 строк), включая ошибочные:
   - Несуществующая шахта
   - Некорректная дата ('32-01-2025')
   - Fe = 'N/A' (не число)
   - Fe = 150 (вне диапазона)
   - Корректные записи
3. Создайте функцию `process_lab_import()`, которая:
   - Перебирает все записи со status = 'NEW'
   - Валидирует каждую запись (преобразование типов, проверка диапазонов, проверка шахты)
   - При успехе: обновляет status = 'VALID'
   - При ошибке: обновляет status = 'ERROR', записывает error_msg, логирует в error_log
   - Возвращает статистику: total, valid, errors
4. Выполните функцию и проверьте:
   ```sql
   SELECT * FROM process_lab_import();
   SELECT * FROM staging_lab_results ORDER BY row_id;
   SELECT * FROM error_log WHERE source = 'process_lab_import' ORDER BY log_id DESC;
   ```

---

## Задание 6. Комплексная функция с иерархией обработки ошибок (сложное)

**Бизнес-задача:** Создать надёжную функцию пересчёта ежедневных KPI по всем шахтам.

**Требования:**

1. Создайте таблицу результатов KPI:
   ```sql
   CREATE TABLE daily_kpi (
       kpi_id         SERIAL PRIMARY KEY,
       mine_id        INT,
       date_id        INT,
       tons_mined     NUMERIC,
       oee_percent    NUMERIC,
       downtime_hours NUMERIC,
       quality_score  NUMERIC,
       status         VARCHAR(20),
       error_detail   TEXT,
       calculated_at  TIMESTAMP DEFAULT NOW(),
       UNIQUE (mine_id, date_id)
   );
   ```
2. Создайте функцию `recalculate_daily_kpi(p_date_id INT)`:
   - Перебирает все шахты из `dim_mine`
   - Для каждой шахты в отдельном подблоке рассчитывает:
     - Общая добыча (из fact_production)
     - OEE (operating_hours / planned_hours * 100)
     - Часы простоев (из fact_equipment_downtime)
     - Средний показатель качества Fe (из fact_ore_quality)
   - Использует UPSERT (INSERT ... ON CONFLICT DO UPDATE)
   - При ошибке расчёта для конкретной шахты:
     - Записывает KPI с status = 'ERROR' и error_detail
     - Логирует через log_error()
     - Продолжает с следующей шахтой
   - При критической ошибке (не в подблоке):
     - Логирует и возвращает ошибку
3. Функция возвращает TABLE: `mines_processed INT, mines_ok INT, mines_error INT`
4. Протестируйте:
   ```sql
   SELECT * FROM recalculate_daily_kpi(20250115);
   SELECT * FROM daily_kpi WHERE date_id = 20250115 ORDER BY mine_id;
   ```

---

## Критерии оценки

| Задание | Сложность | Баллы |
|---------|-----------|-------|
| 1. Безопасное деление | Простое | 10 |
| 2. Валидация телеметрии | Простое | 15 |
| 3. Обработка ошибок при вставке | Среднее | 20 |
| 4. GET STACKED DIAGNOSTICS | Среднее | 15 |
| 5. Безопасный импорт | Среднее | 20 |
| 6. Комплексная функция KPI | Сложное | 20 |
| **Итого** | | **100** |

**Шкала оценок:**
- 85-100 баллов — «Отлично»
- 70-84 баллов — «Хорошо»
- 55-69 баллов — «Удовлетворительно»
- < 55 баллов — «Требуется доработка»
