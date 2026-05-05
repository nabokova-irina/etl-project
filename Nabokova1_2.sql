create or replace procedure ds.fill_account_turnover_f(i_ondate DATE)
    LANGUAGE plpgsql
AS $$
BEGIN
    -- Логирование старта
    INSERT INTO logs.etl_log (job_name, status, start_time)
    VALUES ('fill_account_turnover_f', 'STARTED_TURNOVER', NOW());

    -- Удаляем записи за дату расчёта (для перезапуска)
    DELETE FROM dm.dm_account_turnover_f
    WHERE on_date = i_OnDate;

    -- Заполняем витрину оборотов
    INSERT INTO dm.dm_account_turnover_f (
        on_date,
        account_rk,
        credit_amount,
        credit_amount_rub,
        debet_amount,
        debet_amount_rub
    )
    SELECT
        i_ondate AS on_date,
        t.account_rk,
        SUM(t."CREDIT_AMOUNT")                              AS credit_amount,
        SUM(t."CREDIT_AMOUNT" * COALESCE(er."REDUCED_COURCE", 1)) AS credit_amount_rub,
        SUM(t."DEBET_AMOUNT")                               AS debet_amount,
        SUM(t."DEBET_AMOUNT" * COALESCE(er."REDUCED_COURCE", 1))  AS debet_amount_rub
    FROM (
             SELECT
                 "CREDIT_ACCOUNT_RK" AS account_rk,
                 "CREDIT_AMOUNT",
                 "DEBET_AMOUNT"
             FROM ds."FT_POSTING_F"
             WHERE "OPER_DATE" = i_ondate

             UNION ALL

             SELECT
                 "DEBET_ACCOUNT_RK" AS account_rk,
                 "CREDIT_AMOUNT",
                 "DEBET_AMOUNT"
             FROM ds."FT_POSTING_F"
             WHERE "OPER_DATE"  = i_ondate
         ) t
             LEFT JOIN ds."MD_ACCOUNT_D" a
                       ON a."ACCOUNT_RK" = t.account_rk
                           AND a."DATA_ACTUAL_DATE" <= i_ondate
                           AND a."DATA_ACTUAL_END_DATE" >= i_ondate
             LEFT JOIN ds."MD_EXCHANGE_RATE_D" er
                       ON er."CURRENCY_RK" = a."CURRENCY_RK"
                           AND er."DATA_ACTUAL_DATE" <= i_ondate
                           AND (er."DATA_ACTUAL_END_DATE" >= i_ondate
                               OR er."DATA_ACTUAL_END_DATE" IS NULL)
    GROUP BY t.account_rk;

-- Логирование завершения
    UPDATE logs.etl_log
    SET status = 'SUCCESS',
        end_time = NOW()
    WHERE job_name = 'fill_account_turnover_f'
      AND status = 'STARTED_TURNOVER';



END;
$$;

CALL ds.fill_account_turnover_f('2018-01-01');

--за январь
DO $$
    DECLARE
        v_date DATE := '2018-01-01';
    BEGIN
        WHILE v_date <= '2018-01-31' LOOP
                CALL ds.fill_account_turnover_f(v_date);
               -- CALL ds.fill_account_balance_f(v_date);
                v_date := v_date + INTERVAL '1 day';
            END LOOP;
    END;
$$;


CREATE OR REPLACE PROCEDURE ds.fill_account_balance_f(i_OnDate DATE)
    LANGUAGE plpgsql
AS $$
DECLARE
    v_start_time TIMESTAMP;
