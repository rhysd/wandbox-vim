if exists('g:loaded_wandbox')
    finish
endif

command! -range=% -nargs=* Wandbox call wandbox#compile_and_dump(<q-args>, [<line1>, <line2>])
command! -nargs=0 WandboxOptionList call wandbox#dump_option_list()

let g:loaded_wandbox = 1
