CREATE TABLE atm_events (
id serial PRIMARY KEY,
transaction_id int NOT NULL,
event text NOT NULL,
event_time timestamp DEFAULT now() NOT NULL
);