; RTL - A Formal Theory of Register-Transfer Logic and Computer Arithmetic
; Copyright (C) 1995-2013 Advanced Mirco Devices, Inc.
;
; Contact:
;   David Russinoff
;   1106 W 9th St., Austin, TX 78703
;   http://www.russsinoff.com/
;
; This program is free software; you can redistribute it and/or modify it under
; the terms of the GNU General Public License as published by the Free Software
; Foundation; either version 2 of the License, or (at your option) any later
; version.
;
; This program is distributed in the hope that it will be useful but WITHOUT ANY
; WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A
; PARTICULAR PURPOSE.  See the GNU General Public License for more details.
;
; You should have received a copy of the GNU General Public License along with
; this program; see the file "gpl.txt" in this directory.  If not, write to the
; Free Software Foundation, Inc., 51 Franklin Street, Suite 500, Boston, MA
; 02110-1335, USA.
;
; Author: David M. Russinoff (david@russinoff.com)

(in-package "ACL2")

(set-enforce-redundancy t)

(local (include-book "../support/top"))

(set-inhibit-warnings "theory")
(local (in-theory nil))

;; From basic.lisp:

(defund fl (x)
  (declare (xargs :guard (real/rationalp x)))
  (floor x 1))

(defund cg (x)
  (declare (xargs :guard (real/rationalp x)))
  (- (fl (- x))))

;; From bits.lisp:

(defund bits (x i j)
  (declare (xargs :guard (and (integerp x)
                              (integerp i)
                              (integerp j))))
  (mbe :logic (if (or (not (integerp i))
                      (not (integerp j)))
                  0
                (fl (/ (mod x (expt 2 (1+ i))) (expt 2 j))))
       :exec  (if (< i j)
                  0
                (logand (ash x (- j)) (1- (ash 1 (1+ (- i j))))))))

(defund bitn (x n)
  (declare (xargs :guard (and (integerp x)
                              (integerp n))))
  (mbe :logic (bits x n n)
       :exec  (if (evenp (ash x (- n))) 0 1)))

;; From float.lisp:

(defund sgn (x)
  (declare (xargs :guard t))
  (if (or (not (rationalp x)) (equal x 0))
      0
    (if (< x 0) -1 +1)))

(defund expo (x)
  (declare (xargs :guard t
                  :measure (:? x)))
  (cond ((or (not (rationalp x)) (equal x 0)) 0)
	((< x 0) (expo (- x)))
	((< x 1) (1- (expo (* 2 x))))
	((< x 2) 0)
	(t (1+ (expo (/ x 2))))))

(defund sig (x)
  (declare (xargs :guard t))
  (if (rationalp x)
      (if (< x 0)
          (- (* x (expt 2 (- (expo x)))))
        (* x (expt 2 (- (expo x)))))
    0))

(defund exactp (x n)
  (integerp (* (sig x) (expt 2 (1- n)))))

(defun fp+ (x n)
  (+ x (expt 2 (- (1+ (expo x)) n))))

;; From reps.lisp:

(defund bias (q) (- (expt 2 (- q 1)) 1) )

(defund spn (q)
  (expt 2 (- 1 (bias q))))

(defund spd (p q)
     (expt 2 (+ 2 (- (bias q)) (- p))))

(defund drepp (x p q)
  (and (rationalp x)
       (not (= x 0))
       (<= (- 2 p) (+ (expo x) (bias q)))
       (<= (+ (expo x) (bias q)) 0)
       ;number of bits available in the sig field = p - 1 - ( - bias - expo(x))
       (exactp x (+ -2 p (expt 2 (- q 1)) (expo x)))))


;;;**********************************************************************
;;;                         Truncation
;;;**********************************************************************

