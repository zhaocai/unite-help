" help source for unite.vim
" Version:     0.0.3
" Last Change: 03 Jul 2011.
" Author:      tsukkee <takayuki0510 at gmail.com>
" Licence:     The MIT License {{{
"     Permission is hereby granted, free of charge, to any person obtaining a copy
"     of this software and associated documentation files (the "Software"), to deal
"     in the Software without restriction, including without limitation the rights
"     to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
"     copies of the Software, and to permit persons to whom the Software is
"     furnished to do so, subject to the following conditions:
"
"     The above copyright notice and this permission notice shall be included in
"     all copies or substantial portions of the Software.
"
"     THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
"     IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
"     FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
"     AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
"     LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
"     OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
"     THE SOFTWARE.
" }}}

" define source
function! unite#sources#help#define()
    return unite#util#has_vimproc() ? s:source : {}
endfunction


" cache
let s:cache = []
function! unite#sources#help#refresh()
    let s:cache = []
endfunction
let s:vimproc_files = {}

" source
let s:source = {
\   'name': 'help',
\   'max_candidates': 50,
\   'action_table': {},
\   'default_action': { '*': 'execute' }
\}
function! s:source.gather_candidates(args, context)
    let should_refresh = a:context.is_redraw
    let lang_filter = []
    for arg in a:args
        if arg == '!'
            let should_refresh = 1
        endif

        if arg =~ '[a-z]\{2\}'
            call add(lang_filter, arg)
        endif
    endfor

    if should_refresh
        call unite#sources#help#refresh()
    endif

    if empty(s:cache)
        " load files.
        let s:vimproc_files = {}
        for tagfile in split(globpath(&runtimepath, 'doc/{tags,tags-*}'), "\n")
            if !filereadable(tagfile) | continue | endif

            let file = {
                        \ 'proc' : vimproc#fopen(tagfile, 'O_RDONLY'),
                        \ 'lang' : matchstr(tagfile, 'tags-\zs[a-z]\{2\}'),
                        \ 'path': fnamemodify(expand(tagfile), ':p:h:h:t'),
                        \ }
            let s:vimproc_files[tagfile] = file
        endfor
    endif

    let a:context.source__lang_filter = lang_filter
    let list = copy(s:cache)
    if !empty(a:context.source__lang_filter)
        call filter(list, 'empty(a:context.source__lang_filter)
                    \    || index(a:context.source__lang_filter, v:val.source__lang) != -1')
    endif

    return list
endfunction
function! s:source.async_gather_candidates(args, context)
    let list = []
    let cnt = 0
    for [key, file] in items(s:vimproc_files)
        while !file.proc.eof
            let line = file.proc.read_line()
            if line == '' || line[0] == '!'
                continue
            endif

            let name = split(line, "\t")[0]
            let word = name . '@' . (file.lang != '' ? file.lang : 'en')
            let abbr = printf("%s%s (in %s)",
                        \ name, ((file.lang != '') ? '@' . file.lang : ''), file.path)

            call add(list, {
                        \ 'word':   word,
                        \ 'abbr':   abbr,
                        \ 'action__command': 'help ' . word,
                        \ 'source__lang'   : file.lang != '' ? file.lang : 'en'
                        \})

            let cnt += 1
            if cnt > 400
                break
            endif
        endwhile

        if file.proc.eof
            call remove(s:vimproc_files, key)
        endif
    endfor

    if empty(s:vimproc_files)
        let a:context.is_async = 0
        call unite#print_message('[help] Completed.')
    endif
    let s:cache += list

    if !empty(a:context.source__lang_filter)
        call filter(list,
                    \   'empty(a:context.source__lang_filter)
                    \    || index(a:context.source__lang_filter, v:val.source__lang) != -1')
    endif

    return list
endfunction


" action
let s:action_table = {}

let s:action_table.execute = {
\   'description': 'lookup help'
\}
function! s:action_table.execute.func(candidate)
    let save_ignorecase = &ignorecase
    set noignorecase
    execute a:candidate.action__command
    let &ignorecase = save_ignorecase
endfunction

let s:action_table.tabopen = {
\   'description': 'open help in a new tab'
\}
function! s:action_table.tabopen.func(candidate)
    let save_ignorecase = &ignorecase
    set noignorecase
    execute 'tab' a:candidate.action__command
    let &ignorecase = save_ignorecase
endfunction

let s:source.action_table.common = s:action_table

" vim: expandtab:ts=4:sts=4:sw=4
