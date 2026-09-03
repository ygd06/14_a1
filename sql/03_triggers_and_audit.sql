CREATE OR REPLACE FUNCTION fn_audit_client_escrow()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN

    IF NEW.escrow_balance <> OLD.escrow_balance THEN

        INSERT INTO wallet_audit_logs
        (client_id, amount_changed, action_type, balance_after)
        VALUES
        (
            NEW.id,
            ABS(NEW.escrow_balance - OLD.escrow_balance),
            CASE
                WHEN NEW.escrow_balance < OLD.escrow_balance
                THEN 'DEBIT'
                ELSE 'CREDIT'
            END,
            NEW.escrow_balance
        );

    END IF;

    RETURN NEW;
END;
$$;


DROP TRIGGER IF EXISTS trg_client_escrow_audit ON clients;

CREATE TRIGGER trg_client_escrow_audit
AFTER UPDATE OF escrow_balance ON clients
FOR EACH ROW
EXECUTE FUNCTION fn_audit_client_escrow();