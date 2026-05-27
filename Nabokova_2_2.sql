
SELECT COUNT(*), effective_from_date
FROM rd.deal_info
GROUP BY effective_from_date
ORDER BY effective_from_date;

SELECT COUNT(*), effective_from_date
FROM rd.loan_holiday
GROUP BY effective_from_date
ORDER BY effective_from_date;


SELECT COUNT(*), effective_from_date
FROM dm.loan_holiday_info
GROUP BY effective_from_date
ORDER BY effective_from_date;

DROP TABLE IF EXISTS rd.deal_info;
DROP TABLE IF EXISTS rd.loan_holiday;
DROP TABLE IF EXISTS rd.product;
DROP TABLE dm.loan_holiday_info;

CREATE TABLE dm.loan_holiday_info (
          deal_rk                         BIGINT NOT NULL,
          effective_from_date             DATE NOT NULL,
          effective_to_date               DATE NOT NULL,
          agreement_rk                    BIGINT,
          account_rk                      BIGINT,
          client_rk                       BIGINT,
          department_rk                   BIGINT,
          product_rk                      BIGINT,
          product_name                    TEXT,
          deal_type_cd                    TEXT,
          deal_start_date                 DATE,
          deal_name                       TEXT,
          deal_number                     TEXT,
          deal_sum                        NUMERIC,
          loan_holiday_type_cd            TEXT,
          loan_holiday_start_date         DATE,
          loan_holiday_finish_date        DATE,
          loan_holiday_fact_finish_date   DATE,
          loan_holiday_finish_flg         BOOLEAN,
          loan_holiday_last_possible_date DATE
);

CREATE OR REPLACE PROCEDURE dm.load_loan_holiday_info()
    LANGUAGE plpgsql
AS $$
BEGIN
    -- Шаг 1: очистка витрины
    TRUNCATE TABLE dm.loan_holiday_info;

    -- Шаг 2: вставка данных по логике прототипа
    INSERT INTO dm.loan_holiday_info (
                                       deal_rk
                                     ,effective_from_date
                                     ,effective_to_date
                                     ,agreement_rk
                                     ,account_rk
                                     ,client_rk
                                     ,department_rk
                                     ,product_rk
                                     ,product_name
                                     ,deal_type_cd
                                     ,deal_start_date
                                     ,deal_name
                                     ,deal_number
                                     ,deal_sum
                                     ,loan_holiday_type_cd
                                     ,loan_holiday_start_date
                                     ,loan_holiday_finish_date
                                     ,loan_holiday_fact_finish_date
                                     ,loan_holiday_finish_flg
                                     ,loan_holiday_last_possible_date
    )
    WITH deal AS (
        SELECT deal_rk
             ,deal_num
             ,deal_name
             ,deal_sum
             ,client_rk
             ,account_rk
             ,agreement_rk
             ,deal_start_date
             ,department_rk
             ,product_rk
             ,deal_type_cd
             ,effective_from_date
             ,effective_to_date
        FROM rd.deal_info
    ),
         loan_holiday AS (
             SELECT deal_rk
                  ,loan_holiday_type_cd
                  ,loan_holiday_start_date
                  ,loan_holiday_finish_date
                  ,loan_holiday_fact_finish_date
                  ,loan_holiday_finish_flg
                  ,loan_holiday_last_possible_date
                  ,effective_from_date
                  ,effective_to_date
             FROM rd.loan_holiday
         ),
         product AS (
             SELECT product_rk
                  ,product_name
                  ,effective_from_date
                  ,effective_to_date
             FROM rd.product
         ),
         holiday_info AS (
             SELECT d.deal_rk
                  ,lh.effective_from_date
                  ,lh.effective_to_date
                  ,d.agreement_rk
                  ,d.account_rk
                  ,d.client_rk
                  ,d.department_rk
                  ,d.product_rk
                  ,p.product_name
                  ,d.deal_type_cd
                  ,d.deal_start_date
                  ,d.deal_name
                  ,d.deal_num AS deal_number
                  ,d.deal_sum
                  ,lh.loan_holiday_type_cd
                  ,lh.loan_holiday_start_date
                  ,lh.loan_holiday_finish_date
                  ,lh.loan_holiday_fact_finish_date
                  ,lh.loan_holiday_finish_flg
                  ,lh.loan_holiday_last_possible_date
             FROM deal d
                      LEFT JOIN loan_holiday lh ON d.deal_rk = lh.deal_rk
                 AND d.effective_from_date = lh.effective_from_date
                      LEFT JOIN product p ON p.product_rk = d.product_rk
                 AND p.effective_from_date = d.effective_from_date
         )
    SELECT * FROM holiday_info;

END;
$$;

CALL dm.load_loan_holiday_info();

