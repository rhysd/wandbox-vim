let s:save_cpo = &cpo
set cpo&vim

let [s:V, s:_, s:_, s:JSON, s:List, s:Prelude] = wandbox#_export_vital_modules() | unlet s:_

" vim-quickrun runner definition {{{
let s:runner = { 'config' : {
             \     'compiler' : '',
             \     'options' : '',
             \     'runtime_options' : '',
             \     'stdin' : '',
             \     'updatetime' : g:wandbox#updatetime,
             \     'enable_output_every_polling' : 0,
             \   }
             \ }

augroup wandbox-quickrun-polling
augroup END

function! s:runner.run(commands, input, session)
    if ! wandbox#is_available(&filetype)
        throw "No setting for Wandbox is found in the filetype: ".&filetype
    endif

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
        let options = repeat(options, len(compilers))
    endif

    let a:session._work = {}
    if self.config.updatetime > 0
        let self._updatetime = &updatetime
        let &updatetime = self.config.updatetime
    endif

    for [compiler, option] in s:List.zip(compilers, options)
        call wandbox#compile_async(code, compiler, option, self.config.runtime_options, self.config.stdin, a:session._work)
    endfor

    let key = a:session.continue()
    augroup wandbox-quickrun-polling
        execute 'autocmd! CursorHold,CursorHoldI * call s:polling_response('.string(key).')'
    augroup END
endfunction

function! s:runner.sweep()
    autocmd! wandbox-quickrun-polling
    if has_key(self, '_updatetime')
        let &updatetime = self._updatetime
    endif
endfunction

function! quickrun#runner#wandbox#new()
  return deepcopy(s:runner)
endfunction
" }}}

" Polling response {{{
function! s:is_blank(dict, key)
    if ! has_key(a:dict, a:key)
        return 1
    endif
    return empty(a:dict[a:key])
endfunction

function! s:format_process_result(content, file)
    return printf("%s\n%s"
         \, s:is_blank(a:content, 'compiler_message') ? '' : printf(" * [compiler]\n\n%s", substitute(a:content.compiler_message, 'prog\.cc', wandbox#_escape_backslash(a:file), 'g'))
         \, s:is_blank(a:content, 'program_message') ? '' : printf(" * [output]\n\n%s", a:content.program_message))
endfunction

function! s:abort(session, msg)
    call a:session.output(a:msg)
    call a:session.finish(1)
endfunction

function! s:polling_response(key)
    let session = quickrun#session(a:key)
    if ! wandbox#_shinchoku_doudesuka(session._work)
        if session.runner.config.enable_output_every_polling
            call session.output('')
        endif
        call feedkeys(mode() =~# '[iR]' ? "\<C-g>\<ESC>" : "g\<ESC>", 'n')
        return
    endif

    let result = ''
    let exit_status = 0
    for [compiler, request] in items(filter(copy(session._work), 's:Prelude.is_dict(v:val) && has_key(v:val, "_exit_status")'))
        let response = request.callback(request.files)
        if ! response.success
            call s:abort(session, 'Request has failed while executing '.compiler.'!: Status '. response.status . ': ' . response.statusText)
        endif
        let json_response = s:JSON.decode(response.content)
        let result .= '## ' . compiler . "\n" . s:format_process_result(json_response, session.config.srcfile) . "\n"
        let exit_status = exit_status || (json_response.status != 0)
    endfor

    call session.output(result)
    call session.finish(exit_status)
endfunction
"}}}

let &cpo = s:save_cpo
unlet s:save_cpo
