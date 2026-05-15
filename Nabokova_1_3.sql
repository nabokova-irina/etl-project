CREATE TABLE IF NOT EXISTS dm.dm_f101_round_f (
                                                  from_date         DATE,
                                                  to_date           DATE,
                                                  chapter           CHAR(1),
                                                  ledger_account    CHAR(5),
                                                  characteristic    CHAR(1),
                                                  balance_in_rub    NUMERIC(23, 8),
                                                  balance_in_val    NUMERIC(23, 8),
                                                  balance_in_total  NUMERIC(23, 8),
                                                  turn_deb_rub      NUMERIC(23, 8),
                                                  turn_deb_val      NUMERIC(23, 8),
                                                  turn_deb_total    NUMERIC(23, 8),
                                                  turn_cre_rub      NUMERIC(23, 8),
                                                  turn_cre_val      NUMERIC(23, 8),
                                                  turn_cre_total    NUMERIC(23, 8),
                                                  balance_out_rub   NUMERIC(23, 8),
                                                  balance_out_val   NUMERIC(23, 8),
                                                  balance_out_total NUMERIC(23, 8)
);

create or replace procedure dm.fill_f101_round_f(i_OnDate DATE)
    LANGUAGE plpgsql
AS $$
DECLARE
    v_from_date  DATE;
    v_to_date    DATE;
    v_log_id     INTEGER;
    v_rows       INTEGER;

