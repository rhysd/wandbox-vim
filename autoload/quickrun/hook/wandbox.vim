let s:save_cpo = &cpo
set cpo&vim

let s:hook = {
\   "name" : "wandbox",
\   "kind" : "hook",
\   "config" : {
\       "enable" : 0,
\       "compiler" : "",
\       "options" : "",
\   }
\}

let s:wandbox_root = escape(substitute(fnamemodify(globpath(&rtp, 'plugin/wandbox.vim'), ':p:h:h'), '\\', '/', 'g'), ' ')

function! s:hook.on_normalized(session, context)
    let wandbox_opts = ''
    if self.config.compiler != ''
        let wandbox_opts .= ' --compiler=' . self.config.compiler
    endif
    if self.config.options != ''
        let wandbox_opts .= ' --options=' . self.config.options
    endif
    let a:session.config.exec = '%C -N -u NONE -i NONE -V1 -e -s -c "set rtp+=' . s:wandbox_root . '" -c "runtime plugin/wandbox.vim" -c "setf '.&filetype.'" -c "WandboxSync --file=%s'.wandbox_opts.'" -c qall!'
endfunction

function! quickrun#hook#wandbox#new()
    return deepcopy(s:hook)
endfunction

let &cpo = s:save_cpo
unlet s:save_cpo
