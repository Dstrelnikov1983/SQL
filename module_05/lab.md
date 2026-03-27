# Лабораторная работа — Модуль 5

## Использование DML для изменения данных

**Продолжительность:** 60 минут
**Формат:** самостоятельная работа
**Инструменты:** PostgreSQL (Yandex Managed Service for PostgreSQL)
**База данных:** «Руда+» (MES-система горнодобывающего предприятия)

---

## Общие указания

- Все задания выполняются на **practice_** таблицах (созданных скриптом `scripts/create_practice_tables.sql`).
- Перед каждым заданием **проверяйте текущее состояние данных** с помощью SELECT.
- Сохраняйте все запросы в файл `lab_solutions.sql`.
- Используйте транзакции (BEGIN / ROLLBACK) для безопасного тестирования.
- Задания расположены по возрастанию сложности.

---

## Задание 1. Добавление нового оборудования (INSERT — одна строка)

**Бизнес-задача:** На шахту «Южная» (mine_id = 2) поступил новый шахтный самосвал.

**Требования:**
- Таблица: `practice_dim_equipment`
- Данные:
  - equipment_id: 200
  - equipment_type_id: 2 (шахтный самосвал)
  - mine_id: 2
  - equipment_name: 'Самосвал МоАЗ-7529'
  - inventory_number: 'INV-TRK-200'
  - manufacturer: 'МоАЗ'
  - model: '7529'
  - year_manufactured: 2025
  - commissioning_date: '2025-03-15'
  - status: 'active'
  - has_video_recorder: TRUE
  - has_navigation: TRUE

**Проверка:** выполните SELECT и убедитесь, что запись создана.

---

## Задание 2. Массовая вставка операторов (INSERT — несколько строк)

**Бизнес-задача:** На предприятие приняты 3 новых оператора.

**Требования:**
- Таблица: `practice_dim_operator`
- Добавить одним INSERT:

| operator_id | tab_number | last_name | first_name | middle_name | position | qualification | hire_date | mine_id |
|---|---|---|---|---|---|---|---|---|
| 200 | TAB-200 | Сидоров | Михаил | Иванович | Машинист ПДМ | 4 разряд | 2025-03-01 | 1 |
| 201 | TAB-201 | Петрова | Елена | Сергеевна | Оператор скипа | 3 разряд | 2025-03-01 | 2 |
| 202 | TAB-202 | Волков | Дмитрий | Алексеевич | Водитель самосвала | 5 разряд | 2025-03-10 | 2 |

**Проверка:** должно быть 3 новых строки с operator_id >= 200.

---

## Задание 3. Загрузка из staging (INSERT ... SELECT)

**Бизнес-задача:** В staging_production находятся записи о добыче. Нужно перенести **только валидированные** записи (is_validated = TRUE) в `practice_fact_production`, исключив дубликаты.

**Требования:**
- Источник: `staging_production` (WHERE is_validated = TRUE)
- Назначение: `practice_fact_production`
- production_id: используйте формулу `3000 + staging_id`
- Условие исключения дубликатов: NOT EXISTS по комбинации (date_id, shift_id, equipment_id, operator_id)

**Проверка:** подсчитайте количество строк до и после INSERT.

**Ожидаемый результат:** 4 новых записи (1 запись с is_validated = FALSE пропущена).

---

## Задание 4. INSERT ... RETURNING с логированием

**Бизнес-задача:** Добавить новый тип сорта руды и записать факт добавления в лог.

**Требования:**
1. Вставить в `practice_dim_ore_grade`:
   - ore_grade_id: 300
   - grade_name: 'Экспортный'
   - grade_code: 'EXPORT'
   - fe_content_min: 63.00
   - fe_content_max: 68.00
   - description: 'Руда для экспортных поставок'
2. Использовать RETURNING для получения ore_grade_id и grade_name
3. На основе полученных данных вставить запись в `practice_equipment_log`:
   - equipment_id: 0 (справочные данные)
   - action: 'INSERT'
   - details: 'Добавлен сорт руды: Экспортный (EXPORT)'

**Подсказка:** Используйте CTE (WITH ... AS) для объединения INSERT ... RETURNING и второго INSERT.

---

## Задание 5. Обновление статуса оборудования (UPDATE)

**Бизнес-задача:** По итогам ежемесячного осмотра необходимо обновить статусы оборудования.

**Требования:**
1. Перевести в статус 'maintenance' все единицы оборудования шахты «Северная» (mine_id = 1), у которых year_manufactured <= 2018
2. Использовать UPDATE ... RETURNING для получения списка затронутых единиц

**Проверка:** Выведите equipment_id, equipment_name, year_manufactured для всех единиц со статусом 'maintenance'.

---

## Задание 6. UPDATE с подзапросом

**Бизнес-задача:** Установить флаг `has_navigation = TRUE` для всего оборудования, которое имеет хотя бы один активный датчик навигации (sensor_type_id, соответствующий типу 'NAV').

**Требования:**
- Таблица: `practice_dim_equipment`
- Подзапрос: выбрать equipment_id из dim_sensor, у которых sensor_type_id соответствует навигационному типу датчика
- Обновить только те записи, где has_navigation = FALSE

