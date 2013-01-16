;; Processing Unicode Files with ACL2
;; Copyright (C) 2005-2006 by Jared Davis <jared@cs.utexas.edu>
;;
;; This program is free software; you can redistribute it and/or modify it
;; under the terms of the GNU General Public License as published by the Free
;; Software Foundation; either version 2 of the License, or (at your option)
;; any later version.
;;
;; This program is distributed in the hope that it will be useful but WITHOUT
;; ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
;; FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
;; more details.
;;
;; You should have received a copy of the GNU General Public License along with
;; this program; if not, write to the Free Software Foundation, Inc., 59 Temple
;; Place - Suite 330, Boston, MA 02111-1307, USA.

(in-package "ACL2")
(set-state-ok t)

(include-book "file-measure")
;; (local (include-book "open-input-channel"))
;; (local (include-book "read-char"))
;; (local (include-book "close-input-channel"))
(local (include-book "std/lists/revappend" :dir :system))
(local (include-book "tools/mv-nth" :dir :system))

(defun tr-read-char$-all (channel state acc)
  (declare (xargs :guard (and (state-p state)
                              (symbolp channel)
                              (open-input-channel-p channel :character state)
                              (true-listp acc))
                  :measure (file-measure channel state)))
  (if (mbt (state-p state))
      (mv-let (char state)
              (read-char$ channel state)
              (if (eq char nil)
                  (mv acc state)
                (tr-read-char$-all channel state (cons char acc))))
    (mv nil state)))

(defun read-char$-all (channel state)
  (declare (xargs :guard (and (state-p state)
                              (symbolp channel)
                              (open-input-channel-p channel :character state))
                  :measure (file-measure channel state)
                  :verify-guards nil))
  (mbe :logic (if (state-p state)
                  (mv-let (char state)
                          (read-char$ channel state)
                          (if (null char)
                              (mv nil state)
                            (mv-let (rest state)
                                    (read-char$-all channel state)
                                    (mv (cons char rest) state))))
                (mv nil state))
       :exec (mv-let (data state)
                     (tr-read-char$-all channel state nil)
                     (mv (reverse data) state))))

(defun read-file-characters (filename state)
  "Read the entire file and return its contents as a list of characters."
  (declare (xargs :guard (and (state-p state)
                              (stringp filename))
                  :verify-guards nil))
  (mv-let (channel state)
          (open-input-channel filename :character state)
          (if channel
              (mv-let (data state)
                      (read-char$-all channel state)
                      (let ((state (close-input-channel channel state)))
                        (mv data state)))
            (mv "Error opening file." state))))

(defun read-file-characters-rev (filename state)
  "Read the entire file and return its contents as a list of characters in
   reverse order.  This is faster than read-file-characters because it does
   not need to reverse the accumulator."
  (declare (xargs :guard (and (state-p state)
                              (stringp filename))
                  :verify-guards nil))
  (mv-let (channel state)
          (open-input-channel filename :character state)
          (if channel
              (mv-let (data state)
                      (tr-read-char$-all channel state nil)
                      (let ((state (close-input-channel channel state)))
                        (mv data state)))
            (mv "Error opening file." state))))

(local (defthm lemma-decompose-impl
         (equal (tr-read-char$-all channel state acc)
                (list (mv-nth 0 (tr-read-char$-all channel state acc))
                      (mv-nth 1 (tr-read-char$-all channel state acc))))
         :rule-classes nil))

(local (defthm lemma-decompose-spec
         (equal (read-char$-all channel state)
                (list (mv-nth 0 (read-char$-all channel state))
                      (mv-nth 1 (read-char$-all channel state))))
         :rule-classes nil))

(local (defthm lemma-data-equiv
         (implies (and (state-p1 state)
                       (symbolp channel)
                       (open-input-channel-p1 channel :character state)
                       (true-listp acc))
                  (equal (mv-nth 0 (tr-read-char$-all channel state acc))
                         (revappend (mv-nth 0 (read-char$-all channel state)) acc)))))

(local (defthm lemma-state-equiv
         (equal (mv-nth 1 (tr-read-char$-all channel state acc))
                (mv-nth 1 (read-char$-all channel state)))))

(local (defthm lemma-true-listp-impl
         (implies (true-listp acc)
                  (true-listp (mv-nth 0 (tr-read-char$-all channel state acc))))
         :rule-classes :type-prescription))

(local (defthm lemma-true-listp-spec
         (true-listp (mv-nth 0 (read-char$-all channel state)))
         :rule-classes :type-prescription))

(local (defthm lemma-equiv
         (implies (and (state-p1 state)
                       (symbolp channel)
                       (open-input-channel-p1 channel :character state))
                  (equal (tr-read-char$-all channel state nil)
                         (mv (reverse (mv-nth 0 (read-char$-all channel state)))
                             (mv-nth 1 (read-char$-all channel state)))))
         :hints(("Goal" :in-theory (disable tr-read-char$-all read-char$-all)
                 :use ((:instance lemma-decompose-impl (acc nil))
                       (:instance lemma-decompose-spec)
                       (:instance lemma-data-equiv (acc nil)))))))

(encapsulate
 ()
 (local (include-book "std/lists/rev" :dir :system))
 (verify-guards read-char$-all))


(defthm read-file-characters-rev-redefinition
  (implies (and (force (stringp filename))
                (force (state-p1 state)))
           (equal (read-file-characters-rev filename state)
                  (mv-let (data state)
                          (read-file-characters filename state)
                          (if (stringp data)
                              (mv data state)
                            (mv (reverse data) state))))))


(defthm read-char$-all-preserves-state
  (implies (and (force (state-p1 state))
                (force (symbolp channel))
                (force (open-input-channel-p1 channel :character state)))
           (state-p1 (mv-nth 1 (read-char$-all channel state)))))

(defthm read-char$-all-preserves-open-input-channel-p1
  (implies (and (force (state-p1 state))
                (force (symbolp channel))
                (force (open-input-channel-p1 channel :character state)))
           (open-input-channel-p1 channel :character
                                  (mv-nth 1 (read-char$-all channel state)))))

(defthm read-char$-all-character-listp
  (implies (and (force (state-p1 state))
                (force (symbolp channel))
                (force (open-input-channel-p1 channel :character state)))
           (character-listp (mv-nth 0 (read-char$-all channel state)))))

(verify-guards read-file-characters)

(verify-guards read-file-characters-rev)


(defthm read-file-characters-preserves-state
  (implies (and (force (state-p1 state))
                (force (stringp filename)))
           (state-p1 (mv-nth 1 (read-file-characters filename state)))))

(defthm read-file-characters-error-or-character-list
  (implies (and (not (stringp (mv-nth 0 (read-file-characters filename state))))
                (force (state-p1 state))
                (force (stringp filename)))
           (character-listp (mv-nth 0 (read-file-characters filename state)))))


(in-theory (disable tr-read-char$-all
                    read-char$-all
                    read-file-characters
                    read-file-characters-rev))
