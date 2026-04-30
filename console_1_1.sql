create database project;

-- В своей БД создать пользователя / схему «DS».
CREATE USER ds WITH PASSWORD 'pass';
CREATE SCHEMA DS AUTHORIZATION ds;

-- Для хранения логов нужно в БД создать отдельного пользователя / схему «LOGS»
CREATE USER logs WITH PASSWORD 'pass';
CREATE SCHEMA LOGS AUTHORIZATION logs;

-- Таблица логов
CREATE TABLE LOGS.ETL_LOG (
              log_id       SERIAL PRIMARY KEY,
              job_name     VARCHAR(100),
              status       VARCHAR(20),   -- STARTED / SUCCESS / ERROR
              start_time   TIMESTAMP,
              end_time     TIMESTAMP,
              rows_loaded  INT,
              error_msg    TEXT
);


GRANT USAGE ON SCHEMA LOGS TO ds;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA LOGS TO ds;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA LOGS TO ds;

ALTER DEFAULT PRIVILEGES IN SCHEMA LOGS
    GRANT ALL ON TABLES TO ds;

-- Права на схему DS
GRANT USAGE ON SCHEMA DS TO ds;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA DS TO ds;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA DS TO ds;

-- Права на будущие таблицы
ALTER DEFAULT PRIVILEGES IN SCHEMA DS
    GRANT ALL ON TABLES TO ds;


SELECT column_name
FROM information_schema.columns
WHERE table_schema = 'ds'
  AND table_name = 'FT_BALANCE_F';




CREATE TABLE DS."FT_BALANCE_F" (
       "ON_DATE"      DATE    NOT NULL,
       "ACCOUNT_RK"   NUMERIC NOT NULL,
       "CURRENCY_RK"  NUMERIC,
       "BALANCE_OUT"  FLOAT,
       CONSTRAINT pk_ft_balance_f PRIMARY KEY ("ON_DATE", "ACCOUNT_RK")
);


CREATE TABLE DS."FT_POSTING_F" (
       "OPER_DATE"          DATE    NOT NULL,
       "CREDIT_ACCOUNT_RK"  NUMERIC NOT NULL,
       "DEBET_ACCOUNT_RK"   NUMERIC NOT NULL,
       "CREDIT_AMOUNT"      FLOAT,
       "DEBET_AMOUNT"       FLOAT
);

CREATE TABLE DS."FT_POSTING_F" (
         "OPER_DATE"          DATE    NOT NULL,
         "CREDIT_ACCOUNT_RK"  NUMERIC NOT NULL,
         "DEBET_ACCOUNT_RK"   NUMERIC NOT NULL,
         "CREDIT_AMOUNT"      FLOAT,
         "DEBET_AMOUNT"       FLOAT
);



CREATE TABLE DS."MD_ACCOUNT_D" (
       "DATA_ACTUAL_DATE"     DATE        NOT NULL,
       "DATA_ACTUAL_END_DATE" DATE        NOT NULL,
       "ACCOUNT_RK"           NUMERIC     NOT NULL,
       "ACCOUNT_NUMBER"       VARCHAR(20) NOT NULL,
       "CHAR_TYPE"            VARCHAR(1)  NOT NULL,
       "CURRENCY_RK"          NUMERIC     NOT NULL,
       "CURRENCY_CODE"        VARCHAR(3)  NOT NULL,
       CONSTRAINT pk_md_account_d PRIMARY KEY ("DATA_ACTUAL_DATE", "ACCOUNT_RK")
);


CREATE TABLE DS."MD_CURRENCY_D" (
        "CURRENCY_RK"          NUMERIC    NOT NULL,
        "DATA_ACTUAL_DATE"     DATE       NOT NULL,
        "DATA_ACTUAL_END_DATE" DATE,
        "CURRENCY_CODE"        VARCHAR(3),
        "CODE_ISO_CHAR"        VARCHAR(3),
        CONSTRAINT pk_md_currency_d PRIMARY KEY ("CURRENCY_RK", "DATA_ACTUAL_DATE")
);

CREATE TABLE DS."MD_EXCHANGE_RATE_D" (
         "DATA_ACTUAL_DATE"     DATE    NOT NULL,
         "DATA_ACTUAL_END_DATE" DATE,
         "CURRENCY_RK"          NUMERIC NOT NULL,
         "REDUCED_COURCE"       FLOAT,
         "CODE_ISO_NUM"         VARCHAR(3),
         CONSTRAINT pk_md_exchange_rate_d PRIMARY KEY ("DATA_ACTUAL_DATE", "CURRENCY_RK")
);

CREATE TABLE DS."MD_LEDGER_ACCOUNT_S" (
          "CHAPTER"               VARCHAR(10),
          "CHAPTER_NAME"          VARCHAR(100),
          "SECTION_NUMBER"        INTEGER,
          "SECTION_NAME"          VARCHAR(100),
          "SUBSECTION_NAME"       VARCHAR(100),
          "LEDGER1_ACCOUNT"       INTEGER,
          "LEDGER1_ACCOUNT_NAME"  VARCHAR(200),
          "LEDGER_ACCOUNT"        INTEGER NOT NULL,
          "LEDGER_ACCOUNT_NAME"   VARCHAR(500),
          "CHARACTERISTIC"        VARCHAR(10),
          "START_DATE"            DATE NOT NULL,
          "END_DATE"              DATE,
          PRIMARY KEY ("LEDGER_ACCOUNT", "START_DATE")
);

SELECT COUNT(*) FROM DS."FT_BALANCE_F";
SELECT COUNT(*) FROM DS."FT_POSTING_F";
SELECT COUNT(*) FROM DS."MD_ACCOUNT_D";
SELECT COUNT(*) FROM DS."MD_CURRENCY_D";
SELECT COUNT(*) FROM DS."MD_EXCHANGE_RATE_D";
SELECT COUNT(*) FROM DS."MD_LEDGER_ACCOUNT_S";

DELETE FROM LOGS.ETL_LOG;
DELETE FROM DS."FT_BALANCE_F";
DELETE FROM DS."FT_POSTING_F";
DELETE FROM DS."MD_ACCOUNT_D";
DELETE FROM DS."MD_CURRENCY_D";
DELETE FROM DS."MD_EXCHANGE_RATE_D";
DELETE FROM DS."MD_LEDGER_ACCOUNT_S";


SHOW client_encoding;
SHOW server_encoding;
TRUNCATE TABLE DS."MD_LEDGER_ACCOUNT_S";