DROP PROCEDURE IF EXISTS sp_execute_gig_funding(BIGINT, BIGINT, NUMERIC);

CREATE OR REPLACE PROCEDURE sp_execute_gig_funding(
    p_client_id BIGINT,
    p_freelancer_id BIGINT,
    p_budget NUMERIC(12,2)
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_balance NUMERIC(12,2);
BEGIN
    IF p_budget IS NULL OR p_budget <= 0 THEN
        RAISE EXCEPTION 'Budget must be greater than zero';
    END IF;

    -- Serialize concurrent funding requests for the same client.
    SELECT escrow_balance
      INTO v_balance
      FROM clients
     WHERE id = p_client_id
     FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Client % does not exist', p_client_id;
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM freelancers
        WHERE id = p_freelancer_id
    ) THEN
        RAISE EXCEPTION 'Freelancer % does not exist', p_freelancer_id;
    END IF;

    IF v_balance < p_budget THEN
        RAISE EXCEPTION
            'Insufficient escrow balance: balance=%, requested=%',
            v_balance, p_budget;
    END IF;

    UPDATE clients
       SET escrow_balance = escrow_balance - p_budget
     WHERE id = p_client_id;

    INSERT INTO contracts (
        client_id,
        freelancer_id,
        budget,
        status
    )
    VALUES (
        p_client_id,
        p_freelancer_id,
        p_budget,
        'FUNDED'
    );

    -- PostgreSQL procedures may issue transaction control when invoked
    -- as a top-level CALL. If any statement above fails, PostgreSQL aborts
    -- the transaction and no partial state is committed.
    COMMIT;
END;
$$;

-- Example:
-- CALL sp_execute_gig_funding(1, 1, 250.00);
