scriptencoding utf-8
let s:save_cpo = &cpo
set cpo&vim

let s:V = vital#of('wandbox-vim')
let s:OptionParser = s:V.import('OptionParser')
let s:HTTP = s:V.import('Web.HTTP')
let s:JSON = s:V.import('Web.JSON')

let s:option_parser = s:OptionParser.new()
                                   \.on('--compiler=VAL', '-c', 'Compiler command (like g++, clang, ...)')
                                   \.on('--options=VAL', '-o', 'Comma separated options (like "warning,gnu++1y"')

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

function! wandbox#compile(...)
    let parsed = s:parse_args(a:000)
    if parsed == {} | return '' | endif
    let buf = substitute(join(getline(parsed.__range__[0], parsed.__range__[1]), "\n")."\n", '\\', '\\\\', 'g')
    let compiler = has_key(parsed, 'compiler') ? parsed.compiler : 'gcc-head'
    let options = has_key(parsed, 'options') ? parsed.options : 'warning,gnu++1y,boost-1.55'
    let json = s:JSON.encode({'code':buf, 'options':options, 'compiler':compiler})
    let response = s:HTTP.post('http://melpon.org/wandbox/api/compile.json',
                             \ json,
                             \ {'Content-type' : 'application/json'})
    if ! response.success
        throw "Request has failed! Status is ".response.status.'.'
    endif
    let content = s:JSON.decode(response.content)
    return s:format_result(content)
endfunction

function! wandbox#compile_and_dump(...)
    for l in split(call('wandbox#compile', a:000), "\n")
        if l ==# '[compiler]' || l ==# '[output]'
            echohl MoreMsg
        endif
        echomsg l
        echohl None
    endfor
endfunction

function! wandbox#list()
    let response = s:HTTP.get('http://melpon.org/wandbox/api/list.json')
    if ! response.success
        throw "Request has failed! Status is " . response.status . '.'
    endif
    return wandbox#prettyprint#pp(s:JSON.decode(response.content))
endfunction

function! wandbox#dump_option_list()
    for l in split(wandbox#list(), "\n")
        echomsg l
    endfor
endfunction

let &cpo = s:save_cpo
unlet s:save_cpo
