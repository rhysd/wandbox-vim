Wandbox for vimmers
===================

This is a Vim plugin to use [Wandbox](https://wandbox.org/) in Vim.
You can compile and execute the current buffer with one or more compilers and display the results in Vim without any registration.
Now, Wandbox can execute C, C++, C#, D, Ruby, Python, Python3, PHP, Lua, Perl, Haskell, Erlang, Bash and SQL codes.

![screenshot](https://github.com/rhysd/ss/blob/master/wandbox-vim/wandbox.png?raw=true)

## What is Wandbox?

[Wandbox](https://wandbox.org/) is a new and cool social compilation service mainly for C++ers.
You can use various versions of compilers and famous libraries.
In addition, Wandbox provides some other languages like Ruby, Python, Haskell, D and so on.
Wandbox has been created by @melpon and @kikairoya.  Repository page is [here](https://github.com/melpon/wandbox).

## Usage

```
:[range]Wandbox [--compiler={compiler}] [--options={options}] [--compiler-options={options}] [--file={file}] [--runtime-options] [--stdin] [--stdin-file={stdin-file}]
```

If `[range]` is omitted, whole buffer would be selected.

`[--compiler={compiler}]` specifies a compiler like `gcc-head`, `clang-head`, `gcc-4.8.2`, `clang-3.3`... Default value is `gcc-head` for C++. See `autoload/wandbox.vim` to know default values of each filetype.  You can set multiple compilers with comma-separated string like `'gcc-head,clang-head'`.

`[--options={options}]` specifies options for compilation like `warning`, `c++1y`, `boost-1.55`... This value must be comma-separated and no space is allowed like `warning,c++1y,boost-1.55`. Default value is `warning,gnu++1y,boost-1.55` for C++, 'haskell-warning' for Haskell, '' for others.  If multiple compilers are set, you can set each options for the compilers with colon-separated string like `'warning,c++11:warning,c++0x'`.  When you set single options like `'warning,c++11'` even if multiple compilers are set, all compilers uses the same option you set.

`[--compiler-options={options}]` directly specifies compiler options like `-Wall`, `-std=c++17`, `-O2`... This value must be separated by backslash comma ('\,') and no space is allowed like `-Wall\,-std=c++17\,-O2`. If multiple compilers are set, you can set each options for the compilers with backslash-colon-separated string like `-Wall\,-std=c++11\:-Wall\,-std=c++17`. When you set single options even if multiple compilers are set, all compilers uses the same option you set.

`[--file={file}]` specifies the file to execute. If it is omitted, a current buffer will be executed.

`[--runtime-options]` specifies arguments for the program at runtime.  You can input the arguments.

`[--stdin]` specifies stdin. You can input the arguments, or use global variable like `--stdin=g:stdin`.

`[--stdin-file]` specifies file which will be used as stdin.

Files included with relative paths in a source are expand automatically.
To send requests asynchronously, `curl` or `wget` command and [vimproc](https://github.com/Shougo/vimproc.vim) are required. Otherwise, requests are sent synchronously and they will block Vim.

The compile time messages (warnings, errors) are output to a quickfix window and the program output messages are output to a message window.

## Example

Execute the buffer with default compiler and options.

```
:Wandbox
```

Execute the buffer with clang and gcc at the same time.

```
:Wandbox --compiler=clang-head,gcc-head
```

When you want to know about options,

```
:WandboxOptionList
```

If you want to search incrementally, [unite.vim](https://github.com/Shougo/unite.vim) is a good choice.

```
:Unite output:WandboxOptionList
```

Below is an example for heavy use.

```
:Wandbox --compiler=clang-3.3 --options=boost-1.55,c++1y,warning,optimize,sprout
```

If you want to use wandbox with [vim-quickrun](https://github.com/thinca/vim-quickrun), `wandbox` runner for quickrun is available.

```
:QuickRun -runner wandbox
```


## Installation

Use modern plugin manager like [neobundle.vim](https://github.com/Shougo/neobundle.vim) or [vundle](https://github.com/gmarik/vundle).

Though it is _NOT_ recommended, you can install manually by copying the files in this repository into your Vim script directory which is usually `~/.vim/`, or `$HOME/vimfiles` on Windows.

```sh
git clone https://github.com/rhysd/wandbox-vim.git
cd wandbox-vim
cp -R autoload/* ~/.vim/autoload/
cp -R plugin/* ~/.vim/plugin/
```

## Customization

### Variables

You can set the default compiler and default options for each filetype by `g:wandbox#default_compiler` and `g:wandbox#default_options`.

```vim
" Set default compilers for each filetype
if ! exists('g:wandbox#default_compiler')
    let g:wandbox#default_compiler = {}
endif
let g:wandbox#default_compiler = {
\   'cpp' : 'clang-head',
\   'ruby' : 'ruby-1.9.3-p0',
\ }

" Set default options for each filetype.  Type of value is string or list of string
if ! exists('g:wandbox#default_options')
    let g:wandbox#default_options = {}
endif
let g:wandbox#default_options = {
\   'cpp' : 'warning,optimize,boost-1.55',
\   'haskell' : [
\     'haskell-warning',
\     'haskell-optimize',
\   ],
\ }

" Set extra options for compilers if you need
let g:wandbox#default_extra_options = {
\   'clang-head' : '-O3 -Werror',
\ }
```

### Mappings

If you want to execute `:Wandbox` quickly, you can add mappings to `:Wandbox` like below.

```vim
" For all filetypes, use default compiler and options
noremap <Leader>wb :Wandbox<CR>
" For specific filetypes, specify compilers to use
augroup wandbox-settings
    autocmd!
    autocmd FileType cpp noremap <buffer><Leader>ww :Wandbox --compiler=gcc-head,clang-head<CR>
    autocmd FileType cpp noremap <buffer><Leader>wg :Wandbox --compiler=gcc-head<CR>
    autocmd FileType cpp noremap <buffer><Leader>wc :Wandbox --compiler=clang-head<CR>
augroup END
```

## (Maybe) To Do

- Better command interface
- Unite interface for compiler options
- Unite interface for compilers
- Persistent caching for options which would be used in quickrun type generation and unite interface
- `doc/wandbox.txt`
- Execute remote Gist code
- No plugin is allowed to have no test
- Make an option list prettier
- Separate default setting and user setting
- Output error and warning to location-list
- Retry if request is timed out

## Libraries wandbox-vim Using

wandbox-vim is standing on the shoulders of below libraries (you don't need to install below by your hand).

- Vital.Web.HTTP
- Vital.Web.JSON
- Vital.OptionParser
- Vital.Data.List
- Vital.Prelude
- vim-prettyprint

## References

- Wandbox

https://wandbox.org/

- Wandbox API

https://github.com/melpon/wandbox/blob/master/kennel2/API.rst

## License

  Copyright (c) 2013 rhysd

  Permission is hereby granted, free of charge, to any person obtaining
  a copy of this software and associated documentation files (the
  "Software"), to deal in the Software without restriction, including
  without limitation the rights to use, copy, modify, merge, publish,
  distribute, sublicense, and/or sell copies of the Software, and to
  permit persons to whom the Software is furnished to do so, subject to
  the following conditions:
  The above copyright notice and this permission notice shall be
  included in all copies or substantial portions of the Software.

  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
  EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
  MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
  IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
  CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
  TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
  SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
