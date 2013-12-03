let s:save_cpo = &cpo
set cpo&vim

function! wandbox#quickrun#add_wandbox_type(quickrun_config)
    let a:quickrun_config['wandbox'] = {
            \ 'command' : 'vim',
            \ 'runner' : 'vimproc',
            \ 'hook/wandbox/enable' : 1,
            \ }
endfunction

let &cpo = s:save_cpo
unlet s:save_cpo
