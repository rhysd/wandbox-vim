scriptencoding utf-8
let s:save_cpo = &cpo
set cpo&vim

" Import vital {{{
let s:V = vital#of('wandbox-vim')
let s:OptionParser = s:V.import('OptionParser')
let s:HTTP = s:V.import('Web.HTTP')
let s:JSON = s:V.import('Web.JSON')
let s:List = s:V.import('Data.List')
let s:Xor128 = s:V.import('Random.Xor128')
let s:Prelude = s:V.import('Prelude')
"}}}

" Initialize variables {{{
let g:wandbox#default_compiler = get(g:, 'wandbox#default_compiler', {})
call extend(g:wandbox#default_compiler, {
            \ '-' : 'gcc-head',
            \ 'cpp' : 'gcc-head',
            \ 'c' : 'gcc-4.8.2-c',
            \ 'cs' : 'mcs-3.2.0',
            \ 'php' : 'php-5.5.6',
            \ 'lua' : 'lua-5.2.2',
            \ 'sql' : 'sqlite-3.8.1',
            \ 'sh' : 'bash',
            \ 'erlang' : 'erlang-maint',
            \ 'ruby' : 'ruby-2.0.0-p247',
            \ 'python' : 'python-2.7.3',
            \ 'python3' : 'python-3.3.2',
            \ 'perl' : 'perl-5.19.2',
            \ 'haskell' : 'ghc-7.6.3',
            \ 'd' : 'gdc-head',
            \ }, 'keep')

if exists('g:wandbox#default_options')
    call map(g:wandbox#default_options, 's:Prelude.is_string(v:val) ? v:val : join(v:val, ",")')
else
    let g:wandbox#default_options = {}
endif

call extend(g:wandbox#default_options, {
            \ '-' : '',
            \ 'cpp' : 'warning,gnu++1y,boost-1.55',
            \ 'c' : 'warning,c11',
            \ 'haskell' : 'haskell-warning',
            \ }, 'keep')

let g:wandbox#result_indent = get(g:, 'wandbox#result_indent', 2)
let g:wandbox#echo_command = get(g:, 'wandbox#echo_command', 'echo')
let g:wandbox#disable_python_client = get(g:, 'wandbox#disable_python_client', executable('curl') || executable('wget') ? 1 : 0)
if ! exists('g:wandbox#updatetime')
    let g:wandbox#updatetime =
                  \ exists('g:quickrun_config["_"]["runner/vimproc/updatetime"]') ?
                  \ g:quickrun_config["_"]["runner/vimproc/updatetime"] :
                  \ 500
endif

let g:wandbox#_async_works = []
let s:is_asynchronously_executable = s:Prelude.has_vimproc() && (executable('curl') || executable('wget'))
"}}}

" Option definitions {{{
let s:option_parser = s:OptionParser.new()
                                   \.on('--compiler=VAL', '-c', 'Comma separated compiler commands (like "gcc-head,clang-head")')
                                   \.on('--options=VAL', '-o', 'Comma separated options (like "warning,gnu++1y"')
                                   \.on('--file=VAL', '-f', 'File name to execute')
                                   \.on('--filetype=VAL', 'Filetype with which Wandbox executes')
                                   \.on('--puff-puff', '???')
"}}}

" Initialize augroup {{{
augroup wandbox-polling-response
augroup END
"}}}

" Utility functions {{{
function! s:echo(string)
    execute g:wandbox#echo_command string(a:string)
endfunction

function! s:parse_args(args)
    let parsed = call(s:option_parser.parse, a:args, s:option_parser)
    if parsed.__unknown_args__ != []
        throw 'Unknown arguments: '.join(parsed.__unknown_args__, ', ')
    endif
    if has_key(parsed, 'help')
        return {}
    elseif has_key(parsed, 'puff-puff')
        call s:puffpuff()
        return {}
    endif
    return parsed
endfunction

function! s:is_blank(dict, key)
    if ! has_key(a:dict, a:key)
        return 1
    endif
    return empty(a:dict[a:key])
endfunction

function! s:format_process_result(content)
    return printf("%s\n%s"
         \, s:is_blank(a:content, 'compiler_message') ? '' : printf(" * [compiler]\n\n%s", a:content.compiler_message)
         \, s:is_blank(a:content, 'program_message') ? '' : printf(" * [output]\n\n%s", a:content.program_message))
