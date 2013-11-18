if exists('g:loaded_wandbox')
    finish
endif

command! -range=% -nargs=* WandBox call wandbox#compile_and_dump(<q-args>, [<line1>, <line2>])
command! -range=% -nargs=* WandBoxOptionList call wandbox#dump_option_list()

let g:loaded_wandbox = 1
