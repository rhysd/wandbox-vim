scriptencoding utf-8
let s:save_cpo = &cpo
set cpo&vim

let s:V = vital#of('wandbox-vim')
let s:OptionParser = s:V.import('OptionParser')
let s:HTTP = s:V.import('Web.HTTP')
let s:JSON = s:V.import('Web.JSON')
let s:List = s:V.import('Data.List')

let s:default_compiler = {
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
            \ }

if exists('wandbox#default_compiler')
    for [name, compiler] in items(wandbox#default_compiler)
        let s:default_compiler[name] = compiler
    endfor
endif

let s:default_options = {
            \ '-' : '',
            \ 'cpp' : 'warning,gnu++1y,boost-1.55',
            \ 'c' : 'warning,c11',
            \ 'haskell' : 'haskell-warning',
            \ }

if exists('wandbox#default_options')
    for [name, options] in items(wandbox#default_options)
        let s:default_options[name] = type(options) == type("") ? options : join(options, ',')
        unlet options
    endfor
endif

let s:result_indent = repeat(' ', get(g:, 'wandbox#result_indent', 2))
let g:wandbox#echo_command = get(g:, 'wandbox#echo_command', 'echo')

let s:option_parser = s:OptionParser.new()
                                   \.on('--compiler=VAL', '-c', 'Comma separated compiler commands (like "gcc-head,clang-head")')
                                   \.on('--options=VAL', '-o', 'Comma separated options (like "warning,gnu++1y"')
                                   \.on('--file=VAL', '-f', 'File name to execute')

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
         \, s:is_blank(a:content, 'compiler_message') ? '' : printf("[compiler]\n%s", a:content.compiler_message)
         \, s:is_blank(a:content, 'program_message') ? '' : printf("[output]\n%s", a:content.program_message))
endfunction

function! s:get_code(range, range_given, ...)
    if a:0 > 0
        " XXX
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
    echohl Constant | call s:echo('[['.a:compiler.']]') | echohl None
    for l in split(a:result, "\n")
        if l ==# '[compiler]' || l ==# '[output]'
            echohl MoreMsg | call s:echo(s:result_indent.(l=='' ? ' ' : l)) | echohl None
        else
            call s:echo(s:result_indent.(l=='' ? ' ' : l))
        endif
    endfor
endfunction

function! wandbox#run(range_given, ...)
    let parsed = s:parse_args(a:000)
    if parsed == {} | return | endif
    let code = has_key(parsed, 'file') ?
                \ s:get_code(parsed.__range__, a:range_given, parsed.file) :
                \ s:get_code(parsed.__range__, a:range_given)
    let compilers = split(get(parsed, 'compiler', get(s:default_compiler, &filetype, s:default_compiler['-'])), ',')
    let options = split(get(parsed, 'options', get(s:default_options, &filetype, s:default_options['-'])), ':')
    if len(options) <= 1
        let options = repeat([options == [] ? '' : options[0]], len(compilers))
    endif
    let results = map(s:List.zip(compilers, options), '[v:val[0], wandbox#compile(code, v:val[0], v:val[1])]')
    for [compiler, output] in results
        call s:dump_result(compiler, output)
    endfor
    call s:echo(' ')
endfunction

function! wandbox#compile(code, compiler, options)
    let json = s:JSON.encode({'code' : a:code, 'options' : a:options, 'compiler' : a:compiler})
    let response = s:HTTP.post('http://melpon.org/wandbox/api/compile.json',
                             \ json,
                             \ {'Content-type' : 'application/json'})
    if ! response.success
        throw "Request has failed! Status " . response.status . ': ' . response.statusText
    endif
    let content = s:JSON.decode(response.content)
    return s:format_result(content)
endfunction

function! wandbox#list()
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
