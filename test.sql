--TEST 1
SELECT state,event,transaction_event(state,event) 
FROM (VALUES 
		('start','create'),
		('insert_card_state','insert'),
		('pin_waiting','cancel'),
		('password_verification','correct')
	) 
AS examples(state,event);

--TEST 2
SELECT transaction_event_fsm(event ORDER BY id)
FROM (VALUES
		(1, 'create'),
		(2, 'insert'),
		(3, 'cancel')
) examples2(id, event);

--TEST 3
INSERT INTO atm_events (transaction_id, event) VALUES
	(1,'create'),
	(2,'insert'),
	(3,'cancel');

--TEST 4
INSERT INTO atm_events (transaction_id,event) VALUES
	(2,'create'),
	(2,'correct');

--TEST 5
SELECT id, transaction_id, event FROM atm_events;