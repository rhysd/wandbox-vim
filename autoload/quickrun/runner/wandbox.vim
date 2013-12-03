let s:save_cpo = &cpo
set cpo&vim

let s:V = vital#of('wandbox-vim')
let s:List = s:V.import('Data.List')

let s:runner = { 'config' : {
             \     'compiler' : '',
             \     'options' : '',
             \   }
             \ }

function! s:runner.run(commands, input, session)
    call wandbox#touch()
    let code = substitute(join(readfile(a:session.config.srcfile), "\n"), '\\', '\\\\', 'g')
    if self.config.compiler ==# ''
        let compilers = split(get(g:wandbox#default_compiler, &filetype, g:wandbox#default_compiler['-']), ',')
    else
        let compilers = split(self.config.compiler, ',')
    endif

    if self.config.options ==# ''
        let options = split(get(g:wandbox#default_options, &filetype, g:wandbox#default_options['-']), ':', 1)
    else
        let options = split(self.config.options, ':', 1)
    endif
    if len(options) == 1
        let options = repeat([options[0]], len(compilers))
    endif

    call add(g:wandbox#_async_works, {})

    for [compiler, option] in s:List.zip(compilers, options)
        call wandbox#compile_async(code, compiler, option)
    endfor

endfunction

function! s:polling_quickrun_result(session_key)
    
endfunction

function! quickrun#runner#wandbox#new()
  return deepcopy(s:runner)
endfunction

let &cpo = s:save_cpo
unlet s:save_cpo
