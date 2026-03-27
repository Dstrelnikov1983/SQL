# Практическая работа — Модуль 18

## Применение транзакций

**Продолжительность:** 60 минут
**Инструменты:** Yandex Managed Service for PostgreSQL (два окна/сессии SQL)
**Предприятие:** «Руда+» — добыча железной руды
**Файл с примерами:** `examples.sql`

---

## Предварительные требования

1. База данных «Руда+» развёрнута на PostgreSQL
2. **Два подключения** к БД (две вкладки в DBeaver / два окна pgAdmin / два терминала psql)
3. Файл `examples.sql` открыт для справки

> **Важно:** Для демонстрации уровней изоляции и блокировок потребуется работа в двух одновременных сессиях. Обозначим их как **Сессия A** и **Сессия B**.

---

## Часть 1. BEGIN / COMMIT / ROLLBACK (10 мин)

### Шаг 1.1. Успешная транзакция

**Сессия A:**

```sql
-- Начинаем транзакцию
BEGIN;

-- Вставляем данные о добыче
INSERT INTO fact_production (
    production_id, date_id, shift_id, equipment_id,
    mine_id, operator_id, tons_mined, trips_count, operating_hours
)
VALUES (800001, 20250301, 1, 1, 1, 1, 120.5, 10, 7.5);

-- Проверяем — запись видна в НАШЕЙ транзакции
SELECT * FROM fact_production WHERE production_id = 800001;
```

**Сессия B (НЕ закрывая Сессию A):**

```sql
-- Видна ли запись 800001 в другой сессии?
SELECT * FROM fact_production WHERE production_id = 800001;
-- Результат: 0 строк (запись ещё не зафиксирована!)
```

**Сессия A:**

```sql
-- Фиксируем транзакцию
COMMIT;
```

**Сессия B:**

```sql
-- Теперь проверяем снова
SELECT * FROM fact_production WHERE production_id = 800001;
-- Результат: 1 строка (запись зафиксирована и видна всем)
```

**Что наблюдаем:** До COMMIT данные видны только в текущей транзакции.

### Шаг 1.2. Откат транзакции

**Сессия A:**

```sql
BEGIN;

INSERT INTO fact_production (
    production_id, date_id, shift_id, equipment_id,
    mine_id, operator_id, tons_mined, trips_count, operating_hours
)
VALUES (800002, 20250301, 2, 2, 1, 2, 300.0, 20, 8.0);

-- Обнаружили ошибку: 300 тонн за смену — невозможно
-- Откатываем
ROLLBACK;

-- Проверяем — записи нет
SELECT * FROM fact_production WHERE production_id = 800002;
-- Результат: 0 строк
```

### Шаг 1.3. Ошибка внутри транзакции

```sql
BEGIN;

INSERT INTO fact_production (
    production_id, date_id, shift_id, equipment_id,
    mine_id, operator_id, tons_mined, trips_count, operating_hours
)
VALUES (800003, 20250301, 1, 1, 1, 1, 100.0, 8, 7.0);

-- Ошибка: equipment_id = 99999 не существует
INSERT INTO fact_production (
    production_id, date_id, shift_id, equipment_id,
    mine_id, operator_id, tons_mined, trips_count, operating_hours
)
VALUES (800004, 20250301, 1, 99999, 1, 1, 50.0, 4, 3.0);
-- ОШИБКА: foreign key violation

-- Попробуем что-то выполнить
SELECT 1;
-- ОШИБКА: current transaction is aborted

-- Единственный вариант — ROLLBACK
ROLLBACK;
```

> **Обсуждение:** Что произошло с записью 800003? Она тоже откатилась! В PostgreSQL ошибка «портит» всю транзакцию.

---

## Часть 2. SAVEPOINT (10 мин)

### Шаг 2.1. Частичный откат

```sql
BEGIN;

-- Шаг 1: вставляем данные о добыче (критичные)
INSERT INTO fact_production (
    production_id, date_id, shift_id, equipment_id,
    mine_id, operator_id, tons_mined, trips_count, operating_hours
)
VALUES (800010, 20250302, 1, 1, 1, 1, 110.0, 9, 7.0);

-- Точка сохранения перед опциональными данными
SAVEPOINT sp_quality;

-- Шаг 2: пытаемся вставить данные о качестве
-- (может не получиться, если нет замера)
INSERT INTO fact_ore_quality (
    quality_id, date_id, shift_id, mine_id,
    sample_number, fe_content, moisture_percent
)
VALUES (900001, 20250302, 1, 1, 'ORE-2025-0001', 55.5, 3.2);

-- Допустим, второй замер с ошибкой
SAVEPOINT sp_quality_2;

-- Ошибка: дубликат quality_id
INSERT INTO fact_ore_quality (
    quality_id, date_id, shift_id, mine_id,
    sample_number, fe_content, moisture_percent
)
VALUES (900001, 20250302, 1, 1, 'ORE-2025-0002', 52.0, 3.8);
-- ОШИБКА: unique_violation
```

