import psycopg2
import csv
import logging
import glob
import os

# --- Настройка логирования ---
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
    handlers=[
        logging.FileHandler("import.log", encoding="utf-8"),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger(__name__)

# --- Параметры подключения к БД ---
DB_CONFIG = {
    "host": "localhost",
    "port": 5432,
    "dbname": "project",
    "user": "ds",
    "password": "pass"
}

# --- Параметры импорта ---
TARGET_TABLE = "dm.dm_account_turnover_f_v2" #"dm.dm_f101_round_f_v2"

# Автоматически берём последний выгруженный CSV файл
csv_files = glob.glob("dm_account_turnover_f_*.csv")
#поиск файлов в текущей папке по шаблону

if not csv_files:
    logger.error("CSV файл не найден!")
    exit(1)
    # если CSV файл не найден — нет смысла продолжать,
    #скрипт останавливается с кодом ошибки 1

INPUT_FILE = max(csv_files, key=os.path.getctime)
#Из всех найденных файлов берёт самый последний по дате создания
#это параметр для функции max(), который говорит по какому
#критерию искать максимум

logger.info(f"Будет импортирован файл: {INPUT_FILE}")


def import_from_csv():
    logger.info(f"Начало импорта из файла {INPUT_FILE} в таблицу {TARGET_TABLE}")

    #инициализация переменных пустым значением в самом начале
    conn = None
    cursor = None

    try:
        # Подключение к БД
        conn = psycopg2.connect(**DB_CONFIG)
        cursor = conn.cursor()
        logger.info("Подключение к БД установлено")

        # Читаем CSV файл
        with open(INPUT_FILE, mode="r", encoding="utf-8") as f:
            reader = csv.reader(f, delimiter=";")
            columns = next(reader)  # первая строка — названия колонок
            rows = list(reader)     # остальные строки — данные

        logger.info(f"Прочитано колонок: {len(columns)} → {columns}")
        logger.info(f"Прочитано строк: {len(rows)}")

        # Очищаем таблицу перед загрузкой
        cursor.execute(f"TRUNCATE TABLE {TARGET_TABLE};")
        logger.info(f"Таблица {TARGET_TABLE} очищена")

        # Формируем INSERT запрос
        placeholders = ", ".join(["%s"] * len(columns))
        #Создаёт список из %s — столько штук сколько колонок
        # + Склеивает список в строку через ,
        col_names = ", ".join(columns)
        insert_query = f"INSERT INTO {TARGET_TABLE} ({col_names}) VALUES ({placeholders});"

        # Вставляем строки
        cursor.executemany(insert_query, rows)
        #Выполняет INSERT запрос для каждой строки из rows.

        conn.commit()#Подтверждает все изменения в БД

        logger.info(f"Успешно загружено строк: {len(rows)}")
        logger.info(f"Импорт в таблицу {TARGET_TABLE} завершён")

    except psycopg2.Error as e:
        logger.error(f"Ошибка при работе с БД: {e}")
        if conn:
            conn.rollback()
            logger.info("Транзакция отменена (rollback)")
        raise

    except Exception as e:
        logger.error(f"Непредвиденная ошибка: {e}")
        raise

    finally:
        if cursor:
            cursor.close()
        if conn:
            conn.close()
        logger.info("Соединение с БД закрыто")


if __name__ == "__main__":
    import_from_csv()