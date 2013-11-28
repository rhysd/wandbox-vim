if exists('g:loaded_wandbox')
    finish
endif

command! -range=0 -nargs=* Wandbox call wandbox#run_sync_or_async(<count>, <q-args>, [<line1>, <line2>])
command! -range=0 -nargs=* WandboxAsync call wandbox#run_async(<count>, <q-args>, [<line1>, <line2>])
command! -range=0 -nargs=* WandboxSync call wandbox#run(<count>, <q-args>, [<line1>, <line2>])
command! -nargs=0 WandboxOptionList call wandbox#bark()

let g:loaded_wandbox = 1
