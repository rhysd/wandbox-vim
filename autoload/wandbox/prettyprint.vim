" Original author : thinca <thinca+vim@gmail.com>
" License: zlib License
" Modified by rhysd <lin90162@yahoo.co.jp>

let s:save_cpo = &cpo
set cpo&vim

" functions. {{{1
function! s:pp(expr, shift, width, stack)
  let indent = repeat(s:blank, a:shift)
  let indentn = indent . s:blank

  let appear = index(a:stack, a:expr)
  call add(a:stack, a:expr)

  let width = s:width - a:width - s:indent * a:shift

  let str = ''
  if type(a:expr) == type([])
    if appear < 0
      let result = []
      for Expr in a:expr
        call add(result, s:pp(Expr, a:shift + 1, 0, a:stack))
        unlet Expr
      endfor
      let oneline = '[' . join(result, ', ') . ']'
      if strlen(oneline) < width && oneline !~ "\n"
        let str = oneline
      else
        let content = join(map(result, 'indentn . v:val'), ",\n")
        let str = printf("[\n%s\n%s]", content, indent)
      endif
    else
      let str = '[nested element ' . appear .']'
    endif

  elseif type(a:expr) == type({})
    if appear < 0
      let result = []
      for key in sort(keys(a:expr))
        let skey = string(strtrans(key))
        let sep = ': '
        let value = s:pp(a:expr[key], a:shift + 1, strlen(skey . sep), a:stack)
        if s:indent < strlen(skey . sep) &&
        \ width - s:indent < strlen(skey . sep . value) && value !~ "\n"
          let sep = ":\n" . indentn . s:blank
        endif
        call add(result, skey . sep . value)
        unlet value
      endfor
      let oneline = '{' . join(result, ', ') . '}'
      if strlen(oneline) < width && oneline !~ "\n"
        let str = oneline
      else
        let content = join(map(result, 'indentn . v:val'), ",\n")
        let str = printf("{\n%s\n%s}", content, indent)
      endif
    else
      let str = '{nested element ' . appear .'}'
    endif

  else
    if &verbose && type(a:expr) == type(function('tr'))
      let funcname = matchstr(string(a:expr), '^function(''\zs.*\ze'')$')
      if funcname =~# '^\d\+$'
        let funcname = '{' . funcname . '}'
      endif
      if exists('*' . funcname)
        redir => func
        " Don't print a definition location if &verbose == 1.
        silent! execute (&verbose - 1) 'verbose function' funcname
        redir END
        let str = func
      else
        let str = string(a:expr)
      endif
    elseif type(a:expr) == type('')
      let str = a:expr
      if a:expr =~# "\n" && s:string_split
        let expr = s:string_raw ? 'string(v:val)' : 'string(strtrans(v:val))'
        let str = "join([\n" . indentn .
        \ join(map(split(a:expr, '\n', 1), expr), ",\n" . indentn) .
        \ "\n" . indent . '], "\n")'
      elseif s:string_raw
        let str = string(a:expr)
      else
        let str = string(strtrans(a:expr))
      endif
    else
      let str = string(a:expr)
    endif
  endif

  unlet a:stack[-1]
  return str
endfunction

function! s:option(name)
  let name = 'prettyprint_' . a:name
  let opt = has_key(b:, name) ? b:[name] : g:[name]
  return type(opt) == type('') ? eval(opt) : opt
endfunction

function! wandbox#prettyprint#pp(...)
  let s:indent = s:option('indent')
  let s:blank = repeat(' ', s:indent)
  let s:width = s:option('width') - 1
  let string = s:option('string')
  let strlist = type(string) is type([]) ? string : [string]
  let s:string_split = 0 <= index(strlist, 'split')
  let s:string_raw = 0 <= index(strlist, 'raw')
  let result = []
  for Expr in a:000
    call add(result, s:pp(Expr, 0, 0, []))
    unlet Expr
  endfor
  return join(result, "\n")
endfunction

" options. {{{1
if !exists('g:prettyprint_indent')  " {{{2
  let g:prettyprint_indent = '&l:shiftwidth'
endif

if !exists('g:prettyprint_width')  " {{{2
  let g:prettyprint_width = '&columns'
endif

if !exists('g:prettyprint_string')  " {{{2
  let g:prettyprint_string = []
endif

if !exists('g:prettyprint_show_expression')  " {{{2
  let g:prettyprint_show_expression = 0
endif

let &cpo = s:save_cpo
unlet s:save_cpo
