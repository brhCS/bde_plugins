" Vim plugin to cleanup a module according to BDE standards
" @author Ben Hipple
"
" @ dependencies:
source ~/.vim/bundle/bde_plugins/class_formatters.vim
source ~/.vim/bundle/bde_plugins/cpp_h_template.vim

" WIP (relative path sourcing)
"exec "source " . expand("%:p:h") . "/class_formatters.vim"
"exec "source " . expand("%:p:h") . "/cpp_h_template.vim"
"
function! Bde_Format(...)
    " Save current cursor location
    let lineNo=line('.')

    if(a:0 == 1 && a:1 == "clang")
        " TODO - just use the shellscript clang
        exec "silent w"
        cd %:h
        exec "!clang-format -i -style=file " . expand('%:t')

        " Visual selection doesn't seem to work
        "exec "normal! ggVG"
        "exec ":pyf ~/bin/clang-format.py<CR>"
    endif

    " Remove tabs and EOL whitespaces
    call StripTabsAndTrailingWhitespaces()

    " Fix filename and language tag
    let firstline = getline(1)
    let reg = '// ' . expand('%:t')
    normal! gg
    if(firstline !~ reg)
        put!=s:FilenameLanguageCommentTag()
    elseif(len(firstline) != 79)
        normal! dd
        put!=s:FilenameLanguageCommentTag()
    endif

    call FixIncludeGuard()

    " Proper class subsection indentation
    %s/^public:$/  public:/ge
    %s/^private:$/  private:/ge

    " Fix RCSID spacing
    %s/^\([A-Z]*_IDENT_RCSID([A-z_]*,\) /\1/ge

    " Restore line
    exec "normal! " . lineNo . "gg"
    exec "normal! zz"

endfunction

" Optional second argument specifies what character to use for comment (if not in C/C++)
function! CmtSection(title, ...)
    let commentChar = "/"
    if(a:0 == 1)
        let commentChar = a:1
    endif

    put!=s:CmtSection(a:title, commentChar)
endfunction

function! s:CmtSection(title, commentChar)
    let str = a:commentChar . a:commentChar . " ============================================================================\n"
    let str = str . a:commentChar . a:commentChar . " "

    let startCol = s:CenteredStringStartColumn(a:title) - strlen("// ") - 1
    let ct = 0
    while ct < startCol
        let str = str . " "
        let ct += 1
    endwhile

    let str = str . a:title . "\n"
    let str = str . a:commentChar . a:commentChar . " ============================================================================"
    return str
endfunction

" Find and return a list of [namespace string, line number] pairs
function! FindNamespaces()
    let curLine = 0
    let namespaces = []

    while(curLine < line('$'))
        if(getline(curLine) =~# '^namespace \w* \={')
            let namespaceParts = split(getline(curLine))
            if(len(namespaceParts) == 2)
                let nsName = "anonymous"
            else
                let nsName = namespaceParts[1]
            endif

            let namespaces += [[nsName, curLine]]
        endif
        let curLine += 1
    endwhile

    return namespaces
endfunction

function! FixIncludeGuard()
    " Only operate on header files
    if(expand('%:e') != 'h')
        return
    endif

    let correctGuard = 'INCLUDED_' . toupper(expand('%:t:r'))

    let curLine = 0
    let found = 0
    while(!found && curLine < line('$'))
        if(getline(curLine) =~# '^#ifndef \(INCLUDED_[A-Z_]\)')
            let incorrectGuard = (split(getline(curLine)))[1]
            exec '%s/' . incorrectGuard . '/' . correctGuard . '/ge'
            let found = 1
        endif
        let curLine += 1
    endwhile

    " BDE standard specify that #endif must not be followed by a comment
    %s/^#endif.*$/#endif/ge
endfunction

" =============================================================================
"                             Helper Functions
" =============================================================================
function! s:CenteredStringStartColumn(str)
    if strlen(a:str) >= 79
        return 0
    endif

    let midCol = 40
    let strMidptDist = strlen(a:str) / 2
    return midCol - strMidptDist
endfunction
