# zoxide: z/zi springen in häufig besuchte Ordner
if status is-interactive; and type -q zoxide
    zoxide init fish | source
end
