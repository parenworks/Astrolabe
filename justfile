# Astrolabe — Terminal-native personal operations console
# Build and run recipes using just (https://github.com/casey/just)

# Paths to local dependencies (adjust if needed)
charmed_path := env("CHARMED_PATH", "/home/glenn/SourceCode/charmed/")
mcclim_charmed_path := env("MCCLIM_CHARMED_PATH", "/home/glenn/SourceCode/charmed-mcclim/Backends/charmed/")
astrolabe_path := env("ASTROLABE_PATH", "/home/glenn/SourceCode/Astrolabe/")

sbcl := "sbcl"
target := "astrolabe"

# Default recipe
default: run

# Run from source (development mode)
run:
    {{sbcl}} --noinform \
        --eval '(push #P"{{charmed_path}}" asdf:*central-registry*)' \
        --eval '(asdf:load-system :charmed :force nil)' \
        --eval '(ql:quickload :mcclim :silent t)' \
        --eval '(push #P"{{mcclim_charmed_path}}" asdf:*central-registry*)' \
        --eval '(asdf:load-system :mcclim-charmed :force nil)' \
        --eval '(push #P"{{astrolabe_path}}" asdf:*central-registry*)' \
        --eval '(asdf:load-system :astrolabe)' \
        --eval '(astrolabe:run)' \
        --eval '(sb-ext:exit)'

# Build standalone executable
build:
    {{sbcl}} --noinform --non-interactive \
        --eval '(push #P"{{charmed_path}}" asdf:*central-registry*)' \
        --eval '(asdf:load-system :charmed :force nil)' \
        --eval '(ql:quickload :mcclim :silent t)' \
        --eval '(push #P"{{mcclim_charmed_path}}" asdf:*central-registry*)' \
        --eval '(asdf:load-system :mcclim-charmed :force nil)' \
        --eval '(push #P"{{astrolabe_path}}" asdf:*central-registry*)' \
        --eval '(asdf:load-system :astrolabe)' \
        --eval '(sb-ext:save-lisp-and-die "{{target}}" :toplevel #'"'"'astrolabe:run :executable t :compression t)'

# Check that code compiles without running
check:
    {{sbcl}} --noinform --non-interactive \
        --eval '(push #P"{{charmed_path}}" asdf:*central-registry*)' \
        --eval '(asdf:load-system :charmed :force nil)' \
        --eval '(ql:quickload :mcclim :silent t)' \
        --eval '(push #P"{{mcclim_charmed_path}}" asdf:*central-registry*)' \
        --eval '(asdf:load-system :mcclim-charmed :force nil)' \
        --eval '(push #P"{{astrolabe_path}}" asdf:*central-registry*)' \
        --eval '(asdf:load-system :astrolabe)' \
        --eval '(format t "~&Astrolabe compiled successfully.~%")' \
        --eval '(sb-ext:exit)'

# Start REPL with Astrolabe loaded
repl:
    {{sbcl}} --noinform \
        --eval '(push #P"{{charmed_path}}" asdf:*central-registry*)' \
        --eval '(asdf:load-system :charmed :force nil)' \
        --eval '(ql:quickload :mcclim :silent t)' \
        --eval '(push #P"{{mcclim_charmed_path}}" asdf:*central-registry*)' \
        --eval '(asdf:load-system :mcclim-charmed :force nil)' \
        --eval '(push #P"{{astrolabe_path}}" asdf:*central-registry*)' \
        --eval '(asdf:load-system :astrolabe)' \
        --eval '(in-package :astrolabe)'

# Force recompile (clear ASDF cache first)
rebuild:
    find ~/.cache/common-lisp/ -path "*astrolabe*" -delete 2>/dev/null; true
    just build

# Clean build artifacts
clean:
    rm -f {{target}}
    find ~/.cache/common-lisp/ -path "*astrolabe*" -delete 2>/dev/null; true

# Reset database (WARNING: destroys all data)
reset-db:
    rm -f ~/.astrolabe/astrolabe.db
    @echo "Database removed. Will be recreated on next run."

# Show help
help:
    @echo "Astrolabe — Terminal-native personal operations console"
    @echo ""
    @echo "Recipes:"
    @echo "  just run       - Run from source (default)"
    @echo "  just build     - Build standalone executable"
    @echo "  just rebuild   - Force recompile from clean"
    @echo "  just check     - Check compilation without running"
    @echo "  just repl      - Start REPL with Astrolabe loaded"
    @echo "  just clean     - Remove build artifacts"
    @echo "  just reset-db  - Delete database (WARNING: data loss)"
    @echo "  just help      - Show this help"
    @echo ""
    @echo "Environment variables:"
    @echo "  CHARMED_PATH         - Path to charmed library (default: ~/SourceCode/charmed/)"
    @echo "  MCCLIM_CHARMED_PATH  - Path to charmed-mcclim backend (default: ~/SourceCode/charmed-mcclim/Backends/charmed/)"