(defsection-rtl |Truncation| |Rounding|

(defund rtz (x n)
  (declare (xargs :guard (integerp n)))
  (* (sgn x)
     (fl (* (expt 2 (1- n)) (sig x)))
     (expt 2 (- (1+ (expo x)) n))))

(defthmd rtz-rewrite
    (implies (and (rationalp x)
		  (integerp n)
		  (> n 0))
	     (equal (rtz x n)
		    (* (sgn x)
		       (fl (* (expt 2 (- (1- n) (expo x))) (abs x)))
		       (expt 2 (- (1+ (expo x)) n))))))

(defthm rtz-integer-type-prescription
  (implies (and (>= (expo x) n)
                (case-split (integerp n)))
           (integerp (rtz x n)))
  :rule-classes :type-prescription)

(defthm rtz-neg-bits
    (implies (and (integerp n)
		  (<= n 0))
	     (equal (rtz x n) 0)))

(defthmd sgn-rtz
    (implies (and (< 0 n)
                  (rationalp x)
		  (integerp n))
	     (equal (sgn (rtz x n))
		    (sgn x))))

(defthm rtz-positive
   (implies (and (< 0 x)
                 (case-split (rationalp x))
                 (case-split (integerp n))
                 (case-split (< 0 n)))
            (< 0 (rtz x n)))
   :rule-classes (:rewrite :linear))

(defthm rtz-negative
  (implies (and (< x 0)
                (case-split (rationalp x))
                (case-split (integerp n))
                (case-split (< 0 n)))
           (< (rtz x n) 0))
  :rule-classes (:rewrite :linear))

(defthm rtz-0
  (equal (rtz 0 n) 0))

(defthmd abs-rtz
  (equal (abs (rtz x n))
         (* (fl (* (expt 2 (1- n)) (sig x))) (expt 2 (- (1+ (expo x)) n)))))

(defthmd rtz-minus
  (equal (rtz (* -1 x) n) (* -1 (rtz x n))))

(defthmd rtz-shift
  (implies (integerp n)
           (equal (rtz (* x (expt 2 k)) n)
                  (* (rtz x n) (expt 2 k)))))

(defthmd rtz-upper-bound
    (implies (and (rationalp x)
		  (integerp n))
	     (<= (abs (rtz x n)) (abs x)))
  :rule-classes :linear)

(defthmd rtz-upper-pos
    (implies (and (<= 0 x)
                  (rationalp x)
		  (integerp n))
	     (<= (rtz x n) x))
  :rule-classes :linear)

(defthm expo-rtz
    (implies (and (< 0 n)
                  (rationalp x)
		  (integerp n))
	     (equal (expo (rtz x n))
                    (expo x))))

(defthmd rtz-lower-bound
    (implies (and (rationalp x)
		  (integerp n))
	     (> (abs (rtz x n)) (- (abs x) (expt 2 (- (1+ (expo x)) n)))))
  :rule-classes :linear)

(defthm rtz-diff
    (implies (and (rationalp x)
		  (integerp n)
                  (> n 0))
	     (< (abs (- x (rtz x n))) (expt 2 (- (1+ (expo x)) n))))
  :rule-classes ())

(defthm rtz-exactp-a
  (exactp (rtz x n) n))

(defthmd rtz-exactp-b
    (implies (and (rationalp x)
		  (integerp n)
		  (> n 0))
	     (iff (exactp x n)
                  (= x (rtz x n)))))

(defthm rtz-exactp-c
    (implies (and (exactp a n)
		  (<= a x)
                  (rationalp x)
		  (integerp n)
		  (rationalp a))
	     (<= a (rtz x n)))
  :rule-classes ())

(defthmd rtz-squeeze
  (implies (and (rationalp x)
                (rationalp a)
                (>= x a)
                (> a 0)
                (not (zp n))
                (exactp a n)
                (< x (fp+ a n)))
           (equal (rtz x n) a)))

(defthmd rtz-monotone
  (implies (and (<= x y)
                (rationalp x)
                (rationalp y)
                (integerp n))
           (<= (rtz x n) (rtz y n)))
  :rule-classes :linear)

(defthmd rtz-midpoint
    (implies (and (natp n)
		  (rationalp x) (> x 0)
		  (exactp x (1+ n))
		  (not (exactp x n)))
	     (equal (rtz x n)
                    (- x (expt 2 (- (expo x) n))))))

(defthm rtz-rtz
    (implies (and (>= n m)
                  (integerp n)
		  (integerp m))
	     (equal (rtz (rtz x n) m)
		    (rtz x m))))

(defthm plus-rtz
    (implies (and (rationalp x)
		  (>= x 0)
		  (rationalp y)
		  (>= y 0)
		  (integerp k)
		  (exactp x (+ k (- (expo x) (expo y)))))
	     (= (+ x (rtz y k))
		(rtz (+ x y) (+ k (- (expo (+ x y)) (expo y))))))
  :rule-classes ())

(defthm minus-rtz
    (implies (and (rationalp x)
		  (> x 0)
		  (rationalp y)
		  (> y 0)
		  (< x y)
		  (integerp k)
		  (> k 0)
		  (> (+ k (- (expo (- x y)) (expo y))) 0)
		  (= n (+ k (- (expo x) (expo y))))
		  (exactp x (+ k (- (expo x) (expo y)))))
	     (= (- x (rtz y k))
                (- (rtz (- y x) (+ k (- (expo (- x y)) (expo y)))))))
  :rule-classes ())

(defthmd bits-rtz
  (implies (and (= n (1+ (expo x)))
                (>= x 0)
                (integerp k)
                (> k 0))
           (equal (rtz x k)
                  (* (expt 2 (- n k))
                     (bits x (1- n) (- n k))))))

(defthmd bits-rtz-bits
  (implies (and (rationalp x)
                (>= x 0)
                (integerp k)
                (integerp i)
                (integerp j)
                (> k 0)
                (>= (expo x) i)
                (>= j (- (1+ (expo x)) k)))
           (equal (bits (rtz x k) i j)
                  (bits x i j))))

(defthmd rtz-split
  (implies (and (= n (1+ (expo x)))
                (>= x 0)
                (integerp m)
                (> m k)
                (integerp k)
                (> k 0))
           (equal (rtz x m)
                  (+ (rtz x k)
                     (* (expt 2 (- n m))
                        (bits x (1- (- n k)) (- n m)))))))

(defthmd rtz-logand
  (implies (and (>= x (expt 2 (1- n)))
                (< x (expt 2 n))
                (integerp x)
                (integerp m) (>= m n)
                (integerp n) (> n k)
                (integerp k) (> k 0))
           (equal (rtz x k)
                  (logand x (- (expt 2 m) (expt 2 (- n k)))))))
)

;;;**********************************************************************
;;;                    Rounding Away from Zero
;;;**********************************************************************

