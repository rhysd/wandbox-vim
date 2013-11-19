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
[range]WandBox [--compiler={compiler}] [--options={options}]
```

If `[range]` is omitted, whole buffer would be selected.

`[--compiler={compiler}]` specifies a compiler like `gcc-head`, `clang-head`, `gcc-4.8`, `clang-3.3`... Default value is `gcc-head`.

`[--options={options}]` specifies options for compilation like `warning`, `c++1y`, `boost-1.55`... This value must be comma-separated and no space is allowed like `warning,c++1y,boost-1.55`. Default value is `warning,gnu++1y,boost-1.55`.


## Example

Execute the buffer with default compiler and options.

```
:WandBox
```

Execute the buffer with clang.

```
:WandBox --compiler=clang-head
```

When you want to know about options,

```
:WandBoxOptionList
```

If you want to search incrementally, [unite.vim](https://github.com/Shougo/unite.vim) is a good choice.

```
:Unite output:WandBoxOptionList
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

Comming soon.

## Libraries wandbox-vim Using

wandbox-vim is standing on the shoulders of bellow.

- Vital.Web.HTTP
- Vital.Web.JSON
- Vital.OptionParser
- [vim-prettyprint](https://github.com/thinca/vim-prettyprint)

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
