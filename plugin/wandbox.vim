if exists('g:loaded_wandbox')
    finish
endif

command! -range=0 -nargs=* -complete=customlist,wandbox#complete_command Wandbox call wandbox#run_sync_or_async(<count>, <q-args>, [<line1>, <line2>])
command! -range=0 -nargs=* -complete=customlist,wandbox#complete_command WandboxAsync call wandbox#run_async(<count>, <q-args>, [<line1>, <line2>])
command! -range=0 -nargs=* -complete=customlist,wandbox#complete_command WandboxSync call wandbox#run(<count>, <q-args>, [<line1>, <line2>])
command! -nargs=0 WandboxOptionList call wandbox#show_option_list()
command! -nargs=0 WandboxOptionListAsync call wandbox#show_option_list_async()
command! -nargs=0 WandboxAbortAsyncWorks call wandbox#abort_async_works()
command! -nargs=0 WandboxOpenBrowser call wandbox#open_browser()

let g:loaded_wandbox = 1
