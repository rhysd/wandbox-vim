let s:save_cpo = &cpo
set cpo&vim

" initialize augroup
augroup wandbox-polling-quickrun-response
augroup END

let s:runner = { 'config' : {
             \     'compiler' : '',
             \     'options' : '',
             \   }
             \ }

function! s:runner.run(commands, input, session)
    
endfunction

function! s:polling_quickrun_result(session_key)
    
endfunction

function! quickrun#runner#vimproc#new()
  return deepcopy(s:runner)
endfunction

let &cpo = s:save_cpo
unlet s:save_cpo