```sql
-- Откатываем только второй замер
ROLLBACK TO sp_quality_2;

-- Проверяем — первый замер сохранён
SELECT * FROM fact_ore_quality WHERE quality_id = 900001;

-- Фиксируем всё
COMMIT;

-- Проверяем итог
SELECT * FROM fact_production WHERE production_id = 800010;
SELECT * FROM fact_ore_quality WHERE quality_id = 900001;
```

**Что наблюдаем:** SAVEPOINT позволил откатить только ошибочную часть, сохранив остальные данные.

---

## Часть 3. Уровни изоляции (20 мин)

### Шаг 3.1. READ COMMITTED — non-repeatable read

**Сессия A:**

```sql
BEGIN;
-- По умолчанию READ COMMITTED
SELECT SUM(tons_mined) AS total
FROM fact_production WHERE date_id = 20250115 AND mine_id = 1;
-- Запомните результат: ______ т
```

**Сессия B:**

```sql
-- Вставляем новую запись
INSERT INTO fact_production (
    production_id, date_id, shift_id, equipment_id,
    mine_id, operator_id, tons_mined, trips_count, operating_hours
)
VALUES (800020, 20250115, 3, 1, 1, 1, 50.0, 4, 3.0);
-- Без BEGIN — автоматический COMMIT
```

**Сессия A:**

```sql
-- Повторяем тот же запрос
SELECT SUM(tons_mined) AS total
FROM fact_production WHERE date_id = 20250115 AND mine_id = 1;
-- Результат ИЗМЕНИЛСЯ! Это non-repeatable read.
COMMIT;
```

### Шаг 3.2. REPEATABLE READ — стабильный снимок

**Сессия A:**

```sql
BEGIN;
SET TRANSACTION ISOLATION LEVEL REPEATABLE READ;

SELECT SUM(tons_mined) AS total
FROM fact_production WHERE date_id = 20250115 AND mine_id = 1;
-- Запомните результат: ______ т
```

**Сессия B:**

```sql
INSERT INTO fact_production (
    production_id, date_id, shift_id, equipment_id,
    mine_id, operator_id, tons_mined, trips_count, operating_hours
)
VALUES (800021, 20250115, 3, 2, 1, 2, 75.0, 6, 5.0);
```

**Сессия A:**

```sql
-- Повторяем тот же запрос
SELECT SUM(tons_mined) AS total
FROM fact_production WHERE date_id = 20250115 AND mine_id = 1;
-- Результат НЕ ИЗМЕНИЛСЯ! Repeatable read гарантирует стабильность.
COMMIT;
```

### Шаг 3.3. REPEATABLE READ — ошибка сериализации

**Сессия A:**

```sql
BEGIN;
SET TRANSACTION ISOLATION LEVEL REPEATABLE READ;
SELECT tons_mined FROM fact_production
WHERE production_id = 800020;
```

**Сессия B:**

```sql
-- Обновляем ту же запись
UPDATE fact_production SET tons_mined = 999
WHERE production_id = 800020;
```

**Сессия A:**

```sql
-- Пытаемся обновить ту же запись
UPDATE fact_production SET tons_mined = 888
WHERE production_id = 800020;
-- ОШИБКА: could not serialize access due to concurrent update
ROLLBACK;
```

> **Обсуждение:** Что делать при ошибке сериализации? (Ответ: повторить транзакцию.)

### Шаг 3.4. Сравнение уровней изоляции

Заполните таблицу по результатам экспериментов:

| Аномалия | READ COMMITTED | REPEATABLE READ | SERIALIZABLE |
|----------|:-:|:-:|:-:|
| Dirty Read | Нет | Нет | Нет |
| Non-Repeatable Read | ? | ? | ? |
| Phantom Read | ? | ? | ? |
| Serialization Anomaly | ? | ? | ? |

---

## Часть 4. Блокировки и Deadlock (10 мин)

### Шаг 4.1. Наблюдение за блокировками

**Сессия A:**

```sql
BEGIN;
UPDATE fact_production SET tons_mined = tons_mined + 1
WHERE production_id = 800001;
-- Транзакция НЕ закрыта — блокировка удерживается
```

**Сессия B:**

