function tu --wraps "task list"
    set ids (task export status:pending estimate.any: due.any: | python3 -c "
import sys, json, datetime
now = datetime.datetime.now(datetime.timezone.utc).date()
ids = []
for t in json.load(sys.stdin):
    due_str = t.get('due')
    est_val = t.get('estimate')
    if not due_str or est_val is None:
        continue
    due = datetime.datetime.strptime(due_str, '%Y%m%dT%H%M%SZ').replace(tzinfo=datetime.timezone.utc).date()
    est = float(est_val)
    if (now + datetime.timedelta(days=est)) >= due:
        ids.append(str(t['id']))
print(','.join(ids))
")
    if test -n "$ids"
        task $ids list rc.report.list.columns='id,estimate,due,description' \
                        rc.report.list.labels='ID,Est,Due,Description'
    else
        echo "No urgent tasks found."
    end
end
