def login_rate(rows):
    """Share of users who logged in during the window."""
    if not rows:
        return None
    total = len(rows)
    logged = sum(1 for r in rows if r["last_login"])
    return logged / total