(defsection-rtl |Rounding Away from Zero| |Rounding|

(defund raz (x n)
  (* (sgn x)
     (cg (* (expt 2 (1- n)) (sig x)))
     (expt 2 (- (1+ (expo x)) n))))

(defthmd raz-rewrite
    (implies (and (rationalp x)
		  (integerp n)
		  (> n 0))
	     (equal (raz x n)
		    (* (sgn x)
		       (cg (* (expt 2 (- (1- n) (expo x))) (abs x)))
		       (expt 2 (- (1+ (expo x)) n))))))

(defthmd abs-raz
    (implies (and (rationalp x)
		  (integerp n))
	     (equal (abs (raz x n))
		    (* (cg (* (expt 2 (1- n)) (sig x))) (expt 2 (- (1+ (expo x)) n))))))

(defthm raz-integer-type-prescription
  (implies (and (>= (expo x) n)
                (case-split (integerp n)))
           (integerp (raz x n)))
  :rule-classes :type-prescription)

(defthmd sgn-raz
  (equal (sgn (raz x n))
         (sgn x)))

(defthm raz-positive
  (implies (and (< 0 x)
                (case-split (rationalp x)))
           (< 0 (raz x n)))
  :rule-classes (:rewrite :linear))

(defthm raz-negative
    (implies (and (< x 0)
                  (case-split (rationalp x)))
	     (< (raz x n) 0))
    :rule-classes (:rewrite :linear))

(defthm raz-0
  (equal (raz 0 n) 0))

(defthmd raz-minus
  (equal (raz (* -1 x) n) (* -1 (raz x n))))

(defthm raz-shift
    (implies (integerp n)
	     (= (raz (* x (expt 2 k)) n)
		(* (raz x n) (expt 2 k))))
  :rule-classes ())

(defthm raz-neg-bits
  (implies (and (<= n 0)
                (rationalp x)
                (integerp n))
           (equal (raz x n)
                  (* (sgn x) (expt 2 (+ 1 (expo x) (- n)))))))

(defthmd raz-lower-bound
    (implies (and (case-split (rationalp x))
		  (case-split (integerp n)))
	     (>= (abs (raz x n)) (abs x)))
  :rule-classes :linear)

(defthmd raz-lower-pos
    (implies (and (>= x 0)
                  (case-split (rationalp x))
		  (case-split (integerp n)))
	     (>= (raz x n) x))
  :rule-classes :linear)

(defthmd raz-upper-bound
    (implies (and (rationalp x)
		  (integerp n)
		  (> n 0))
	     (< (abs (raz x n)) (+ (abs x) (expt 2 (- (1+ (expo x)) n)))))
  :rule-classes :linear)

(defthmd raz-diff
    (implies (and (rationalp x)
		  (integerp n)
		  (> n 0))
	     (< (abs (- (raz x n) x)) (expt 2 (- (1+ (expo x)) n))))
  :rule-classes :linear)

(defthm raz-expo-upper
    (implies (and (rationalp x)
		  (not (= x 0))
		  (natp n))
	     (<= (abs (raz x n)) (expt 2 (1+ (expo x)))))
  :rule-classes ())

(defthmd expo-raz-upper-bound
    (implies (and (rationalp x)
		  (natp n))
	     (<= (expo (raz x n)) (1+ (expo x))))
  :rule-classes :linear)

(defthmd expo-raz-lower-bound
    (implies (and (rationalp x)
		  (natp n))
	     (>= (expo (raz x n)) (expo x)))
  :rule-classes :linear)

(defthmd expo-raz
    (implies (and (rationalp x)
		  (natp n)
		  (not (= (abs (raz x n)) (expt 2 (1+ (expo x))))))
	     (equal (expo (raz x n))
                    (expo x))))

(defthm raz-exactp-a
    (implies (case-split (< 0 n))
	     (exactp (raz x n) n)))

(defthmd raz-exactp-b
    (implies (and (rationalp x)
		  (integerp n)
		  (> n 0))
	     (iff (exactp x n)
                  (= x (raz x n)))))

(defthm raz-exactp-c
    (implies (and (exactp a n)
		  (>= a x)
                  (rationalp x)
		  (integerp n)
		  (> n 0)
		  (rationalp a))
	     (>= a (raz x n)))
  :rule-classes ())

(defthmd raz-squeeze
  (implies (and (rationalp x)
                (rationalp a)
                (> x a)
                (> a 0)
                (not (zp n))
                (exactp a n)
                (<= x (fp+ a n)))
           (equal (raz x n) (fp+ a n))))

(defthmd raz-monotone
    (implies (and (rationalp x)
		  (rationalp y)
		  (integerp n)
		  (<= x y))
	     (<= (raz x n) (raz y n)))
  :rule-classes :linear)

(defthmd rtz-raz
    (implies (and (rationalp x) (> x 0)
		  (integerp n) (> n 0)
		  (not (exactp x n)))
	     (equal (raz x n)
	            (+ (rtz x n)
		       (expt 2 (+ (expo x) 1 (- n)))))))

(defthmd raz-midpoint
    (implies (and (natp n)
		  (rationalp x) (> x 0)
		  (exactp x (1+ n))
		  (not (exactp x n)))
	     (equal (raz x n)
		    (+ x (expt 2 (- (expo x) n))))))

(defthmd raz-raz
    (implies (and (rationalp x)
		  (>= x 0)
		  (integerp n)
		  (integerp m)
		  (> m 0)
		  (>= n m))
	     (equal (raz (raz x n) m)
		    (raz x m))))

(defthm plus-raz
  (implies (and (exactp x (+ k (- (expo x) (expo y))))
                (rationalp x)
                (>= x 0)
                (rationalp y)
                (>= y 0)
                (integerp k))
           (= (+ x (raz y k))
              (raz (+ x y)
                    (+ k (- (expo (+ x y)) (expo y))))))
  :rule-classes ())

(defthm minus-rtz-raz
  (implies (and (rationalp x)
                (> x 0)
                (rationalp y)
                (> y 0)
                (< y x)
                (integerp k)
                (> k 0)
                (> (+ k (- (expo (- x y)) (expo y))) 0)
                (= n (+ k (- (expo x) (expo y)))) ;; why we need "n"??
                (exactp x (+ k (- (expo x) (expo y)))))
           (= (- x (rtz y k))
              (raz (- x y) (+ k (- (expo (- x y)) (expo y))))))
  :rule-classes ())

(defthm rtz-plus-minus
    (implies (and (rationalp x)
                  (rationalp y)
                  (not (= x 0))
                  (not (= y 0))
                  (not (= (+ x y) 0))
                  (integerp k)
                  (> k 0)
                  (= k1 (+ k (- (expo x) (expo y))))
                  (= k2 (+ k (expo (+ x y)) (* -1 (expo y))))
                  (exactp x k1)
                  (> k2 0))
             (= (+ x (rtz y k))
                (if (= (sgn (+ x y)) (sgn y))
                    (rtz (+ x y) k2)
                  (raz (+ x y) k2))))
  :rule-classes ())

(defthmd raz-imp
    (implies (and (rationalp x)
		  (> x 0)
		  (integerp n)
		  (> n 0)
		  (integerp m)
		  (>= m n)
		  (exactp x m))
	     (equal (raz x n)
		    (rtz (+ x
		    	    (expt 2 (- (1+ (expo x)) n))
			    (- (expt 2 (- (1+ (expo x)) m))))
		         n))))
)

;;;**********************************************************************
;;;                    Unbiased Rounding
;;;**********************************************************************

