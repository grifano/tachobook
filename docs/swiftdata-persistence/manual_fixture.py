"""Synthetic legacy fixture and read-only disk snapshot for isolated simulator review."""
import argparse
import datetime
import json
import pathlib
import sqlite3
import uuid

parser = argparse.ArgumentParser()
parser.add_argument('action', choices=['seed-active', 'seed-closed', 'snapshot'])
parser.add_argument('sandbox', type=pathlib.Path)
parser.add_argument('output', type=pathlib.Path)
args = parser.parse_args()
folder = args.sandbox / 'Library/Application Support/TachoBook'
store = folder / 'shifts-v1.store'
legacy = folder / 'shift-journal-v1.json'
if args.action.startswith('seed-'):
    # Only use on a newly created, explicitly isolated simulator, never a user store.
    if legacy.exists() or store.exists():
        raise SystemExit('Refusing to replace any existing journal/store')
    now = datetime.datetime.now(datetime.timezone.utc).timestamp() - 978307200
    start = now - 6 * 3600
    closed = args.action == 'seed-closed'
    current = dict(id=str(uuid.uuid4()), calendarZone='Europe/Warsaw', date=start,
                   start=start, drivingMinutes=570, isClosed=closed, rests=[])
    if closed:
        current['end'] = now - 3600
        current['rests'] = [dict(id=str(uuid.uuid4()), start=now - 3600)]
    history = [dict(id=str(uuid.uuid4()), calendarZone='Europe/Warsaw',
                    date=start - day * 86400, start=start - day * 86400,
                    end=start - day * 86400 + 3600, drivingMinutes=90 + day,
                    isClosed=True, rests=[]) for day in [2, 1]]
    folder.mkdir(parents=True, exist_ok=True)
    legacy.write_text(json.dumps(dict(current=current, history=history)))
    args.output.write_bytes(legacy.read_bytes())
    print('Created synthetic legacy fixture; current duty ID:', current['id'])
else:
    with sqlite3.connect(store.as_uri() + '?mode=ro', uri=True) as connection:
        connection.row_factory = sqlite3.Row
        rows = connection.execute('SELECT ZID, ZCALENDARZONE, ZDATE, ZSTART, ZEND, '
                                  'ZDRIVINGMINUTES, ZISCLOSED, ZISCURRENT, ZARCHIVEORDER, '
                                  'ZRESTDATA FROM ZPERIOD ORDER BY ZARCHIVEORDER').fetchall()
        values = [{key: (row[key].hex() if isinstance(row[key], bytes) else row[key])
                   for key in row.keys()} for row in rows]
    args.output.write_text(json.dumps(values, indent=2))
    print(json.dumps(values, indent=2))
