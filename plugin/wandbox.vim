if exists('g:loaded_wandbox')
    finish
endif

command! -range=% -nargs=* WandBox call wandbox#dump(split(wandbox#compile(<q-args>, [<line1>, <line2>]), "\n"))

let g:loaded_wandbox = 1