```sql
-- Просмотр блокировок
SELECT
    l.locktype,
    l.relation::regclass AS table_name,
    l.mode,
    l.granted,
    a.pid,
    LEFT(a.query, 60) AS query
FROM pg_locks l
JOIN pg_stat_activity a ON l.pid = a.pid
WHERE l.relation IS NOT NULL
  AND a.state != 'idle'
ORDER BY l.relation;
```

```sql
-- Попытка обновить ту же запись
UPDATE fact_production SET tons_mined = tons_mined + 2
WHERE production_id = 800001;
-- Сессия B ЗАБЛОКИРОВАНА! Ожидает освобождения блокировки.
```

**Сессия A:**

```sql
COMMIT;
-- Сессия B немедленно разблокируется и выполнит UPDATE
```

### Шаг 4.2. Создание Deadlock

**Подготовка:**

```sql
CREATE TABLE IF NOT EXISTS test_deadlock (
    id     INT PRIMARY KEY,
    amount NUMERIC DEFAULT 0
);
INSERT INTO test_deadlock VALUES (1, 1000), (2, 2000) ON CONFLICT DO NOTHING;
```

**Сессия A:**

```sql
BEGIN;
UPDATE test_deadlock SET amount = amount - 100 WHERE id = 1;
-- Блокировка строки id=1
```

**Сессия B:**

```sql
BEGIN;
UPDATE test_deadlock SET amount = amount - 200 WHERE id = 2;
-- Блокировка строки id=2
```

**Сессия A:**

```sql
-- Пытаемся обновить id=2 (заблокирована Сессией B)
UPDATE test_deadlock SET amount = amount + 100 WHERE id = 2;
-- ОЖИДАНИЕ...
```

**Сессия B:**

```sql
-- Пытаемся обновить id=1 (заблокирована Сессией A)
UPDATE test_deadlock SET amount = amount + 200 WHERE id = 1;
-- DEADLOCK DETECTED! PostgreSQL отменит одну из транзакций
```

```sql
-- Откатываем оставшуюся транзакцию
ROLLBACK;
```

**Сессия A:**

```sql
-- Если наша транзакция выжила — фиксируем
COMMIT;
-- Если нет — откатываем
-- ROLLBACK;
```

> **Обсуждение:** Как предотвратить deadlock? (Единый порядок блокировки ресурсов.)

---

## Часть 5. Advisory Locks (10 мин)

### Шаг 5.1. Защита от дублирования ETL

**Сессия A:**

```sql
DO $$
DECLARE
    v_lock_id BIGINT := 20250301;  -- ID = дата
    v_acquired BOOLEAN;
BEGIN
    v_acquired := pg_try_advisory_lock(v_lock_id);

    IF v_acquired THEN
        RAISE NOTICE 'ETL запущен для даты %', v_lock_id;
        -- Имитация длительного ETL
        PERFORM pg_sleep(10);
        PERFORM pg_advisory_unlock(v_lock_id);
        RAISE NOTICE 'ETL завершён';
    ELSE
        RAISE NOTICE 'ETL уже выполняется!';
    END IF;
END;
$$;
```

**Сессия B (пока Сессия A «работает»):**

```sql
DO $$
DECLARE
    v_acquired BOOLEAN;
BEGIN
    v_acquired := pg_try_advisory_lock(20250301);

    IF v_acquired THEN
        RAISE NOTICE 'Блокировка захвачена';
        PERFORM pg_advisory_unlock(20250301);
    ELSE
        RAISE NOTICE 'ETL уже выполняется другим процессом!';
    END IF;
END;
$$;
```

**Что наблюдаем:** Вторая сессия не может захватить блокировку, пока первая её удерживает. Это предотвращает параллельный запуск одного и того же ETL.

---

## Очистка тестовых данных

```sql
DELETE FROM fact_production WHERE production_id BETWEEN 800001 AND 900000;
DELETE FROM fact_ore_quality WHERE quality_id = 900001;
DROP TABLE IF EXISTS test_deadlock;
```

---

## Итоги практической работы

В ходе работы мы:

1. Освоили **BEGIN / COMMIT / ROLLBACK** — управление транзакциями
2. Применили **SAVEPOINT** для частичного отката
3. Сравнили **уровни изоляции** (READ COMMITTED, REPEATABLE READ) на практике
4. Наблюдали **блокировки** и воспроизвели **deadlock**
5. Использовали **Advisory Locks** для защиты от дублирования процессов

> **Для продвинутых:** Попробуйте уровень SERIALIZABLE — выполните два конкурентных UPDATE и наблюдайте за ошибкой сериализации.