(defsection-rtl |Unbiased Rounding| |Rounding|

(defun re (x)
  (- x (fl x)))

(defund rne (x n)
  (let ((z (fl (* (expt 2 (1- n)) (sig x))))
	(f (re (* (expt 2 (1- n)) (sig x)))))
    (if (< f 1/2)
	(rtz x n)
      (if (> f 1/2)
	  (raz x n)
	(if (evenp z)
	    (rtz x n)
	  (raz x n))))))

(defthm rne-choice
    (or (= (rne x n) (rtz x n))
	(= (rne x n) (raz x n)))
  :rule-classes ())

(defthmd sgn-rne
    (implies (and (rationalp x)
		  (integerp n)
		  (> n 0))
	     (equal (sgn (rne x n))
		    (sgn x))))

(defthm rne-positive
    (implies (and (< 0 x)
                  (< 0 n)
                  (rationalp x)
		  (integerp n))
	     (< 0 (rne x n)))
  :rule-classes (:type-prescription :linear))

(defthmd rne-negative
  (implies (and (< x 0)
                (< 0 n)
                (rationalp x)
                (integerp n))
           (< (rne x n) 0))
  :rule-classes (:type-prescription :linear))

(defthm rne-0
  (equal (rne 0 n) 0))

(defthm rne-exactp-a
    (implies (< 0 n)
	     (exactp (rne x n) n)))

(defthmd rne-exactp-b
    (implies (and (rationalp x)
		  (integerp n)
		  (> n 0))
	     (iff (exactp x n)
                  (= x (rne x n)))))

(defthm rne-exactp-c
    (implies (and (exactp a n)
		  (>= a x)
                  (rationalp x)
		  (integerp n)
		  (> n 0)
		  (rationalp a))
	     (>= a (rne x n)))
  :rule-classes ())

(defthm rne-exactp-d
    (implies (and (rationalp x)
		  (integerp n)
		  (> n 0)
		  (rationalp a)
		  (exactp a n)
		  (<= a x))
	     (<= a (rne x n)))
  :rule-classes ())

(defthm expo-rne
    (implies (and (rationalp x)
		  (> n 0)
                  (integerp n)
		  (not (= (abs (rne x n)) (expt 2 (1+ (expo x))))))
	     (equal (expo (rne x n))
                    (expo x))))

(defthm rne<=raz
    (implies (and (rationalp x)
		  (> x 0)
		  (integerp n)
		  (> n 0))
	     (<= (rne x n) (raz x n)))
  :rule-classes ())

(defthm rne>=rtz
    (implies (and (rationalp x)
		  (> x 0)
		  (integerp n)
		  (> n 0))
	     (>= (rne x n) (rtz x n)))
  :rule-classes ())

(defthm rne-shift
    (implies (and (rationalp x)
                  (integerp n)
		  (integerp k))
	     (= (rne (* x (expt 2 k)) n)
		(* (rne x n) (expt 2 k))))
  :rule-classes ())

(defthmd rne-minus
  (equal (rne (* -1 x) n) (* -1 (rne x n))))

(defthmd rne-rtz
    (implies (and (< (abs (- x (rtz x n)))
                     (abs (- (raz x n) x)))
                  (rationalp x)
		  (integerp n))
	     (equal (rne x n)
                    (rtz x n))))

(defthmd rne-raz
  (implies (and (> (abs (- x (rtz x n)))
                   (abs (- (raz x n) x)))
                (rationalp x)
                (integerp n))
           (equal (rne x n)
                  (raz x n))))

(defthmd rne-down
  (implies (and (rationalp x)
                (rationalp a)
                (>= x a)
                (> a 0)
                (not (zp n))
                (exactp a n)
                (< x (+ a (expt 2 (- (expo a) n)))))
           (equal (rne x n) a)))

(defthmd rne-up
  (implies (and (rationalp x)
                (rationalp a)
                (> a 0)
                (not (zp n))
                (exactp a n)
                (< x (fp+ a n))
                (> x (+ a (expt 2 (- (expo a) n)))))
           (equal (rne x n) (fp+ a n))))

(defthm rne-nearest
    (implies (and (exactp y n)
                  (rationalp x)
		  (rationalp y)
		  (integerp n)
		  (> n 0))
	     (>= (abs (- x y)) (abs (- x (rne x n)))))
  :rule-classes ())

(defthm rne-diff
    (implies (and (integerp n)
		  (> n 0)
		  (rationalp x))
	     (<= (abs (- x (rne x n)))
		 (expt 2 (- (expo x) n))))
  :rule-classes ())

(defthm rne-diff-cor
    (implies (and (integerp n)
		  (> n 0)
		  (rationalp x))
	     (<= (abs (- x (rne x n)))
		 (* (abs x) (expt 2 (- n)))))
  :rule-classes ())

(defthm rne-monotone
    (implies (and (<= x y)
                  (rationalp x)
		  (rationalp y)
		  (integerp n)
		  (> n 0))
	     (<= (rne x n) (rne y n)))
  :rule-classes ())

(defund rne-witness (x y n)
  (if (= (expo x) (expo y))
      (/ (+ (rne x n) (rne y n)) 2)
    (expt 2 (expo y))))

(defthm rne-rne-lemma
    (implies (and (rationalp x)
		  (rationalp y)
		  (< 0 x)
		  (< x y)
		  (integerp n)
		  (> n 0)
		  (not (= (rne x n) (rne y n))))
	     (and (<= x (rne-witness x y n))
		  (<= (rne-witness x y n) y)
		  (exactp (rne-witness x y n) (1+ n))))
  :rule-classes ())

(defthm rne-rne
    (implies (and (rationalp x)
		  (rationalp y)
		  (rationalp a)
		  (integerp n)
		  (integerp k)
		  (> k 0)
		  (>= n k)
		  (< 0 a)
		  (< a x)
		  (< 0 y)
		  (< y (fp+ a (1+ n)))
		  (exactp a (1+ n)))
	     (<= (rne y k) (rne x k)))
  :rule-classes ())

(defthm rne-boundary
    (implies (and (rationalp x)
		  (rationalp y)
		  (rationalp a)
		  (< 0 x)
		  (< x a)
		  (< a y)
		  (integerp n)
		  (> n 0)
		  (exactp a (1+ n))
		  (not (exactp a n)))
	     (< (rne x n) (rne y n)))
  :rule-classes ())

(defthm rne-exact
    (implies (and (rationalp x)
		  (integerp n)
		  (> n 1)
		  (exactp x (1+ n))
		  (not (exactp x n)))
	     (exactp (rne x n) (1- n)))
  :rule-classes ())

(defund rna (x n)
  (if (< (re (* (expt 2 (1- n)) (sig x)))
	 1/2)
      (rtz x n)
    (raz x n)))

(defthm rna-choice
    (or (= (rna x n) (rtz x n))
	(= (rna x n) (raz x n)))
  :rule-classes ())

(defthm sgn-rna
    (implies (and (rationalp x)
		  (integerp n)
		  (> n 0))
	     (equal (sgn (rna x n))
		    (sgn x))))

(defthm rna-positive
  (implies (and (rationalp x)
                (> x 0)
                (integerp n)
                (> n 0))
           (> (rna x n) 0))
  :rule-classes :linear)

(defthm rna-negative
    (implies (and (< x 0)
                  (rationalp x)
		  (integerp n)
		  (> n 0))
	     (< (rna x n) 0))
  :rule-classes :linear)

(defthm rna-0
  (equal (rna 0 n) 0))

(defthm rna-exactp-a
    (implies (> n 0)
	     (exactp (rna x n) n)))

(defthmd rna-exactp-b
    (implies (and (rationalp x)
		  (integerp n)
		  (> n 0))
	     (iff (exactp x n)
                  (= x (rna x n)))))

(defthm rna-exactp-c
    (implies (and (rationalp x)
		  (integerp n)
		  (> n 0)
		  (rationalp a)
		  (exactp a n)
		  (>= a x))
	     (>= a (rna x n)))
  :rule-classes ())

(defthm rna-exactp-d
    (implies (and (rationalp x)
		  (integerp n)
		  (> n 0)
		  (rationalp a)
		  (exactp a n)
		  (<= a x))
	     (<= a (rna x n)))
  :rule-classes ())

(defthmd expo-rna
    (implies (and (rationalp x)
		  (natp n)
		  (not (= (abs (rna x n)) (expt 2 (1+ (expo x))))))
	     (equal (expo (rna x n))
                    (expo x))))

(defthm rna<=raz
    (implies (and (rationalp x)
		  (> x 0)
		  (integerp n)
		  (> n 0))
	     (<= (rna x n) (raz x n)))
  :rule-classes ())

(defthm rna>=rtz
    (implies (and (rationalp x)
		  (> x 0)
		  (integerp n)
		  (> n 0))
	     (>= (rna x n) (rtz x n)))
  :rule-classes ())

(defthm rna-shift
    (implies (and (rationalp x)
		  (integerp n)
		  (integerp k))
	     (= (rna (* x (expt 2 k)) n)
		(* (rna x n) (expt 2 k))))
  :rule-classes ())

(defthmd rna-minus
  (equal (rna (* -1 x) n) (* -1 (rna x n))))

(defthmd rna-rtz
    (implies (and (rationalp x)
		  (integerp n)
		  (< (abs (- x (rtz x n)))
                     (abs (- (raz x n) x))))
	     (equal (rna x n) (rtz x n))))

(defthmd rna-raz
    (implies (and (rationalp x)
		  (integerp n)
		  (> (abs (- x (rtz x n)))
                     (abs (- (raz x n) x))))
	     (equal (rna x n) (raz x n))))

(defthm rna-nearest
    (implies (and (exactp y n)
                  (rationalp x)
                  (rationalp y)
		  (integerp n)
		  (> n 0))
	     (>= (abs (- x y)) (abs (- x (rna x n)))))
  :rule-classes ())

(defthm rna-diff
    (implies (and (integerp n)
		  (> n 0)
		  (rationalp x))
	     (<= (abs (- x (rna x n)))
		 (expt 2 (- (expo x) n))))
  :rule-classes ())

(defthm rna-monotone
  (implies (and (<= x y)
                (rationalp x)
                (rationalp y)
                (natp n))
           (<= (rna x n) (rna y n)))
  :rule-classes ())

(defund rna-witness (x y n)
  (if (= (expo x) (expo y))
      (/ (+ (rna x n) (rna y n)) 2)
    (expt 2 (expo y))))

(defthm rna-rna-lemma
    (implies (and (rationalp x)
		  (rationalp y)
		  (< 0 x)
		  (< x y)
		  (integerp n)
		  (> n 0)
		  (not (= (rna x n) (rna y n))))
	     (and (<= x (rna-witness x y n))
		  (<= (rna-witness x y n) y)
		  (exactp (rna-witness x y n) (1+ n))))
  :rule-classes ())

(defthm rna-rna
    (implies (and (rationalp x)
		  (rationalp y)
		  (rationalp a)
		  (integerp n)
		  (integerp k)
		  (> k 0)
		  (>= n k)
		  (< 0 a)
		  (< a x)
		  (< 0 y)
		  (< y (fp+ a (1+ n)))
		  (exactp a (1+ n)))
	     (<= (rna y k) (rna x k)))
  :rule-classes ())

(defthmd rna-midpoint
    (implies (and (rationalp x)
		  (integerp n)
		  (exactp x (1+ n))
		  (not (exactp x n)))
	     (equal (rna x n) (raz x n))))

(defthm rne-power-2
    (implies (and (rationalp x) (> x 0)
		  (integerp n) (> n 1)
		  (>= (+ x (expt 2 (- (expo x) n)))
		      (expt 2 (1+ (expo x)))))
	     (= (rne x n)
		(expt 2 (1+ (expo x)))))
  :rule-classes ())

(defthm rtz-power-2
    (implies (and (rationalp x) (> x 0)
		  (integerp n) (> n 1)
		  (>= (+ x (expt 2 (- (expo x) n)))
		      (expt 2 (1+ (expo x)))))
	     (= (rtz (+ x (expt 2 (- (expo x) n))) n)
		(expt 2 (1+ (expo x)))))
  :rule-classes ())

(defthm rna-power-2
    (implies (and (rationalp x) (> x 0)
		  (integerp n) (> n 1)
		  (>= (+ x (expt 2 (- (expo x) n)))
		      (expt 2 (1+ (expo x)))))
	     (= (rna x n)
		(expt 2 (1+ (expo x)))))
  :rule-classes ())

(defthm plus-rne
  (implies (and (exactp x (1- (+ k (- (expo x) (expo y)))))
                (rationalp x)
                (>= x 0)
                (rationalp y)
                (>= y 0)
                (integerp k))
           (= (+ x (rne y k))
              (rne (+ x y)
                    (+ k (- (expo (+ x y)) (expo y))))))
  :rule-classes ())

(defthm plus-rna
  (implies (and (exactp x (+ k (- (expo x) (expo y))))
                (rationalp x)
                (>= x 0)
                (rationalp y)
                (>= y 0)
                (integerp k))
           (= (+ x (rna y k))
              (rna (+ x y)
                    (+ k (- (expo (+ x y)) (expo y))))))
  :rule-classes ())

(defthmd rne-imp
    (implies (and (rationalp x) (> x 0)
		  (integerp n) (> n 1))
	     (equal (rne x n)
		    (if (and (exactp x (1+ n)) (not (exactp x n)))
		        (rtz (+ x (expt 2 (- (expo x) n))) (1- n))
		      (rtz (+ x (expt 2 (- (expo x) n))) n)))))

(defthmd rna-imp
    (implies (and (rationalp x)
		  (> x 0)
		  (integerp n)
		  (> n 0))
	     (equal (rna x n)
		    (rtz (+ x (expt 2 (- (expo x) n))) n))))

(defthmd rna-imp-cor
    (implies (and (rationalp x)
		  (integerp m)
		  (integerp n)
                  (> n m)
		  (> m 0))
	     (equal (rna (rtz x n) m)
                    (rna x m))))
)

