scriptencoding utf-8
let s:save_cpo = &cpo
set cpo&vim

" Import vital {{{
let s:V = vital#of('wandbox_vim')
let s:OptionParser = s:V.import('OptionParser')
let s:HTTP = s:V.import('Web.HTTP')
let s:JSON = s:V.import('Web.JSON')
let s:List = s:V.import('Data.List')
let s:Prelude = s:V.import('Prelude')
let s:Process = s:V.import('Process')
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
            \ 'lazyk' : 'lazyk',
            \ 'rust' : 'rust-head',
            \ 'lisp' : 'clisp-2.49.0',
            \ 'pascal' : 'fpc-2.6.2',
            \ 'java' : 'java7-openjdk',
            \ 'groovy' : 'groovy-2.2.1',
            \ 'javascript' : 'mozjs-24.2.0',
            \ 'javascript.node' : 'node-0.10.24',
            \ 'coffee' : 'coffee-script-head',
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
let g:wandbox#disable_quickfix = get(g:, 'wandbox#disable_quickfix', 0)
let g:wandbox#open_quickfix_window = get(g:, 'wandbox#open_quickfix_window', 1)
let g:wandbox#complete_message = get(g:, 'wandbox#complete_message', 'Wandbox returned no output.')
let g:wandbox#expand_included_files = get(g:, 'wandbox#expand_included_files', 1)
let g:wandbox#default_extra_options = get(g:, 'wandbox#default_extra_options', {})

let s:async_works = []
let s:is_asynchronously_executable = s:Process.has_vimproc() && (executable('curl') || executable('wget'))
"}}}

" Option definitions {{{
let s:option_parser = s:OptionParser.new()
                                   \.on('--compiler=VAL', 'Comma separated compiler commands (like "gcc-head,clang-head")', {'short' : '-c'})
                                   \.on('--options=VAL', 'Comma separated options (like "warning,gnu++1y"', {'short' : '-o'})
                                   \.on('--file=VAL', 'File name to execute', {'short' : '-f'})
                                   \.on('--filetype=VAL', 'Filetype with which Wandbox executes')
                                   \.on('--runtime-options', 'Input runtime program options', {'short' : '-r', 'default' : 0})
                                   \.on('--stdin', 'Stdin to the program', {'short' : '-s', 'default' : 0})
                                   \.on('--puff-puff', '???')
"}}}

" Complete function {{{
function! wandbox#complete_command(arglead, cmdline, cursorpos)
    return s:option_parser.complete(a:arglead, a:cmdline, a:cursorpos)
endfunction
" }}}

" Initialize augroup {{{
augroup wandbox-polling-response
augroup END
"}}}

