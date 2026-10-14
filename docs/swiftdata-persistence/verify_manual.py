"""Compare the synthetic input and read-only disk evidence from actual app relaunches."""
import json
from pathlib import Path
from uuid import UUID

folder = Path(__file__).parent
for name in ['active', 'closed']:
    before = json.loads((folder / f'{name}-before.json').read_text())
    after = json.loads((folder / f'{name}-after.json').read_text())
    fixture = json.loads((folder / f'{name}-fixture.json').read_text())
    assert before == after and len(after) == 3
    assert sum(row['ZISCURRENT'] for row in after) == 1
    for row, period in zip(after, fixture['history'] + [fixture['current']]):
        assert UUID(row['ZID']) == UUID(period['id'])
        assert row['ZDATE'] == period['date']
        assert row['ZSTART'] == period['start']
        assert row['ZEND'] == period.get('end')
        assert row['ZCALENDARZONE'] == period['calendarZone']
        assert row['ZDRIVINGMINUTES'] == period['drivingMinutes']
        assert bool(row['ZISCLOSED']) == period['isClosed']
        rests = json.loads(bytes.fromhex(row['ZRESTDATA']))
        assert len(rests) == len(period['rests'])
        for actual, expected in zip(rests, period['rests']):
            assert UUID(actual['id']) == UUID(expected['id'])
            assert actual['start'] == expected['start']
            assert actual.get('end') == expected.get('end')
    print(f'{name}: PASS — same IDs/timestamps/state/driving/rests; 3 records, no duplicates')
