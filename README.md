Wandbox for vimmers
===================

This is a Vim plugin to use [Wandbox](http://melpon.org/wandbox/) in Vim.

## What is Wandbox?

[Wandbox](http://melpon.org/wandbox/) is a new and cool social compilation service mainly for C++ers.
You can use various versions of compilers and famous libraries.
In addition, Wandbox provides some other languages like Ruby, Python, Haskell, D and so on.
Wandbox has been created by @melpon and @kikairoya.  Repository page is [here](https://github.com/melpon/wandbox).

## Usage

```
:[range]Wandbox [--compiler={compiler}] [--options={options}]
```

If `[range]` is omitted, whole buffer would be selected.

`[--compiler={compiler}]` specifies a compiler like `gcc-head`, `clang-head`, `gcc-4.8.2`, `clang-3.3`... Default value is `gcc-head`.

`[--options={options}]` specifies options for compilation like `warning`, `c++1y`, `boost-1.55`... This value must be comma-separated and no space is allowed like `warning,c++1y,boost-1.55`. Default value is `warning,gnu++1y,boost-1.55`.


## Example

Execute the buffer with default compiler and options.

```
:Wandbox
```

Execute the buffer with clang.

```
:Wandbox --compiler=clang-head
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

Comming soon.

### Mappings

If you want to execute `:Wandbox` quickly, you can add mappings to `:Wandbox` like below.

```vim
augroup wandbox-settings
    autocmd!
    autocmd FileType cpp noremap <buffer><Leader>wg :Wandbox --compiler=gcc-head<CR>
    autocmd FileType cpp noremap <buffer><Leader>wc :Wandbox --compiler=clang-head<CR>
augroup END
```

## TODO

- Types of [vim-quickrun](https://github.com/thinca/vim-quickrun) like wandbox/gcc-head, wandbox/clang-head...
- Execute asynchronously with Vital.ProcessManager
- Better command interface
- Unite interface for compiler options
- Unite interface for compilers
- Persistent caching for options which would be used in quickrun type generation and unite interface
- Make default options and a compiler customizable


## Libraries wandbox-vim Using

wandbox-vim is standing on the shoulders of below libraries.

- Vital.Web.HTTP
- Vital.Web.JSON
- Vital.OptionParser
- vim-prettyprint

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
