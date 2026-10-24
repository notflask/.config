# PATH: -g statt universal, damit fish_variables nichts Rechnerspezifisches speichert
test -x /opt/homebrew/bin/brew; and /opt/homebrew/bin/brew shellenv fish | source
fish_add_path -g ~/.cargo/bin ~/.local/bin

if status is-interactive
    # Commands to run in interactive sessions can go here
end

function fish_greeting
    fastfetch
end

alias fetch "fetch --rotate-y"

# opencode
fish_add_path /home/flask/.opencode/bin
