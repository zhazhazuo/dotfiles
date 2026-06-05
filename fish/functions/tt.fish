function tt --wraps "task list"
    if test (count $argv) -gt 0
        task list due.before:today+$argv[1]d $argv[2..-1]
    else
        task list due.before:tomorrow
    end
end
