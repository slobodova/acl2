; VL Verilog Toolkit
; Copyright (C) 2008-2011 Centaur Technology
;
; Contact:
;   Centaur Technology Formal Verification Group
;   7600-C N. Capital of Texas Highway, Suite 300, Austin, TX 78731, USA.
;   http://www.centtech.com/
;
; This program is free software; you can redistribute it and/or modify it under
; the terms of the GNU General Public License as published by the Free Software
; Foundation; either version 2 of the License, or (at your option) any later
; version.  This program is distributed in the hope that it will be useful but
; WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
; FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
; more details.  You should have received a copy of the GNU General Public
; License along with this program; if not, write to the Free Software
; Foundation, Inc., 51 Franklin Street, Suite 500, Boston, MA 02110-1335, USA.
;
; Original author: Jared Davis <jared@centtech.com>

(in-package "VL")
(include-book "parse-statements-def")
;; (include-book "parse-statements-error")
(local (include-book "../util/arithmetic"))



(local (in-theory (disable
                   acl2-count-positive-when-consp
                   acl2::acl2-count-when-member-equal
                   (:type-prescription acl2-count)
                   consp-under-iff-when-true-listp
                   VL-IS-TOKEN?-FN-WHEN-NOT-CONSP-OF-TOKENS
                   double-containment
                   consp-by-len
                   consp-when-member-equal-of-cons-listp
                   member-equal-when-member-equal-of-cdr-under-iff
                   default-<-1 default-<-2
                   (:type-prescription vl-is-token?-fn)
                   (:type-prescription vl-is-some-token?-fn)
                   acl2::cancel_plus-lessp-correct
                   acl2::cancel_times-equal-correct
                   acl2::cancel_plus-equal-correct
                   vl-tokenlist-p-of-vl-match-token-fn
                   vl-parse-assignment-result
                   car-when-all-equalp
                   default-car default-cdr
                   acl2::subsetp-equal-member
                   (:rules-of-class :type-prescription :here))))


(local (defthm integerp-acl2-count
         (integerp (acl2-count x))
         :rule-classes :type-prescription))

(local (in-theory (disable (tau-system))))

(with-output
 :off prove :gag-mode :goals
 (make-event
  `(defthm-vl-flag-parse-statement vl-parse-statement-progress
     ,(vl-progress-claim vl-parse-case-item-fn)
     ,(vl-progress-claim vl-parse-1+-case-items-fn)
     ,(vl-progress-claim vl-parse-case-statement-fn
                         :extra-args (atts))
     ,(vl-progress-claim vl-parse-conditional-statement-fn
                         :extra-args (atts))
     ,(vl-progress-claim vl-parse-loop-statement-fn
                         :extra-args (atts))
     ,(vl-progress-claim vl-parse-par-block-fn
                         :extra-args (atts))
     ,(vl-progress-claim vl-parse-seq-block-fn
                         :extra-args (atts))
     ,(vl-progress-claim vl-parse-procedural-timing-control-statement-fn
                         :extra-args (atts))
     ,(vl-progress-claim vl-parse-wait-statement-fn
                         :extra-args (atts))
     ,(vl-progress-claim vl-parse-statement-aux-fn
                         :extra-args (atts))
     ,(vl-progress-claim vl-parse-statement-fn)
     ,(vl-progress-claim vl-parse-statement-or-null-fn)
     (vl-parse-statements-until-end-fn
      (and (<= (acl2-count (mv-nth 2 (vl-parse-statements-until-end-fn tokens warnings)))
               (acl2-count tokens))
           (implies (and (not (mv-nth 0 (vl-parse-statements-until-end-fn
                                         tokens warnings)))
                         (mv-nth 1 (vl-parse-statements-until-end-fn tokens warnings)))
                    (< (acl2-count (mv-nth 2 (vl-parse-statements-until-end-fn tokens warnings)))
                       (acl2-count tokens))))
      :rule-classes ((:rewrite) (:linear)))
     :hints(("Goal" :induct (vl-flag-parse-statement flag atts tokens warnings))
            '(:do-not '(simplify))
            (flag::expand-calls-computed-hint
             acl2::clause
             ',(flag::get-clique-members 'vl-parse-statement-fn
                                         (w state)))
            (and stable-under-simplificationp
                 '(:do-not nil))))))