" Utility functions {{{
function! wandbox#_escape_backslash(str)
    return substitute(a:str, '\', s:Prelude.is_windows() ? '/' : '\\\\', 'g')
endfunction

function! wandbox#_export_vital_modules()
    return [s:V, s:OptionParser, s:HTTP, s:JSON, s:List, s:Prelude]
endfunction

function! wandbox#is_available(filetype)
    return has_key(g:wandbox#default_compiler, a:filetype)
endfunction

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

function! s:expand_included_files(buf)
    for [line, idx] in s:List.with_index(a:buf)
        let included = matchstr(line, '^\s*#\s*include\s\+"\zs[^"]\+\ze"')
        if included !=# ''
            let included_path = expand('%:p:h') . '/' . included
            if filereadable(included_path)
                call remove(a:buf, idx)
                call extend(a:buf, readfile(included_path), idx)
            endif
        endif
    endfor
endfunction

function! s:get_code(range, range_given, ...)
    if a:0 > 0
        let buf = a:range_given ?
                    \ readfile(a:1)[a:range[0]-1:a:range[1]-1] :
                    \ readfile(a:1)
    else
        let range = a:range_given ? a:range : [1, line('$')]
        let buf = getline(range[0], range[1]) + ["\n"]
    endif
    if g:wandbox#expand_included_files
        call s:expand_included_files(buf)
    endif
    return substitute(join(buf, "\n"), '\', '\\\\', 'g')
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

function! s:echo_complete_message(no_compiler_msg, no_program_msg)
    if ! (a:no_compiler_msg || g:wandbox#open_quickfix_window)
        echohl ErrorMsg | echomsg "Wandbox returned compilation error or warning." | echohl None
    elseif a:no_compiler_msg && a:no_program_msg
        call s:echo(g:wandbox#complete_message)
    else
        " Do nothing
    endif
endfunction

" @param: results is a list of 2-elems list
"         first elem is compiler, second elem is json result
function! s:dump_with_quickfix(results, file, bufnr)
    let quickfix_list = []
    let no_compiler_message = 1
    let no_program_message = 1
    for [compiler, json] in a:results
        if has_key(json, 'compiler_message') && json.compiler_message != ''
            let message = a:file == '' ? json.compiler_message : substitute(json.compiler_message, '\%(^\|\n\)\zsprog\.cc', wandbox#_escape_backslash(a:file), 'g')
            let quickfix_list += ['## '.compiler] + split(message, "\n") + ["\n"]
            let no_compiler_message = 0
        endif
    endfor
    if quickfix_list == []
        " Clear quickfix list
        call setqflist([])
    else
        if a:file == ''
            call setqflist(map(quickfix_list, '{"bufnr" : a:bufnr, "filename" : a:file, "text" : v:val}'))
        else
            cgetexpr quickfix_list
        endif
        if g:wandbox#open_quickfix_window
            copen
        endif
    endif
    syntax match wandboxCompilerName /## .\+$/ containedin=all
    highlight def link wandboxCompilerName Constant
    redraw!
    for [compiler, json] in a:results
        if has_key(json, 'program_message') && json.program_message != ''
            call s:dump_result(compiler, json.program_message)
            let no_program_message = 0
        endif
        if has_key(json, 'signal')
            echohl ErrorMsg | call s:echo(json.signal) | echohl None
            let no_program_message = 0
        endif
    endfor
    call s:echo_complete_message(no_compiler_message, no_program_message)
endfunction

function! s:filetype(parsed)
    return has_key(a:parsed, 'filetype') ? a:parsed.filetype : &filetype
endfunction

function! s:prepare_args(parsed, range_given)
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
    if a:parsed['runtime-options']
        " XXX Replace white spaces except for spaces in quoted strings
        let runtime_options = input('Input runtime program options: ')
    else
        let runtime_options = ''
    endif
    if a:parsed.stdin
        if (s:Prelude.is_number(a:parsed.stdin) && a:parsed.stdin == 1) || a:parsed.stdin ==# 'input'
            let stdin = input('Enter stdin: ')
        elseif a:parsed.stdin =~# '^g:.\+'
            let stdin = {a:parsed.stdin}
        endif
    else
        let stdin = ''
    endif
    return [code, compilers, options, runtime_options, stdin]
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
    call filter(s:async_works, '! has_key(v:val, "_completed")')
    autocmd! wandbox-polling-response
    let &updatetime = s:previous_updatetime
    unlet s:previous_updatetime
    throw a:message
endfunction

function! wandbox#_shinchoku_doudesuka(work)
    for request in filter(copy(values(a:work)), 's:Prelude.is_dict(v:val) && ! has_key(v:val, "_exit_status")')
        let [condition, status] = request.process.checkpid()
        if condition ==# 'exit'
            let request._exit_status = status
            call request.process.stdout.close()
            call request.process.stderr.close()
        elseif condition ==# 'error'
            let a:work._completed = 1
            call request.process.stdout.close()
            call request.process.stderr.close()
            " XXX Is this OK?
            echohl ErrorMsg
            echomsg "Error happened while Wandbox asynchronous execution!"
            echohl None
        endif
    endfor
    return s:List.all('type(v:val) != type({}) || has_key(v:val, "_exit_status")', a:work)
endfunction

function! s:prepare_to_output(work)
    let a:work._completed = 1
    if a:work._tag ==# 'compile'
        let s:async_compile_info = {'file' : expand('%:p'), 'bufnr' : a:work._bufnr}
        for [compiler, request] in items(filter(copy(a:work), 's:Prelude.is_dict(v:val) && has_key(v:val, "_exit_status")'))
            let response = request.callback(request.files)
            if ! response.success
                call s:abort('Request has failed while executing '.compiler.'!: Status '. response.status . ': ' . response.statusText)
            endif
            let s:async_compile_outputs = get(s:, 'async_compile_outputs', [])
            call add(s:async_compile_outputs, [compiler, s:JSON.decode(response.content)])
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
    if exists('s:async_compile_outputs') && exists('s:async_compile_info')
        silent call feedkeys((mode() =~# '[iR]' ? "\<C-o>:" : ":\<C-u>")
                    \ . "call wandbox#_dump_compile_results_for_autocmd_workaround()\<CR>", 'n')
    endif
    if exists('s:async_list_outputs')
        silent call feedkeys((mode() =~# '[iR]' ? "\<C-o>:" : ":\<C-u>")
                    \ . "call wandbox#_dump_list_results_for_autocmd_workaround()\<CR>", 'n')
    endif
endfunction

function! s:polling_response()
    for work in s:async_works
        if wandbox#_shinchoku_doudesuka(work)
            " when all processes are completed
            call s:prepare_to_output(work)
        endif
    endfor

    call s:do_output_with_workaround()

    " remove completed jobs
    call filter(s:async_works, '! has_key(v:val, "_completed")')

    " schedule next polling
    if s:async_works != []
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
    let [code, compilers, options, runtime_options, stdin] = s:prepare_args(parsed, a:range_given)
    let results = map(s:List.zip(compilers, options), '[v:val[0], wandbox#compile(code, v:val[0], v:val[1], runtime_options, stdin)]')
    if g:wandbox#disable_quickfix
        for [compiler, json_result] in results
            call s:dump_result(compiler, s:format_process_result(json_result))
        endfor
    else
        call s:dump_with_quickfix(results, expand('%:p'), bufnr('%'))
    endif
endfunction

function! wandbox#compile(code, compiler, options, runtime_options, stdin)
    let data = {'code' : a:code, 'options' : a:options, 'compiler' : a:compiler}
    if has_key(g:wandbox#default_extra_options, a:compiler)
        let data['compiler-option-raw'] = g:wandbox#default_extra_options[a:compiler]
    endif
    if a:runtime_options != ''
        let data['runtime-option-raw'] = a:runtime_options
    endif
    if a:stdin != ''
        let data['stdin'] = a:stdin
    endif
    let response = s:HTTP.request({
                \ 'url' : 'http://melpon.org/wandbox/api/compile.json',
                \ 'data' : s:JSON.encode(data),
                \ 'headers' : {'Content-type' : 'application/json'},
                \ 'method' : 'POST',
                \ 'client' : (g:wandbox#disable_python_client ? ['curl', 'wget'] : ['python', 'curl', 'wget']),
                \ })
    if ! response.success
        throw "Request has failed! Status " . response.status . ': ' . response.statusText
    endif
    return s:JSON.decode(response.content)
endfunction
"}}}
" Compile asynchronously {{{
function! wandbox#run_async(range_given, ...)
    let parsed = s:parse_args(a:000)
    if parsed == {} | return | endif
    let [code, compilers, options, runtime_options, stdin] = s:prepare_args(parsed, a:range_given)
    call add(s:async_works, {})
    for [compiler, option] in s:List.zip(compilers, options)
        call wandbox#compile_async(code, compiler, option, runtime_options, stdin, s:async_works[-1])
    endfor
    call s:start_polling()
endfunction

function! wandbox#_dump_compile_results_for_autocmd_workaround()
    if ! exists('s:async_compile_outputs') || ! exists('s:async_compile_info')
        return
    endif
    if g:wandbox#disable_quickfix
        for [compiler, output] in s:async_compile_outputs
            call s:dump_result(compiler, s:format_process_result(output))
        endfor
    else
        call s:dump_with_quickfix(s:async_compile_outputs, s:async_compile_info.file, s:async_compile_info.bufnr)
    endif
    unlet s:async_compile_outputs
    unlet s:async_compile_info
endfunction

function! wandbox#compile_async(code, compiler, options, runtime_options, stdin, work)
    let data = {'code' : a:code, 'options' : a:options, 'compiler' : a:compiler}
    if has_key(g:wandbox#default_extra_options, a:compiler)
        let data['compiler-option-raw'] = substitute(g:wandbox#default_extra_options[a:compiler], '\s\+', "\n", 'g')
    endif
    if a:runtime_options != ''
        " XXX Replace white spaces except for spaces in quoted strings
        let data['runtime-option-raw'] = substitute(a:runtime_options, '\s\+', "\n", 'g')
    endif
    if a:stdin != ''
        let data.stdin = a:stdin
    endif
    let a:work[a:compiler] = s:HTTP.request_async({
                                       \ 'url' : 'http://melpon.org/wandbox/api/compile.json',
                                       \ 'data' : s:JSON.encode(data),
                                       \ 'headers' : {'Content-type' : 'application/json'},
                                       \ 'method' : 'POST',
                                       \ 'client' : (g:wandbox#disable_python_client ? ['curl', 'wget'] : ['python', 'curl', 'wget']),
                                       \ })
    let a:work._tag = 'compile'
    let a:work._bufnr = bufnr('%')
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

    call add(s:async_works, {})
    let s:async_works[-1]._list = s:HTTP.request_async({
                \ 'url' : 'http://melpon.org/wandbox/api/list.json',
                \ 'client' : (g:wandbox#disable_python_client ? ['curl', 'wget'] : ['python', 'curl', 'wget']),
                \ })
    let s:async_works[-1]._tag = 'list'

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
        unlet s:previous_updatetime
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
    let s:async_works = []
    unlet! s:async_compile_outputs
    unlet! s:async_compile_info
    unlet! s:async_list_outputs
endfunction
"}}}

" Open Wandbox in a browser {{{
function! s:open_browser(url)
    if s:Prelude.is_windows()
        s:Prelude.system('start '.a:url)
    elseif s:Prelude.is_mac()
        s:Prelude.system('open '.a:url)
    elseif s:Prelude.is_unix()
        if executable('xdg-open')
            s:Prelude.system('xdg-open '.a:url)
        else
            throw "Unsupported environment."
        endif
    else
        throw "Unsupported environment."
    endif
endfunction
function! wandbox#open_browser()
    if exists(':OpenBrowser')
        OpenBrowser http://melpon.org/wandbox/
    else
        call s:open_browser('http://melpon.org/wandbox/')
    endif
endfunction
"}}}

let &cpo = s:save_cpo
unlet s:save_cpo