BEGIN
    v_start_time := NOW();

    -- Логирование старта
    INSERT INTO logs.etl_log (job_name, status, start_time)
    VALUES ('fill_account_balance_f_' || i_OnDate::TEXT, 'STARTED_account_balance', v_start_time);

    -- Удаляем записи за дату расчёта
    DELETE FROM dm.dm_account_balance_f
    WHERE on_date = i_OnDate;

    -- Заполняем витрину остатков
    INSERT INTO dm.dm_account_balance_f (
        on_date,
        account_rk,
        balance_out,
        balance_out_rub
    )

    SELECT
        i_OnDate AS on_date,
        a."ACCOUNT_RK" AS account_rk,
        --для активных счетов (DS.MD_ACCOUNT_D.char_type = ‘А’):
        -- берем остаток в валюте счета за предыдущий день (если его нет,
        -- то считаем его равным 0), прибавляем к нему обороты по дебету
        -- в валюте счета (DM.DM_ACCOUNT_TURNOVER_F.debet_amount) и
        -- вычитаем обороты по кредиту в валюте счета
        -- (DM.DM_ACCOUNT_TURNOVER_F.credit_amount) за этот день.
        CASE
            WHEN a."CHAR_TYPE" = 'А' THEN
                COALESCE(b.balance_out, 0)
                    + COALESCE(t.debet_amount, 0)
                    - COALESCE(t.credit_amount, 0)
            WHEN a."CHAR_TYPE" = 'П' THEN
                COALESCE(b.balance_out, 0)
                    - COALESCE(t.debet_amount, 0)
                    + COALESCE(t.credit_amount, 0)
            END AS balance_out,
        CASE
            WHEN a."CHAR_TYPE" = 'А' THEN
                COALESCE(b.balance_out_rub, 0)
                    + COALESCE(t.debet_amount_rub, 0)
                    - COALESCE(t.credit_amount_rub, 0)
            WHEN a."CHAR_TYPE" = 'П' THEN
                COALESCE(b.balance_out_rub, 0)
                    - COALESCE(t.debet_amount_rub, 0)
                    + COALESCE(t.credit_amount_rub, 0)
            END AS balance_out_rub
    FROM ds."MD_ACCOUNT_D" a
             -- Остатки за предыдущий день
             LEFT JOIN dm.dm_account_balance_f b
                       ON b.account_rk = a."ACCOUNT_RK"
                           AND b.on_date = i_OnDate - INTERVAL '1 day'
        -- Обороты за текущий день
             LEFT JOIN dm.dm_account_turnover_f t
                       ON t.account_rk = a."ACCOUNT_RK"
                           AND t.on_date = i_OnDate
    WHERE a."DATA_ACTUAL_DATE" <= i_OnDate
      AND a."DATA_ACTUAL_END_DATE" >= i_OnDate;

    -- Логирование завершения
    UPDATE logs.etl_log
    SET status = 'SUCCESS', end_time = NOW()
    WHERE job_name = 'fill_account_balance_f_' || i_OnDate::TEXT
      AND status = 'STARTED_account_balance';

END;
$$;

INSERT INTO dm.dm_account_balance_f (
    on_date, account_rk, balance_out, balance_out_rub
)
SELECT
    -- Поля on_date, account_rk, balance_out заполняются один в один,
    -- поле balance_out_rub заполняем как balance_out, умноженный на курс
    -- действующий за 31.12.2017
    '2017-12-31'::DATE AS on_date,
    b."ACCOUNT_RK" AS account_rk,
    b."BALANCE_OUT" AS balance_out,
    b."BALANCE_OUT" * COALESCE(er."REDUCED_COURCE", 1) AS balance_out_rub
FROM ds."FT_BALANCE_F" b
         LEFT JOIN ds."MD_EXCHANGE_RATE_D" er
                   ON er."DATA_ACTUAL_DATE" <= '2017-12-31'
                       AND er."DATA_ACTUAL_END_DATE" >= '2017-12-31'
                       AND er."CURRENCY_RK" = (
                           SELECT a."CURRENCY_RK"
                           FROM ds."MD_ACCOUNT_D" a
                           WHERE a."ACCOUNT_RK" = b."ACCOUNT_RK"
                             AND a."DATA_ACTUAL_DATE" <= '2017-12-31'
                             AND a."DATA_ACTUAL_END_DATE" >= '2017-12-31'
                           LIMIT 1
                       );