BEGIN

    -- Определяем отчётный период
    v_from_date := DATE_TRUNC('month', i_OnDate - INTERVAL '1 month')::DATE;
    v_to_date   := (i_OnDate - INTERVAL '1 day')::DATE;

    -- Логирование старта
    INSERT INTO logs.etl_log (job_name, status, start_time)
    VALUES ('fill_f101_round_f', 'STARTED', NOW())
    RETURNING log_id INTO v_log_id;

    -- Удаляем записи за дату расчёта
    DELETE FROM dm.dm_f101_round_f
    WHERE from_date = v_from_date;

    -- Заполняем витрину
    INSERT INTO dm.dm_f101_round_f (
        from_date,
        to_date,
        chapter,
        ledger_account,
        characteristic,
        balance_in_rub,
        balance_in_val,
        balance_in_total,
        turn_deb_rub,
        turn_deb_val,
        turn_deb_total,
        turn_cre_rub,
        turn_cre_val,
        turn_cre_total,
        balance_out_rub,
        balance_out_val,
        balance_out_total
    )

    SELECT
        v_from_date                              AS from_date,
        v_to_date                                AS to_date,
        la."CHAPTER"                             AS chapter,
        SUBSTRING(a."ACCOUNT_NUMBER", 1, 5)      AS ledger_account,
        a."CHAR_TYPE"                            AS characteristic,

        -- BALANCE_IN: остатки на 31 декабря 2017
        SUM(CASE
                WHEN a."CURRENCY_CODE" IN ('810', '643')
                    THEN b_in.balance_out_rub ELSE 0
            END)                                     AS balance_in_rub,

        SUM(CASE
                WHEN a."CURRENCY_CODE" NOT IN ('810', '643')
                    THEN b_in.balance_out_rub ELSE 0
            END)                                     AS balance_in_val,

        SUM(b_in.balance_out_rub)                AS balance_in_total,

        -- TURN_DEB: дебетовые обороты за январь 2018
        SUM(CASE
                WHEN a."CURRENCY_CODE" IN ('810', '643')
                    THEN t.debet_amount_rub ELSE 0
            END)                                     AS turn_deb_rub,

        SUM(CASE
                WHEN a."CURRENCY_CODE" NOT IN ('810', '643')
                    THEN t.debet_amount_rub ELSE 0
            END)                                     AS turn_deb_val,

        SUM(t.debet_amount_rub)                  AS turn_deb_total,

        -- TURN_CRE: кредитовые обороты за январь 2018
        SUM(CASE
                WHEN a."CURRENCY_CODE" IN ('810', '643')
                    THEN t.credit_amount_rub ELSE 0
            END)                                     AS turn_cre_rub,

        SUM(CASE
                WHEN a."CURRENCY_CODE" NOT IN ('810', '643')
                    THEN t.credit_amount_rub ELSE 0
            END)                                     AS turn_cre_val,

        SUM(t.credit_amount_rub)                 AS turn_cre_total,

        -- BALANCE_OUT: остатки на 31 января 2018
        SUM(CASE
                WHEN a."CURRENCY_CODE" IN ('810', '643')
                    THEN b_out.balance_out_rub ELSE 0
            END)                                     AS balance_out_rub,

        SUM(CASE
                WHEN a."CURRENCY_CODE" NOT IN ('810', '643')
                    THEN b_out.balance_out_rub ELSE 0
            END)                                     AS balance_out_val,

        SUM(b_out.balance_out_rub)               AS balance_out_total

    FROM ds."MD_ACCOUNT_D" a

             JOIN ds."MD_LEDGER_ACCOUNT_S" la
                  ON la."LEDGER_ACCOUNT" = SUBSTRING(a."ACCOUNT_NUMBER", 1, 5)::integer  -- ВОТ ЭТА СТРОКА
                      AND la."START_DATE" <= v_to_date
                      AND la."END_DATE"   >= v_from_date

             LEFT JOIN dm.dm_account_balance_f b_in
                       ON b_in.account_rk = a."ACCOUNT_RK"
                           AND b_in.on_date = (v_from_date - INTERVAL '1 day')::DATE

             LEFT JOIN dm.dm_account_turnover_f t
                       ON t.account_rk = a."ACCOUNT_RK"
                           AND t.on_date BETWEEN v_from_date AND v_to_date

             LEFT JOIN dm.dm_account_balance_f b_out
                       ON b_out.account_rk = a."ACCOUNT_RK"
                           AND b_out.on_date = v_to_date

    WHERE a."DATA_ACTUAL_DATE"     <= v_to_date
      AND a."DATA_ACTUAL_END_DATE" >= v_from_date

    GROUP BY
        la."CHAPTER",
        SUBSTRING(a."ACCOUNT_NUMBER", 1, 5),
        a."CHAR_TYPE";

    -- Считаем количество вставленных строк
    GET DIAGNOSTICS v_rows = ROW_COUNT;

    -- Логирование успешного окончания
    UPDATE logs.etl_log
    SET status      = 'FINISHED',
        end_time    = NOW(),
        rows_loaded = v_rows
    WHERE log_id = v_log_id;

END;
$$;


--  за январь 2018
CALL dm.fill_f101_round_f('2018-02-01'::DATE);


SELECT column_name, data_type
FROM information_schema.columns
WHERE table_schema = 'dm'
  AND table_name = 'dm_account_balance_f';

SELECT column_name, data_type
FROM information_schema.columns
WHERE table_schema = 'dm'
  AND table_name = 'dm_f101_round_f';

SELECT column_name, data_type
FROM information_schema.columns
WHERE table_schema = 'dm'
  AND table_name = 'dm_account_turnover_f';

SELECT column_name, data_type
FROM information_schema.columns
WHERE table_schema = 'ds'
  AND table_name = 'MD_LEDGER_ACCOUNT_S';

SELECT column_name, data_type
FROM information_schema.columns
WHERE table_schema = 'ds'
  AND table_name = 'MD_ACCOUNT_D';

SELECT column_name
FROM information_schema.columns
WHERE table_schema = 'ds'
  AND table_name = 'MD_ACCOUNT_D';

SELECT column_name
FROM information_schema.columns
WHERE table_schema = 'ds'
  AND table_name = 'MD_LEDGER_ACCOUNT_S';

-- Посмотреть все таблицы во всех схемах
SELECT table_schema, table_name
FROM information_schema.tables
WHERE table_name ILIKE '%account%'
ORDER BY table_schema, table_name;