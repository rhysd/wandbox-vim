scriptencoding utf-8
let s:save_cpo = &cpo
set cpo&vim

let s:V = vital#of('wandbox-vim')
let s:OptionParser = s:V.import('OptionParser')
let s:HTTP = s:V.import('Web.HTTP')
let s:JSON = s:V.import('Web.JSON')
let s:List = s:V.import('Data.List')
let s:Xor128 = s:V.import('Random.Xor128')

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
    call map(g:wandbox#default_options, 'type(v:val) == type("") ? v:val : join(v:val, ",")')
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
let g:wandbox#disable_python_client = get(g:, 'wandbox#disable_python_client', 0)
if ! exists('g:wandbox#updatetime')
    let g:wandbox#updatetime =
                  \ exists('g:quickrun_config["_"]["runner/vimproc/updatetime"]') ?
                  \ g:quickrun_config["_"]["runner/vimproc/updatetime"] :
                  \ 500
endif

let s:option_parser = s:OptionParser.new()
                                   \.on('--compiler=VAL', '-c', 'Comma separated compiler commands (like "gcc-head,clang-head")')
                                   \.on('--options=VAL', '-o', 'Comma separated options (like "warning,gnu++1y"')
                                   \.on('--file=VAL', '-f', 'File name to execute')

let s:actions = {}

function! s:echo(string)
    execute g:wandbox#echo_command string(a:string)
endfunction

function! s:parse_args(args)
    " TODO: parse returned value
    let parsed = call(s:option_parser.parse, a:args, s:option_parser)
    if parsed.__unknown_args__ != []
        if parsed.__unknown_args__[0] == '--puff-puff'
            echo '三へ( へ՞ਊ ՞)へ ﾊｯﾊｯ'
            return {}
        else
            throw 'Unknown arguments: '.join(parsed.__unknown_args__, ', ')
        endif
    endif
    if has_key(parsed, 'help')
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

function! s:format_result(content)
    return printf("%s\n%s"
         \, s:is_blank(a:content, 'compiler_message') ? '' : printf("* [compiler]\n\n%s", a:content.compiler_message)
         \, s:is_blank(a:content, 'program_message') ? '' : printf("* [output]\n\n%s", a:content.program_message))
endfunction

function! s:get_code(range, range_given, ...)
    if a:0 > 0
        let buf = join(a:range_given ?
                        \ readfile(a:1) :
                        \ readfile(a:1)[a:range[0]-1:a:range[1]-1], "\n")
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
        if l ==# '* [compiler]' || l ==# '* [output]'
            echohl MoreMsg | call s:echo(l=='' ? ' ' : l) | echohl None
        else
            call s:echo(indent . (l=='' ? ' ' : l))
        endif
    endfor
    call s:echo(' ')
endfunction

function! s:prepare_wandbox_args(parsed, range_given)
    let code = has_key(a:parsed, 'file') ?
                \ s:get_code(a:parsed.__range__, a:range_given, a:parsed.file) :
                \ s:get_code(a:parsed.__range__, a:range_given)
    let compilers = split(get(a:parsed, 'compiler', get(g:wandbox#default_compiler, &filetype, g:wandbox#default_compiler['-'])), ',')
    if compilers == []
        throw "At least one compiler must be specified!"
    endif
    let options = split(get(a:parsed, 'options', get(g:wandbox#default_options, &filetype, g:wandbox#default_options['-'])), ':', 1)
    if len(options) == 1
        let options = repeat([options[0]], len(compilers))
    endif
    return [code, compilers, options]
endfunction

function! wandbox#run(range_given, ...)
    let parsed = s:parse_args(a:000)
    if parsed == {} | return | endif
    let [code, compilers, options] = s:prepare_wandbox_args(parsed, a:range_given)
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
    return s:format_result(s:JSON.decode(response.content))
endfunction

function! wandbox#run_async(range_given, ...)
    let parsed = s:parse_args(a:000)
    if parsed == {} | return | endif
    let [code, compilers, options] = s:prepare_wandbox_args(parsed, a:range_given)
    let id = s:Xor128.rand()
    while has_key(s:actions, id)
        let id = s:Xor128.rand()
    endwhile
    let s:actions[id] = {}
    for [compiler, option] in s:List.zip(compilers, options)
        call wandbox#compile_async(code, compiler, option, id)
    endfor
endfunction

function! s:polling_response()
    for action in values(s:actions)
        for [compiler, request] in items(action)
            " TODO: check process
            let [condition, status] = request.process.checkpid()
            if condition ==# 'exit'
                " TODO
                let request.exit_status = status
            elseif condition ==# 'error'
                throw "Error happened while wandbox asynchronous execution: status was ".status
            endif
        endfor
        " TODO: check all requests have been completed
        "       if all are done, output result and remove action from
        "       s:actions
    endfor

    if s:actions != {}
        call feedkeys(mode() ==# 'i' ? "\<C-g>\<ESC>" : "g\<ESC>", 'n')
        return
    endif

    " clear away
    autocmd! wandbox-polling-response
    let &updatetime = s:previous_updatetime
endfunction

function! wandbox#compile_async(code, compiler, options, id)
    let s:actions[a:id][a:compiler] = s:HTTP.request_async({
                                       \ 'url' : 'http://melpon.org/wandbox/api/compile.json',
                                       \ 'data' : s:JSON.encode({'code' : a:code, 'options' : a:options, 'compiler' : a:compiler}),
                                       \ 'headers' : {'Content-type' : 'application/json'},
                                       \ 'method' : 'POST',
                                       \ 'client' : (g:wandbox#disable_python_client ? ['curl', 'wget'] : ['python', 'curl', 'wget']),
                                       \ })
    let s:previous_updatetime = &updatetime
    let &updatetime = g:wandbox#updatetime
    augroup wandbox-polling-response
        autocmd! CursorHold,CursorHoldI * call s:polling_response()
    augroup END
endfunction

function! wandbox#list()
    let response = s:HTTP.request({
                \ 'url' : 'http://melpon.org/wandbox/api/list.json',
                \ 'client' : (g:wandbox#disable_python_client ? ['curl', 'wget'] : ['python', 'curl', 'wget']),
                \ })
    let response = s:HTTP.get('http://melpon.org/wandbox/api/list.json')
    if ! response.success
        throw "Request has failed! Status " . response.status . ': ' . response.statusText
    endif
    return wandbox#prettyprint#pp(s:JSON.decode(response.content))
endfunction

function! wandbox#bark()
    for l in split(wandbox#list(), "\n")
        call s:echo(l)
    endfor
endfunction

let &cpo = s:save_cpo
unlet s:save_cpo
