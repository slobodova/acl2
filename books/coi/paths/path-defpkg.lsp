; Computational Object Inference
; Copyright (C) 2005-2014 Kookamara LLC
;
; Contact:
;
;   Kookamara LLC
;   11410 Windermere Meadows
;   Austin, TX 78759, USA
;   http://www.kookamara.com/
;
; License: (An MIT/X11-style license)
;
;   Permission is hereby granted, free of charge, to any person obtaining a
;   copy of this software and associated documentation files (the "Software"),
;   to deal in the Software without restriction, including without limitation
;   the rights to use, copy, modify, merge, publish, distribute, sublicense,
;   and/or sell copies of the Software, and to permit persons to whom the
;   Software is furnished to do so, subject to the following conditions:
;
;   The above copyright notice and this permission notice shall be included in
;   all copies or substantial portions of the Software.
;
;   THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
;   IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
;   FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
;   AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
;   LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
;   FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
;   DEALINGS IN THE SOFTWARE.

(in-package "ACL2")

; (ld "Makefile.acl2")

(ld "../adviser/adviser-defpkg.lsp")
(ld "../lists/list-exports.lsp")
(ld "../alists/alist-defpkg.lsp")
(ld "../syntax/syn-defpkg.lsp")
(ld "../util/util-exports.lsp")

(defpkg "CPATH" ;(remove-duplicates-eql ;no longer necessary
		`(,@*acl2-exports*
		  ,@*common-lisp-symbols-from-main-lisp-package*
	          ,@LIST::*exports*
	          ,@*util-exports*

		  ;; BZO make an alist exports?
		  ALIST::alistfix
                  ;;ALIST::keys
                  ALIST::vals
                  ALIST::clr-key
                  ALIST::range
                  ALIST::pre-image-aux
                  ALIST::pre-image
		  ALIST::remove-shadowed-pairs
                  firstn
		  ADVISER::defadvice

                  ;; BZO these don't belong here at all, they are just
                  ;; here to make the records/path.lisp happy.
		  tag-location
		  failed-location
                  g s wfkey wfkeys wfr g-of-s-redux s-diff-s
		  SYN::defignore
		  SYN::defignored
		  SYN::defirrelevant
                ;  )
                ))
