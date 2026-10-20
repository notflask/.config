if status is-interactive
    # Commands to run in interactive sessions can go here
end

function fish_greeting
    fastfetch
end

alias fetch "fetch --rotate-y"

# opencode
fish_add_path /home/flask/.opencode/bin
