function fp --wraps lsof
    lsof -i :$argv
end
