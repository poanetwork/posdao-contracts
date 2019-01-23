function s:A()
   set ff=unix eol fenc=UTF-8 nomore
   if &bin
      return
   elseif &ft ==# 'diff'
      g/\v^\+/ %s/\v\s+$//e
   else
      %s/\v\s+$//e
   endif
   w
endfunction
argdo call s:A()
q
