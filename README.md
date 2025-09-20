# Midnight Event Alerts (Flask)

A minimal Flask service that accepts user action events at **POST `/event`** and returns alert codes based on rules.

## Payload
    {
      "type": "deposit",   // "deposit" | "withdraw"
      "amount": "42.00",   // decimal string, >= 0
      "user_id": 1,        // integer user identifier
      "t": 10              // event time in seconds (monotonic, strictly increasing)
    }

## Response
    {
      "alert": true,
      "alert_codes": [30, 123],
      "user_id": 1
    }

## Alert rules
- **1100** — withdraw amount > 100  
- **30** — 3 consecutive withdraws  
- **300** — 3 consecutive **increasing** deposits (ignoring withdraws)  
- **123** — sum of deposits over a sliding window of 30 seconds > 200

If `alert_codes` is empty, `alert` must be `false`; otherwise `true`. Always include `user_id` in the response.

## Run locally (Windows)

    setup_win.cmd

This script will (1) create/activate a virtualenv, (2) install dependencies from `requirements.txt`, and (3) start the app on `http://127.0.0.1:5000`.

Alternatively (manual):

    python -m venv .venv
    call .venv\Scripts\activate.bat
    pip install -r requirements.txt
    python app.py

## cURL examples

### Windows CMD
    curl -X POST http://127.0.0.1:5000/event -H "Content-Type: application/json" -d "{\"type\":\"deposit\",\"amount\":\"42.00\",\"user_id\":1,\"t\":0}"

### Unix/macOS (bash/zsh)
    curl -X POST http://127.0.0.1:5000/event -H 'Content-Type: application/json' -d '{"type":"deposit","amount":"42.00","user_id":1,"t":0}'

## Notes
- The service keeps per-user state in memory (`MemoryUserStateRepository`), so data resets on process restart.
- Event time `t` must be strictly increasing and unique per payload, as required by the rules engine.
