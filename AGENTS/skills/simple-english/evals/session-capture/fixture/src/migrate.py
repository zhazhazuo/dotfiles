STATEMENTS = [
    "ALTER TABLE users ADD COLUMN last_login timestamptz",
]


def up(conn):
    for s in STATEMENTS:
        conn.execute(s)


def down(conn):
    raise NotImplementedError("no downgrade")
