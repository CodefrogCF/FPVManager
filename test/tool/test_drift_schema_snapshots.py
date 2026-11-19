"""Verify exported Drift SQL and entity snapshots agree on their columns."""
import json
import sqlite3
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


class DriftSchemaSnapshotTest(unittest.TestCase):
    def test_exported_schema_entities_match_create_statements(self):
        for path in sorted((ROOT / 'drift_schemas').glob('drift_schema_v*.json')):
            with self.subTest(schema=path.name):
                snapshot = json.loads(path.read_text(encoding='utf-8'))
                db = sqlite3.connect(':memory:')
                try:
                    for entry in snapshot['fixed_sql']:
                        for statement in entry['sql']:
                            if statement['dialect'] == 'sqlite':
                                db.execute(statement['sql'])
                    for entity in snapshot['entities']:
                        if entity['type'] != 'table':
                            continue
                        name = entity['data']['name']
                        expected = {column['name'] for column in entity['data']['columns']}
                        safe_name = '"' + name.replace('"', '""') + '"'
                        actual = {row[1] for row in db.execute(f'PRAGMA table_info({safe_name})')}
                        self.assertEqual(actual, expected, f'{path.name}: {name}')
                finally:
                    db.close()


if __name__ == '__main__':
    unittest.main()
