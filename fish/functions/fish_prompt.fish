# Senko prompt: одна строка — папка, git-ветка, стрелка (краснеет после ошибки)
function fish_prompt
    set -l last $status
    set_color dcb6f2
    echo -n (prompt_pwd)
    set -l branch (command git branch --show-current 2>/dev/null)
    if test -n "$branch"
        set_color 8a7a96; echo -n ' on '
        set_color f4b3d3; echo -n " $branch"
        if test -n "$(command git status --porcelain 2>/dev/null | head -1)"
            set_color ffd3b0; echo -n ' ●'
        end
    end
    if test $last -eq 0
        set_color f4b3d3
    else
        set_color f28fad
    end
    echo -n ' ❯ '
    set_color normal
end
