let s:save_cpo = &cpo
set cpo&vim

function! wandbox#quickrun#add_wandbox_type(quickrun_config)
    echoerr "wandbox#quickrun#add_wandbox_type() is deprecated. Use wandbox#quickrun#add_type_with_hook() or wandbox#quickrun#add_type_with_runner()."
    call wandbox#quickrun#add_type_with_hook(a:quickrun_config)
endfunction

function! wandbox#quickrun#add_type_with_hook(quickrun_config)
    let a:quickrun_config['wandbox'] = {
            \ 'command' : 'vim',
            \ 'runner' : 'vimproc',
            \ 'hook/wandbox/enable' : 1,
            \ }
endfunction

function! wandbox#quickrun#add_type_with_runner(quickrun_config)
    let a:quickrun_config['wandbox'] = {
            \ 'runner' : 'wandbox',
            \ }
endfunction

let &cpo = s:save_cpo
unlet s:save_cpo
