# справа: время выполнения долгой команды и часы
function fish_right_prompt
    if test -n "$CMD_DURATION"; and test $CMD_DURATION -gt 2000
        set_color ffd3b0
        echo -n (math -s1 $CMD_DURATION / 1000)"s "
    end
    set_color 8a7a96
    echo -n (date +%H:%M)
    set_color normal
end