endfunction

function! s:get_code(range, range_given, ...)
    if a:0 > 0
        let buf = join(a:range_given ?
                        \ readfile(a:1)[a:range[0]-1:a:range[1]-1] :
                        \ readfile(a:1), "\n")
    else
        let range = a:range_given ? a:range : [1, line('$')]
        let buf = join(getline(range[0], range[1]), "\n")."\n"
    endif
    return substitute(buf, '\\', '\\\\', 'g')
endfunction

function! s:dump_result(compiler, result)
    let indent = repeat(' ', g:wandbox#result_indent)
    echohl Constant | call s:echo('## '.a:compiler) | echohl None
    for l in split(a:result, "\n")
        if l ==# ' * [compiler]' || l ==# ' * [output]'
            echohl MoreMsg | call s:echo(l=='' ? ' ' : l) | echohl None
        else
            call s:echo(indent . (l=='' ? ' ' : l))
        endif
    endfor
    call s:echo(' ')
endfunction

function! s:filetype(parsed)
    return has_key(a:parsed, 'filetype') ? a:parsed.filetype : &filetype
endfunction

function! wandbox#_prepare_args(parsed, range_given)
    let code = has_key(a:parsed, 'file') ?
                \ s:get_code(a:parsed.__range__, a:range_given, a:parsed.file) :
                \ s:get_code(a:parsed.__range__, a:range_given)
    let compilers = split(get(a:parsed, 'compiler', get(g:wandbox#default_compiler, s:filetype(a:parsed), g:wandbox#default_compiler['-'])), ',')
    if compilers == []
        throw "At least one compiler must be specified!"
    endif
    let options = split(get(a:parsed, 'options', get(g:wandbox#default_options, s:filetype(a:parsed), g:wandbox#default_options['-'])), ':', 1)
    if len(options) == 1
        let options = repeat(options, len(compilers))
    endif
    return [code, compilers, options]
endfunction
"}}}

" Wandbox Compile API {{{
function! wandbox#run_sync_or_async(...)
    if s:is_asynchronously_executable
        call call('wandbox#run_async', a:000)
    else
        call call('wandbox#run', a:000)
    endif
endfunction

" Polling {{{
function! s:abort(message)
    call filter(g:wandbox#_async_works, '! has_key(v:val, "_completed")')
    autocmd! wandbox-polling-response
    let &updatetime = s:previous_updatetime
    throw a:message
endfunction

function! s:shinchoku_doudesuka(work)
    for request in filter(copy(values(a:work)), 's:Prelude.is_dict(v:val) && ! has_key(v:val, "_exit_status")')
        let [condition, status] = request.process.checkpid()
        if condition ==# 'exit'
            let request._exit_status = status
        elseif condition ==# 'error'
            let a:work._completed = 1
            call s:abort("Error happened while Wandbox asynchronous execution!")
        endif
    endfor
endfunction

function! s:prepare_to_output(work)
    let a:work._completed = 1
    if a:work._tag ==# 'compile'
        for [compiler, request] in items(filter(copy(a:work), 's:Prelude.is_dict(v:val) && has_key(v:val, "_exit_status")'))
            let response = request.callback(request.files)
            if ! response.success
                call s:abort('Request has failed while executing '.compiler.'!: Status '. response.status . ': ' . response.statusText)
            endif
            if has_key(a:work, '_quickrun_session_key')
                " if executed via quickrun runner
                let s:async_quickrun_outputs = get(s:, 'async_quickrun_outputs', [])
                call add(s:async_quickrun_outputs, [
                            \ a:work._quickrun_session_key,
                            \ compiler,
                            \ s:format_process_result(s:JSON.decode(response.content))
                            \ ])
            else
                let s:async_compile_outputs = get(s:, 'async_compile_outputs', [])
                call add(s:async_compile_outputs, [compiler, s:format_process_result(s:JSON.decode(response.content))])
            endif
        endfor
    elseif a:work._tag ==# 'list'
        let response = a:work._list.callback(a:work._list.files)
        if ! response.success
            call s:abort('Request has failed! Status while getting option list!: '. response.status . ': ' . response.statusText)
        endif
        let s:async_list_outputs = get(s:, 'async_list_outputs', [])
        call add(s:async_list_outputs, wandbox#prettyprint#pp(s:JSON.decode(response.content)))
    endif
endfunction

function! s:do_output_with_workaround()
    if exists('s:async_compile_outputs')
        silent call feedkeys((mode() =~# '[iR]' ? "\<C-o>:" : ":\<C-u>")
                    \ . "call wandbox#_dump_compile_results_for_autocmd_workaround()\<CR>", 'n')
    endif
    if exists('s:async_list_outputs')
        silent call feedkeys((mode() =~# '[iR]' ? "\<C-o>:" : ":\<C-u>")
                    \ . "call wandbox#_dump_list_results_for_autocmd_workaround()\<CR>", 'n')
    endif
    if exists('s:async_quickrun_outputs')
        let outputs = {}
        for [key, compiler, output] in s:async_quickrun_outputs
            if ! has_key(outputs, key) | let outputs[key] = '' | endif
            let outputs[key] .= "## " . compiler . "\n" . output
        endfor
        unlet s:async_quickrun_outputs
        for [key, output] in items(outputs)
            let session = quickrun#session(key)
            call session.output(output)
            call session.finish(1)
        endfor
    endif
endfunction

function! s:polling_response()
    for work in g:wandbox#_async_works
        call s:shinchoku_doudesuka(work)

        " when all processes are completed
        if s:List.all('type(v:val) != type({}) || has_key(v:val, "_exit_status")', work)
            call s:prepare_to_output(work)
        endif
    endfor

    call s:do_output_with_workaround()

    " remove completed jobs
    call filter(g:wandbox#_async_works, '! has_key(v:val, "_completed")')

    " schedule next polling
    if g:wandbox#_async_works != []
        call feedkeys(mode() =~# '[iR]' ? "\<C-g>\<ESC>" : "g\<ESC>", 'n')
        return
    endif

    " clear away
    autocmd! wandbox-polling-response
    let &updatetime = s:previous_updatetime
    unlet s:previous_updatetime
endfunction

function! s:start_polling()
    if ! exists('s:previous_updatetime')
        let s:previous_updatetime = &updatetime
        let &updatetime = g:wandbox#updatetime
    endif
    augroup wandbox-polling-response
        autocmd! CursorHold,CursorHoldI * call s:polling_response()
    augroup END
endfunction
"}}}
" Compile synchrously {{{
function! wandbox#run(range_given, ...)
    let parsed = s:parse_args(a:000)
    if parsed == {} | return | endif
    let [code, compilers, options] = wandbox#_prepare_args(parsed, a:range_given)
    let results = map(s:List.zip(compilers, options), '[v:val[0], wandbox#compile(code, v:val[0], v:val[1])]')
    for [compiler, output] in results
        call s:dump_result(compiler, output)
    endfor
endfunction

function! wandbox#compile(code, compiler, options)
    let response = s:HTTP.request({
                \ 'url' : 'http://melpon.org/wandbox/api/compile.json',
                \ 'data' : s:JSON.encode({'code' : a:code, 'options' : a:options, 'compiler' : a:compiler}),
                \ 'headers' : {'Content-type' : 'application/json'},
                \ 'method' : 'POST',
                \ 'client' : (g:wandbox#disable_python_client ? ['curl', 'wget'] : ['python', 'curl', 'wget']),
                \ })
    if ! response.success
        throw "Request has failed! Status " . response.status . ': ' . response.statusText
    endif
    return s:format_process_result(s:JSON.decode(response.content))
endfunction
"}}}
" Compile asynchronously {{{
function! wandbox#run_async(range_given, ...)
    let parsed = s:parse_args(a:000)
    if parsed == {} | return | endif
    let [code, compilers, options] = wandbox#_prepare_args(parsed, a:range_given)
    call add(g:wandbox#_async_works, {})
    for [compiler, option] in s:List.zip(compilers, options)
        call wandbox#compile_async(code, compiler, option)
    endfor
endfunction

function! wandbox#_dump_compile_results_for_autocmd_workaround()
    if ! exists('s:async_compile_outputs')
        return
    endif
    for [compiler, output] in s:async_compile_outputs
        call s:dump_result(compiler, output)
    endfor
    unlet s:async_compile_outputs
endfunction

function! wandbox#compile_async(code, compiler, options)
    let g:wandbox#_async_works[-1][a:compiler] = s:HTTP.request_async({
                                       \ 'url' : 'http://melpon.org/wandbox/api/compile.json',
                                       \ 'data' : s:JSON.encode({'code' : a:code, 'options' : a:options, 'compiler' : a:compiler}),
                                       \ 'headers' : {'Content-type' : 'application/json'},
                                       \ 'method' : 'POST',
                                       \ 'client' : (g:wandbox#disable_python_client ? ['curl', 'wget'] : ['python', 'curl', 'wget']),
                                       \ })
    let g:wandbox#_async_works[-1]._tag = 'compile'
    call s:start_polling()
endfunction
"}}}
"}}}

" Wandbox List API {{{
function! wandbox#show_option_list()
    for l in split(wandbox#list(), "\n")
        call s:echo(l)
    endfor
endfunction

function! wandbox#list()
    let response = s:HTTP.request({
                \ 'url' : 'http://melpon.org/wandbox/api/list.json',
                \ 'client' : (g:wandbox#disable_python_client ? ['curl', 'wget'] : ['python', 'curl', 'wget']),
                \ })
    if ! response.success
        throw "Request has failed! Status " . response.status . ': ' . response.statusText
    endif
    return wandbox#prettyprint#pp(s:JSON.decode(response.content))
endfunction

function! wandbox#_dump_list_results_for_autocmd_workaround()
    if ! exists('s:async_list_outputs')
        return
    endif
    for output in s:async_list_outputs
        for l in split(output, "\n")
            call s:echo(l)
        endfor
    endfor
    " XXX It seems that the program cannot reach here. Why?
    "     It cannot reach here even if replace 'call s:echo(l)' with 'echo l'.
    unlet s:async_list_outputs
endfunction

function! wandbox#show_option_list_async()
    if ! s:is_asynchronously_executable
        throw "Cannot execute asynchronously!"
    endif

    call add(g:wandbox#_async_works, {})
    let g:wandbox#_async_works[-1]._list = s:HTTP.request_async({
                \ 'url' : 'http://melpon.org/wandbox/api/list.json',
                \ 'client' : (g:wandbox#disable_python_client ? ['curl', 'wget'] : ['python', 'curl', 'wget']),
                \ })
    let g:wandbox#_async_works[-1]._tag = 'list'

    " XXX temporary
    unlet! s:async_list_outputs

    call s:start_polling()
endfunction
"}}}

" ??? {{{
let g:wandbox#inu_aa = get(g:, 'wandbox#inu_aa', '三へ( へ՞ਊ ՞)へ ')
let g:wandbox#inu_serif = get(g:, 'wandbox#inu_serif', ['ﾊｯ', 'ﾊｯ'])
function! s:do_inu_animation()
    let distance = repeat(' ', s:inu_count)
    let scene = distance . g:wandbox#inu_aa . (s:inu_count / 4 % 2 == 0 ? g:wandbox#inu_serif[0].'  ' : '  '.g:wandbox#inu_serif[1])

    if (exists('*strdisplaywidth') ? strdisplaywidth(scene) : len(scene)) >= winwidth(0)
        let &updatetime = s:previous_updatetime
        autocmd! wandbox-puffpuff-animation
        redraw | echo
        return
    endif

    redraw | echo scene

    let s:inu_count += 1
    let hoge = 10 / 3 / 5
    let &updatetime = s:inu_updatetime / (s:inu_count / 5 + 1)
    call feedkeys(mode() =~# '[iR]' ? "\<C-g>\<ESC>" : "g\<ESC>", 'n')
endfunction
function! s:puffpuff()
    let s:inu_count = 0
    let s:inu_updatetime = 150
    let s:previous_updatetime = &updatetime
    let &updatetime = s:inu_updatetime
    augroup wandbox-puffpuff-animation
        autocmd! CursorHold,CursorHoldI * call s:do_inu_animation()
    augroup END
endfunction
" }}}

" Abort async works {{{
function! wandbox#abort_async_works()
    autocmd! wandbox-polling-response
    if exists('s:previous_updatetime')
        let &updatetime = s:previous_updatetime
        unlet s:previous_updatetime
    endif
    " TODO: sweep temprary files
    let g:wandbox#_async_works = []
    unlet! s:async_compile_outputs
    unlet! s:async_list_outputs
endfunction
"}}}

" A function to load this file
function! wandbox#touch()
endfunction

let &cpo = s:save_cpo
unlet s:save_cpo
