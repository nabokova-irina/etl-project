import psycopg2
import csv
import logging
from datetime import datetime

# --- Настройка логирования ---
logging.basicConfig(

    level=logging.INFO,
    #Минимальный уровень сообщений которые будут записываться.
    #INFO означает — писать все информационные сообщения и
    #выше (INFO, WARNING, ERROR)

    format="%(asctime)s [%(levelname)s] %(message)s",
    # Формат каждой строки лога
    # %(asctime)s — дата и время
    # %(levelname)s — уровень (INFO, ERROR)
    # %(message)s — само сообщение

    handlers=[ #Указывает куда писать логи
        logging.FileHandler("export.log", encoding="utf-8"),#пишет в файл export.log на диске
        logging.StreamHandler() #также пишет в консоль
    ]
)

logger = logging.getLogger(__name__)#Создаёт или получает логгер
# __name__ = "export_to_csv"

# --- Параметры подключения к БД ---
DB_CONFIG = {
    "host": "localhost",
    "port": 5432,
    "dbname": "project",
    "user": "ds",
    "password": "pass"
}

# --- Параметры выгрузки ---
TABLE_NAME = "dm.dm_account_turnover_f" #dm_f101_round_f

OUTPUT_FILE = f"dm_account_turnover_f_{datetime.now().strftime('%Y%m%d_%H%M%S')}.csv"
#Переменная — в ней хранится имя выходного файла
#f-строка — позволяет вставлять переменные и выражения прямо внутрь
#строки через {}

def export_to_csv():
    logger.info(f"start upload from table {TABLE_NAME}")

    try:
        conn = psycopg2.connect(**DB_CONFIG)
        #Подключается к PostgreSQL используя параметры из DB_CONFIG

        cursor = conn.cursor()
        #Создаёт курсор — это объект через который отправляются
        #SQL-запросы и получаются результаты

        logger.info("connet to db is ok")
        #Записывает в лог что подключение прошло успешно.

        query = f"SELECT * FROM {TABLE_NAME};"
        #Формирует строку SQL-запроса. Подставляет название таблицы из переменной

        logger.info(f"query is trying: {query}")

        cursor.execute(query)
        #Отправляет SQL-запрос в БД и выполняет его

        columns = [desc[0] for desc in cursor.description]
        #После выполнения запроса cursor.description содержит информацию
        #о колонках. Этот код проходит по каждой колонке и берёт только
        #её имя (desc[0]).

        logger.info(f"found columns: {len(columns)} -> {columns}")

        rows = cursor.fetchall()
        #Забирает все строки результата запроса из БД и сохраняет
        #в переменную rows.

        logger.info(f"take strok: {len(rows)}")
        #Логирует количество полученных строк.
        #len(rows) — считает сколько строк в списке.

        #Открываем файл для записи.
        with open(OUTPUT_FILE, mode="w", newline="", encoding="utf-8") as f:
        # OUTPUT_FILE — имя файла которое сформировали ранее
        # mode="w" — режим записи (write)
        # newline="" — чтобы не было лишних пустых строк в CSV
        # encoding="utf-8" — кодировка, чтобы корректно сохранялись русские буквы
        #  f — даём файлу псевдоним f

            writer = csv.writer(f, delimiter=";")
            #Создаёт объект для записи CSV

            writer.writerow(columns)
            #Записывает первую строку — названия колонок

            writer.writerows(rows)
            #Записывает все остальные строки — данные из таблицы:

        logger.info(f"date success writing: {OUTPUT_FILE}")

    except psycopg2.Error as e:
        logger.error(f"error work db: {e}")
        raise

    except Exception as e:
        logger.error(f"unknown error: {e}")
        raise

    finally:
    #Блок кода который выполняется всегда — независимо от того,
    #прошёл скрипт успешно или возникла ошибка.

        if cursor:
            cursor.close()#Закрывает курсор если он был создан — освобождает ресурсы
        if conn:
            conn.close()#Закрывает соединение с БД.
        logger.info("connect to db is close")


if __name__ == "__main__":
    export_to_csv()