;;;**********************************************************************
;;;                          Odd Rounding
;;;**********************************************************************

(defsection-rtl |Odd Rounding| |Rounding|

(defund rto (x n)
  (if (exactp x (1- n))
      x
    (+ (rtz x (1- n))
       (* (sgn x) (expt 2 (1+ (- (expo x) n)))))))

(defthm sgn-rto
    (implies (and (rationalp x)
		  (integerp n)
		  (> n 0))
	     (equal (sgn (rto x n))
		    (sgn x))))

(defthmd rto-positive
    (implies (and (< 0 x)
                  (rationalp x)
		  (integerp n)
                  (> n 0))
	     (> (rto x n) 0))
  :rule-classes :linear)

(defthmd rto-negative
    (implies (and (< x 0)
                  (rationalp x)
		  (integerp n)
                  (> n 0))
	     (< (rto x n) 0))
  :rule-classes :linear)

(defthm rto-0
  (equal (rto 0 n) 0))

(defthmd rto-minus
  (equal (rto (* -1 x) n) (* -1 (rto x n))))

(defthm rto-shift
    (implies (and (rationalp x)
		  (integerp n) (> n 0)
		  (integerp k))
	     (= (rto (* (expt 2 k) x) n)
		(* (expt 2 k) (rto x n))))
  :rule-classes ())

(defthm expo-rto
    (implies (and (rationalp x) ;; (> x 0)
		  (integerp n) (> n 0))
	     (equal (expo (rto x n))
		    (expo x))))

(defthm rto-exactp-a
    (implies (and (rationalp x)
		  (integerp n) (> n 0))
	     (exactp (rto x n) n)))

(defthmd rto-exactp-b
    (implies (and (rationalp x)
		  (integerp n)
		  (> n 0))
	     (iff (exactp x n)
                  (= x (rto x n)))))

(defthmd rto-monotone
  (implies (and (<= x y)
                (rationalp x)
                (rationalp y)
                (natp n))
           (<= (rto x n) (rto y n)))
  :rule-classes :linear)

(defthm rto-exactp-c
    (implies (and (rationalp x)
		  (integerp m)
		  (integerp n)
		  (> n m)
		  (> m 0))
	     (iff (exactp (rto x n) m)
		  (exactp x m))))

(defthm rtz-rto
    (implies (and (rationalp x)
		  (integerp m) (> m 0)
		  (integerp n) (> n m))
	     (equal (rtz (rto x n) m)
		    (rtz x m))))

(defthm raz-rto
    (implies (and (rationalp x)
		  (integerp m) (> m 0)
		  (integerp n) (> n m))
	     (equal (raz (rto x n) m)
		    (raz x m))))

(defthm rne-rto
    (implies (and (rationalp x)
		  (integerp m) (> m 0)
		  (integerp n) (> n (1+ m)))
	     (equal (rne (rto x n) m)
		    (rne x m))))

(defthm rna-rto
    (implies (and (rationalp x)
		  (integerp m) (> m 0)
		  (integerp n) (> n (1+ m)))
	     (equal (rna (rto x n) m)
		    (rna x m))))

(defthm rto-rto
    (implies (and (rationalp x)
		  (integerp m)
		  (> m 1)
		  (integerp n)
		  (>= n m))
	     (equal (rto (rto x n) m)
		    (rto x m))))

(defthm rto-plus
    (implies (and (rationalp x)
		  (rationalp y)
		  (not (= y 0))
		  (not (= (+ x y) 0))
		  (integerp k)
		  (= k1 (+ k (- (expo x) (expo y))))
		  (= k2 (+ k (- (expo (+ x y)) (expo y))))
		  (> k 1)
		  (> k1 1)
		  (> k2 1)
		  (exactp x (1- k1)))
	     (= (+ x (rto y k))
		(rto (+ x y) k2)))
  :rule-classes ())
)