**Подсказка:** Используйте JOIN с dim_sensor_type для определения типа датчика.

---

## Задание 7. DELETE с условием и архивированием

**Бизнес-задача:** Удалить все аварийные показания телеметрии (is_alarm = TRUE) за 15 марта 2024 г., но сохранить их в архиве.

**Требования:**
1. Использовать CTE с DELETE ... RETURNING
2. Вставить удалённые данные в `practice_archive_telemetry`
3. После операции проверить:
   - В `practice_fact_telemetry` нет записей с is_alarm = TRUE за 20240315
   - В `practice_archive_telemetry` появились архивные записи

**Ожидаемый результат:**
- Количество удалённых/архивированных записей зависит от текущего состояния данных
- В архивной таблице поле `archived_at` заполнено автоматически

---

## Задание 8. MERGE — синхронизация справочника (PostgreSQL 15+)

**Бизнес-задача:** Синхронизировать справочник причин простоев из staging-таблицы.

**Требования:**
- Целевая таблица: `practice_dim_downtime_reason`
- Источник: `staging_downtime_reasons`
- Ключ соединения: `reason_code`
- WHEN MATCHED: обновить reason_name, category, description
- WHEN NOT MATCHED: вставить новую запись (сгенерировать reason_id = MAX + 1)

**Проверка:**
1. Перед MERGE: посмотрите содержимое обеих таблиц
2. После MERGE: убедитесь, что:
   - Существующие записи обновлены
   - Новые записи добавлены
   - Нет дубликатов по reason_code

---

## Задание 9. UPSERT — идемпотентная загрузка (INSERT ... ON CONFLICT)

**Бизнес-задача:** Реализовать идемпотентную загрузку операторов. Скрипт должен быть безопасен для повторного запуска.

**Требования:**
1. Написать INSERT ... ON CONFLICT для таблицы `practice_dim_operator`
2. Вставить/обновить 3 записи:
   - TAB-200: если существует — обновить position и qualification
   - TAB-201: если существует — обновить position и qualification
   - TAB-NEW: новый оператор — вставить
3. Конфликт по: `tab_number`
4. При конфликте: обновить только position и qualification (DO UPDATE SET)

**Проверка:** запустите запрос дважды. Результат должен быть одинаковым.

---

## Задание 10. Комплексный ETL-процесс (транзакция)

**Бизнес-задача:** Реализовать полный цикл загрузки сменных данных в аналитическую БД.

**Требования:**

Написать транзакцию (BEGIN ... COMMIT), которая выполняет следующие шаги:

1. **INSERT:** Загрузить валидированные записи о добыче из `staging_production` в `practice_fact_production` (исключая дубликаты)

2. **UPDATE:** Обновить статусы оборудования из `staging_equipment_status` (через UPDATE ... FROM)

3. **DELETE + архивирование:** Удалить из `practice_fact_telemetry` записи с quality_flag = 'ERROR' и сохранить их в `practice_archive_telemetry` (через CTE)

4. **Логирование:** Записать в `practice_equipment_log` информацию о каждом обновлённом оборудовании (action = 'ETL_UPDATE')

5. **Очистка staging:** Выполнить TRUNCATE для staging_production и staging_equipment_status

**Проверка после выполнения:**
- В `practice_fact_production` появились новые записи
- В `practice_dim_equipment` обновлены статусы
- В `practice_archive_telemetry` сохранены удалённые записи
- В `practice_equipment_log` есть записи аудита
- staging-таблицы пустые

**Дополнительное задание (*):** Добавьте обработку ошибок: если на любом этапе количество затронутых строк равно 0, выполните ROLLBACK и выведите сообщение с помощью RAISE NOTICE (потребуется DO-блок).

---

## Критерии оценки

| Задание | Баллы | Критерии |
|---|---|---|
| 1-2 | по 5 | Корректный INSERT, данные добавлены |
| 3 | 10 | INSERT...SELECT с исключением дубликатов |
| 4 | 10 | CTE с INSERT...RETURNING + второй INSERT |
| 5-6 | по 10 | Корректный UPDATE, RETURNING, подзапрос |
| 7 | 15 | CTE с DELETE...RETURNING + архивирование |
| 8 | 15 | Корректный MERGE с двумя ветками |
| 9 | 10 | ON CONFLICT DO UPDATE, идемпотентность |
| 10 | 15 | Полный ETL в транзакции, логирование |
| **Итого** | **100** | |

---

## Полезные ссылки

- [PostgreSQL: INSERT](https://www.postgresql.org/docs/current/sql-insert.html)
- [PostgreSQL: UPDATE](https://www.postgresql.org/docs/current/sql-update.html)
- [PostgreSQL: DELETE](https://www.postgresql.org/docs/current/sql-delete.html)
- [PostgreSQL: MERGE](https://www.postgresql.org/docs/current/sql-merge.html)
- [PostgreSQL: TRUNCATE](https://www.postgresql.org/docs/current/sql-truncate.html)
