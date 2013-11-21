if exists('g:loaded_wandbox')
    finish
endif

command! -range=0 -nargs=* Wandbox call wandbox#run(<count>, <q-args>, [<line1>, <line2>])
command! -nargs=0 WandboxOptionList call wandbox#bark()

let g:loaded_wandbox = 1