;;;**********************************************************************
;;;                    IEEE Rounding
;;;**********************************************************************

(defsection-rtl |IEEE Rounding| |Rounding|

(defun rup (x n)
  (if (>= x 0)
      (raz x n)
    (rtz x n)))

(defun rdn (x n)
  (if (>= x 0)
      (rtz x n)
    (raz x n)))

(defthmd rup-lower-bound
    (implies (and (case-split (rationalp x))
		  (case-split (integerp n)))
	     (>= (rup x n) x))
  :rule-classes :linear)

(defthmd rdn-lower-bound
    (implies (and (case-split (rationalp x))
		  (case-split (integerp n)))
	     (<= (rdn x n) x))
  :rule-classes :linear)

(defund IEEE-rounding-mode-p (mode)
  (member mode '(rtz rup rdn rne)))

(defund common-mode-p (mode)
  (or (IEEE-rounding-mode-p mode) (equal mode 'raz) (equal mode 'rna)))

(defthm ieee-mode-is-common-mode
  (implies (IEEE-rounding-mode-p mode)
           (common-mode-p mode)))

(defund rnd (x mode n)
  (case mode
    (raz (raz x n))
    (rna (rna x n))
    (rtz (rtz x n))
    (rup (rup x n))
    (rdn (rdn x n))
    (rne (rne x n))
    (otherwise 0)))

(defthm rationalp-rnd
  (rationalp (rnd x mode n))
  :rule-classes (:type-prescription))

(defthm rnd-choice
  (implies (and (rationalp x)
                (integerp n)
                (common-mode-p mode))
           (or (= (rnd x mode n) (rtz x n))
	       (= (rnd x mode n) (raz x n))))
  :rule-classes ())

(defthmd sgn-rnd
    (implies (and (common-mode-p mode)
		  (integerp n)
		  (> n 0))
	     (equal (sgn (rnd x mode n))
		    (sgn x))))

(defthm rnd-positive
  (implies (and (< 0 x)
                (rationalp x)
                (integerp n)
                (> n 0)
                (common-mode-p mode))
           (> (rnd x mode n) 0))
  :rule-classes (:type-prescription))

(defthm rnd-negative
    (implies (and (< x 0)
                  (rationalp x)
		  (integerp n)
		  (> n 0)
		  (common-mode-p mode))
	     (< (rnd x mode n) 0))
  :rule-classes (:type-prescription))

(defthm rnd-0
  (equal (rnd 0 mode n) 0))

(defthm rnd-non-pos
    (implies (<= x 0)
	     (<= (rnd x mode n) 0))
  :rule-classes (:rewrite :type-prescription :linear))

(defthm rnd-non-neg
    (implies (<= 0 x)
	     (<= 0 (rnd x mode n)))
  :rule-classes (:rewrite :type-prescription :linear))

(defund flip-mode (m)
  (case m
    (rup 'rdn)
    (rdn 'rup)
    (t m)))

(defthm ieee-rounding-mode-p-flip-mode
    (implies (ieee-rounding-mode-p m)
	     (ieee-rounding-mode-p (flip-mode m))))

(defthm common-mode-p-flip-mode
    (implies (common-mode-p m)
	     (common-mode-p (flip-mode m))))

(defthmd rnd-minus
  (equal (rnd (* -1 x) mode n)
         (* -1 (rnd x (flip-mode mode) n))))

(defthm rnd-exactp-a
    (implies (< 0 n)
	     (exactp (rnd x mode n) n)))

(defthmd rnd-exactp-b
  (implies (and (rationalp x)
                (common-mode-p mode)
                (integerp n)
                (> n 0))
           (equal (exactp x n)
                  (equal x (rnd x mode n)))))

(defthm rnd-exactp-c
    (implies (and (rationalp x)
		  (common-mode-p mode)
		  (integerp n)
		  (> n 0)
		  (rationalp a)
		  (exactp a n)
		  (>= a x))
	     (>= a (rnd x mode n)))
  :rule-classes ())

(defthm rnd-exactp-d
    (implies (and (rationalp x)
		  (common-mode-p mode)
		  (integerp n)
		  (> n 0)
		  (rationalp a)
		  (exactp a n)
		  (<= a x))
	     (<= a (rnd x mode n)))
  :rule-classes ())

(defthm rnd<=raz
    (implies (and (rationalp x)
		  (>= x 0)
		  (common-mode-p mode)
		  (natp n))
	     (<= (rnd x mode n) (raz x n)))
  :rule-classes ())

(defthm rnd>=rtz
    (implies (and (rationalp x)
		  (> x 0) ;;
		  (common-mode-p mode)
                  (integerp n)
                  (> n 0))
	     (>= (rnd x mode n) (rtz x n)))
  :rule-classes ())

(defthm rnd<equal
  (implies (and (rationalp x)
                (rationalp y)
                (natp n)
                (common-mode-p mode)
                (> n 0)
                (> x 0)
                (not (exactp x (1+ n)))
                (< (rtz x (1+ n)) y)
                (< y x))
           (= (rnd y mode n) (rnd x mode n)))
  :rule-classes ()
  :hints (("Goal" :use (fp-rnd<equal
                        (:instance rna-rna (y x) (x y) (k n) (a (rtz x (1+ n))))))))

(defthm rnd>equal
  (implies (and (rationalp x)
                (rationalp y)
                (natp n)
                (common-mode-p mode)
                (> n 0)
                (> x 0)
                (not (exactp x (1+ n)))
                (> (raz x (1+ n)) y)
                (> y x))
           (= (rnd y mode n) (rnd x mode n)))
  :rule-classes ()
  :hints (("Goal" :use fp-rnd>equal)))

(defthm rnd-near-equal
  (implies (and (rationalp x)
                (rationalp y)
                (natp n)
                (common-mode-p mode)
                (> n 0)
                (> x 0)
                (not (exactp x (1+ n))))
           (let ((d (min (- x (rtz x (1+ n))) (- (raz x (1+ n)) x))))
             (and (> d 0)
                  (implies (< (abs (- x y)) d)
                           (= (rnd y mode n) (rnd x mode n))))))
  :rule-classes ()
  :hints (("Goal" :use fp-rnd-near-equal)))

(defthmd expo-rnd
    (implies (and (rationalp x)
		  (integerp n)
		  (> n 0)
		  (common-mode-p mode)
		  (not (= (abs (rnd x mode n))
			  (expt 2 (1+ (expo x))))))
	     (equal (expo (rnd x mode n))
		    (expo x))))

(defthm rnd-monotone
    (implies (and (<= x y)
                  (rationalp x)
		  (rationalp y)
		  (common-mode-p mode)
                  (INTEGERP N)
                  (> N 0))
	     (<= (rnd x mode n) (rnd y mode n)))
  :rule-classes ())

(defthm rnd-shift
    (implies (and (rationalp x)
		  (integerp n)
		  (common-mode-p mode)
		  (integerp k))
	     (= (rnd (* x (expt 2 k)) mode n)
		(* (rnd x mode n) (expt 2 k))))
  :rule-classes ())

(defthm plus-rnd
  (implies (and (rationalp x)
                (>= x 0)
                (rationalp y)
                (>= y 0)
                (integerp k)
                (exactp x (+ -1 k (- (expo x) (expo y))))
                (common-mode-p mode))
           (= (+ x (rnd y mode k))
              (rnd (+ x y)
                   mode
                   (+ k (- (expo (+ x y)) (expo y))))))
  :rule-classes ())

(defthmd rnd-rto
  (implies (and (common-mode-p mode)
                (rationalp x)
                (integerp m)
		(> m 0)
                (integerp n)
		(>= n (+ m 2)))
           (equal (rnd (rto x n) mode m)
                  (rnd x mode m))))

(defun rnd-const (e mode n)
  (case mode
    ((rne rna) (expt 2 (- e n)))
    ((rup raz) (1- (expt 2 (1+ (- e n)))))
    (otherwise 0)))

(defthmd rnd-const-thm
    (implies (and (common-mode-p mode)
		  (integerp n)
		  (> n 1)
		  (integerp x)
		  (> x 0)
		  (>= (expo x) n))
	     (equal (rnd x mode n)
		    (if (and (eql mode 'rne)
			     (exactp x (1+ n))
                             (not (exactp x n)))
                        (rtz (+ x (rnd-const (expo x) mode n)) (1- n))
                      (rtz (+ x (rnd-const (expo x) mode n)) n)))))

(defund round-up-p (x sticky mode n)
  (case mode
    (rna (= (bitn x (- (expo x) n)) 1))
    (rne (and (= (bitn x (- (expo x) n)) 1)
               (or (not (= (bits x (- (expo x) (1+ n)) 0) 0))
                   (= sticky 1)
                   (= (bitn x (- (1+ (expo x)) n)) 1))))
    ((rup raz) (or (not (= (bits x (- (expo x) n) 0) 0))
                   (= sticky 1)))
    (otherwise ())))

(defthmd round-up-p-thm
  (implies (and (common-mode-p mode)
                (rationalp z)
                (> z 0)
                (not (zp n))
                (natp k)
                (< n k)
                (<= k (1+ (expo z))))
           (let* ((x (rtz z k))
                  (sticky (if (< x z) 1 0)))
	     (equal (rnd z mode n)
                    (if (round-up-p x sticky mode n)
                        (fp+ (rtz z n) n)
                      (rtz z n))))))
)

;;;**********************************************************************
;;;                         Denormal Rounding
;;;**********************************************************************

(defsection-rtl |Denormal Rounding| |Rounding|

(defund drnd (x mode p q)
  (rnd x mode (+ p (expo x) (- (expo (spn q))))))

(defthmd drnd-minus
  (equal (drnd (* -1 x) mode p q)
         (* -1 (drnd x (flip-mode mode) p q))))

(defthm drnd-exactp-a
  (implies (and (rationalp x)
                (<= (abs x) (spn q))
                (integerp p)
                (> p 1)
                (integerp q)
                (> q 0)
                (common-mode-p mode))
           (or (drepp (drnd x mode p q) p q)
               (= (drnd x mode p q) 0)
               (= (drnd x mode p q) (* (sgn x) (spn q)))))
  :rule-classes ())

(defthmd drnd-exactp-b
  (implies (and (rationalp x)
	        (drepp x p q)
                (integerp p)
                (> p 1)
                (integerp q)
                (> q 0)
                (common-mode-p mode))
           (equal (drnd x mode p q)
                  x)))

(defthm drnd-exactp-c
  (implies (and (rationalp x)
                (<= (abs x) (spn q))
		(rationalp a)
                (drepp a p q)
		(>= a x)
                (integerp p)
                (> p 1)
                (integerp q)
                (> q 0)
                (common-mode-p mode))
           (>= a (drnd x mode p q)))
  :rule-classes ())

(defthm drnd-exactp-d
  (implies (and (rationalp x)
                (<= (abs x) (spn q))
		(rationalp a)
                (drepp a p q)
		(<= a x)
                (integerp p)
                (> p 1)
                (integerp q)
                (> q 0)
                (common-mode-p mode))
           (<= a (drnd x mode p q)))
  :rule-classes ())

(defthm drnd-rtz
  (implies (and (integerp p)
                (> p 1)
                (integerp q)
                (> q 0)
                (rationalp x)
                (<= (abs x) (spn q)))
           (<= (abs (drnd x 'rtz p q))
               (abs x)))
  :rule-classes ())

(defthm drnd-raz
  (implies (and (integerp p)
                (> p 1)
                (integerp q)
                (> q 0)
                (rationalp x)
                (<= (abs x) (spn q)))
           (>= (abs (drnd x 'raz p q))
               (abs x)))
  :rule-classes ())

(defthm drnd-rdn
  (implies (and (integerp p)
                (> p 1)
                (integerp q)
                (> q 0)
                (rationalp x)
                (<= (abs x) (spn q)))
           (<= (drnd x 'rdn p q)
               x))
  :rule-classes ())

(defthm drnd-rup
  (implies (and (integerp p)
                (> p 1)
                (integerp q)
                (> q 0)
                (rationalp x)
                (<= (abs x) (spn q)))
           (>= (drnd x 'rup p q)
               x))
  :rule-classes ())

(defthm drnd-diff
  (implies (and (rationalp x)
                (<= (abs x) (spn q))
                (integerp p)
                (> p 1)
                (integerp q)
                (> q 0)
                (common-mode-p mode))
           (< (abs (- x (drnd x mode p q))) (spd p q)))
  :rule-classes ())

(defthm drnd-rne-diff
  (implies (and (rationalp x)
                (<= (abs x) (spn q))
                (integerp p)
                (> p 1)
                (integerp q)
                (> q 0)
                (drepp a p q))
           (>= (abs (- x a)) (abs (- x (drnd x 'rne p q)))))
  :rule-classes ())

(defthm drnd-rna-diff
  (implies (and (rationalp x)
                (<= (abs x) (spn q))
                (integerp p)
                (> p 1)
                (integerp q)
                (> q 0)
                (drepp a p q))
           (>= (abs (- x a)) (abs (- x (drnd x 'rna p q)))))
  :rule-classes ())

(defthmd drnd-rto
    (implies (and (common-mode-p mode)
		  (natp p)
		  (> p 1)
		  (natp q)
		  (> q 0)
		  (rationalp x)
                  (<= (abs x) (spn q))
		  (natp n)
		  (>= n (+ p (expo x) (- (expo (spn q))) 2)))
	     (equal (drnd (rto x n) mode p q)
		    (drnd x mode p q))))

(defthmd drnd-rewrite
  (implies (and (rationalp x)
                (<= (abs x) (spn q))
                (common-mode-p mode)
                (integerp p)
                (> p 1)
                (integerp q)
                (> q 0))
           (equal (drnd x mode p q)
                  (- (rnd (+ x (* (sgn x) (spn q))) mode p)
		     (* (sgn x) (spn q))))))

(defthmd drnd-tiny
  (implies (and (common-mode-p mode)
                (natp p)
                (> p 1)
                (natp q)
                (> q 0)
                (rationalp x)
                (< 0 x)
                (< x (/ (spd p q) 2)))
           (equal (drnd x mode p q)
                  (if (member mode '(raz rup))
                      (spd p q)
                     0))))

(defthm drnd-tiny-equal
    (implies (and (common-mode-p mode)
                  (natp p)
                  (> p 1)
                  (natp q)
                  (> q 0)
                  (rationalp x)
                  (< 0 x)
                  (< (abs x) (/ (spd p q) 2))
                  (rationalp y)
                  (< 0 y)
                  (< (abs y) (/ (spd p q) 2)))
             (equal (drnd x mode p q)
                    (drnd y mode p q)))
    :rule-classes ())
)
