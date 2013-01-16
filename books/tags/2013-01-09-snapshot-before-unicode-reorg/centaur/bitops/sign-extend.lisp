; Centaur Bitops Library
; Copyright (C) 2010-2011 Centaur Technology
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
; Original authors: Jared Davis <jared@centtech.com>
;                   Sol Swords <sswords@centtech.com>

(in-package "ACL2")
(include-book "xdoc/top" :dir :system)
(include-book "misc/definline" :dir :system)
(include-book "tools/bstar" :dir :system)
(include-book "ihs/logops-definitions" :dir :system)
(local (include-book "ihs-extensions"))

(defsection sign-extend
  :parents (bitops)
  :short "@(call sign-extend) interprets the least significant @('b') bits of
the integer @('x') as a signed number of with @('b')."

  :long "<p>This is logically identical to @(see logext).  But, for better
performance we adopt a method from Sean Anderson's <a
href='http://graphics.stanford.edu/~seander/bithacks.html'>bit twiddling
hacks</a> page, viz:</p>

@({
unsigned b;                  // number of bits representing the number in x
int x;                       // sign extend this b-bit number to r
int r;                       // resulting sign-extended number
int const m = 1U << (b - 1); // mask can be pre-computed if b is fixed
x = x & ((1U << b) - 1);     // (Skip this if bits in x above position b are already zero.)
r = (x ^ m) - m;
})

<p>@('sign-extend') is actually a macro.  Generally it expands into a call of
@('sign-extend-fn'), which carries out the above computation.  But in the
common cases where @('n') is explicitly 8, 16, 32, or 64, it instead expands
into a call of a specialized, inlined function.</p>"

  (definlined sign-extend-exec (b x)
    (declare (xargs :guard (and (posp b)
                                (integerp x))))
    (b* ((x1 (logand (1- (ash 1 b)) x)) ;; x = x & ((1U << b) - 1)
         (m  (ash 1 (- b 1))))          ;; int const m = 1U << (b - 1)
      (- (logxor x1 m) m)))             ;; r = (x ^ m) - m

  (local (defthmd equal-constant
           (implies (and (syntaxp (and (quotep x)
                                       (not (and (consp y)
                                                 (member (car y) '(logcar logcdr))))))
                         (integerp x))
                    (equal (equal x y)
                           (and (integerp y)
                                (equal (logcar x) (logcar y))
                                (equal (logcdr x) (logcdr y)))))))

  (local (defthm minus-in-terms-of-lognot
           (implies (integerp x)
                    (equal (- x)
                           (+ 1 (lognot x))))
           :hints(("Goal" :in-theory (enable lognot)))))

  (defthm sign-extend-exec-is-logext
    (implies (posp b)
             (equal (sign-extend-exec b x)
                    (logext b x)))
    :hints(("Goal" :in-theory (e/d* (ihsext-recursive-redefs
                                     ihsext-arithmetic
                                     ihsext-inductions
                                     sign-extend-exec
                                     equal-logcons-strong)
                                    (ash-1-removal
                                     logand-with-bitmask
                                     logand-with-negated-bitmask
                                     logxor->=-0-linear-2
                                     logxor-<-0-linear-2))
            :induct t)))


  (defun sign-extend-fn (b x)
    (declare (xargs :guard (and (posp b)
                                (integerp x))))
    (mbe :logic (logext b x)
         :exec (sign-extend-exec b x)))


  (local (defthm sign-extend8-crux
           (equal (+ #x-80 (logxor (logand #xFF x) #x80))
                  (logext 8 x))
           :hints(("Goal"
                   :in-theory (e/d (sign-extend-exec)
                                   (sign-extend-exec-is-logext))
                   :use ((:instance sign-extend-exec-is-logext (b 8)))))))

  (definline sign-extend8 (x)
    (declare (xargs :guard (integerp x)))
    (mbe :logic (logext 8 x)
         :exec (the (signed-byte 8)
                 (- (the (unsigned-byte 8)
                      (logxor (the (unsigned-byte 8) (logand #xFF x))
                              (the (unsigned-byte 8) #x80)))
                    #x80))))

  (local (defthm sign-extend16-crux
           (equal (+ #x-8000 (logxor (logand #xFFFF x) #x8000))
                  (logext 16 x))
           :hints(("Goal"
                   :in-theory (e/d (sign-extend-exec)
                                   (sign-extend-exec-is-logext))
                   :use ((:instance sign-extend-exec-is-logext (b 16)))))))

  (definline sign-extend16 (x)
    (declare (xargs :guard (integerp x)))
    (mbe :logic (logext 16 x)
         :exec (the (signed-byte 16)
                 (- (the (unsigned-byte 16)
                      (logxor (the (unsigned-byte 16) (logand #xFFFF x))
                              (the (unsigned-byte 16) #x8000)))
                    #x8000))))

  (local (defthm sign-extend32-crux
           (equal (+ #ux-8000_0000 (logxor (logand #uxFFFF_FFFF x) #ux8000_0000))
                  (logext 32 x))
           :hints(("Goal"
                   :in-theory (e/d (sign-extend-exec)
                                   (sign-extend-exec-is-logext))
                   :use ((:instance sign-extend-exec-is-logext (b 32)))))))

  (definline sign-extend32 (x)
    (declare (xargs :guard (integerp x)))
    (mbe :logic (logext 32 x)
         :exec (the (signed-byte 32)
                 (- (the (unsigned-byte 32)
                      (logxor (the (unsigned-byte 32) (logand #uxFFFF_FFFF x))
                              (the (unsigned-byte 32) #ux8000_0000)))
                    #ux8000_0000))))

  (local (defthm sign-extend64-crux
           (equal (+ #ux-8000_0000_0000_0000
                     (logxor (logand #uxFFFF_FFFF_FFFF_FFFF x)
                             #ux8000_0000_0000_0000))
                  (logext 64 x))
           :hints(("Goal"
                   :in-theory (e/d (sign-extend-exec)
                                   (sign-extend-exec-is-logext))
                   :use ((:instance sign-extend-exec-is-logext (b 64)))))))

  (definline sign-extend64 (x)
    (declare (xargs :guard (integerp x)))
    (mbe :logic (logext 64 x)
         :exec (the (signed-byte 64)
                 (- (the (unsigned-byte 64)
                      (logxor (the (unsigned-byte 64) (logand #uxFFFF_FFFF_FFFF_FFFF x))
                              (the (unsigned-byte 64) #ux8000_0000_0000_0000)))
                    #ux8000_0000_0000_0000))))


  (defmacro sign-extend (n x)
    (cond ((eql n 8)   `(sign-extend8 ,x))
          ((eql n 16)  `(sign-extend16 ,x))
          ((eql n 32)  `(sign-extend32 ,x))
          ((eql n 64)  `(sign-extend64 ,x))
          (t           `(sign-extend-fn ,n ,x))))

  (add-macro-alias sign-extend sign-extend-fn))




#||

;; Basic timing tests

(time (loop for i fixnum from 1 to 100000000 do (logext 4 i)))        ;; 5.787 sec
(time (loop for i fixnum from 1 to 100000000 do (logext 8 i)))        ;; 5.446 sec
(time (loop for i fixnum from 1 to 100000000 do (sign-extend 4 i)))   ;; 2.207 sec
(time (loop for i fixnum from 1 to 100000000 do (sign-extend 8 i)))   ;;  .669 sec

(time (loop for i fixnum from 1 to 100000000 do (logext 15 i)))       ;; 5.393 sec
(time (loop for i fixnum from 1 to 100000000 do (logext 16 i)))       ;; 5.381 sec
(time (loop for i fixnum from 1 to 100000000 do (sign-extend 15 i)))  ;; 2.208 sec
(time (loop for i fixnum from 1 to 100000000 do (sign-extend 16 i)))  ;;  .066 sec

(time (loop for i fixnum from 1 to 100000000 do (logext 31 i)))       ;; 5.284 sec
(time (loop for i fixnum from 1 to 100000000 do (logext 32 i)))       ;; 5.237 sec
(time (loop for i fixnum from 1 to 100000000 do (sign-extend 31 i)))  ;; 2.241 sec
(time (loop for i fixnum from 1 to 100000000 do (sign-extend 32 i)))  ;;  .066 sec

(time (loop for i fixnum from 1 to 100000000 do (logext 63 i)))       ;; 6.524 sec, 1.6 GB
(time (loop for i fixnum from 1 to 100000000 do (logext 64 i)))       ;; 6.942 sec, 3.2 GB
(time (loop for i fixnum from 1 to 100000000 do (sign-extend 63 i)))  ;; 42.5 sec (some gc), 12 GB!
(time (loop for i fixnum from 1 to 100000000 do (sign-extend 64 i)))  ;;  .066 sec

||#