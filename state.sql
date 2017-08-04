CREATE FUNCTION transaction_event (state text, event text) RETURNS text
LANGUAGE sql as $$
	SELECT  CASE state
		WHEN 'start' THEN
			CASE event
				WHEN 'create' THEN 'insert_card_state'
				ELSE 'error'
			END
		WHEN 'insert_card_state' THEN
			case event
				WHEN 'insert' THEN 'pin_waiting'
				WHEN 'cancel' THEN 'card_withdrawal'
				ELSE 'error'
			END
		WHEN 'pin_waiting' THEN
			case event
				WHEN 'enter' THEN 'password_verification'
				WHEN 'cancel' THEN 'card_withdrawal'
				ELSE 'error'
			END
		WHEN 'password_verification' THEN
			CASE event
				WHEN 'correct' THEN 'wait_for_order'
				WHEN 'incorrect' THEN 'check_no_attempts'
				ELSE 'error'
			END
		WHEN 'check_no_attempts' THEN
			CASE event
				WHEN 'above_threshold' THEN 'seize_the_card'
				WHEN 'below_threshold' THEN 'pin_waiting'
				ELSE 'error'
			END
		WHEN 'wait_for_order' THEN
			CASE event
				WHEN 'check_balance' THEN 'show_balance'
				WHEN 'withdraw' THEN 'wait_for_amount'
				WHEN 'deposit' THEN 'wait_for_envelope'
				WHEN 'cancel' THEN 'card_withdrawal'
				ELSE 'error'
			END
		WHEN 'show_balance' THEN
			CASE event
				WHEN 'more' THEN 'wait_for_order'
				WHEN 'done' THEN 'card_withdrawal'
				ELSE 'error'
			END
		WHEN 'wait_for_amount' THEN
			CASE event
				WHEN 'enter' THEN 'check_correctness'
				WHEN 'cancel' THEN 'card_withdrawal'
				ELSE 'error'
			END
		WHEN 'check_correctness' THEN
			CASE event
				WHEN 'permitted' THEN 'pay'
				WHEN 'not_permitted' THEN 'wait_for_order'
				ELSE 'error'
			END
		WHEN 'pay' THEN
			CASE event
				WHEN 'withdraw' THEN 'more'
				ELSE 'error'
			END
		WHEN 'paid' THEN
			CASE event
				WHEN 'finish' THEN 'card_withdrawal'
				ELSE 'error'
			END
		WHEN 'wait_for_envelope' THEN
			CASE event
				WHEN 'enter' THEN 'envelope_process'
				WHEN 'cancel' THEN 'card_withdrawal'
				ELSE 'error'
			END
		WHEN 'envelope_process' THEN
			CASE event
				WHEN 'finish' THEN 'card_withdrawal'
				ELSE 'error'
			END
		WHEN 'card_withdrawal' THEN
			CASE event
				WHEN 'finish' THEN 'start'
				ELSE 'error'
			END
		ELSE 'error'
	END
$$;

-- for more information on the aggregate function see "postgresql.org/docs/current/static/xaggr.html"
CREATE AGGREGATE transaction_event_fsm(text) (
	SFUNC = transaction_event,
	STYPE = text,
	INITCOND = 'start'
);

CREATE FUNCTION transaction_events_trigger_fcn() RETURNS trigger
LANGUAGE plpgsql AS $$
DECLARE
	new_state text;
BEGIN
	SELECT transaction_event_fsm(event ORDER BY id)
	FROM (
		SELECT id, event FROM atm_events WHERE transaction_id = new.transaction_id
		UNION
		SELECT new.id,new.event		
	)s
	INTO new_state;

	IF new_state = 'error' THEN
		RAISE EXCEPTION 'invalid event';
	END IF;

	RETURN new;
END
$$;

CREATE TRIGGER transaction_events_trigger BEFORE INSERT ON atm_events
FOR EACH ROW EXECUTE PROCEDURE transaction_events_trigger_fcn();