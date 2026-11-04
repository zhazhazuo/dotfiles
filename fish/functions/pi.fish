function pi --description 'Launch pi with project-scoped memory when the tree has .pi/memory'
    # pi-memory reads its storage path only from PI_MEMORY_DIR at process start.
    # This wrapper gives any tree that owns a .pi/memory directory its own store,
    # and leaves every other directory on the global ~/.pi/agent/memory.
    #
    # Two fish scoping traps are avoided on purpose: `set -l` inside a while or
    # if body is scoped to that block, so the found path is held in a
    # function-level variable and the export sits outside any block.
    set -l memory_dir
    set -l dir (pwd)
    while test -n "$dir"
        if test -d "$dir/.pi/memory"
            set memory_dir "$dir/.pi/memory"
            break
        end
        set -l up (dirname "$dir")
        # Stop at the filesystem root, where dirname returns its own argument.
        if test "$up" = "$dir"
            break
        end
        set dir $up
    end
    test -n "$memory_dir"; and set -lx PI_MEMORY_DIR $memory_dir
    # `command` skips this function, so the real binary runs.
    command pi $argv
end
